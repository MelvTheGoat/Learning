# Customer Segmentation

## Project Overview
This project applies unsupervised machine learning techniques to segment customers into distinct groups based on their purchasing behavior and demographic data. By identifying these clusters, businesses can optimize targeted marketing strategies, improve customer retention, and drive revenue growth.

## Features
* **Exploratory Data Analysis (EDA):** Visualized customer demographics and spending scores to identify initial patterns.
* **Data Preprocessing:** Handled missing values, scaled features, and encoded categorical variables for optimal model performance.
* **K-Means Clustering:** Implemented the K-Means algorithm to partition the customer base.
* **Optimal Cluster Selection:** Utilized the Elbow Method and Silhouette Score to determine the ideal number of clusters.
* **Actionable Insights:** Translated the resulting clusters into business-driven recommendations.

## Tech Stack
* **Language:** Python
* **Data Manipulation:** Pandas, NumPy
* **Machine Learning:** Scikit-learn (K-Means, StandardScaler)
* **Data Visualization:** Matplotlib, Seaborn

## Repository Structure
```text
├── data/                   # Raw and processed datasets (ignored in .gitignore)
├── notebooks/              # Jupyter notebooks containing EDA and modeling steps
├── src/                    # Python scripts for data preprocessing and clustering
├── visuals/                # Exported graphs and cluster visualizations
├── requirements.txt        # Project dependencies
└── README.md               # Project documentation

```
Installation & Usage
Clone the repository:

Bash
git clone [https://github.com/MelvTheGoat/customer-segmentation.git](https://github.com/MelvTheGoat/customer-segmentation.git)
cd customer-segmentation
Set up a virtual environment (optional but recommended):

Bash
python -m venv venv
source venv/bin/activate  # On Windows use: venv\Scripts\activate
Install the dependencies:

Bash
pip install -r requirements.txt
Run the analysis:
Navigate to the notebooks/ directory to run the Jupyter notebooks, or execute the main script:

Bash
python src/main.py
