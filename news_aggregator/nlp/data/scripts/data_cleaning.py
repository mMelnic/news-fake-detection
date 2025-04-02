import re
from collections import Counter
from nlp.data.data_loader import DatasetLoader
import pandas as pd

class DataCleaner:
    def __init__(self, loader, file_path=None, file_type="csv", required_columns=None, true_path=None, fake_path=None):
        """
        Initializes the cleaner and loads data via DatasetLoader.
        :param loader: Instance of DatasetLoader.
        :param file_path: Path to the dataset file (for JSON or single CSV).
        :param file_type: Type of file ('json', 'csv', or 'fake_news').
        :param required_columns: List of columns to extract (for JSON or CSV).
        :param true_path: Path to TRUE.csv (for fake news detection).
        :param fake_path: Path to FAKE.csv (for fake news detection).
        """
        self.loader = loader
        if file_type == 'json':
            self.data = loader.load_json(file_path, required_columns)
        elif file_type == 'csv':
            self.data = loader.load_csv(file_path, required_columns)
        elif file_type == 'fake_news':
            self.data = loader.load_fake_news_data(true_path, fake_path)
        else:
            raise ValueError("Unsupported file type. Use 'json', 'csv', or 'fake_news'.")

    def clean_special_characters(self, text_column):
        """
        Normalizes special characters such as curly quotes and dashes.
        :param text_column: Name of the column containing text data.
        """
        def normalize_text(text):
            text = re.sub(r"[“”]", '"', str(text))  # Replace curly quotes with double quotes
            text = re.sub(r"[‘’]", "'", str(text))  # Replace curly apostrophe with a single quote
            text = re.sub(r"[–—]", "-", text)  # Normalize dashes
            text = re.sub(r"\s+", " ", text).strip()  # Remove extra spaces
            return text

        self.data[text_column] = self.data[text_column].apply(normalize_text)

    def remove_duplicates(self, text_column):
        """
        Removes duplicate records based on the specified text column.
        :param text_column: Name of the column containing text data.
        """
        before_count = len(self.data)
        self.data.drop_duplicates(subset=[text_column], inplace=True)
        after_count = len(self.data)
        print(f"Removed {before_count - after_count} duplicate records.")

    def filter_short_texts(self, text_column, min_words=5):
        """
        Removes text entries that contain fewer than `min_words` words.
        :param text_column: Name of the column containing text data.
        :param min_words: Minimum number of words required in an entry.
        """
        before_count = len(self.data)
        self.data = self.data[self.data[text_column].apply(lambda x: len(str(x).split()) >= min_words)]
        after_count = len(self.data)
        print(f"Removed {before_count - after_count} short text entries.")

    def merge_datasets(self, additional_data):
        """
        Merges an additional dataset with the existing data.
        :param additional_data: A DataFrame with text and labels.
        """
        self.data = pd.concat([self.data, additional_data], ignore_index=True)
        print(f"Final dataset size after merging: {len(self.data)}")

    def rename_rows_by_value(self, column_name, old_value, new_value):
        """
        Renames the rows where the column's value matches `old_value` to `new_value`.
        :param column_name: The column to search for the `old_value`.
        :param old_value: The value in the column that you want to rename.
        :param new_value: The new value to replace the old value with.
        """
        if column_name not in self.data.columns:
            raise ValueError(f"Column '{column_name}' does not exist in the DataFrame.")
        self.data[column_name] = self.data[column_name].replace(old_value, new_value)

    def balance_classes(self, label_column):
        """
        Undersamples the majority class to match the minority class count.
        :param label_column: Name of the column containing labels.
        """
        min_class_count = min(Counter(self.data[label_column]).values())

        balanced_data = self.data.groupby(label_column).apply(lambda x: x.sample(min_class_count)).reset_index(drop=True)
        print(f"Balanced dataset: {Counter(balanced_data[label_column])}")
        
        self.data = balanced_data

    def save_cleaned_data(self, output_path):
        """
        Saves the cleaned dataset to a new CSV file.
        :param output_path: Path to save the cleaned dataset.
        """
        self.data.to_csv(output_path, index=False)
        print(f"Cleaned dataset saved to {output_path}")

if __name__ == '__main__':
    loader = DatasetLoader()
    cleaner = DataCleaner(loader, "nlp/data/datasets/news.csv", file_type="csv", required_columns=["news", "sentiment"])
    cleaner.clean_special_characters("news")
    cleaner.remove_duplicates("news")
    cleaner.filter_short_texts("news")
    cleaner.balance_classes("sentiment")
    cleaner.data.rename(columns={"news": "title", "sentiment": "label"}, inplace=True)
    cleaner.save_cleaned_data("nlp/data/datasets/cleaned_sentiment.csv")

    cleaner = DataCleaner(loader, "nlp/data/datasets/News_Category_Dataset_v3.json", file_type="json", required_columns=["headline", "category"])
    cleaner.clean_special_characters("headline")
    cleaner.remove_duplicates("headline")
    cleaner.filter_short_texts("headline", 4)
    cleaner.rename_rows_by_value("category", "CULTURE & ARTS", "ARTS & CULTURE")
    cleaner.data.rename(columns={"headline": "title", "category": "label"}, inplace=True)
    cleaner.save_cleaned_data("nlp/data/datasets/cleaned_category.csv")

    # Load the first dataset (WELFake_Dataset.csv)
    cleaner1 = DataCleaner(loader, file_path="nlp/data/datasets/WELFake_Dataset.csv", file_type="csv", required_columns=["title", "label"])
    cleaner1.clean_special_characters("title")
    cleaner1.remove_duplicates("title")
    cleaner1.filter_short_texts("title")

    # Load the second dataset (True.csv and Fake.csv)
    cleaner2 = DataCleaner(loader, file_type="fake_news", true_path="nlp/data/datasets/True.csv", fake_path="nlp/data/datasets/Fake.csv")
    cleaner2.clean_special_characters("title")
    cleaner2.remove_duplicates("title")
    cleaner2.filter_short_texts("title")

    cleaner1.merge_datasets(cleaner2.data)
    cleaner1.remove_duplicates("title")

    cleaner1.save_cleaned_data("nlp/data/datasets/cleaned_fake_news.csv")