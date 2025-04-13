import pandas as pd
from nlp.data.data_split import DatasetSplitter
from nlp.data.preprocess import DataPreprocessor
from imblearn.over_sampling import RandomOverSampler
from imblearn.under_sampling import RandomUnderSampler
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

def resample_topic_train_set(train_df):
    class_counts = train_df['label'].value_counts()
    tiers = {
        'large': class_counts[class_counts > 15000].index.tolist(),
        'medium_large': class_counts[(class_counts > 7000) & (class_counts <= 15000)].index.tolist(),
        'medium': class_counts[(class_counts >= 2500) & (class_counts <= 7000)].index.tolist(),
        'small': class_counts[class_counts < 2500].index.tolist()
    }

    sampling_strategy = {
        cls: 8000 if cls in tiers['large'] else
            7000 if cls in tiers['medium_large'] else
            class_counts[cls] if cls in tiers['medium'] else
            2500
        for cls in class_counts.index
    }

    # Undersample large classes
    rus = RandomUnderSampler(sampling_strategy={cls: sampling_strategy[cls] for cls in tiers['large'] + tiers['medium_large']})
    X_temp, y_temp = rus.fit_resample(train_df[['title']], train_df['label'])

    # Oversample medium/small classes
    ros = RandomOverSampler(sampling_strategy={cls: sampling_strategy[cls] for cls in tiers['small']})
    X_resampled, y_resampled = ros.fit_resample(X_temp, y_temp)

    resampled_df = pd.DataFrame({
        'title': X_resampled['title'],
        'label': y_resampled
    })
    return resampled_df

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
    label_maps = {}

    for task, file in data_files.items():
        df = pd.read_csv(file)
        # Merge classes before encoding
        if task == "topic_classification":
            df = merge_topic_classes(df)

        df = preprocessor.encode_labels(df, "label")
        label_maps[task] = {int(v): str(k) for k, v in preprocessor.label_mapping.items()}
        train_df, val_df, test_df, weights = splitter.stratified_split(df, "label")

        # Resample only topic classification train set
        if task == "topic_classification":
            train_df = resample_topic_train_set(train_df)
            class_weights[task] = splitter.compute_class_weights(train_df, "label")
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
    with open("nlp/outputs/label_maps.json", "w") as f:
        json.dump(label_maps, f)

    print("Data splitting, tokenization, and saving complete")

if __name__ == "__main__":
    split_tokenize_and_save_data()
