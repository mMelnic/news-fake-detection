from sklearn.model_selection import train_test_split

class DatasetSplitter:
    def split_data(self, data, train_size=0.7, val_size=0.15, random_state=42):
        """
        Splits the dataset into train, validation, and test sets.
        """
        train_data, temp_data = train_test_split(data, train_size=train_size, random_state=random_state)
        val_data, test_data = train_test_split(temp_data, train_size=val_size/(1-train_size), random_state=random_state)
        
        return train_data, val_data, test_data
