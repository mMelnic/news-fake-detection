import torch
from nlp.models.multitask_model import MultiTaskModel  # Assuming you have a MultiTaskModel class

# Model parameters
task_classes = {
    "sentiment_analysis": 2,  # POSITIVE, NEGATIVE
    "topic_classification": 41,  # Num of categories
    "fake_news_detection": 2  # REAL, FAKE
}

# Initialize model
model = MultiTaskModel("roberta-base", task_classes)

# Verify encoder loading
print("Model initialized successfully.")

# Create dummy input
dummy_input_ids = torch.randint(0, 50265, (1, 128))  # Simulating tokenized input
dummy_attention_mask = torch.ones_like(dummy_input_ids)

# Check forward pass for sentiment classification
sentiment_output = model(dummy_input_ids, dummy_attention_mask, "sentiment_analysis")
print("Sentiment Output Shape:", sentiment_output.shape)

# Check forward pass for topic classification
topic_output = model(dummy_input_ids, dummy_attention_mask, "topic_classification")
print("Topic Classification Output Shape:", topic_output.shape)

# Check forward pass for fake news detection
fake_news_output = model(dummy_input_ids, dummy_attention_mask, "fake_news_detection")
print("Fake News Output Shape:", fake_news_output.shape)