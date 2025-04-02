from transformers import AutoModel
from .heads import TaskHeadFactory
import torch.nn as nn

class MultiTaskModel(nn.Module):
    _instance = None

    def __new__(cls, *args, **kwargs):
        if cls._instance is None:
            cls._instance = super(MultiTaskModel, cls).__new__(cls)
        return cls._instance

    def __init__(self, model_name, task_heads_config):
        """
        Initialize the multi-task model.
        :param model_name: Pretrained model name (e.g., 'roberta-base').
        :param task_heads_config: A dictionary containing task names and the number of classes for each.
        """
        super(MultiTaskModel, self).__init__()
        self.shared_encoder = AutoModel.from_pretrained(model_name)
        self.dropout = nn.Dropout(0.1)
        self.heads = nn.ModuleDict({
            task_name: TaskHeadFactory.create_head(task_name, self.shared_encoder.config.hidden_size, num_classes)
            for task_name, num_classes in task_heads_config.items()
        })

    def forward(self, input_ids, attention_mask, task_name):
        """
        Forward pass for the multi-task model.
        :param input_ids: Input token IDs.
        :param attention_mask: Attention mask.
        :param task_name: The name of the task.
        :return: Task-specific output.
        """
        encoder_outputs = self.shared_encoder(input_ids, attention_mask)
        pooled_output = encoder_outputs.pooler_output  # CLS token
        pooled_output = self.dropout(pooled_output)
        return self.heads[task_name](pooled_output)
