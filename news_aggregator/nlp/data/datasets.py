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
