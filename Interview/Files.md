# Repository Architecture Breakdown

This project is structured into specific, modular pipelines to handle everything from memory constraints to strict guardrails. Below is a breakdown of the core files and their intended purposes based on the repository structure.

## Root Level & Documentation
These files handle the project setup, deployment, and high-level documentation.
* **`.env.example`**: Provides a template for the environment variables required to run the project.
* **`.github/workflows/ci.yml`**: Automates the testing and continuous integration pipeline via GitHub Actions every time code is pushed.
* **`.gitignore`**: Tells Git which files and folders to exclude from version control.
* **`DEMO_SCRIPT.md`**: Contains the script or intended prompts to effectively demonstrate the RAG application's capabilities.
* **`DEPLOY.md`**: Houses the specific instructions for pushing and configuring the app for its target hosting environment.
* **`MANUAL_SOURCES.md`**: Documents the exact origins, links, and dates of the regulatory texts used in the corpus to ensure auditability.
* **`README.md`**: Acts as the main landing page explaining what the project is, how to install it, and how to use it.
* **`app.py`**: Serves as the main frontend entry point for the application.
* **`pyproject.toml`** / **`requirements.txt`** / **`requirements-dev.txt`**: Manage the Python dependencies and library versions needed for standard execution and development.

## Data & Indexing (`data/` & `index/`)
This is where the knowledge base lives and how the machine reads it.
* **`data/corpus/*.md`**: Contains the raw markdown files of Nigerian financial and data protection acts (e.g., `cbn_aml_cft_regulations.md`, `ndpa_2023.md`).
* **`index/bm25.json`**: Stores the sparse, keyword-based index used for exact-match text retrieval.
* **`index/chunks.jsonl`**: Contains the parsed, broken-down pieces of the regulatory documents mapped to their metadata.
* **`index/manifest.json`**: Tracks the metadata, versions, and configurations of the currently built index.
* **`index/vectors.npy`**: Holds the dense mathematical embeddings (vectors) of the chunks for semantic similarity search.

## Scripts (`scripts/`)
These are standalone utilities meant to be run from the command line during build or maintenance phases.
* **`scripts/build_index.py`**: Automates the process of reading the corpus, chunking it, embedding it, and saving the output to the index directory.
* **`scripts/check_memory.py`**: Profiles the application to ensure the vector index and models won't exceed the strict RAM limits of the hosting environment.
* **`scripts/export_reranker.py`**: Packages or serializes the cross-encoder reranking model for faster loading during production inference.
* **`scripts/fetch_corpus.py`**: A utility to automatically scrape or download the latest versions of the required regulatory documents.

## The Core Application (`src/`)
This is the main backend logic, split into distinct modular domains.
* **`src/config.py`** & **`src/constants.py`**: Centralize all the magic numbers, paths, and application settings so they aren't hardcoded throughout the logic.
* **`src/feedback.py`**: Handles capturing user feedback (thumbs up/down) on the generated answers.
* **`src/limits.py`**: Enforces strict constraints like maximum token counts or rate limits.
* **`src/textutils.py`**: Provides shared helper functions for string cleaning and text manipulation.

### Generation (`src/generation/`)
* **`answer.py`**: Orchestrates the final prompt formulation and the call to the LLM to get the final response.
* **`prompts.py`**: Stores the actual prompt templates instructing the LLM on how to behave as a compliance assistant.
* **`providers.py`**: Wraps the specific API calls to the chosen LLM provider.

### Guardrails (`src/guardrails/`)
* **`input_guard.py`**: Screens user queries before they hit the retrieval pipeline to reject malicious prompts or off-topic questions.
* **`output_guard.py`**: Evaluates the LLM's final response to ensure it doesn't hallucinate or provide illegal financial advice.
* **`pii.py`**: Scans both inputs and outputs to redact sensitive Personally Identifiable Information.

### Ingestion (`src/ingest/`)
* **`chunking.py`**: Contains the logic for splitting the long regulatory markdowns into optimal, overlapping sizes.
* **`extract.py`**: Handles pulling text and metadata cleanly out of the raw source files.
* **`schema.py`**: Defines the exact data structures for what a document or chunk must look like.

### Retrieval (`src/retrieval/`)
* **`bm25.py`**: Executes the keyword-based sparse search against the BM25 index.
* **`embedder.py`**: Converts the user's live query into a vector to search the vector store.
* **`fusion.py`**: Combines and normalizes the scores from both the dense and sparse searches using reciprocal rank fusion.
* **`pipeline.py`**: Glues the entire search process together from query string to final retrieved chunks.
* **`rerank.py`**: Applies a secondary model to re-order the retrieved chunks for maximum relevance.
* **`store.py`**: Manages loading and accessing the pre-built index files from disk into memory.

## Evaluation & Testing (`eval/` & `tests/`)
These directories ensure the application actually works and is legally accurate.
* **`eval/`**: Contains the offline evaluation harness (`judge.py`, `metrics.py`, `run_eval.py`) to systematically test the RAG's answers against a known `golden_set.yaml` of correct compliance answers.
* **`tests/`**: Houses standard unit tests (e.g., `test_generation.py`, `test_retrieval.py`) to catch regressions during development.
