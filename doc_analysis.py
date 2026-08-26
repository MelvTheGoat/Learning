import pdfplumber
# Imports the pdfplumber library, which allows us to read and extract text from PDF files.

from transformers import pipeline
# Imports the pipeline function from the Hugging Face transformers library, which easily loads pre-trained AI models.

import nltk
# Imports the Natural Language Toolkit, a library used for working with human language data (text).

from nltk.tokenize import sent_tokenize
# Imports a specific function from nltk that splits a large block of text into individual sentences.

pdf_path = "System_Design_for_Builders_-_Volume_1_Foundations.pdf"
# Defines the file path to the PDF document we want to analyze.

output_text_file = "extracted_text.txt"
# Defines the name of the text file where we will save the extracted text.

with pdfplumber.open(pdf_path) as pdf:
# Opens the PDF file safely, ensuring it automatically closes when we are done with it.

    extracted_text = ""
    # Initializes an empty string variable that will hold all the text we extract from the PDF.

    for page in pdf.pages:
    # Loops through every single page in the opened PDF document one by one.

        extracted_text += page.extract_text() + "\n"
        # Extracts the text from the current page and adds it to our extracted_text variable, followed by a line break.

with open(output_text_file, "w", encoding="utf-8") as text_file:
# Opens (or creates) the output text file in write mode ("w"), using UTF-8 encoding to prevent special character errors.

    text_file.write(extracted_text)
    # Writes all the extracted text from the PDF into the new text file.

with open(output_text_file, "r", encoding="utf-8") as file:
# Opens the saved text file in read mode ("r"), again using UTF-8 encoding.

    document_text = file.read()
    # Reads the entire content of the text file into a new variable called document_text.

print(document_text[:500])
# Prints the first 500 characters of the document to the console so we can visually verify it loaded correctly.

summarizer = pipeline("summarization", model="t5-small")
# Loads a lightweight, pre-trained AI model called "t5-small" specifically configured to summarize text.

summary = summarizer(document_text[:10000], max_length=150, min_length=30, do_sample=False)
# Generates a summary for the first 10,000 characters of the document, restricting the output to between 30 and 150 words.

print("Summary:", summary[0]['summary_text'])
# Prints the generated summary text to the console.

nltk.download('punkt_tab')
# Downloads the 'punkt_tab' dataset for nltk, which contains the grammar rules needed to accurately split text into sentences.

sentences = sent_tokenize(document_text)
# Uses the downloaded rules to chop the entire document text into a list of individual sentences.

passages = []
# Initializes an empty list that will hold our grouped text chunks (which we call passages).

current_passage = ""
# Initializes an empty string to help us build the current chunk of text.

for sentence in sentences:
# Starts a loop to look at each individual sentence in the document.

    if len(current_passage.split()) + len(sentence.split()) < 200:
    # Checks if adding the next sentence keeps the current passage under 200 words total.

        current_passage += " " + sentence
        # If it stays under 200 words, it adds the sentence to the current passage string.

    else:
    # If adding the sentence would push the word count to 200 or more:

        passages.append(current_passage.strip())
        # It saves the completed passage to our 'passages' list, stripping away any extra spaces at the beginning or end.

        current_passage = sentence
        # It resets the current passage, starting a new chunk with the current sentence.

if current_passage:
# After the loop finishes, this checks if there is any leftover text sitting in current_passage.

    passages.append(current_passage.strip())
    # Adds that final, remaining passage to our list.

qg_pipeline = pipeline("text2text-generation", model="t5-small", tokenizer="t5-small")
# Loads the "t5-small" model again, but this time configures it for generating text based on a prompt (for question generation).

def generate_questions_pipeline(passage, min_questions=3):
# Defines a custom function that takes a text passage and a minimum number of questions we want to generate.

    input_text = f"generate questions: {passage}"
    # Formats the input string with a specific prompt ("generate questions:") so the T5 model knows what task to perform.

    results = qg_pipeline(input_text)
    # Passes the formatted text into the AI model to generate the questions.

    questions = results[0]['generated_text'].split('<sep>')
    # Takes the raw generated output and splits it into a list wherever the '<sep>' (separator) token appears.

    questions = [q.strip() for q in questions if q.strip()]
    # Cleans up the list by removing extra spaces and filtering out any accidental empty strings.

    if len(questions) < min_questions:
    # Checks if the model generated fewer questions than our requested minimum (default is 3).

        passage_sentences = passage.split('. ')
        # Splits the passage into a list of its sentences so we can feed smaller chunks to the AI to force more questions.

        for i in range(len(passage_sentences)):
        # Loops through the numerical indices of the sentences in the passage.

            if len(questions) >= min_questions:
            # Checks if we have finally reached the required minimum number of questions.

                break
                # If we have enough questions, it breaks out of the loop early.

            additional_input = ' '.join(passage_sentences[i:i+2])
            # Combines the current sentence and the next one to create a very small text window.

            additional_results = qg_pipeline(f"generate questions: {additional_input}")
            # Asks the AI model to generate questions based ONLY on this smaller 2-sentence chunk.

            additional_questions = additional_results[0]['generated_text'].split('<sep>')
            # Splits the new AI output into individual questions.

            questions.extend([q.strip() for q in additional_questions if q.strip()])
            # Cleans the new questions and tacks them onto the end of our main list of questions.

    return questions[:min_questions]
    # Returns exactly the number of requested questions by slicing the list down to the minimum amount.

for idx, passage in enumerate(passages):
# Loops through each of our text passages, keeping track of the index/number of the passage (idx).

    questions = generate_questions_pipeline(passage)
    # Calls our custom function to generate questions for the current passage.

    print(f"Passage {idx+1}:\n{passage}\n")
    # Prints the passage number and the actual text of the passage to the console.

    print("Generated Questions:")
    # Prints a header title for the questions section.

    for q in questions:
    # Loops through each question generated for this specific passage.

        print(f"- {q}")
        # Prints the question formatted as a bullet point.

    print(f"\n{'-'*50}\n")
    # Prints a dashed line separator to make the terminal output easier to read.

qa_pipeline = pipeline("question-answering", model="deepset/roberta-base-squad2")
# Loads a different AI model (RoBERTa) that is specifically trained to find the answers to questions inside a given text.

def answer_unique_questions(passages, qa_pipeline):
# Defines a custom function that takes all our text passages and the QA model to find answers.

    answered_questions = set()
    # Creates an empty mathematical 'set' to keep track of questions we've already answered (sets prevent duplicate entries).

    for idx, passage in enumerate(passages):
    # Loops through each text passage again.

        questions = generate_questions_pipeline(passage)
        # Generates the questions for the current passage.

        for question in questions:
        # Loops through each generated question.

            if question not in answered_questions:
            # Checks if this specific question has NOT been answered yet.

                answer = qa_pipeline({'question': question, 'context': passage})
                # Asks the QA model to find the answer to the question using the current passage as the source of truth.

                print(f"Q: {question}")
                # Prints the question.

                print(f"A: {answer['answer']}\n")
                # Prints the exact answer the AI extracted from the passage.

                answered_questions.add(question)
                # Adds this question to our set so we don't accidentally ask and answer it again later.

    print(f"{'='*50}\n")
    # Prints a thicker equal-sign separator line to divide the outputs neatly.

answer_unique_questions(passages, qa_pipeline)
# Actually runs our final custom function, kicking off the full question and answer extraction process.
