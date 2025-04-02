import random
from torch.utils.data import Dataset

class MultiTaskDataset(Dataset):
    def __init__(self, datasets):
        """
        Initialize the multi-task dataset.
        :param datasets: A dictionary containing task names as keys and their corresponding datasets as values.
        """
        self.datasets = datasets
        self.task_list = list(datasets.keys())

        self.samples = []
        for task_name, dataset in datasets.items():
            for sample in dataset:
                sample["task"] = task_name
                self.samples.append(sample)

        # Shuffle for better task distribution
        random.shuffle(self.samples)

    def __len__(self):
        return len(self.samples)

    def __getitem__(self, idx):
        sample = self.samples[idx]
        
        # Each sample has the required fields for batching
        input_ids = sample.get("input_ids")
        attention_mask = sample.get("attention_mask")
        labels = sample.get("label")
        task = sample.get("task")
        
        if "input_ids" not in sample:
            raise KeyError(f"Sample at index {idx} is missing 'input_ids'.")
        if "attention_mask" not in sample:
            raise KeyError(f"Sample at index {idx} is missing 'attention_mask'.")
        if "label" not in sample:
            raise KeyError(f"Sample at index {idx} is missing 'labels'.")

        return {
            "input_ids": input_ids,
            "attention_mask": attention_mask,
            "label": labels,
            "task": task
        }