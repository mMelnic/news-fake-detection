import torch
from transformers import AutoTokenizer
from nlp.models.lightning_model import LightningMultiTaskModel
import json

def predict_for_tasks(model, tasks, texts, device="cpu", label_maps=None):
    """
    Generate predictions for specified tasks using a trained multi-task model.
        :param model (nn.Module): Trained LightningMultiTaskModel.
        :param tasks (list): List of task names to predict on.
        :param texts (list): List of input texts.
        :param device (str): Device to run prediction on.
        :param label_maps (dict): Optional. Maps from class indices to label names per task.
                           Format: {"task_name": {0: "label0", 1: "label1", ...}}
        :return dict: {task_name: list of predictions}
    """
    model.eval()
    model.to(device)

    tokenizer = AutoTokenizer.from_pretrained("distilroberta-base")
    encoded = tokenizer(texts, padding=True, truncation=True, return_tensors="pt").to(device)

    predictions = {}

    with torch.no_grad():
        for task in tasks:
            logits = model(encoded["input_ids"], encoded["attention_mask"], task_name=task)
            pred_ids = torch.argmax(logits, dim=1).cpu().tolist()

            if label_maps and task in label_maps:
                predictions[task] = [label_maps[task][i] for i in pred_ids]
            else:
                predictions[task] = pred_ids

    return predictions

if __name__ == "__main__":
    with open("nlp/outputs/label_maps.json") as f:
        raw_label_maps = json.load(f)

    label_maps = {
        task: {int(k): v for k, v in mapping.items()}
        for task, mapping in raw_label_maps.items()
    }

    input_texts = [
        "This article is completely fake and misleading. The government is hiding aliens.", # False, 0
        "Boeing Cuts 10% Of Jobs After Receiving $8.7 Billion In Government Tax Breaks And Subsidies", # True, 1
        "Breaking news: Scientists discover new vaccine that shows promising results in clinical trials.", # False, 0
        "Stock market plunges 20% in worst day since 2008 financial crisis.", # False, 0
        "Justice Dept. group studying national security threats of internet-linked devices", # False, 0
        "The president announced a new tax plan today that will cut taxes for middle-class families.", # False, 0
        "Harry Potter and the Nipple Pumps - Culture Minister to consider Ban", # True, 1
        "Planned Parenthood sues Ohio over plan to restrict funds", # False, 0
    ]

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
    predictions = predict_for_tasks(model, tasks=["fake_news_detection", "sentiment_analysis", "topic_classification"], texts=input_texts, device=device, label_maps=label_maps)

    for task in predictions:
        print(f"\nTask: {task}")
        for text, prediction in zip(input_texts, predictions[task]):
            print(f"  → \"{text[:60]}...\": {prediction}")
