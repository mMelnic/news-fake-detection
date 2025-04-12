import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
from nlp.data.data_split import DatasetSplitter

file_paths = {
    "sentiment": "nlp/data/datasets/cleaned_sentiment.csv",
    "topic_classification": "nlp/data/datasets/cleaned_category.csv",
    "fake_news": "nlp/data/datasets/cleaned_fake_news.csv"
}

datasets = {name: pd.read_csv(path) for name, path in file_paths.items()}
splitter = DatasetSplitter()

def visualize_class_distribution(dataset, label_column, dataset_name, split_type="Original"):
    """
    Generates bar plots for class distribution in train, val, and test sets.
    :param dataset: DataFrame containing dataset split.
    :param label_column: Column representing class labels.
    :param dataset_name: Name of the dataset.
    :param split_type: Indicates whether the visualization is for 'Original' or 'Split'.
    """
    plt.figure(figsize=(10, 5))
    sns.countplot(data=dataset, x=label_column, hue=label_column, palette="pastel", legend=False)
    plt.title(f"Class Distribution in {dataset_name} ({split_type})")
    plt.xlabel("Class Labels")
    plt.ylabel("Count")
    plt.xticks(rotation=45)
    plt.show()

def show_random_samples(dataset, text_column, dataset_name, num_samples=5):
    """
    Displays random text samples to ensure variety in each split.
    :param dataset: DataFrame containing dataset split.
    :param text_column: Column representing textual data.
    :param dataset_name: Name of the dataset.
    :param num_samples: Number of random samples to display.
    """
    print(f"Random Samples from {dataset_name}:")
    print(dataset.sample(num_samples)[text_column])

def compute_word_statistics(dataset, text_column, dataset_name, split_type="Original"):
    """
    Computes word count statistics for text length in train, val, test sets.
    :param dataset: DataFrame containing dataset split.
    :param text_column: Column representing textual data.
    :param dataset_name: Name of the dataset.
    :param split_type: Indicates whether the visualization is for 'Original' or 'Split'.
    """
    dataset["word_count"] = dataset[text_column].apply(lambda x: len(str(x).split()))
    print(f"\nWord Count Statistics for {dataset_name} ({split_type}):")
    print(f"Mean: {dataset['word_count'].mean():.2f}")
    print(f"Median: {dataset['word_count'].median():.2f}")
    print(f"Standard Deviation: {dataset['word_count'].std():.2f}")

for dataset_name, dataset in datasets.items():
    label_column = "label"
    text_column = "title"

    # Visualize original dataset
    visualize_class_distribution(dataset, label_column, dataset_name, split_type="Original")
    compute_word_statistics(dataset, text_column, dataset_name, split_type="Original")

    # Perform stratified split
    train_data, val_data, test_data, class_weights = splitter.stratified_split(dataset, label_column)

    # Visualize splits
    visualize_class_distribution(train_data, label_column, dataset_name, split_type="Train Set")
    visualize_class_distribution(val_data, label_column, dataset_name, split_type="Validation Set")
    visualize_class_distribution(test_data, label_column, dataset_name, split_type="Test Set")

    compute_word_statistics(train_data, text_column, dataset_name, split_type="Train Set")
    compute_word_statistics(val_data, text_column, dataset_name, split_type="Validation Set")
    compute_word_statistics(test_data, text_column, dataset_name, split_type="Test Set")

    print(f"Class Weights for {dataset_name}: {class_weights}")
