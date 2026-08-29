# ML Interview Practice — Set 3

20 questions in random order (no difficulty grouping this time), with my own answers.

---

**1. What is a Perceptron?**
A perceptron is the simplest unit of a neural network: it takes a set of inputs, multiplies each by a weight, sums them plus a bias, and passes the result through an activation function (originally a step function) to produce an output. A single perceptron can only learn linearly separable patterns — it's the building block that, stacked in layers with nonlinear activations, becomes a multilayer perceptron capable of learning much more complex functions.

**2. What is the vanishing gradient problem, and how do you detect it?**
As gradients are backpropagated through many layers (or time steps in an RNN), repeated multiplication by small derivative values — common with saturating activations like sigmoid/tanh — causes the gradient to shrink toward zero by the time it reaches early layers. Those layers then barely update, and training stalls. You can detect it by logging gradient norms per layer during training: if early-layer gradients are orders of magnitude smaller than later-layer ones, or the loss plateaus early despite a reasonable learning rate, vanishing gradients are a likely culprit.

**3. Explain Diffusion Models — why do they work better than autoregressive generation for images?**
Diffusion models learn to reverse a gradual noising process: starting from pure noise, the model is trained to iteratively denoise it step by step until a realistic sample emerges. Unlike autoregressive image generation (predicting pixels or patches one at a time in a fixed order), diffusion models generate the whole image jointly at each denoising step, which avoids compounding errors from a rigid sequential order and better captures global structure — this generally produces higher-fidelity, more coherent images, at the cost of needing many denoising steps at inference time.

**4. How do you handle outliers in a dataset?**
First, decide if the outlier is a genuine data error (mistyped value, sensor glitch) or a real extreme observation. For errors, correct or remove them. For real outliers, options include: capping/winsorizing (clip to a percentile), transforming the feature (log transform to compress the tail), using a robust scaler instead of standard scaling, or choosing models/losses that are naturally less sensitive to outliers (e.g. MAE over MSE, tree-based models). The right choice depends heavily on whether the outliers carry meaningful signal for your problem (e.g. fraud) or are just noise.

**5. What is Cross-Entropy loss, and why is it used for classification?**
Cross-entropy measures the difference between two probability distributions — the true label distribution (usually one-hot) and the model's predicted probability distribution. It heavily penalizes confident wrong predictions (predicting 0.01 probability for the true class incurs a large loss) more than squared error would, which gives much stronger gradients when the model is badly wrong — making it a better-behaved loss for training classifiers than MSE.

**6. Explain KV Cache in LLMs — what problem does it solve?**
During autoregressive generation, each new token's attention computation needs the key and value vectors of all previous tokens. Without caching, you'd recompute those K/V vectors for the entire sequence on every single new token — wasteful and slow. The KV cache stores the K/V vectors from previous steps so each new token only needs to compute its own K/V and attend using the cached ones, turning what would be quadratic recomputation into much cheaper incremental work — at the cost of memory that grows with sequence length.

**7. What is Q-Learning?**
Q-Learning is a model-free reinforcement learning algorithm that learns the expected cumulative reward (the "Q-value") of taking a given action in a given state, without needing a model of the environment's dynamics. It updates its Q-value estimates using the Bellman equation: current estimate is nudged toward the observed reward plus the discounted value of the best action in the next state. Over many episodes, this converges toward an optimal policy — at each state, just pick the action with the highest learned Q-value.

**8. What is Retrieval-Augmented Generation (RAG), and how does it differ from fine-tuning?**
RAG augments an LLM's input at inference time by retrieving relevant documents or passages from an external knowledge base (usually via vector similarity search) and feeding them into the prompt as context, so the model can ground its answer in that retrieved information. Fine-tuning instead updates the model's own weights on a task-specific dataset. RAG is cheaper, keeps knowledge up to date without retraining, and reduces hallucination on factual queries, but doesn't change the model's underlying behavior or reasoning style the way fine-tuning can.

**9. Explain the curse of dimensionality and how to address it.**
As the number of features grows, the volume of the feature space grows exponentially, so data points become increasingly sparse and "far apart" from each other — distance-based methods (KNN, clustering) start to break down because all points look roughly equidistant, and models need exponentially more data to maintain the same sample density. It's addressed with dimensionality reduction (PCA, feature selection), regularization, or simply gathering more data relative to the feature count.

**10. What is the difference between a generative and a discriminative model?**
A discriminative model learns the decision boundary directly — it models P(label | input), e.g. logistic regression, SVM. A generative model instead learns the full joint distribution P(input, label), which lets it also generate new data samples and reason about how likely an input is under each class, e.g. Naive Bayes, GANs, VAEs. Discriminative models are often simpler and perform better when you only care about classification accuracy; generative models are useful when you need to generate data, handle missing features, or reason about uncertainty in the data itself.

**11. How does Gradient Boosting work, and how does XGBoost improve on it?**
Gradient boosting builds an ensemble sequentially: each new tree is trained to predict the *residual errors* of the current ensemble (technically, the negative gradient of the loss with respect to current predictions), and its output is added, scaled by a learning rate, to correct those errors. XGBoost is an optimized implementation that adds regularization (L1/L2 on leaf weights) to reduce overfitting, uses a more efficient approximate split-finding algorithm, handles missing values natively, and is engineered for speed via parallelization and cache-aware computation.

**12. What is causal masking, and why does a decoder-only Transformer need it?**
Causal masking prevents a token's attention computation from "seeing" any tokens that come after it in the sequence — it's implemented by masking out (setting to -infinity before softmax) the attention scores to future positions. This is essential for autoregressive generation: since the model has to predict each next token using only what came before, letting it peek at future tokens during training would leak the answer and make the model useless at actual generation time.

**13. Explain RMSNorm and why it's used instead of LayerNorm in many LLMs.**
LayerNorm normalizes a layer's activations by subtracting the mean and dividing by the standard deviation, then applies a learned scale and shift. RMSNorm simplifies this by skipping the mean-centering step entirely and only normalizing by the root-mean-square of the activations, then applying a learned scale. It's cheaper to compute (fewer operations, no mean subtraction) while empirically performing about as well as LayerNorm in large Transformer models, which is why many modern LLMs (like LLaMA) use it to save compute at scale.

**14. What is model drift, and how do you detect/handle it in production?**
Model drift is when a deployed model's performance degrades over time because the real-world data distribution has shifted from what it was trained on — either the input feature distribution changes (data drift/covariate shift) or the relationship between inputs and the target changes (concept drift). You detect it by monitoring input feature distributions against a training-time baseline (e.g. with a KS-test or PSI), tracking live prediction distributions, and watching downstream business metrics. You handle it with scheduled or trigger-based retraining, or online/incremental learning if the domain allows it.

**15. Explain skip (residual) connections — what problem do they solve?**
A residual connection adds a layer's input directly to its output (`output = F(x) + x`) instead of only passing the transformed value forward. This gives gradients a direct, unimpeded path backward through the network during backpropagation, which mitigates vanishing gradients in very deep networks and makes it much easier to train architectures with many stacked layers (ResNets, Transformers) — the network only has to learn the *residual* correction needed on top of the identity mapping, rather than the full transformation from scratch.

**16. What is speculative decoding, and how does it speed up LLM inference?**
Speculative decoding uses a small, fast "draft" model to generate several candidate tokens ahead of time, then has the larger target model verify all of them in a single forward pass (instead of one token at a time). Any tokens the draft model got right are accepted immediately; the first one it got wrong is corrected by the target model, and generation continues from there. Since verifying several tokens in parallel is roughly as expensive as generating one with the full model, this can meaningfully speed up generation as long as the draft model's guesses are frequently correct.

**17. How would you systematically choose the optimal number of clusters (k) for k-means?**
Common approaches: the elbow method (plot within-cluster sum of squares against k, and look for the point where the marginal improvement flattens), the silhouette score (measures how well-separated and cohesive clusters are, and you pick the k that maximizes it), or the Davies-Bouldin index (lower is better, measuring cluster similarity). In practice I'd fit k-means across a range of k values, compute one or more of these metrics for each, plot the results, and pick the value where improvement clearly diminishes rather than eyeballing a single run.

**18. What is knowledge distillation, and why would you use it?**
Knowledge distillation trains a smaller "student" model to mimic the behavior of a larger, already-trained "teacher" model — typically by training the student to match the teacher's soft output probabilities (which carry more nuanced information than just the hard labels) rather than the ground truth labels alone. This lets you deploy a much smaller, faster, cheaper model that retains a large fraction of the teacher's performance, which is valuable for latency- or memory-constrained production environments (mobile, edge devices).

**19. What is the difference between MLE and MAP estimation?**
Maximum Likelihood Estimation picks the parameters that make the observed data most probable, based purely on the likelihood function — it has no notion of prior belief about the parameters. Maximum a Posteriori estimation adds a prior distribution over the parameters and picks the parameters that maximize the *posterior* (likelihood × prior), effectively regularizing the estimate toward values that are plausible a priori. In practice, many regularization techniques (like L2 regularization in linear regression) can be shown to be equivalent to MAP estimation with a specific choice of prior (a Gaussian prior, in L2's case).

**20. How would you handle missing or noisy GPS data in an ETA prediction model?**
For short gaps, linear or spline interpolation between known points usually works well. For noisy but continuous signals, a Kalman filter can smooth out sensor jitter while tracking the true underlying trajectory. Clear outliers — like GPS points that imply teleporting faster than physically possible — should be clipped or dropped rather than interpolated through. In production, I'd also build a fallback path: if live GPS signal drops out entirely, default to a historical average ETA for that route/time-of-day rather than failing the prediction outright.

## Coding Question

**Write code to perform k-fold cross-validation.**

This one has no linked reference solution, so here's a from-scratch implementation:

```python
import numpy as np

def k_fold_cross_validation(X, y, model_fn, k=5, seed=42):
    """
    model_fn: a function that takes (X_train, y_train, X_val, y_val)
              and returns a validation score (e.g. accuracy or MSE).
    """
    rng = np.random.default_rng(seed)
    n = len(X)
    indices = rng.permutation(n)
    fold_sizes = np.full(k, n // k)
    fold_sizes[: n % k] += 1  # distribute the remainder across folds

    scores = []
    current = 0
    for fold_size in fold_sizes:
        start, stop = current, current + fold_size
        val_idx = indices[start:stop]
        train_idx = np.concatenate([indices[:start], indices[stop:]])

        X_train, y_train = X[train_idx], y[train_idx]
        X_val, y_val = X[val_idx], y[val_idx]

        score = model_fn(X_train, y_train, X_val, y_val)
        scores.append(score)
        current = stop

    return np.array(scores), np.mean(scores), np.std(scores)
