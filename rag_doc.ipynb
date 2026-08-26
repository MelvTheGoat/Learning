import pdfplumber
# Imports the pdfplumber library to read and extract text from the local PDF file.

from transformers import AutoTokenizer, AutoModelForQuestionAnswering, pipeline
# Imports classes from Hugging Face to load tokenizers, models, and build the question-answering pipeline.

from sentence_transformers import SentenceTransformer
# Imports the SentenceTransformer library, which converts text into numerical vectors (embeddings) based on meaning.

import faiss
# Imports FAISS (Facebook AI Similarity Search), a library optimized for quickly searching and comparing massive amounts of vector data.

import numpy as np
# Imports NumPy to handle mathematical arrays, which FAISS requires for its search functions.

pdf_path = "System_Design_for_Builders_-_Volume_1_Foundations.pdf"
# Sets the file path for the PDF we are going to analyze.

with pdfplumber.open(pdf_path) as pdf:
# Safely opens the PDF file so it will automatically close when we are done extracting text.

    document = ""
    # Initializes an empty string to hold all the text extracted from the entire document.

    for page in pdf.pages:
    # Loops through each page in the PDF one by one.

        extracted = page.extract_text()
        # Extracts the raw text from the current page.

        if extracted:
        # Checks to make sure the page actually contained text (avoiding errors on blank pages or image-only pages).

            document += extracted + "\n"
            # Appends the extracted text to our main document string, adding a line break at the end of each page.

tokenizer = AutoTokenizer.from_pretrained("sentence-transformers/all-mpnet-base-v2")
# Loads a tokenizer that perfectly matches our embedding model, so it splits the text the exact same way the model expects.

def split_text(text, chunk_size=256, chunk_overlap=20):
# Defines a custom function to break the massive document into smaller, searchable chunks of text.

    tokens = tokenizer.tokenize(text)
    # Converts the entire document text into a list of individual tokens (words and sub-words).

    chunks = []
    # Initializes an empty list to store our final text chunks.

    start = 0
    # Sets the starting index for our chunking loop to 0.

    while start < len(tokens):
    # Starts a loop that will run until we have processed every token in the document.

        end = min(start + chunk_size, len(tokens))
        # Calculates where the current chunk should end, ensuring we don't try to go past the total number of tokens.

        chunks.append(tokenizer.convert_tokens_to_string(tokens[start:end]))
        # Grabs the slice of tokens, converts them back into a readable text string, and adds it to our chunks list.

        if end == len(tokens):
        # Checks if we have reached the very end of the document.

            break
            # If we are at the end, it breaks out of the while loop entirely.

        start = end - chunk_overlap
        # Moves our starting position forward for the next chunk, but steps back slightly (overlap) so we don't cut concepts in half.

    return chunks
    # Returns the completed list of text chunks.

chunks = split_text(document)
# Runs our custom function on the extracted PDF text to generate the chunks.

print(f"Number of chunks: {len(chunks)}")
# Prints out how many total chunks the document was broken into.

embedding_model = SentenceTransformer("sentence-transformers/all-mpnet-base-v2")
# Loads the AI model that will convert our text chunks into numerical vectors based on their semantic meaning.

embeddings = embedding_model.encode(chunks)
# Passes all our text chunks through the model, generating a list of dense vector arrays (embeddings).

dimension = embeddings.shape[1]
# Checks the shape of the embeddings to find out how many dimensions the vectors have (required to set up FAISS).

index = faiss.IndexFlatL2(dimension)
# Creates a FAISS search index that uses L2 (Euclidean) distance to calculate how similar vectors are to one another.

index.add(np.array(embeddings))
# Converts our list of embeddings into a NumPy array and loads them into the FAISS search index.

query = input("Ask a question about the document: ")
# Pauses the script and waits for the user to type a question into the console.

query_embedding = embedding_model.encode([query])
# Converts the user's typed question into a vector using the exact same model we used for the text chunks.

k = 3
# Sets a variable 'k' to 3, meaning we want to find the top 3 most relevant chunks.

distances, indices = index.search(np.array(query_embedding), k)
# Asks FAISS to compare the question's vector against all chunk vectors and return the closest 3 matches (and their distances).

retrieved_chunks = [chunks[i] for i in indices[0]]
# Uses the index numbers returned by FAISS to pull the actual text strings from our original 'chunks' list.

print("Retrieved chunks:")
# Prints a header for the console output.

for chunk in retrieved_chunks:
# Loops through the 3 highly relevant text chunks we just retrieved.

    print("- " + chunk)
    # Prints each chunk to the console so the user can see what context the AI is using.

qa_model_name = "deepset/roberta-base-squad2"
# Defines the specific Hugging Face model we want to use for extracting answers (RoBERTa trained on the SQuAD2 dataset).

qa_tokenizer = AutoTokenizer.from_pretrained(qa_model_name)
# Loads the specific tokenizer required for the RoBERTa QA model.

qa_model = AutoModelForQuestionAnswering.from_pretrained(qa_model_name)
# Loads the RoBERTa QA model itself into memory.

qa_pipeline = pipeline("question-answering", model=qa_model, tokenizer=qa_tokenizer)
# Combines the model and tokenizer into a streamlined question-answering pipeline.

context = " ".join(retrieved_chunks)
# Combines our 3 retrieved text chunks into one single block of text to serve as the context.

answer = qa_pipeline(question=query, context=context)
# Passes the user's question and the combined context into the QA pipeline to find the exact answer.

print(f"Answer: {answer['answer']}")
# Prints the final, extracted answer to the console.
