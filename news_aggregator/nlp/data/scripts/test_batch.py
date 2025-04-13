from nlp.data.preprocess import DataPreprocessor
import pandas as pd
import json

# Define the main function
def main():
    train_files = {
        "sentiment_analysis": "nlp/outputs/sentiment_analysis_train.csv",
        "topic_classification": "nlp/outputs/topic_classification_train.csv",
        "fake_news_detection": "nlp/outputs/fake_news_detection_train.csv"
    }

    train_datasets = {task: pd.read_csv(file).to_dict(orient="records") for task, file in train_files.items()}

    with open("nlp/outputs/class_weights.json", "r") as f:
        class_weights = json.load(f)

    from nlp.data.datasets import MultiTaskDataset

    # Initialize multi-task dataset
    multi_task_dataset = MultiTaskDataset(train_datasets)

    from torch.utils.data import DataLoader
    from nlp.data.multitask_collate import multitask_collate_fn

    # Initialize DataLoader
    train_dataloader = DataLoader(multi_task_dataset, batch_size=32, shuffle=True, collate_fn=multitask_collate_fn, num_workers=4)

    # Fetch a sample batch
    batch = next(iter(train_dataloader))

    print("Batch Structure:")
    print("Input IDs Shape:", batch["input_ids"].shape)  # Expected: (batch_size, sequence_length)
    print("Attention Mask Shape:", batch["attention_mask"].shape)  # Expected: (batch_size, sequence_length)
    print("Labels Shape:", batch["labels"].shape)  # Expected: (batch_size,)
    print("Task Names:", batch["tasks"])  # Expected: List of task names per sample

    # Sample tokenized input check
    print("\nSample Tokenized Input:", batch["input_ids"][0])
    print("Sample Attention Mask:", batch["attention_mask"][0])
    print("Sample Label:", batch["labels"][0])
    print("Sample Task:", batch["tasks"][0])

    import torch
    from nlp.models.multitask_model import MultiTaskModel

    # Initialize the model
    task_classes = {
        "sentiment_analysis": 2,
        "topic_classification": len(class_weights['topic_classification']),
        "fake_news_detection": 2
    }

    model = MultiTaskModel("distilroberta-base", task_classes)
    model.eval()  # Set model to evaluation mode

    # Run inference on a sample batch
    input_ids = batch["input_ids"]
    attention_mask = batch["attention_mask"]
    tasks = batch["tasks"]

    # Process each sample by its task
    outputs = {task: [] for task in task_classes.keys()}

    for i in range(len(tasks)):
        task_name = tasks[i]
        with torch.no_grad():  # Disable gradient calculation for inference
            logits = model(input_ids[i].unsqueeze(0), attention_mask[i].unsqueeze(0), task_name)
            outputs[task_name].append(logits)

    # Print output shapes
    for task, logits_list in outputs.items():
        print(f"Task: {task}, Output Shape: {logits_list[0].shape}")

    from nlp.models.loss import LossStrategy
    # Initialize loss strategy with computed class weights
    loss_strategy = LossStrategy(class_weights)

    # Generate dummy predictions (logits) for each task
    dummy_predictions = {
        "sentiment_analysis": torch.randn(1, 2),  # (Batch size, Num classes)
        "topic_classification": torch.randn(1, 41),  # (Batch size, Num categories)
        "fake_news_detection": torch.randn(1, 2)  # (Batch size, Num classes)
    }

    # Generate dummy targets
    dummy_targets = {
        "sentiment_analysis": torch.tensor([1]),  # Class index
        "topic_classification": torch.tensor([10]),  # Class index
        "fake_news_detection": torch.tensor([0])  # Class index
    }

    # Compute loss for each task
    for task, preds in dummy_predictions.items():
        loss = loss_strategy.compute_loss(task, preds, dummy_targets[task])
        print(f"Task: {task}, Loss Value: {loss.item()}")

# Wrap the execution in `if __name__ == "__main__":`
if __name__ == "__main__":
    main()