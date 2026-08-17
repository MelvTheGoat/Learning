# ML Interview Practice — Set 2

**Easy → Medium → Hard**, 20 questions with my own answers.

## Easy

**1. What are precision, recall, and F1-score?**
Precision is the share of predicted positives that were actually correct: TP / (TP + FP). Recall is the share of actual positives your model successfully caught: TP / (TP + FN). F1 is the harmonic mean of the two, which penalizes a large gap between them more than a simple average would — useful when both false positives and false negatives carry real cost, like fraud detection or medical screening.

**2. What is the ROC curve, and how is AUC interpreted?**
The ROC curve plots the true positive rate against the false positive rate as you sweep the classification threshold from 0 to 1. AUC (area under that curve) is the probability that a randomly chosen positive example is ranked higher than a randomly chosen negative one. AUC of 1.0 means perfect separation, 0.5 means the model is no better than random guessing. It's popular because it's threshold-independent, unlike accuracy.

**3. What is a confusion matrix, and how do you interpret it?**
A confusion matrix is a table showing true positives, false positives, true negatives, and false negatives for a classifier's predictions vs. actual labels. Reading it tells you not just how many errors a model makes, but what *kind* — e.g. is it mostly missing positives (high false negatives) or over-flagging negatives (high false positives)? All the standard metrics (precision, recall, F1) are derived directly from it.

**4. What is dropout, and why is it used?**
During training, dropout randomly deactivates a fraction of neurons on each forward pass, so the network can't rely too heavily on any single neuron or a small co-adapted group of them. This effectively trains many "thinned" sub-networks that get averaged together at inference time, which reduces overfitting and improves generalization.

**5. What is batch normalization, and why is it used?**
Batch norm normalizes a layer's inputs using the mean and variance of the current mini-batch, then rescales/shifts them with learnable parameters. This keeps activations in a stable range as training progresses, which allows higher learning rates, speeds up convergence, and provides a mild regularizing effect.

**6. What is data augmentation, and what techniques are commonly used?**
Data augmentation artificially expands a training set by applying label-preserving transformations to existing examples, which helps the model generalize better and reduces overfitting, especially when data is limited. For images: rotation, flipping, cropping, color jitter, and noise injection. For text: synonym replacement, back-translation. For audio: pitch shifting, time stretching, adding background noise.

**7. What is Word2Vec?**
Word2Vec is a technique for learning dense vector representations (embeddings) of words based on the context they appear in, under the idea that words with similar meanings appear in similar contexts. It's trained via one of two setups: CBOW (predict a word from its surrounding context) or Skip-gram (predict surrounding context from a word). The resulting vectors capture semantic relationships — famously, "king − man + woman ≈ queen."

## Medium

**8. What is the difference between bagging and boosting?**
Bagging (e.g. Random Forest) trains many models in parallel on bootstrapped samples of the data and averages their predictions — this mainly reduces variance. Boosting (e.g. XGBoost, AdaBoost) trains models sequentially, where each new model focuses on correcting the mistakes of the previous ones — this mainly reduces bias, but is more prone to overfitting on noisy or mislabeled data since it keeps chasing hard examples.

**9. How does the Random Forest algorithm improve over Decision Trees? How does it reduce variance?**
A single decision tree tends to overfit — it can carve very specific, high-variance splits from the training data. Random Forest trains many trees on bootstrapped samples, and at each split only considers a random subset of features, which decorrelates the trees from each other. Averaging (or majority voting) across many decorrelated trees cancels out a lot of the individual variance while keeping bias about the same, since errors that are uncorrelated tend to wash out when you average them.

**10. Explain Support Vector Machines (SVM). What is the kernel trick?**
SVM finds the hyperplane that separates classes with the maximum margin — the widest possible gap between the decision boundary and the closest points of each class (the support vectors). When classes aren't linearly separable in the original feature space, the kernel trick implicitly maps the data into a higher-dimensional space where a linear separator does work — without ever explicitly computing that mapping. It works because the SVM optimization only needs dot products between points, and a kernel function computes what that dot product *would be* in the higher-dimensional space directly, cheaply.

**11. Explain Convolutional Neural Networks (CNN) — filters, stride, padding, and pooling.**
A CNN slides small learnable filters (kernels) across the input, each one detecting a pattern (an edge, texture, shape) wherever it appears — this makes CNNs translation-invariant and far more parameter-efficient than fully connected layers on image data. Stride controls how far the filter moves each step (a larger stride shrinks the output and reduces overlap). Padding adds a border (usually zeros) around the input so filters can center on edge pixels too, and lets you control the output size. Pooling (typically max pooling) downsamples the feature map, retaining the strongest activations while reducing computation and making the representation more robust to small shifts in the input.

**12. What are the limitations of RNNs, and how do LSTM/GRU solve them?**
Vanilla RNNs struggle with long sequences because gradients either vanish or explode as they're backpropagated through many time steps, so the network effectively "forgets" information from early in the sequence. LSTMs and GRUs introduce gating mechanisms (forget/input/output gates in LSTM, reset/update gates in GRU) that let the network explicitly learn what to keep, update, or discard in its memory state. This gives gradients a more direct path backward through time, so long-range dependencies survive much better than in a plain RNN.

**13. How do you approach a dataset with highly imbalanced classes?**
A combination of techniques usually works best: resampling (oversampling the minority class, e.g. SMOTE, or undersampling the majority), assigning class weights in the loss function so the model is penalized more for missing the rare class, and picking evaluation metrics that aren't fooled by imbalance — precision, recall, F1, or AUC-PR instead of raw accuracy. In extreme imbalance cases (fraud, rare disease), it's sometimes better to reframe the problem as anomaly detection entirely.

**14. Explain Grid Search vs Random Search vs Bayesian Optimization.**
Grid search exhaustively tries every combination of hyperparameters in a predefined grid — thorough but scales terribly as the number of parameters grows. Random search samples random combinations from the search space instead, which in practice often finds a comparably good result much faster, since not all hyperparameters matter equally. Bayesian optimization goes further by building a probabilistic model of how hyperparameters affect performance, using past trial results to intelligently choose which combination to try next — usually the most sample-efficient of the three, at the cost of extra complexity.

## Hard

**15. Why do we scale the dot product attention by √dₖ in the Transformer architecture?**
Attention scores start as the dot product between query and key vectors. As the dimensionality dₖ of those vectors grows, the dot products tend to grow large in magnitude too (assuming roughly independent, zero-mean components), which pushes the softmax into regions where its gradient is nearly zero (it saturates, producing very peaked, near-one-hot outputs). Dividing by √dₖ keeps the scores in a range where softmax stays well-behaved and gradients keep flowing properly during training.

**16. What is a Variational Autoencoder (VAE), and how does it differ from a standard autoencoder?**
A standard autoencoder compresses input into a fixed latent vector and reconstructs it, with no constraint on what that latent space looks like — so it can be sparse and full of "gaps" that don't correspond to realistic outputs if you sample from it. A VAE instead encodes each input as a *distribution* (a mean and variance) over the latent space, and is trained with an added KL-divergence term that pushes those distributions toward a standard normal prior. This makes the latent space continuous and well-structured, so sampling any point from it (or interpolating between two encoded points) tends to produce a plausible, coherent output — which is what makes VAEs useful as generative models, unlike plain autoencoders.

**17. What is mode collapse in GANs, and how can it be mitigated?**
Mode collapse happens when the generator learns to produce only a narrow subset of the possible outputs (sometimes even a single one) that reliably fools the discriminator, rather than capturing the full diversity of the real data distribution. It happens because the generator is only optimizing to fool the current discriminator, not to match the true data distribution broadly. Mitigations include mini-batch discrimination (letting the discriminator compare samples within a batch, so it can spot a lack of diversity), unrolled GANs, feature matching losses, or using alternative formulations like Wasserstein GAN that provide smoother, more informative gradients.

**18. How does back-propagation actually compute gradients, and what pitfalls should you watch for?**
Back-propagation applies the chain rule layer by layer, starting from the loss and working backward: for each layer, it computes how much the loss changes with respect to that layer's output (using the gradient already computed for the next layer), then converts that into gradients with respect to that layer's weights and its input, which gets passed further back. Common pitfalls: vanishing gradients (especially with saturating activations like sigmoid/tanh in deep networks), exploding gradients (especially in RNNs over long sequences), and poor weight initialization amplifying either problem. Mitigations include ReLU-family activations, batch normalization, gradient clipping, and initialization schemes like Xavier/He that keep activation variance stable across layers.

**19. What is Grouped-Query Attention (GQA), and how does it differ from Multi-Head Attention (MHA)?**
In standard Multi-Head Attention, every attention head has its own separate set of query, key, and value projections. GQA groups multiple query heads to share the same key/value projections, while each still has its own query — a middle ground between full MHA (every head has its own K/V, most expressive, most memory) and Multi-Query Attention (all heads share one K/V, cheapest but can lose quality). The main motivation is inference efficiency: sharing K/V across grouped heads shrinks the KV cache substantially, speeding up generation with only a small quality trade-off compared to full MHA.

**20. What is Mixture of Experts (MoE), and how does it work in models like Mixtral?**
Instead of routing every input through the full set of the model's parameters, an MoE layer contains many "expert" sub-networks (typically feed-forward blocks) and a small router network that, for each token, selects only a handful of experts (e.g. top-2) to actually process it. This means the *total* parameter count can be huge, but the compute cost per token stays low since only a fraction of the parameters are active — it decouples model capacity from inference cost, which is the core appeal over a dense model of equivalent total size.

## Coding Question

**Implement K-Nearest Neighbors (KNN).**

How to approach it: for a query point, compute its distance (usually Euclidean) to every point in the training set, sort by distance, take the k closest, and for classification return the majority class among them (for regression, return their average). Vectorize the distance computation with NumPy broadcasting instead of looping point-by-point — it's much faster and is what interviewers usually want to see. Worth mentioning: KNN has no real "training" step (it's lazy learning — all the work happens at prediction time), and you should scale your features first since it's a distance-based method.

→ [Solution](https://github.com/amitshekhariitbhu/build-your-own-x-machine-learning/blob/main/tutorials/core-machine-learning-algorithms/knn/knn.py)
