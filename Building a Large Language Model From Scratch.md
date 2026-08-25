# What this example actually builds, in one sentence

A tiny transformer — the same architecture family as GPT — trained on
two toy sentences to predict the next word, built from six components
stacked in a specific order, each one solving a problem the previous
one couldn't.

That "each one solves a problem the previous couldn't" framing is the
thread to teach with. If you present the six steps as a checklist, it
sounds arbitrary. If you present each one as "here's what breaks without
this," it becomes obvious why a transformer needs exactly these parts.

---

# Step 1 — Tokenization

```python
def tokenize(text, vocab):
    return [vocab.get(word, vocab["<UNK>"]) for word in text.split()]
```

**The problem this solves:** neural networks only do arithmetic on
numbers. A word like `"hello"` means nothing to a matrix multiplication.
Tokenization is the translation step — every word gets mapped to an
integer ID via a lookup table (`vocab`), so `"hello world"` becomes
something like `[0, 1]`.

**Reading the line itself:** `text.split()` breaks a sentence into words
on whitespace — the simplest possible tokenizer, splitting only on
spaces. `vocab.get(word, vocab["<UNK>"])` is a dictionary lookup with a
fallback: if the word exists in `vocab`, return its ID; if not, return
the ID for `<UNK>` (unknown). That fallback matters — without it, the
first unfamiliar word the model ever saw would crash the whole pipeline
with a `KeyError`.

**Teaching point to emphasize:** this is a toy tokenizer, and saying so
explicitly is important. Real tokenizers (like GPT's) split on
*subwords*, not whole words — so `"tokenization"` might become
`["token", "ization"]`. That's why real vocabularies only need ~50,000
entries to cover essentially any English text, while a whole-word
tokenizer would need millions of entries and still choke on typos or
made-up words.

---

# Step 2 — Embedding layer

```python
class Embedding(nn.Module):
    def __init__(self, vocab_size, embedding_dim):
        super(Embedding, self).__init__()
        self.embedding = nn.Embedding(vocab_size, embedding_dim)

    def forward(self, x):
        return self.embedding(x)
```

**The problem this solves:** the integer IDs from Step 1 are arbitrary.
If `"hello"` is `0` and `"world"` is `1`, the number `1` doesn't mean
"more" or "bigger" than `0` — it's just a label. But a neural network's
math assumes numbers carry meaningful relationships. Embeddings replace
each ID with a whole *vector* of numbers (say, 16 of them) that the model
learns during training, so that words with similar meanings end up with
similar vectors.

**Reading the line itself:** `nn.Embedding(vocab_size, embedding_dim)` is
PyTorch's built-in embedding table — internally it's just a matrix of
shape `(vocab_size, embedding_dim)`, one row per word. `forward(self, x)`
takes a batch of word IDs and looks up their rows — this is a lookup
operation, not a computation; nothing is calculated here, it's indexing
into the table.

**Teaching point to emphasize:** the embedding table starts out
*random*. The vectors only start meaning anything once training (Step 7)
adjusts them via backpropagation. This is a common point of confusion —
people assume embeddings are pre-loaded with meaning, when actually
they're learned from scratch here, the same way every other weight in
the network is.

---

# Step 3 — Positional encoding

```python
class PositionalEncoding(nn.Module):
    def __init__(self, embedding_dim, max_seq_len=5000):
        super(PositionalEncoding, self).__init__()
        self.embedding_dim = embedding_dim
        pe = torch.zeros(max_seq_len, embedding_dim)
        position = torch.arange(0, max_seq_len, dtype=torch.float).unsqueeze(1)
        div_term = torch.exp(torch.arange(0, embedding_dim, 2).float() * (-math.log(10000.0) / embedding_dim))
        pe[:, 0::2] = torch.sin(position * div_term)
        pe[:, 1::2] = torch.cos(position * div_term)
        pe = pe.unsqueeze(0).transpose(0, 1)
        self.register_buffer('pe', pe)

    def forward(self, x):
        return x + self.pe[:x.size(0), :]
```

**The problem this solves — the most important conceptual point in the
whole example.** Self-attention (Step 4) looks at *all* words in a
sentence simultaneously, with no built-in sense of order — it treats a
sentence like a bag of words thrown on a table. That means, without
fixing this, the model would see "I love you" and "you love I" as
identical. Positional encoding injects information about *where* each
word sits in the sequence, added directly into its embedding vector.

**Reading the line itself, piece by piece:**
- `pe = torch.zeros(max_seq_len, embedding_dim)` — an empty table, one
  row per possible position in a sequence (up to 5000), one column per
  embedding dimension.
- `position = torch.arange(...).unsqueeze(1)` — just the numbers
  `0, 1, 2, 3, ...` representing "this is word 0, this is word 1," etc.
- `div_term` — a set of different frequencies. This is the part that
  looks like unreadable math but has a simple purpose: it creates a
  *different wave frequency for each embedding dimension*, so position
  5 and position 6 don't just differ by a constant — they produce
  genuinely distinct patterns across the whole vector.
- `torch.sin(...)` / `torch.cos(...)` — alternating sine and cosine
  waves are used specifically because they let the model infer *relative*
  position (how far apart two words are) through simple trigonometric
  relationships, not just absolute position.
- `self.register_buffer('pe', pe)` — tells PyTorch "this tensor is part
  of the model's state, but it's not a learnable parameter." It's fixed
  math, computed once, never updated by training.
- `forward`: literally just adds the positional pattern on top of the
  word embedding. Same shape, added element-wise.

**Teaching point to emphasize:** the sine/cosine formula is genuinely the
least intuitive part of a transformer for most people, and it's fine to
teach it as "a deterministic, mathematically clever way to stamp
`(position, dimension)` pairs), so nearby positions get similar patterns
and distant ones don't" without deriving the full trigonometric identity
that makes relative-position inference work. Understanding *why it's
needed* (Step 4 has no order awareness) matters far more than the exact
derivation.

---

# Step 4 — Self-attention

```python
class SelfAttention(nn.Module):
    def __init__(self, embedding_dim):
        super(SelfAttention, self).__init__()
        self.query = nn.Linear(embedding_dim, embedding_dim)
        self.key = nn.Linear(embedding_dim, embedding_dim)
        self.value = nn.Linear(embedding_dim, embedding_dim)

    def forward(self, x):
        queries = self.query(x)
        keys = self.key(x)
        values = self.value(x)
        scores = torch.bmm(queries, keys.transpose(1, 2)) / torch.sqrt(torch.tensor(x.size(-1), dtype=torch.float32))
        attention_weights = torch.softmax(scores, dim=-1)
        attended_values = torch.bmm(attention_weights, values)
        return attended_values
```

**The problem this solves:** not every word in a sentence matters equally
to understanding any other word. In "The cat sat on the mat," the word
"sat" is more related to "cat" (who sat) than to "mat" (where). Self-
attention lets the model learn, for every word, how much to "pay
attention to" every other word when building its representation.

**Reading the line itself:**
- `self.query`, `self.key`, `self.value` — three separate learned linear
  transformations of the same input. This is the part worth explaining
  with the analogy already in the notebook, because it's genuinely the
  clearest way in: think of it as a search engine. **Query** = what this
  word is looking for. **Key** = what each word (including itself) has
  to offer, as a label. **Value** = the actual content each word would
  hand over if selected. All three start as *the same input vector* but
  get pushed through three different learned matrices, so the network
  can learn to use the same word differently depending on whether it's
  doing the "asking" or the "offering."
- `torch.bmm(queries, keys.transpose(1, 2))` — batch matrix multiply.
  This computes a similarity score between every query and every key —
  literally, "how well does what I'm looking for match what you're
  offering," for every pair of words in the sentence.
- `/ torch.sqrt(...)` — scaling down the scores by the square root of the
  embedding dimension. Without this, scores can grow very large as
  `embedding_dim` grows, which pushes the next step (softmax) into a
  regime where gradients vanish and training stalls. This single division
  is why the mechanism is called "**scaled** dot-product attention."
- `torch.softmax(scores, dim=-1)` — converts raw scores into a
  probability distribution that sums to 1 across each row — e.g., "70%
  attention on 'cat', 30% on 'mat'."
- `torch.bmm(attention_weights, values)` — uses those probabilities to
  compute a weighted average of the value vectors. The output for each
  word is now a blend, weighted by relevance, of every other word's
  content.

**Teaching point to emphasize:** this example implements *single-head*
attention — one query/key/value transformation per layer. Real models use
*multi-head* attention: several of these running in parallel, each
potentially learning to focus on a different kind of relationship
(grammar, meaning, position). Naming this gap explicitly is exactly what
the notebook's own final cell does, and it's worth repeating when you
teach this — self-attention here is the mechanism in its simplest,
single-head form.

---

# Step 5 — Transformer block

```python
class TransformerBlock(nn.Module):
    def __init__(self, embedding_dim, hidden_dim):
        super(TransformerBlock, self).__init__()
        self.attention = SelfAttention(embedding_dim)
        self.feed_forward = nn.Sequential(
            nn.Linear(embedding_dim, hidden_dim),
            nn.ReLU(),
            nn.Linear(hidden_dim, embedding_dim)
        )
        self.norm1 = nn.LayerNorm(embedding_dim)
        self.norm2 = nn.LayerNorm(embedding_dim)

    def forward(self, x):
        attended = self.attention(x)
        x = self.norm1(x + attended)
        forwarded = self.feed_forward(x)
        x = self.norm2(x + forwarded)
        return x
```

**The problem this solves:** self-attention alone only *mixes*
information between words — it doesn't add new processing capacity or
help the network train reliably at depth. A transformer block wraps
attention with a small feed-forward network for additional processing,
and two stabilization mechanisms that make stacking many of these blocks
actually trainable.

**Reading the line itself:**
- `self.feed_forward` — a plain two-layer MLP (Linear → ReLU → Linear),
  applied independently to each word's vector. This is where the model
  does extra, non-attention-based computation on what it just gathered.
- `x = self.norm1(x + attended)` — this is a **residual connection**
  (`x + attended`) followed by **layer normalization**. The residual
  connection adds the block's *input* back onto its *output*, which is a
  well-known trick for training deep networks: it gives gradients a
  direct path backward through the network during backpropagation,
  preventing them from vanishing as more layers get stacked. Without it,
  a 12-layer or 96-layer transformer would be nearly impossible to train.
- `LayerNorm` — rescales the numbers in each vector so they stay in a
  stable, consistent range (roughly mean 0, unit variance), preventing
  values from exploding or shrinking to nothing as they pass through many
  stacked blocks.
- The exact same pattern (residual + norm) repeats after the feed-forward
  step.

**Teaching point to emphasize:** the notebook's "listens, thinks, stays
stable" framing (attention = listens, feed-forward = thinks, norm =
stability) is a genuinely good, teachable analogy — worth keeping when
you explain this to someone else, since it maps each sub-component to an
intuitive role without needing the deep-learning-training-stability
explanation up front.

---

# Step 6 — Full language model

```python
class SimpleLLM(nn.Module):
    def __init__(self, vocab_size, embedding_dim, hidden_dim, num_layers):
        super(SimpleLLM, self).__init__()
        self.embedding = Embedding(vocab_size, embedding_dim)
        self.positional_encoding = PositionalEncoding(embedding_dim)
        self.transformer_blocks = nn.Sequential(*[TransformerBlock(embedding_dim, hidden_dim) for _ in range(num_layers)])
        self.output = nn.Linear(embedding_dim, vocab_size)

    def forward(self, x):
        x = self.embedding(x)
        x = x.transpose(0, 1)
        x = self.positional_encoding(x)
        x = x.transpose(0, 1)
        x = self.transformer_blocks(x)
        x = self.output(x)
        return x
```

**The problem this solves:** nothing new conceptually — this is pure
assembly. Every piece from Steps 2–5 gets wired together in sequence,
plus one new piece: `self.output`, a final linear layer that converts the
model's internal representation back into a prediction over the entire
vocabulary.

**Reading the line itself:**
- `self.transformer_blocks = nn.Sequential(*[TransformerBlock(...) for _ in range(num_layers)])` —
  this stacks `num_layers` transformer blocks back to back. This one line
  is literally "how deep is this model" — GPT-3 uses up to 96 of these
  stacked; this toy model uses 2.
- `x.transpose(0, 1)` appearing twice — a shape-juggling detail, not a
  conceptual step. PyTorch's positional encoding here expects a different
  tensor axis order than the embedding layer outputs, so the code
  transposes before and after. Worth mentioning to a learner only so they
  don't mistake it for something meaningful — it's plumbing.
- `self.output = nn.Linear(embedding_dim, vocab_size)` — takes the
  model's final internal vector (size `embedding_dim`) and projects it up
  to `vocab_size` numbers — one score per possible word in the
  vocabulary. The word with the highest score is the model's prediction
  for "what comes next."

**Teaching point to emphasize:** `num_layers` is the single most direct
lever for "how powerful is this model" in this whole example — more
layers means more sequential rounds of attention-then-processing, which
is most of what separates a toy model from GPT-3 architecturally (the
notebook's own closing cell says this: 2 layers here vs. 12–96 in real
models).

---

# Step 7 — Training the model

```python
vocab = {"hello": 0, "world": 1, "how": 2, "are": 3, "you": 4, "<UNK>": 5}
model = SimpleLLM(vocab_size, embedding_dim, hidden_dim, num_layers)
criterion = nn.CrossEntropyLoss()
optimizer = optim.Adam(model.parameters(), lr=0.001)

data = ["hello world how are you", "how are you hello world"]
tokenized_data = [tokenize(sentence, vocab) for sentence in data]

for epoch in range(100):
    for sentence in tokenized_data:
        for i in range(1, len(sentence)):
            input_seq = torch.tensor(sentence[:i]).unsqueeze(0)
            target = torch.tensor(sentence[i]).unsqueeze(0)
            optimizer.zero_grad()
            output = model(input_seq)
            loss = criterion(output[:, -1, :], target)
            loss.backward()
            optimizer.step()
```

**The problem this solves:** every component built so far has random,
untrained weights. Training is the process of showing the model examples
and nudging every weight (embeddings, attention, feed-forward layers, all
of it) so its predictions get closer to correct.

**Reading the line itself, this is the part worth being most precise
about:**
- The triple-nested loop is doing "next-word prediction" the explicit,
  manual way. For the sentence `"hello world how are you"` (tokenized to
  `[0, 1, 2, 3, 4]`), the inner loop walks through `i = 1, 2, 3, 4` and
  creates training pairs: given `[0]` predict `1`; given `[0, 1]` predict
  `2`; given `[0, 1, 2]` predict `3`; and so on. **This is exactly the
  same core idea behind how every modern LLM is trained** — feed in a
  partial sequence, predict the next token, compare to the real next
  token. This toy loop is doing it explicitly and inefficiently; real
  training does it with clever batching and masking, but the underlying
  task is identical.
- `optimizer.zero_grad()` — PyTorch accumulates gradients by default, so
  this clears out the previous step's gradients before computing new
  ones. Skipping this is a classic, very common bug — gradients from
  every previous step would silently pile up.
- `output = model(input_seq)` — runs the forward pass, producing a score
  for every word in the vocabulary, for every position in the input.
- `output[:, -1, :]` — takes only the prediction at the *last* position,
  since that's the one representing "what comes after everything I've
  seen so far."
- `criterion(output[:, -1, :], target)` — cross-entropy loss, which
  measures how far the predicted probability distribution is from the
  correct answer (a single correct word). Lower is better; 0 would mean
  perfect confidence in the right word.
- `loss.backward()` — backpropagation. Computes how much each of the
  model's weights contributed to the error.
- `optimizer.step()` — actually updates every weight, nudging it in the
  direction that would have reduced this specific error.

**Teaching point to emphasize:** with only two training sentences and
100 epochs, this model is almost certainly **memorizing**, not
generalizing. That's fine and expected for a teaching example — the goal
is to see the mechanism work end to end, not to build something useful.
Worth saying this out loud when you teach it, so nobody walks away
thinking a real LLM trains on two sentences.

---

# Step 8 — Using the model

```python
input_text = "hello world how"
input_tokens = tokenize(input_text, vocab)
input_tensor = torch.tensor(input_tokens).unsqueeze(0)
output = model(input_tensor)
predicted_token = torch.argmax(output[:, -1, :]).item()
print(f"Input: {input_text}, Predicted: {list(vocab.keys())[list(vocab.values()).index(predicted_token)]}")
```

**The problem this solves:** this is inference — using the now-trained
model to actually generate a prediction, as opposed to training, where
the model is being corrected.

**Reading the line itself:**
- `torch.argmax(output[:, -1, :])` — of all the vocabulary-sized scores
  at the last position, pick the single highest one. This is **greedy
  decoding** — always taking the single most likely next word, with no
  randomness. It's the simplest possible decoding strategy; real
  generation often samples with some randomness (temperature, top-p —
  concepts from your earlier LLM fundamentals prep) instead of always
  taking the top pick.
- The final line's `list(vocab.keys())[list(vocab.values()).index(predicted_token)]`
  is just a clunky reverse-lookup: turning the predicted integer ID back
  into a readable word, since `vocab` only maps word → ID, not ID → word.
  Worth pointing out as inelegant but harmless — a real implementation
  would keep a reverse dictionary rather than searching the list every
  time.

---

# The closing cell — what's missing to make this a real LLM

The notebook's own final markdown cell is worth treating as required
content, not an afterthought, because it's the honest gap-closing
section: vocabulary from 6 words to 50,000+ via subword tokenization
(BPE), training data from 2 sentences to millions, embedding dimension
from 16 to 512–1024, hidden dimension from 32 to 2048+, layers from 2 to
12–96, single-head attention to multi-head (`nn.MultiheadAttention`), and
training infrastructure from 100 CPU epochs to multi-GPU/TPU runs over
days or weeks.

**The single sentence to leave someone with, if you're teaching this:**
every architectural idea in a frontier model — GPT-4, Claude, anything —
is already present in this 100-line toy. What separates them is scale
and engineering, not a fundamentally different idea.

---

# How to actually teach this to someone else

Walk it in this order, and it holds together as a narrative rather than
eight disconnected facts:

1. Numbers, not words (tokenization) →
2. Numbers need meaning (embeddings) →
3. But meaning without order is broken (positional encoding) →
4. Not every word matters equally (self-attention) →
5. One attention pass isn't enough depth (transformer block) →
6. Stack many of these, add a way to read out a prediction (full model) →
7. Nothing works until you train it (training loop) →
8. Now use it (inference) →
9. This is a toy — here's exactly what scales it up (the closing cell).

Say
