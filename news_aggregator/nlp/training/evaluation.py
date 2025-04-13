if __name__ == "__main__":
    import torch
    from sklearn.metrics import precision_recall_fscore_support
    from torch.utils.data import DataLoader
    import pandas as pd
    from nlp.data.multitask_collate import multitask_collate_fn
    from nlp.data.datasets import MultiTaskDataset
    from nlp.models.lightning_model import LightningMultiTaskModel
    import json

    test_files = {
        "sentiment_analysis": "nlp/outputs/sentiment_analysis_test_1.csv",
        "topic_classification": "nlp/outputs/topic_classification_test_1.csv",
        "fake_news_detection": "nlp/outputs/fake_news_detection_test_1.csv"
    }

    test_datasets = {task: pd.read_csv(file).sample(frac=0.1, random_state=100).to_dict(orient="records") for task, file in test_files.items()}

    test_dataset = MultiTaskDataset(test_datasets)
    test_loader = DataLoader(test_dataset, batch_size=16, num_workers=4, collate_fn=multitask_collate_fn)
    with open("nlp/outputs/class_weights.json", "r") as f:
            class_weights = json.load(f)

    task_classes = {
            "sentiment_analysis": 2,
            "topic_classification": len(class_weights["topic_classification"]),
            "fake_news_detection": 2
        }

    model = LightningMultiTaskModel(
        model_name="distilroberta-base",
        task_heads_config=task_classes,
        class_weights=class_weights
    )
    model.load_state_dict(torch.load("nlp/outputs/multi_task_model.pt", map_location=torch.device("cpu")))
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    model.eval()
    model.to(device)

    # Dictionary to store true and predicted labels per task
    task_metrics = {task: {"true_labels": [], "pred_labels": []} for task in test_files.keys()}

    with torch.no_grad():
        for batch in test_loader:
            input_ids = batch["input_ids"].to(device)
            attention_mask = batch["attention_mask"].to(device)
            labels = batch["labels"].to(device)
            tasks = batch["tasks"]  # List of task names (length = batch_size)

            for i, task_name in enumerate(tasks):
                # Get the i-th sample
                sample_input_ids = input_ids[i].unsqueeze(0)
                sample_attention_mask = attention_mask[i].unsqueeze(0)
                sample_label = labels[i].unsqueeze(0)

                # Forward pass
                logits = model(sample_input_ids, sample_attention_mask, task_name=task_name)
                prediction = torch.argmax(logits, dim=1)

                # Accumulate metrics per task
                task_metrics[task_name]["true_labels"].append(sample_label.item())
                task_metrics[task_name]["pred_labels"].append(prediction.item())

    # Calculate precision, recall, and F1 score for each task
    for task, metrics in task_metrics.items():
        true_labels = metrics["true_labels"]
        pred_labels = metrics["pred_labels"]

        precision, recall, f1, _ = precision_recall_fscore_support(true_labels, pred_labels, average="weighted")

        print(f"Metrics for {task}:")
        print(f"  Precision: {precision:.4f}, Recall: {recall:.4f}, F1-Score: {f1:.4f}")