import pandas as pd
from nlp.data.data_split import DatasetSplitter
from nlp.data.preprocess import DataPreprocessor
import json

def merge_topic_classes(df):
    merge_map = {
        'THE WORLDPOST': 'WORLDPOST',
        'STYLE': 'STYLE & BEAUTY',
        'ARTS': 'ARTS & CULTURE',
        'HEALTHY LIVING': 'WELLNESS'
    }
    df['label'] = df['label'].replace(merge_map)
    return df

def split_tokenize_and_save_data():
    preprocessor = DataPreprocessor("distilroberta-base")
    splitter = DatasetSplitter()

    class_weights = {}
    data_files = {
        "sentiment_analysis": "nlp/data/datasets/cleaned_sentiment.csv",
        "topic_classification": "nlp/data/datasets/cleaned_category.csv",
        "fake_news_detection": "nlp/data/datasets/cleaned_fake_news.csv"
    }

    # Dictionaries to hold split datasets
    train_data, val_data, test_data = {}, {}, {}

    for task, file in data_files.items():
        df = pd.read_csv(file)
        df = preprocessor.encode_labels(df, "label")
        train_df, val_df, test_df, weights = splitter.stratified_split(df, "label")
        class_weights[task] = weights

        # Tokenize
        for split, split_df in zip(["train", "val", "test"], [train_df, val_df, test_df]):
            split_df["title"] = split_df["title"].apply(preprocessor.clean_text)
            split_encoded = preprocessor.tokenize(split_df, "title")

            # Add tokenized columns to the dataframe
            split_df["input_ids"] = split_encoded["input_ids"].tolist()
            split_df["attention_mask"] = split_encoded["attention_mask"].tolist()

            if split == "train":
                train_data[task] = split_df
            elif split == "val":
                val_data[task] = split_df
            elif split == "test":
                test_data[task] = split_df

    for task, df in train_data.items():
        df.to_csv(f"nlp/outputs/{task}_train.csv", index=False)
    for task, df in val_data.items():
        df.to_csv(f"nlp/outputs/{task}_val.csv", index=False)
    for task, df in test_data.items():
        df.to_csv(f"nlp/outputs/{task}_test.csv", index=False)

    with open("nlp/outputs/class_weights.json", "w") as f:
        json.dump(class_weights, f)

    print("Data splitting, tokenization, and saving complete")

if __name__ == "__main__":
    split_tokenize_and_save_data()
