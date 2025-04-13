import pytorch_lightning as pl
import torch
from torch.optim import AdamW
from nlp.models.multitask_model import MultiTaskModel
from nlp.models.loss import LossStrategy

class LightningMultiTaskModel(pl.LightningModule):
    def __init__(self, model_name, task_heads_config, class_weights=None, learning_rate=5e-5, weight_decay=1e-2):
        super().__init__()
        self.model = MultiTaskModel(model_name, task_heads_config)
        self.loss_strategy = LossStrategy(class_weights)
        self.learning_rate = learning_rate
        self.weight_decay = weight_decay

    def forward(self, input_ids, attention_mask, task_name):
        return self.model(input_ids, attention_mask, task_name)

    def training_step(self, batch, batch_idx):
        input_ids, attention_mask, labels, task_names = (
            batch["input_ids"],
            batch["attention_mask"],
            batch["labels"],
            batch["tasks"],
        )

        task_losses = []
        for i, task_name in enumerate(task_names):
            logits = self(input_ids[i].unsqueeze(0), attention_mask[i].unsqueeze(0), task_name)
            loss = self.loss_strategy.compute_loss(task_name, logits, labels[i].unsqueeze(0))
            task_losses.append(loss)

        total_loss = torch.stack(task_losses).mean()
        self.log("train_loss", total_loss, prog_bar=True)
        return total_loss

    def validation_step(self, batch, batch_idx):
        input_ids, attention_mask, labels, task_names = (
            batch["input_ids"],
            batch["attention_mask"],
            batch["labels"],
            batch["tasks"],
        )

        task_losses = []
        for i, task_name in enumerate(task_names):
            logits = self(input_ids[i].unsqueeze(0), attention_mask[i].unsqueeze(0), task_name)
            loss = self.loss_strategy.compute_loss(task_name, logits, labels[i].unsqueeze(0))
            task_losses.append(loss)

        total_loss = torch.stack(task_losses).mean()
        self.log("val_loss", total_loss, prog_bar=True)
        return total_loss

    def configure_optimizers(self):
        optimizer = AdamW(self.parameters(), lr=self.learning_rate, weight_decay=self.weight_decay)
        return optimizer
