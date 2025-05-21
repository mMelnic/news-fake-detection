import os
import torch
import json
import logging
from transformers import AutoTokenizer
from django.conf import settings

logger = logging.getLogger(__name__)

# Define paths relative to project
MODEL_DIR = os.path.join(settings.BASE_DIR, 'nlp/outputs')
MODEL_PATH = os.path.join(MODEL_DIR, 'second_multi_task_model_state_dict.pt')
LABEL_MAPS_PATH = os.path.join(MODEL_DIR, 'label_maps.json')
CLASS_WEIGHTS_PATH = os.path.join(MODEL_DIR, 'class_weights.json')

class NLPPredictionService:
    _instance = None
    
    def __new__(cls):
        if cls._instance is None:
            cls._instance = super(NLPPredictionService, cls).__new__(cls)
            cls._instance._initialized = False
        return cls._instance
    
    def __init__(self):
        if self._initialized:
            return
            
        self.device = torch.device("cpu")
        self.model = None
        self.tokenizer = None
        self.label_maps = None
        
        try:
            self._load_model()
            self._initialized = True
        except Exception as e:
            logger.error(f"Failed to initialize NLP model: {str(e)}")
            self._initialized = False
    
    def _load_model(self):
        """Load the NLP model and related resources"""
        logger.info("Loading NLP prediction model and resources...")
        
        try:
            # Load label maps
            with open(LABEL_MAPS_PATH, 'r') as f:
                raw_label_maps = json.load(f)
                
            self.label_maps = {
                task: {int(k): v for k, v in mapping.items()}
                for task, mapping in raw_label_maps.items()
            }
            
            # Load class weights
            with open(CLASS_WEIGHTS_PATH, 'r') as f:
                class_weights = json.load(f)
                
            # Define task classes - include all three heads but we'll only use two
            task_classes = {
                "sentiment_analysis": 2,
                "fake_news_detection": 2,
                "topic_classification": len(class_weights.get("topic_classification", {}))
            }
            
            # Import here to avoid circular imports
            from nlp.models.lightning_model import LightningMultiTaskModel
            
            # Initialize model with all three heads to match the state dict
            self.model = LightningMultiTaskModel(
                model_name="distilroberta-base",
                task_heads_config=task_classes,
                class_weights=class_weights
            )
            
            # Load state dict with strict=False to allow missing or unexpected keys
            state_dict = torch.load(MODEL_PATH, map_location=self.device)
            self.model.load_state_dict(state_dict, strict=False)
            self.model.eval()
            self.model.to(self.device)
            
            # Load tokenizer
            self.tokenizer = AutoTokenizer.from_pretrained("distilroberta-base")
            
            logger.info("NLP model loaded successfully")
            
        except Exception as e:
            logger.error(f"Error loading NLP model: {str(e)}")
            raise
    
    def predict_batch(self, texts, tasks=None):
        """
        Predict on a batch of texts.
        
        Args:
            texts: List of text strings to predict on
            tasks: List of task names to run. Defaults to fake news detection and sentiment.
            
        Returns:
            List of dictionaries with predictions for each text
        """
        if not self._initialized:
            logger.warning("NLP model not initialized, returning empty predictions")
            return [{"is_fake": None, "sentiment": None} for _ in texts]
            
        if not texts:
            return []
            
        # We only want to use these two tasks, not topic_classification
        if tasks is None:
            tasks = ["fake_news_detection", "sentiment_analysis"]
            
        try:
            # Filter out non-English content
            filtered_texts = []
            filtered_indices = []
            
            for i, text in enumerate(texts):
                if text and isinstance(text, str) and len(text.strip()) > 10:
                    # Simple heuristic to check if text is likely English
                    # This is a very basic check - in production you might want a better language detector
                    english_chars = sum(1 for c in text if c.isalpha() and c.isascii())
                    if english_chars / max(1, len(text)) > 0.7:  # If at least 70% English characters
                        filtered_texts.append(text[:2000])  # Limit text length to prevent overflow
                        filtered_indices.append(i)
            
            results = [{
                "is_fake": None,
                "sentiment": None
            } for _ in texts]
            
            if not filtered_texts:
                return results
                
            # Tokenize texts
            encoded = self.tokenizer(
                filtered_texts,
                padding=True,
                truncation=True,
                max_length=512,
                return_tensors="pt"
            ).to(self.device)
            
            # Get predictions
            with torch.no_grad():
                for task in tasks:
                    # Skip topic_classification even if it exists in the model
                    if task == "topic_classification":
                        continue
                        
                    try:
                        logits = self.model(
                            encoded["input_ids"],
                            encoded["attention_mask"],
                            task_name=task
                        )
                        pred_ids = torch.argmax(logits, dim=1).cpu().tolist()
                        
                        # Map predictions to labels
                        if task in self.label_maps:
                            preds = [self.label_maps[task][i] for i in pred_ids]
                        else:
                            preds = pred_ids
                            
                        # Update results
                        for idx, pred, orig_idx in zip(range(len(preds)), preds, filtered_indices):
                            if task == "fake_news_detection":
                                print(f"Prediction for task {task}: {pred}")
                                results[orig_idx]["is_fake"] = (int(pred) == 0) # Explanation: True = fake, False = real
                                logger.info(f"Fake news prediction for text {orig_idx}: {results[orig_idx]['is_fake']}")
                            elif task == "sentiment_analysis":
                                results[orig_idx]["sentiment"] = pred.lower()
                    except Exception as task_error:
                        logger.error(f"Error processing task '{task}': {str(task_error)}")
            
            return results
            
        except Exception as e:
            logger.error(f"Error in NLP prediction: {str(e)}")
            logger.exception("Full traceback:")
            return [{"is_fake": None, "sentiment": None} for _ in texts]
            
    def is_ready(self):
        """Check if the model is initialized and ready for prediction"""
        return self._initialized