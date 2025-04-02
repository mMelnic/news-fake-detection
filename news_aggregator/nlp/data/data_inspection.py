import re
from collections import Counter
from spellchecker import SpellChecker

class DataInspector:
    def __init__(self, loader, file_path, file_type, required_columns=None, true_path=None, fake_path=None):
        """
        Initialize the DataInspector with a DatasetLoader and dataset details.
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

    def check_special_characters(self, text_column):
        """
        Identifies special characters and noisy whitespace characters in the dataset.
        :param text_column: Name of the column containing text data.
        """
        # Regular expression to match special characters and whitespace characters
        special_char_pattern = re.compile(r'[^\w\s,.?!]')
        whitespace_pattern = re.compile(r'[\s\t\r\n\x0b\x0c]+')  # Matches spaces, tabs, newlines, etc.

        # Apply the patterns to the column and identify special and noisy whitespace characters
        self.data['special_chars'] = self.data[text_column].apply(lambda x: special_char_pattern.findall(str(x)))
        self.data['noisy_whitespace'] = self.data[text_column].apply(lambda x: whitespace_pattern.findall(str(x)))

        print("Sample of special characters and noisy whitespace detected in text:")
        print(self.data[[text_column, 'special_chars', 'noisy_whitespace']].head())

    def check_punctuation(self, text_column):
        """
        Counts excessive punctuation usage.
        :param text_column: Name of the column containing text data.
        """
        punctuation_pattern = re.compile(r'[.,?!]{2,}')
        self.data['punctuation_count'] = self.data[text_column].apply(lambda x: len(punctuation_pattern.findall(str(x))))
        print("Sample of excessive punctuation usage:")
        print(self.data[[text_column, 'punctuation_count']].head())

    def check_contractions(self, text_column):
        """
        Identifies common contractions in the dataset.
        :param text_column: Name of the column containing text data.
        """
        contractions = ["can't", "won't", "don't", "shouldn't", "it's", "they're", "we'll"]
        self.data['contractions'] = self.data[text_column].apply(lambda x: [word for word in str(x).split() if word in contractions])
        print("Sample of contractions detected:")
        print(self.data[[text_column, 'contractions']].head())

    def check_spelling(self, text_column):
        """
        Identifies potential spelling errors.
        :param text_column: Name of the column containing text data.
        """
        spell = SpellChecker()
        self.data['misspelled_words'] = self.data[text_column].apply(lambda x: [word for word in str(x).split() if word not in spell])
        print("Sample of potential spelling errors:")
        print(self.data[[text_column, 'misspelled_words']].head())

    def check_duplicates(self, *text_column):
        """
        Identifies duplicate records in the dataset.
        :param text_column: Name of the column containing text data.
        """
        duplicate_count = self.data.duplicated(subset=text_column).sum()
        print(f"Number of duplicate articles: {duplicate_count}")

    def check_class_balance(self, label_column):
        """
        Checks the distribution of classes.
        :param label_column: Name of the column containing labels.
        """
        class_counts = Counter(self.data[label_column])
        print("Class distribution:")
        print(class_counts)

    def check_noisy_input(self, text_column):
        """
        Identifies text entries that may be too short or fragmented.
        :param text_column: Name of the column containing text data.
        """
        self.data['word_count'] = self.data[text_column].apply(lambda x: len(str(x).split()))
        print("Sample of very short texts:")
        noisy_entries = self.data[self.data['word_count'] < 5]
        print(noisy_entries[[text_column, 'word_count']].head())
        print(f"Total number of noisy entries (less than 5 words): {len(noisy_entries)}")

if __name__ == "__main__":
    from nlp.data.data_loader import DatasetLoader

    loader = DatasetLoader()
    inspector = DataInspector(loader, "nlp/data/datasets/cleaned_sentiment.csv", file_type="csv", required_columns=["news", "sentiment"])
    inspector.check_special_characters("news")
    inspector.check_punctuation("news")
    inspector.check_contractions("news")
    inspector.check_spelling("news")
    inspector.check_duplicates("news")
    inspector.check_class_balance("sentiment")
    inspector.check_noisy_input("news")

    inspector = DataInspector(loader, "nlp/data/datasets/cleaned_category.csv", file_type="csv", required_columns=["headline", "category"])
    inspector.check_special_characters("headline")
    inspector.check_punctuation("headline")
    inspector.check_contractions("headline")
    inspector.check_duplicates("headline", "category")
    inspector.check_class_balance("category")
    inspector.check_noisy_input("headline")

    inspector = DataInspector(loader, None, file_type="fake_news", true_path="nlp/data/datasets/DataSet_Misinfo_TRUE.csv", fake_path="nlp/data/datasets/DataSet_Misinfo_FAKE.csv")
    inspector.check_special_characters("text")
    inspector.check_punctuation("text")
    inspector.check_contractions("text")
    inspector.check_duplicates("text")
    inspector.check_class_balance("label")
    inspector.check_noisy_input("text")

    inspector = DataInspector(loader, "nlp/data/datasets/cleaned_fake_news.csv", file_type="csv", required_columns=['title', 'label'])
    inspector.check_special_characters("title")
    inspector.check_punctuation("title")
    inspector.check_contractions("title")
    inspector.check_duplicates("title")
    inspector.check_class_balance("label")
    inspector.check_noisy_input("title")

    inspector = DataInspector(loader, None, file_type="fake_news", true_path="nlp/data/datasets/True.csv", fake_path="nlp/data/datasets/Fake.csv")
    inspector.check_special_characters("title")
    inspector.check_punctuation("title")
    inspector.check_contractions("title")
    inspector.check_duplicates("title")
    inspector.check_class_balance("label")
    inspector.check_noisy_input("title")
