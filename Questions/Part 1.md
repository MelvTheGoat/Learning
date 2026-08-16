# ML Interview Practice — Set 1

**Easy → Medium → Hard**, 20 questions with my own answers.

## Easy

**1. What is Machine Learning?**
Machine Learning is a way of building systems that learn patterns from data instead of being explicitly programmed with rules. You feed a model examples (input-output pairs, or just inputs), and it adjusts its internal parameters to capture the underlying pattern, so it can make predictions or decisions on new, unseen data.

**2. Differentiate between Supervised and Unsupervised Learning.**
Supervised learning trains on labeled data — you know the "correct answer" for each example (e.g. house price, spam/not spam), and the model learns to map inputs to those known outputs. Unsupervised learning works with unlabeled data — there's no correct answer given, and the model instead tries to find structure on its own, like grouping similar customers together (clustering) or reducing dimensions.

**3. What is the difference between Classification and Regression?**
Both are supervised learning tasks, but they predict different kinds of outputs. Classification predicts a discrete category (spam vs. not spam, cat vs. dog vs. bird). Regression predicts a continuous numeric value (house price, temperature tomorrow). The choice of algorithm, loss function, and evaluation metric all follow from which one you're doing.

**4. What is the main difference between Python lists and NumPy arrays in ML workflows?**
Python lists can hold mixed types and are flexible, but they're slow for numeric work because each element is a separate Python object with overhead. NumPy arrays store homogeneous data in contiguous memory blocks, which lets operations run as fast, vectorized C code instead of Python-level loops — this is why virtually all ML numeric work (matrix multiplication, gradient updates, etc.) is done in NumPy arrays, not lists.

**5. Explain Epoch, Batch, Batch Size, and Iteration.**
An epoch is one full pass through the entire training dataset. Since datasets are usually too large to process all at once, you split them into batches — a batch size is how many examples are in each batch. An iteration is one update step, i.e., processing one batch. So if you have 1,000 examples and a batch size of 100, one epoch = 10 iterations.

**6. What is one-hot encoding? When should you use it?**
One-hot encoding converts a categorical variable into a set of binary columns, one per category, where exactly one column is "1" and the rest are "0" for each row. It's used when a categorical feature has no inherent order (e.g. colors, city names) and you don't want the model to mistakenly infer a numeric relationship between categories (like assuming "red=1" is "less than" "blue=2"). It's less ideal for very high-cardinality features, where it can blow up dimensionality — target or embedding encoding is often better there.

**7. Why is feature scaling important?**
Many algorithms are sensitive to the magnitude of feature values. Distance-based methods (KNN, SVM, k-means) and gradient-based optimization (linear/logistic regression, neural nets) can be dominated by features with larger numeric ranges, or converge slowly/unevenly if features are on very different scales. Scaling (standardization or min-max normalization) puts features on comparable footing so the model treats them fairly and trains more efficiently. Tree-based models (decision trees, random forests, gradient boosting) are scale-invariant, so they generally don't need it.

## Medium

**8. Explain Overfitting and Underfitting. How can you prevent them?**
Overfitting is when a model learns the training data too well, including its noise, so it performs great on training data but poorly on new data — it has high variance. Underfitting is when a model is too simple to capture the underlying pattern at all, performing poorly even on training data — it has high bias. You prevent overfitting with more training data, regularization, dropout, simpler models, or early stopping. You prevent underfitting with a more expressive model, better features, or training longer/with less regularization.

**9. What is the bias-variance tradeoff?**
Bias is error from a model being too simple to capture the true relationship (leads to underfitting). Variance is error from a model being too sensitive to the specific training data it saw (leads to overfitting). As you increase model complexity, bias tends to go down but variance goes up, and vice versa — so there's a sweet spot of complexity that minimizes total error on unseen data, rather than one you can push to zero on both fronts simultaneously.

**10. Why are train/test splits important?**
If you evaluate a model on the same data it was trained on, you're measuring how well it memorized that data, not how well it generalizes. Holding out a separate test set that the model never sees during training gives you an honest estimate of real-world performance. It's also why you should never look at or tune based on the test set until the very end — otherwise you leak information and your estimate becomes optimistic again.

**11. What role does cross-validation play in ML evaluation?**
A single train/test split gives one performance number, which can vary a lot depending on which examples happened to land in the test set — especially with smaller datasets. K-fold cross-validation splits the data into k folds, trains on k-1 and validates on the remaining one, rotating through all k, then averages the results. This gives a more stable, reliable estimate of generalization performance and is especially useful when comparing models or tuning hyperparameters.

**12. What is Regularization? Explain L1 (Lasso) and L2 (Ridge) regularization.**
Regularization adds a penalty term to the loss function to discourage the model from fitting the training data too closely (i.e., it fights overfitting). L1 (Lasso) penalizes the sum of absolute weight values, which tends to push some weights all the way to zero — effectively doing feature selection. L2 (Ridge) penalizes the sum of squared weights, which shrinks weights smoothly toward zero without eliminating them, and tends to handle correlated features more gracefully than L1.

**13. What are Loss Functions and Cost Functions? Explain the key difference between them.**
A loss function measures the error for a single training example — e.g. squared error for one prediction. A cost function is the aggregate of the loss over the entire training set (or a batch), usually the average — this is what the optimizer actually minimizes during training. In casual usage people often use the terms interchangeably, but strictly speaking, loss = per-example, cost = overall.

**14. What's the limitation of accuracy as a metric in ML?**
Accuracy can be highly misleading on imbalanced datasets. If 99% of your data belongs to one class, a model that always predicts that class scores 99% accuracy while being completely useless at identifying the minority class. In cases like fraud detection or disease screening, you need metrics like precision, recall, F1, or AUC-ROC that actually reflect performance on the class you care about.

## Hard

**15. Explain how Logistic Regression differs from Linear Regression.**
Linear regression predicts a continuous value directly as a linear combination of inputs, and is trained by minimizing squared error. Logistic regression is used for classification — it takes that same linear combination and squashes it through a sigmoid function to output a probability between 0 and 1, and is trained by minimizing log loss (cross-entropy) rather than squared error, because squared error isn't a well-behaved loss for probability outputs. The decision boundary in logistic regression is still linear in the input space, but the output itself is nonlinear.

**16. Explain the bias-variance tradeoff as if you were debugging a loan-approval model drifting in production — what diagnostics would you use?**
I'd start by plotting learning curves (training vs. validation error as training set size grows) to see whether the gap suggests high variance (overfitting to old data patterns) or high bias (model too simple to capture new patterns). I'd also look at residual distributions and compare recent live predictions against the training-time distribution to check for data drift — has the applicant population or their feature distributions shifted? If it's variance-driven, I'd increase regularization or simplify the model; if it's bias-driven or drift-driven, I'd retrain on more recent data or add features that capture the new pattern.

**17. How are PCA and k-means mathematically related, and why might you apply PCA before clustering?**
Both PCA and k-means are, in a sense, optimizing variance-related objectives: PCA finds orthogonal directions that capture the maximum variance in the data, while k-means tries to minimize within-cluster variance (distance to centroids). There's a known result that the cluster indicator structure from k-means relates to the top principal components of the data — the first few PCA components approximate cluster-separating directions. Practically, applying PCA before k-means removes noisy or redundant correlated dimensions and speeds up distance computations, since k-means struggles in very high-dimensional spaces where distances become less meaningful (the curse of dimensionality).

**18. Can you prove — or at least sketch why — the standard k-means algorithm is guaranteed to converge?**
Each iteration has two steps: assign every point to its nearest centroid, then recompute each centroid as the mean of its assigned points. Reassigning to the nearest centroid can only decrease or keep constant the total within-cluster sum of squared distances (inertia) — you'd only reassign a point if doing so lowers its distance. Recomputing the centroid as the mean is provably the point that minimizes the sum of squared distances to a fixed set of points. So both steps monotonically decrease (or hold steady) a quantity that's bounded below by zero, and since there are only finitely many ways to partition n points into k clusters, the algorithm can't keep improving forever — it must stabilize in finite steps. (Note: it converges to *a* local optimum, not necessarily the global one — that's why k-means++ initialization or multiple restarts matter.)

**19. Why doesn't simply adding more trees always improve a random-forest model?**
Random forest's error breaks down into bias and variance. Bias is essentially fixed by tree depth and feature sampling, and doesn't change as you add more trees. Variance decreases as you average more trees, but with diminishing returns — after a certain point, each additional tree barely reduces the ensemble's variance further, while cost (training time, memory, inference latency) keeps growing linearly. In practice you'd plot out-of-bag error against the number of trees and look for where the curve flattens, rather than assuming "more trees = always better."

**20. Why do highly correlated features distort feature-importance scores in a random forest?**
When two features carry overlapping information, the tree-building process can split on either one to achieve a similar drop in impurity, essentially at random depending on which one happens to be considered first at a given split. This splits the "true" importance of that underlying signal between the two correlated features, making each look individually less important than it really is, and makes the importance ranking unstable across different runs or bootstrap samples. It's usually addressed by checking a correlation matrix and dropping/combining redundant features, or by using permutation importance or SHAP values, which handle correlated features more robustly than the default impurity-based importance.

## Coding Question

**Write a Python function to compute the mean squared error (MSE).**

How to approach it: MSE is the average of the squared differences between predicted and actual values — `mean((y_true - y_pred) ** 2)`. Write it to accept two equal-length arrays (lists or NumPy arrays), validate the lengths match and neither is empty, and use vectorized NumPy subtraction rather than a manual Python loop for speed and clarity. Once you've written your version, compare it against the reference implementation below.

→ [Solution](https://github.com/amitshekhariitbhu/build-your-own-x-machine-learning/blob/main/tutorials/core-machine-learning-algorithms/mean-squared-error/mean_squared_error.py)
