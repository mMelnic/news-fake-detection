from nlp.data.preprocess import DataPreprocessor
from nlp.data.data_split import DatasetSplitter
import pandas as pd
import matplotlib.pyplot as plt
def main():
    preprocessor = DataPreprocessor("distilroberta-base")
    splitter = DatasetSplitter()

    # Load datasets
    sentiment_data = pd.read_csv("nlp/data/datasets/cleaned_sentiment.csv")
    topic_data = pd.read_csv("nlp/data/datasets/cleaned_category.csv")
    fake_news_data = pd.read_csv("nlp/data/datasets/cleaned_fake_news.csv")

    # Apply text cleaning
    sentiment_data["title"] = sentiment_data["title"].apply(preprocessor.clean_text)
    topic_data["title"] = topic_data["title"].apply(preprocessor.clean_text)
    fake_news_data["title"] = fake_news_data["title"].apply(preprocessor.clean_text)

    # Encode labels
    sentiment_data = preprocessor.encode_labels(sentiment_data, "label")
    topic_data = preprocessor.encode_labels(topic_data, "label")
    fake_news_data = preprocessor.encode_labels(fake_news_data, "label")

    # Split datasets
    sentiment_train, sentiment_val, sentiment_test, sentiment_class_weights = splitter.stratified_split(sentiment_data, "label")
    topic_train, topic_val, topic_test, topic_class_weights = splitter.stratified_split(topic_data, "label")
    fake_news_train, fake_news_val, fake_news_test, fake_news_class_weights = splitter.stratified_split(fake_news_data, "label")

    plot_token_length_hist("Sentiment", sentiment_train, preprocessor.tokenizer)
    plot_token_length_hist("Topic", topic_train, preprocessor.tokenizer)
    plot_token_length_hist("Fake News", fake_news_train, preprocessor.tokenizer)


def plot_token_length_hist(dataset_name, data, tokenizer):
    token_lengths = data["title"].apply(lambda x: len(tokenizer.encode(x, truncation=False)))
    plt.hist(token_lengths, bins=40, edgecolor='black')
    plt.title(f"{dataset_name} - Token Length Distribution")
    plt.xlabel("Number of Tokens")
    plt.ylabel("Number of Samples")
    plt.grid(True)
    plt.show()

if __name__ == "__main__":
    main()