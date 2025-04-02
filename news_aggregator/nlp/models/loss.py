import torch.nn as nn
import torch

class LossStrategy:
    def __init__(self, class_weights=None):
        """
        Initializes the loss function strategy with optional class weights.
        :param class_weights: Dictionary of computed class weights.
        """
        self.class_weights = class_weights
        self.loss_functions = {}

    def compute_loss(self, task_name, predictions, targets):
        """
        Computes weighted loss for classification tasks.
        :param task_name: Task name (e.g., 'topic_classification').
        :param predictions: Model predictions.
        :param targets: Ground truth labels.
        :return: Computed loss.
        """
        if task_name not in self.loss_functions:
            if self.class_weights:
                weights = torch.tensor(list(self.class_weights[task_name].values()), dtype=torch.float32)
                self.loss_functions[task_name] = nn.CrossEntropyLoss(weight=weights)
            else:
                self.loss_functions[task_name] = nn.CrossEntropyLoss()

        return self.loss_functions[task_name](predictions, targets)