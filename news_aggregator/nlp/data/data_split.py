from sklearn.model_selection import train_test_split
from sklearn.utils.class_weight import compute_class_weight
import numpy as np

class DatasetSplitter:
    def split_data(self, data, train_size=0.7, val_size=0.15, random_state=42):
        """
        Splits the dataset into train, validation, and test sets.
        """
        train_data, temp_data = train_test_split(data, train_size=train_size, random_state=random_state)
        val_data, test_data = train_test_split(temp_data, train_size=val_size/(1-train_size), random_state=random_state)
        
        return train_data, val_data, test_data

    def stratified_split(self, data, label_column, train_size=0.7, val_size=0.15, random_state=42):
        """
        Performs stratified splitting while preserving class distribution.
        Also calculates class weights for loss function.
        :param data: DataFrame containing the dataset.
        :param label_column: Column representing class labels.
        :param train_size: Proportion of data to allocate to training.
        :param val_size: Proportion to allocate to validation.
        :param random_state: Seed for reproducibility.
        :return: Train, validation, test splits and class weights.
        """
        train_data, temp_data = train_test_split(data, train_size=train_size, stratify=data[label_column], random_state=random_state)
        val_data, test_data = train_test_split(temp_data, train_size=val_size/(1-train_size), stratify=temp_data[label_column], random_state=random_state)

        class_counts = train_data[label_column].value_counts()
        class_weights = compute_class_weight('balanced', classes=np.array(class_counts.index), y=train_data[label_column])
        class_weights = dict(zip(class_counts.index, class_weights))

        return train_data, val_data, test_data, class_weights
