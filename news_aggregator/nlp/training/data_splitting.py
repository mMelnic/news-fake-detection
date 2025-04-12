import pandas as pd
from nlp.data.data_split import DatasetSplitter
import json

def split_and_save_data():
    splitter = DatasetSplitter()
    class_weights = {}

    processed_files = {
        "sentiment_analysis": "nlp/outputs/sentiment_analysis_processed.csv",
        "topic_classification": "nlp/outputs/topic_classification_processed.csv",
        "fake_news_detection": "nlp/outputs/fake_news_detection_processed.csv"
    }

    train_data, val_data, test_data = {}, {}, {}

    for task, file in processed_files.items():
        df = pd.read_csv(file)
        train_df, val_df, test_df, weights = splitter.stratified_split(df, "label")

        class_weights[task] = weights
        train_data[task] = train_df.to_dict(orient="records")
        val_data[task] = val_df.to_dict(orient="records")
        test_data[task] = test_df.to_dict(orient="records")

    for task, df in train_data.items():
        pd.DataFrame(df).to_csv(f"nlp/outputs/{task}_train.csv", index=False)

    for task, df in val_data.items():
        pd.DataFrame(df).to_csv(f"nlp/outputs/{task}_val.csv", index=False)

    for task, df in test_data.items():
        pd.DataFrame(df).to_csv(f"nlp/outputs/{task}_test.csv", index=False)

    with open("nlp/outputs/class_weights.json", "w") as f:
        json.dump(class_weights, f)

    print("Data splitting complete")

if __name__ == "__main__":
    split_and_save_data()
