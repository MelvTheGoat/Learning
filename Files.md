# Repository Architecture Breakdown

This project is structured into specific, modular pipelines to handle everything from memory constraints to strict guardrails[span_0](start_span)[span_0](end_span). Below is a breakdown of the core files and their intended purposes based on the repository structure[span_1](start_span)[span_1](end_span).

## Root Level & Documentation
These files handle the project setup, deployment, and high-level documentation[span_2](start_span)[span_2](end_span).
* **`.env.example`**: Provides a template for the environment variables required to run the project[span_3](start_span)[span_3](end_span).
* **`.github/workflows/ci.yml`**: Automates the testing and continuous integration pipeline via GitHub Actions every time code is pushed[span_4](start_span)[span_4](end_span).
* **`.gitignore`**: Tells Git which files and folders to exclude from version control[span_5](start_span)[span_5](end_span).
* **`DEMO_SCRIPT.md`**: Contains the script or intended prompts to effectively demonstrate the RAG application's capabilities[span_6](start_span)[span_6](end_span).
* **`DEPLOY.md`**: Houses the specific instructions for pushing and configuring the app for its target hosting environment[span_7](start_span)[span_7](end_span).
* **`MANUAL_SOURCES.md`**: Documents the exact origins, links, and dates of the regulatory texts used in the corpus to ensure auditability[span_8](start_span)[span_8](end_span).
* **`README.md`**: Acts as the main landing page explaining what the project is, how to install it, and how to use it[span_9](start_span)[span_9](end_span).
* **`app.py`**: Serves as the main frontend entry point for the application[span_10](start_span)[span_10](end_span).
* **`pyproject.toml`** / **`requirements.txt`** / **`requirements-dev.txt`**: Manage the Python dependencies and library versions needed for standard execution and development[span_11](start_span)[span_11](end_span).

## Data & Indexing (`data/` & `index/`)
This is where the knowledge base lives and how the machine reads it[span_12](start_span)[span_12](end_span).
* **`data/corpus/*.md`**: Contains the raw markdown files of Nigerian financial and data protection acts (e.g., `cbn_aml_cft_regulations.md`, `ndpa_2023.md`)[span_13](start_span)[span_13](end_span).
* **`index/bm25.json`**: Stores the sparse, keyword-based index used for exact-match text retrieval[span_14](start_span)[span_14](end_span).
* **`index/chunks.jsonl`**: Contains the parsed, broken-down pieces of the regulatory documents mapped to their metadata[span_15](start_span)[span_15](end_span).
* **`index/manifest.json`**: Tracks the metadata, versions, and configurations of the currently built index[span_16](start_span)[span_16](end_span).
* **`index/vectors.npy`**: Holds the dense mathematical embeddings (vectors) of the chunks for semantic similarity search[span_17](start_span)[span_17](end_span).

## Scripts (`scripts/`)
These are standalone utilities meant to be run from the command line during build or maintenance phases[span_18](start_span)[span_18](end_span).
* **`scripts/build_index.py`**: Automates the process of reading the corpus, chunking it, embedding it, and saving the output to the index directory[span_19](start_span)[span_19](end_span).
* **`scripts/check_memory.py`**: Profiles the application to ensure the vector index and models won't exceed the strict RAM limits of the hosting environment[span_20](start_span)[span_20](end_span).
* **`scripts/export_reranker.py`**: Packages or serializes the cross-encoder reranking model for faster loading during production inference[span_21](start_span)[span_21](end_span).
* **`scripts/fetch_corpus.py`**: A utility to automatically scrape or download the latest versions of the required regulatory documents[span_22](start_span)[span_22](end_span).

## The Core Application (`src/`)
This is the main backend logic, split into distinct modular domains[span_23](start_span)[span_23](end_span).
* **`src/config.py`** & **`src/constants.py`**: Centralize all the magic numbers, paths, and application settings so they aren't hardcoded throughout the logic[span_24](start_span)[span_24](end_span).
* **`src/feedback.py`**: Handles capturing user feedback (thumbs up/down) on the generated answers[span_25](start_span)[span_25](end_span).
* **`src/limits.py`**: Enforces strict constraints like maximum token counts or rate limits[span_26](start_span)[span_26](end_span).
* **`src/textutils.py`**: Provides shared helper functions for string cleaning and text manipulation[span_27](start_span)[span_27](end_span).

### Generation (`src/generation/`)
* **`answer.py`**: Orchestrates the final prompt formulation and the call to the LLM to get the final response[span_28](start_span)[span_28](end_span).
* **`prompts.py`**: Stores the actual prompt templates instructing the LLM on how to behave as a compliance assistant[span_29](start_span)[span_29](end_span).
* **`providers.py`**: Wraps the specific API calls to the chosen LLM provider[span_30](start_span)[span_30](end_span).

### Guardrails (`src/guardrails/`)
* **`input_guard.py`**: Screens user queries before they hit the retrieval pipeline to reject malicious prompts or off-topic questions[span_31](start_span)[span_31](end_span).
* **`output_guard.py`**: Evaluates the LLM's final response to ensure it doesn't hallucinate or provide illegal financial advice[span_32](start_span)[span_32](end_span).
* **`pii.py`**: Scans both inputs and outputs to redact sensitive Personally Identifiable Information[span_33](start_span)[span_33](end_span).

### Ingestion (`src/ingest/`)
* **`chunking.py`**: Contains the logic for splitting the long regulatory markdowns into optimal, overlapping sizes[span_34](start_span)[span_34](end_span).
* **`extract.py`**: Handles pulling text and metadata cleanly out of the raw source files[span_35](start_span)[span_35](end_span).
* **`schema.py`**: Defines the exact data structures for what a document or chunk must look like[span_36](start_span)[span_36](end_span).

### Retrieval (`src/retrieval/`)
* **`bm25.py`**: Executes the keyword-based sparse search against the BM25 index[span_37](start_span)[span_37](end_span).
* **`embedder.py`**: Converts the user's live query into a vector to search the vector store[span_38](start_span)[span_38](end_span).
* **`fusion.py`**: Combines and normalizes the scores from both the dense and sparse searches using reciprocal rank fusion[span_39](start_span)[span_39](end_span).
* **`pipeline.py`**: Glues the entire search process together from query string to final retrieved chunks[span_40](start_span)[span_40](end_span).
* **`rerank.py`**: Applies a secondary model to re-order the retrieved chunks for maximum relevance[span_41](start_span)[span_41](end_span).
* **`store.py`**: Manages loading and accessing the pre-built index files from disk into memory[span_42](start_span)[span_42](end_span).

## Evaluation & Testing (`eval/` & `tests/`)
These directories ensure the application actually works and is legally accurate[span_43](start_span)[span_43](end_span).
* **`eval/`**: Contains the offline evaluation harness (`judge.py`, `metrics.py`, `run_eval.py`) to systematically test the RAG's answers against a known `golden_set.yaml` of correct compliance answers[span_44](start_span)[span_44](end_span).
* **`tests/`**: Houses standard unit tests (e.g., `test_generation.py`, `test_retrieval.py`) to catch regressions during development[span_45](start_span)[span_45](end_span).
