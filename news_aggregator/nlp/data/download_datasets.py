import os
import kaggle

def download_datasets():
    datasets = [
        "rmisra/news-category-dataset",
        "myrios/news-sentiment-analysis",
        "stevenpeutz/misinformation-fake-news-text-dataset-79k",
        "saurabhshahane/fake-news-classification",
        "clmentbisaillon/fake-and-real-news-dataset"
    ]
    download_path = './nlp/data/datasets'

    if not os.path.exists(download_path):
        os.makedirs(download_path)

    for dataset_name in datasets:
        print(f"Downloading {dataset_name}...")
        kaggle.api.dataset_download_files(dataset_name, path=download_path, unzip=True)
        print(f"Downloaded and extracted {dataset_name}")

if __name__ == "__main__":
    download_datasets()