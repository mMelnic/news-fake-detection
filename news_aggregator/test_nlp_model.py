import os
import django
import logging
import json

# Configure Django settings
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "news_aggregator.settings")
django.setup()

# Set up logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

def test_nlp_model():
    """Test the NLP model loading and prediction"""
    from news.services.nlp_service import NLPPredictionService
    
    logger.info("Testing NLP model...")
    
    # Initialize service
    service = NLPPredictionService()
    
    if not service.is_ready():
        logger.error("NLP service not initialized!")
        return False
        
    # Test prediction
    test_texts = [
        "This article is completely fake and misleading. The government is hiding aliens.", # False, 0
        "Boeing Cuts 10% Of Jobs After Receiving $8.7 Billion In Government Tax Breaks And Subsidies", # True, 1
        "Breaking news: Scientists discover new vaccine that shows promising results in clinical trials.", # False, 0
        "Stock market plunges 20% in worst day since 2008 financial crisis.", # False, 0
        "Justice Dept. group studying national security threats of internet-linked devices", # False, 0
        "The president announced a new tax plan today that will cut taxes for middle-class families.", # False, 0
        "Harry Potter and the Nipple Pumps - Culture Minister to consider Ban", # True, 1
        "Planned Parenthood sues Ohio over plan to restrict funds", # False, 0
    ]
    
    logger.info("Running predictions on test texts...")
    predictions = service.predict_batch(test_texts)
    
    # Print predictions
    logger.info("Prediction results:")
    for text, prediction in zip(test_texts, predictions):
        logger.info(f"\nText: {text[:50]}...")
        logger.info(f"Fake news: {'Yes' if prediction['is_fake'] else 'No'}")
        logger.info(f"Sentiment: {prediction['sentiment']}")
    
    return True

if __name__ == "__main__":
    success = test_nlp_model()
    if success:
        logger.info("NLP model test completed successfully!")
    else:
        logger.error("NLP model test failed!")