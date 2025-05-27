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
    model.load_state_dict(torch.load("nlp/outputs/second_multi_task_model_state_dict.pt", map_location=torch.device("cpu")))
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    model.eval()
    model.to(device)

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

    from sklearn.metrics import confusion_matrix
    import seaborn as sns
    import matplotlib.pyplot as plt

    # Calculate precision, recall, and F1 score for each task
    for task, metrics in task_metrics.items():
        true_labels = metrics["true_labels"]
        pred_labels = metrics["pred_labels"]

        precision, recall, f1, _ = precision_recall_fscore_support(true_labels, pred_labels, average="weighted")

        print(f"Metrics for {task}:")
        print(f"  Precision: {precision:.4f}, Recall: {recall:.4f}, F1-Score: {f1:.4f}")
        # Plot confusion matrix
        cm = confusion_matrix(true_labels, pred_labels)
        plt.figure(figsize=(6, 5))
        sns.heatmap(cm, annot=True, fmt="d", cmap="Blues", xticklabels=range(cm.shape[1]), yticklabels=range(cm.shape[0]))
        plt.title(f"Confusion Matrix for {task}")
        plt.xlabel("Predicted Label")
        plt.ylabel("True Label")
        plt.tight_layout()
        plt.show()

    from sklearn.metrics import roc_curve, auc
    import matplotlib.pyplot as plt

    # Plot ROC curves for binary classification tasks
    for task in ["sentiment_analysis", "fake_news_detection"]:
        true_labels = task_metrics[task]["true_labels"]
        pred_labels = task_metrics[task]["pred_labels"]

        # Re-run the model to collect predicted probabilities for ROC
        probs = []
        with torch.no_grad():
            for batch in test_loader:
                input_ids = batch["input_ids"].to(device)
                attention_mask = batch["attention_mask"].to(device)
                labels = batch["labels"].to(device)
                tasks = batch["tasks"]

                for i, task_name in enumerate(tasks):
                    if task_name != task:
                        continue

                    sample_input_ids = input_ids[i].unsqueeze(0)
                    sample_attention_mask = attention_mask[i].unsqueeze(0)

                    logits = model(sample_input_ids, sample_attention_mask, task_name=task_name)
                    prob = torch.softmax(logits, dim=1)[0][1].item()  # Probability of class 1
                    probs.append(prob)

        # Compute ROC curve and AUC
        fpr, tpr, _ = roc_curve(true_labels, probs)
        roc_auc = auc(fpr, tpr)

        # Plot
        plt.figure(figsize=(6, 5))
        plt.plot(fpr, tpr, color="blue", lw=2, label=f"AUC = {roc_auc:.2f}")
        plt.plot([0, 1], [0, 1], color="gray", linestyle="--")
        plt.title(f"ROC Curve – {task.replace('_', ' ').title()}")
        plt.xlabel("False Positive Rate")
        plt.ylabel("True Positive Rate")
        plt.legend(loc="lower right")
        plt.grid(True)
        plt.tight_layout()
        plt.show()
