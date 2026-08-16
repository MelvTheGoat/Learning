from flask import Flask, request, jsonify
import joblib
import os

app = Flask(__name__)

# Find the absolute path to your .pkl files
base_dir = os.path.dirname(os.path.dirname(__file__))
model_path = os.path.join(base_dir, 'spam_detector.pkl')
vec_path = os.path.join(base_dir, 'vectorizer.pkl')

# Load the model and vectorizer
try:
    model = joblib.load(model_path)
    vectorizer = joblib.load(vec_path)
except Exception as e:
    print(f"Error loading files: {e}")

@app.route('/')
def home():
    return "Spam Detection API is live and ready!"

@app.route('/predict', methods=['POST'])
def predict():
    try:
        # Get the text from the incoming request
        data = request.json
        text = data.get('text', '')
        
        if not text:
            return jsonify({'error': 'No text provided'}), 400
            
        # 1. Transform the text using your loaded vectorizer
        vectorized_text = vectorizer.transform([text])
        
        # 2. Make the prediction using your loaded model
        prediction = model.predict(vectorized_text)
        
        # 3. Format the result (assuming 1 is spam and 0 is ham based on your notebook)
        result = "Spam" if prediction[0] == 1 else "Not Spam"
        
        return jsonify({
            'text': text, 
            'prediction': result
        })
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    app.run(debug=True)