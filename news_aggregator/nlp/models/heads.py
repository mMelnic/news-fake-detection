import torch.nn as nn

class TaskHeadFactory:
    @staticmethod
    def create_head(task_name, hidden_size, num_classes):
        """
        Factory method to create a task-specific head.
        :param task_name: The name of the task.
        :param hidden_size: The size of the hidden representation.
        :param num_classes: The number of output classes for the task.
        :return: A PyTorch module for the task-specific head.
        """
        if task_name == "topic_classification":
            return nn.Sequential(
                nn.Dropout(0.5),  # Higher dropout for topic head
                nn.Linear(hidden_size, hidden_size//2),
                nn.LayerNorm(hidden_size//2), # Layer normalization for stability
                nn.ReLU(),
                nn.Linear(hidden_size//2, num_classes)
            )
        elif task_name in ["fake_news_detection", "sentiment_analysis"]:
            return nn.Sequential(
                nn.Dropout(p=0.1),
                nn.Linear(hidden_size, hidden_size // 2),
                nn.ReLU(),
                nn.Linear(hidden_size // 2, num_classes)
            )
        else:
            raise ValueError(f"Unknown task: {task_name}")
