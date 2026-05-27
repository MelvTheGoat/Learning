# Spam Detection using SVM

## Project Overview
This project implements a Natural Language Processing (NLP) pipeline and a Support Vector Machine (SVM) classifier to accurately distinguish between spam and legitimate (ham) messages. By leveraging text vectorization techniques, the model efficiently identifies malicious or unwanted content, demonstrating a practical approach to automated text moderation and data filtering.

## 🚀 Features
* **Text Preprocessing:** Automated cleaning of unstructured text data, including tokenization, lowercasing, and stop-word removal.
* **Feature Extraction:** Implemented TF-IDF (Term Frequency-Inverse Document Frequency) to convert raw text documents into meaningful numerical feature vectors.
* **SVM Classification:** Trained and optimized a Support Vector Machine model to handle high-dimensional text classification.
* **Performance Evaluation:** Rigorous model evaluation prioritizing Precision, Recall, F1-Score, and Confusion Matrices to minimize false positives (flagging legitimate messages as spam).

## Tech Stack
* **Language:** Python
* **Data Manipulation:** Pandas, NumPy
* **Machine Learning:** Scikit-learn (SVC, TfidfVectorizer, metrics)
* **Data Visualization:** Matplotlib, Seaborn (for Confusion Matrix plotting)

## Repository Structure
```text
├── data/                   # Raw and processed text datasets (ignored in .gitignore)
├── notebooks/              # Jupyter notebooks containing exploratory data analysis and model training
├── src/                    # Python scripts for data preprocessing, training, and inference
├── models/                 # Saved SVM model (.pkl or .joblib)
├── requirements.txt        # Project dependencies
└── README.md               # Project documentation
```
Installation & Usage
Clone the repository:

Bash
git clone [https://github.com/MelvTheGoat/spam-detection-svm.git](https://github.com/MelvTheGoat/spam-detection-svm.git)
cd spam-detection-svm
Set up a virtual environment:

Bash
python -m venv venv
source venv/bin/activate  # On Windows use: venv\Scripts\activate
Install the dependencies:

Bash
pip install -r requirements.txt
Run the training script:

Bash
python src/train.py
Test the model on new text:

Bash
python src/predict.py --text "Congratulations! You've won a free gift card. Click here to claim."
📊 Evaluation Metrics
(Note: Update these sample metrics with your model's actual results)

Accuracy: 98.5%

Precision (Spam): 99.1%

Recall (Spam): 94.2%

F1-Score: 96.6%
