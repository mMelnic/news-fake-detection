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
        
    def load_fake_news_data(self, true_path: str, fake_path: str) -> pd.DataFrame:
        """
        Combines the TRUE and FAKE datasets into a single DataFrame, adds a label column,
        and keeps only the 'title' column and 'label' column.
        :param true_path: Path to the TRUE.csv file.
        :param fake_path: Path to the FAKE.csv file.
        :return: A pandas DataFrame containing combined data with the 'title' column and labels.
        """
        try:
            true_data = pd.read_csv(true_path)
            fake_data = pd.read_csv(fake_path)

            if "title" not in true_data.columns or "title" not in fake_data.columns:
                raise ValueError("Both files must contain a 'title' column")

            true_data["label"] = 1
            fake_data["label"] = 0

            true_data = true_data[["title", "label"]]
            fake_data = fake_data[["title", "label"]]

            combined_data = pd.concat([true_data, fake_data], ignore_index=True)
            return combined_data

        except FileNotFoundError:
            print(f"Error: One of the files was not found: {true_path}, {fake_path}")
            return pd.DataFrame()
        except ValueError as ve:
            print(f"Error: {ve}")
            return pd.DataFrame()
