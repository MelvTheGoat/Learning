import numpy as np # numerical python - used to handle arrays and math efficiently
from collections import Counter # this is needed to count how many times an item appears in a list/array

class Node: 
    # The blueprint for a single point in the tree. It can be a question (decision) or an answer (leaf).
    def __init__(self, feature=None, threshold=None, left=None, right=None, *, value=None): 
        self.feature = feature # Stores the column index we are asking a question about (e.g., column 3)
        self.threshold = threshold # Stores the exact number we are splitting on (e.g., 2.5)
        self.left = left # A pointer to the next Node if the answer to the question is True
        self.right = right # A pointer to the next Node if the answer to the question is False
        self.value = value # If this node is a dead-end leaf, it holds the final prediction (e.g., "Malignant")

    def is_leaf_node(self):
        # A quick check: if 'value' has data in it, we are at the end of the branch.
        return self.value is not None

class DecisionTree:
    # The main engine that builds the rules and makes the predictions.
    def __init__(self, min_samples_split=2, max_depth=100):
        self.min_samples_split = min_samples_split # The smallest pile of data allowed before we refuse to split it further
        self.max_depth = max_depth # The maximum number of levels down the tree can grow (prevents infinite loops)
        self.root = None # The starting point of our tree, which starts empty
    
    def _entropy(self, y):
        # Measures how "messy" a pile of data is. 0 means perfect purity, higher means chaotic.
        hist = np.bincount(y) # Counts how many of each class are in the pile (e.g., 50 benign, 10 malignant)
        ps = hist / len(y) # Converts those raw counts into percentages/probabilities
        # Runs the probabilities through the entropy math formula. We skip 0s because log2(0) crashes the program.
        return -np.sum([p * np.log2(p) for p in ps if p > 0]) 
    
    def _split(self, X_column, split_thresh):
        # Physically divides the data into two piles based on a threshold.
        left_index = np.argwhere(X_column <= split_thresh).flatten() # Grabs the row numbers that pass the test
        right_index = np.argwhere(X_column > split_thresh).flatten() # Grabs the row numbers that fail the test
        return left_index, right_index # Hands back the two separated lists of row numbers
    
    def _information_gain(self, y, X_column, threshold):
        # Calculates how much a specific question reduces the chaos in the data.
        parent_entropy = self._entropy(y) # Measures the messiness of the whole pile before splitting
        
        left_index, right_index = self._split(X_column, threshold) # Tries splitting the pile based on the test threshold
        
        if len(left_index) == 0 or len(right_index) == 0:
            return 0 # If the split moved 100% of the data to one side, it was a useless split, return 0 gain.
            
        n = len(y) # Total number of items in the parent pile
        n_l, n_r = len(left_index), len(right_index) # Total number of items in the new child piles
        
        e_l, e_r = self._entropy(y[left_index]), self._entropy(y[right_index]) # Measures the messiness of the children
        
        child_entropy = (n_l / n) * e_l + (n_r / n) * e_r # Averages the children's chaos, weighted by how big the piles are

        information_gain = parent_entropy - child_entropy # Subtracts the new chaos from the old chaos. Bigger number = better split!
        return information_gain
    
    def _best_split(self, X, y, feat_indexes):
        # The brute-force search: tests every single value in every single column to find the best question.
        best_gain = -1 # Starts the high score at -1 so any valid split will immediately beat it
        split_index, split_threshold = None, None # Placeholders to memorize the winning column and value

        for feat_index in feat_indexes:
            # Loop through every single column we are allowed to look at
            X_column = X[:, feat_index] # Extract all the data for just this specific column

            thresholds = np.unique(X_column) # Grab only the unique values so we don't waste time testing duplicates

            for thr in thresholds:
                # Test every single unique value to see how good of a split it creates
                gain = self._information_gain(y, X_column, thr)

                if gain > best_gain:
                    # If this split beats our current high score, overwrite the leaderboard!
                    best_gain = gain
                    split_index = feat_index
                    split_threshold = thr

        return split_index, split_threshold # Hand back the absolute best column and threshold combination we found
            
    def fit(self, X, y):
        # The public method a user calls to train the model.
        self.root = self._grow_tree(X, y) # Kicks off the recursive tree-building and saves the final result to root.

    def _grow_tree(self, X, y, depth=0):
        # The recursive engine that actually builds the branches. It repeatedly splits data and calls itself.
        n_samples, n_feats = X.shape # Counts how many rows and columns are in the current pile
        n_labels = len(np.unique(y)) # Counts how many unique classes are left (1 means it's a perfectly pure pile)

        if (depth >= self.max_depth or n_labels == 1 or n_samples < self.min_samples_split):
            # THE BRAKES: If we hit max depth, or the pile is pure, or the pile is too small, stop splitting!
            leaf_value = self._most_common_label(y) # Hold a vote to see what the final answer should be for this pile
            return Node(value=leaf_value) # Create and return a dead-end leaf node with that final answer
        
        feat_indexes = np.arange(n_feats) # Create a list of all column numbers (0, 1, 2...) to test
        best_feature, best_thresh = self._best_split(X, y, feat_indexes) # Run the brute force search to find the best question
        
        left_indexes, right_indexes = self._split(X[:, best_feature], best_thresh) # Physically divide the pile into two based on the winning question

        # The Magic Leap: Pause this node, and call the exact same function on the left pile, increasing the depth by 1
        left_child = self._grow_tree(X[left_indexes, :], y[left_indexes], depth + 1)

        # Do the exact same thing for the right pile
        right_child = self._grow_tree(X[right_indexes, :], y[right_indexes], depth + 1)

        # Package the winning question and the two finished branches into a brand new Node object
        return Node(best_feature, best_thresh, left_child, right_child)
    
    def _most_common_label(self, y):
        # Helper to find the majority class in a pile (e.g., if there are 8 dogs and 2 cats, dogs win).
        counter = Counter(y) # Counts occurrences (e.g., Counter({0: 8, 1: 2}))
        most_common = counter.most_common(1)[0][0] # Extracts just the name of the winner (the '0')
        return most_common
    
    def predict(self, X):
        # Public method to guess the class for a whole batch of new, unseen data.
        # Loops through every row, drops it down the tree, and packages the results in a NumPy array.
        return np.array([self._traverse_tree(x, self.root) for x in X])
    
    def _traverse_tree(self, x, node):
        # The Plinko game: navigates a single row of data down the branches based on the rules we learned.
        if node.is_leaf_node():
            # If we hit a dead end, stop searching and hand back the final answer.
            return node.value
        
        if x[node.feature] <= node.threshold:
            # Check the new data against the question. If True, drop the data down the left branch.
            return self._traverse_tree(x, node.left)
        else:
            # If False, drop the data down the right branch.
            return self._traverse_tree(x, node.right)
