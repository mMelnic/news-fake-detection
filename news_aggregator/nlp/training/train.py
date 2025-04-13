import pytorch_lightning as pl
import pandas as pd
import json
from pytorch_lightning.callbacks import ModelCheckpoint
import torch
from nlp.data.datasets import MultiTaskDataset
from nlp.models.data_module import MultiTaskDataModule
from nlp.models.lightning_model import LightningMultiTaskModel

torch.set_num_threads(4)

def train_multitask_model():
    train_files = {
        "sentiment_analysis": "nlp/outputs/sentiment_analysis_train.csv",
        "topic_classification": "nlp/outputs/topic_classification_train.csv",
        "fake_news_detection": "nlp/outputs/fake_news_detection_train.csv"
    }
    val_files = {
        "sentiment_analysis": "nlp/outputs/sentiment_analysis_val.csv",
        "topic_classification": "nlp/outputs/topic_classification_val.csv",
        "fake_news_detection": "nlp/outputs/fake_news_detection_val.csv"
    }

    train_datasets = {task: pd.read_csv(file).to_dict(orient="records") for task, file in train_files.items()}
    val_datasets = {task: pd.read_csv(file).to_dict(orient="records") for task, file in val_files.items()}

    with open("nlp/outputs/class_weights.json", "r") as f:
        class_weights = json.load(f)

    train_dataset = MultiTaskDataset(train_datasets)
    val_dataset = MultiTaskDataset(val_datasets)
    datamodule = MultiTaskDataModule(train_dataset, val_dataset, batch_size=16, num_workers=4)

    task_classes = {
        "sentiment_analysis": 2,
        "topic_classification": len(class_weights["topic_classification"]),
        "fake_news_detection": 2
    }

    model = LightningMultiTaskModel("distilroberta-base", task_classes, class_weights)

    from pytorch_lightning.callbacks import EarlyStopping

    early_stopping_callback = EarlyStopping(
        monitor="val_loss",  # Stop based on validation loss
        mode="min",  # Stop when val_loss stops decreasing
        patience=2,  # Number of epochs to wait before stopping
        verbose=True,  # Log stopping decisions
    )
    checkpoint_callback = ModelCheckpoint(
        monitor="val_loss",
        mode="min",
        save_top_k=1,
        filename="best-checkpoint"
    )
    accelerator = "gpu" if torch.cuda.is_available() else "cpu"

    trainer = pl.Trainer(
        default_root_dir="nlp/checkpoints",
        max_epochs=5,
        accelerator=accelerator,
        devices=1,
        accumulate_grad_batches=4,
        precision='16-mixed',
        gradient_clip_val=1.0,
        callbacks=[early_stopping_callback, checkpoint_callback]
    )
    
    trainer.fit(model, datamodule)

    print("Training complete!")
    return model

if __name__ == "__main__":
    train_multitask_model()
