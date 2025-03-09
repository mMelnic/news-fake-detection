import pandas as pd
import json

class DatasetLoader:
    def load_json(self, file_path: str, required_columns: list[str]) -> pd.DataFrame:
        """
        Loads a JSON dataset and extracts the required columns.
        :param file_path: Path to the dataset file.
        :param required_columns: List of columns to extract (e.g., ['headline', 'short_description', 'category']).
        :return: A pandas DataFrame containing the extracted data.
        """
        with open(file_path, 'r') as file:
            data = [json.loads(line) for line in file]
        df = pd.DataFrame(data)
        return df[required_columns]
    
    def load_csv(self, file_path: str, required_columns: list[str] = None) -> pd.DataFrame:
        """
        Loads data from a CSV file and extracts the required columns.
        :param file_path: Path to the CSV file.
        :param required_columns: List of columns to extract. If None, all columns will be loaded.
        :return: A pandas DataFrame containing the extracted data.
        """
        try:
            if required_columns:
                data = pd.read_csv(file_path, usecols=required_columns)
            else:
                data = pd.read_csv(file_path)
            return data
        except FileNotFoundError:
            print(f"Error: File not found at path {file_path}")
            return pd.DataFrame()
        except ValueError as ve:
            print(f"Error: {ve}")
            return pd.DataFrame()
