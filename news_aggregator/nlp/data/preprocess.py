from transformers import AutoTokenizer
import pandas as pd

class DataPreprocessor:
    def __init__(self, tokenizer_name: str = "distilroberta-base"):
        self.tokenizer = AutoTokenizer.from_pretrained(tokenizer_name)

    def clean_text(self, text: str) -> str:
        """
        Cleans input text minimally for RoBERTa.
        :param text: Raw text input.
        :return: Cleaned text string.
        """
        if not isinstance(text, str):
            return ""
        text = text.strip()
        return text

    def encode_labels(self, data: pd.DataFrame, label_column: str) -> pd.DataFrame:
        """
        Encodes categorical labels into numeric format.
        :param data: DataFrame with the raw labels.
        :param label_column: Name of the label column to encode.
        :return: DataFrame with an additional 'label' column.
        """
        label_mapping = {label: idx for idx, label in enumerate(data[label_column].unique())}
        data['label'] = data[label_column].map(label_mapping)
        self.label_mapping = label_mapping  # Save for later use
        return data

    def tokenize(self, data: pd.DataFrame, text_column: str, max_length: int = 50):
        """
        Tokenizes text columns and prepares tokenized inputs for the model.
        :param data: DataFrame containing the text to tokenize.
        :param text_columns: Column to use as input.
        :param max_length: Maximum sequence length for the tokenizer.
        :return: Tokenized inputs as a dictionary of tensors.
        """
        
        encoded_data = self.tokenizer(
            list(data[text_column]),
            padding=True,
            truncation=True,
            max_length=max_length,
            return_tensors='pt'
        )
        return encoded_data