import pandas as pd
from nlp.data.preprocess import DataPreprocessor

def process_and_save_data():
    preprocessor = DataPreprocessor("distilroberta-base")

    data_files = {
        "sentiment_analysis": "nlp/data/datasets/cleaned_sentiment.csv",
        "topic_classification": "nlp/data/datasets/cleaned_category.csv",
        "fake_news_detection": "nlp/data/datasets/cleaned_fake_news.csv"
    }

    processed_data = {}

    for task, file in data_files.items():
        df = pd.read_csv(file)
        df["title"] = df["title"].apply(preprocessor.clean_text)
        df = preprocessor.encode_labels(df, "label")

        encoded = preprocessor.tokenize(df, ["title"])
        df["input_ids"] = encoded["input_ids"].tolist()
        df["attention_mask"] = encoded["attention_mask"].tolist()

        processed_data[task] = df

    for task, df in processed_data.items():
        df.to_csv(f"nlp/outputs/{task}_processed.csv", index=False)

    print("Data preprocessing complete")

if __name__ == "__main__":
    process_and_save_data()