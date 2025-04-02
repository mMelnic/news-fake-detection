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
            return nn.Linear(hidden_size, num_classes)
        elif task_name == "fake_news_detection":
            return nn.Linear(hidden_size, num_classes)
        elif task_name == "sentiment_analysis":
            return nn.Linear(hidden_size, num_classes)
        else:
            raise ValueError(f"Unknown task: {task_name}")
