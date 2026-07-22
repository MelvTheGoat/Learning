import numpy as np # numerical python - used to handle arrays
from collections import Counter # this is need to count how many times an item appears in a list/array

class Node: 
    def __init__(self, feature=None, threshold=None, left=None, right=None, *, value=None): # constructor
        self.feature = feature # permanently store the object to a variable
        self.threshold = threshold
        self.left = left
        self.right = right
        self.value = value

    def is_leaf_node(self):
        return self.value is not None

class DecisionTree:
    def __init__(self, min_samples_split=2, max_depth=100):
        self.min_samples_split = min_samples_split
        self.max_depth = max_depth
        self.root = None
    
    def _entropy(self, y):
        hist = np.bincount(y)
        ps = hist / len(y)
        return -np.sum([p * np.log2(p) for p in ps if p > 0])
    
    def _split(self, X_column, split_thresh):
        left_index = np.argwhere(X_column <= split_thresh).flatten()
        right_index = np.argwhere(X_column > split_thresh).flatten()
        return left_index, right_index
    
    def _information_gain(self, y, X_column, threshold):
        parent_entropy = self._entropy(y)
        left_index, right_index = self._split(X_column, threshold)
        if len(left_index) == 0 or len(right_index) == 0:
            return 0
        n = len(y)
        n_l, n_r = len(left_index), len(right_index)
        e_l, e_r = self._entropy(y[left_index]), self._entropy(y[right_index])
        child_entropy = (n_l / n) * e_l + (n_r / n) * e_r

        information_gain = parent_entropy - child_entropy
        return information_gain
    
    def _best_split(self, X, y, feat_indexes):
        best_gain = -1
        split_index, split_threshold = None, None

        for feat_index in feat_indexes:
            X_column = X[:, feat_index]

            thresholds = np.unique(X_column)

            for thr in thresholds:
                gain = self._information_gain(y, X_column, thr)

                if gain > best_gain:
                    best_gain = gain
                    split_index = feat_index
                    split_threshold = thr

        return split_index, split_threshold
            
    def fit(self, X, y):
        self.root = self._grow_tree(X, y)

    def _grow_tree(self, X, y, depth=0):
        n_samples, n_feats = X.shape
        n_labels = len(np.unique(y)) # how many different target classe there are

        if (depth >= self.max_depth or n_labels == 1 or n_samples < self.min_samples_split):
            leaf_value = self._most_common_label(y)
            return Node(value=leaf_value)
        
        feat_indexes = np.arange(n_feats)
        best_feature, best_thresh = self._best_split(X, y, feat_indexes)
        
        left_indexes, right_indexes = self._split(X[:, best_feature], best_thresh)

        left_child = self._grow_tree(X[left_indexes, :], y[left_indexes], depth + 1)

        right_child = self._grow_tree(X[right_indexes, :], y[right_indexes], depth + 1)

        return Node(best_feature, best_thresh, left_child, right_child)
    
    def _most_common_label(self, y):
        counter = Counter(y)
        most_common = counter.most_common(1)[0][0]
        return most_common
    
    def predict(self, X):
        return np.array([self._traverse_tree(x, self.root) for x in X])
    
    def _traverse_tree(self, x, node):
        if node.is_leaf_node():
            return node.value
        
        if x[node.feature] <= node.threshold:
            return self._traverse_tree(x, node.left)
        else:
            return self._traverse_tree(x, node.right)