from decision_tree import DecisionTree
from sklearn.datasets import load_breast_cancer
from sklearn.metrics import accuracy_score, classification_report
from sklearn.model_selection import train_test_split

# 1. Load the Breast Cancer dataset
# This dataset comes perfectly formatted as numpy arrays with integer targets (0 and 1)
data = load_breast_cancer()
X = data.data
y = data.target

# 2. Split into train and test sets
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)

print(f"Training on {len(X_train)} samples, each with 30 features...")

# 3. Instantiate and fit YOUR custom tree
# We are limiting depth to 5 so it doesn't overfit the training data
model = DecisionTree(max_depth=5, min_samples_split=2)
model.fit(X_train, y_train)

# 4. Generate predictions
print("Making predictions...")
pred = model.predict(X_test)

# 5. Evaluate using sklearn's metrics
accuracy = accuracy_score(y_test, pred)

print(f"\nAccuracy: {accuracy * 100:.2f}%\n")
print("Classification Report:")
print(classification_report(y_test, pred, target_names=data.target_names))