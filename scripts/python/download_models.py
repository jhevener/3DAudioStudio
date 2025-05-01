# Script to download all models listed in model_list_links.json from UVR_resources repository
# Original repository: https://github.com/Bebra777228/UVR_resources
# Author: Bebra777228
# Modified by: FretCapo and xAI (Grok 3), last modified April 30, 2025

import json
import os
import requests
from urllib.parse import urlparse
import argparse

def download_file(url, dest_path):
    """Download a file from a URL to the specified destination path."""
    try:
        print(f"Downloading {url} to {dest_path}...")
        response = requests.get(url, stream=True)
        response.raise_for_status()
        with open(dest_path, 'wb') as f:
            for chunk in response.iter_content(chunk_size=8192):
                if chunk:
                    f.write(chunk)
        print(f"Downloaded: {dest_path}")
    except requests.RequestException as e:
        print(f"Failed to download {url}: {e}")

def get_category_folder(url):
    """Extract the category folder from the URL path (e.g., 'Demucs/Demucs_v1', 'Roformer/BandSplit')."""
    parsed_url = urlparse(url)
    path_parts = parsed_url.path.split('/')
    # URLs follow the pattern: .../models/<Category>/<Subcategory>/filename
    # e.g., /Politrees/UVR_resources/resolve/main/models/Demucs/Demucs_v1/demucs.th
    # We want the part after 'models/' up to the filename
    try:
        models_index = path_parts.index('models')
        # Take the category and subcategory (if present) after 'models'
        category_parts = path_parts[models_index + 1:-1]  # Exclude the filename
        return os.path.join(*category_parts)  # e.g., 'Demucs/Demucs_v1', 'Roformer/BandSplit'
    except (ValueError, IndexError):
        # Fallback if 'models' not found or path is too short
        return "Unknown"

def main():
    parser = argparse.ArgumentParser(description="Download models from UVR_resources repository.")
    parser.add_argument(
        'dest_folder',
        type=str,
        help="Base destination folder to save downloaded models"
    )
    args = parser.parse_args()

    # Base destination folder
    base_dest_folder = args.dest_folder
    os.makedirs(base_dest_folder, exist_ok=True)

    # URL of the model_list_links.json file
    json_url = "https://raw.githubusercontent.com/Bebra777228/UVR_resources/main/model_list_links.json"

    try:
        # Fetch the JSON file
        response = requests.get(json_url)
        response.raise_for_status()
        model_data = json.loads(response.text)

        # Process each category (e.g., demucs_download_list, vr_download_list)
        for category, models in model_data.items():
            print(f"\nProcessing category: {category}")
            if not models:  # Skip empty categories
                print(f"  Category {category} is empty, skipping.")
                continue

            # Process each model in the category
            for model_name, files in models.items():
                print(f"  Processing model: {model_name}")
                for file_name, url in files.items():
                    if not url:
                        print(f"    Skipping empty URL for file {file_name} in {model_name}")
                        continue

                    # Extract the category folder from the URL (e.g., 'Demucs/Demucs_v1')
                    category_folder = get_category_folder(url)
                    if category_folder == "Unknown":
                        print(f"    Could not determine category folder for {url}, using 'Unknown'")
                    
                    # Create the full destination path
                    dest_folder = os.path.join(base_dest_folder, category_folder)
                    os.makedirs(dest_folder, exist_ok=True)
                    dest_path = os.path.join(dest_folder, file_name)

                    # Download the file if it doesn't exist
                    if not os.path.exists(dest_path):
                        download_file(url, dest_path)
                    else:
                        print(f"    {dest_path} already exists, skipping.")

    except requests.RequestException as e:
        print(f"Failed to fetch model list: {e}")
    except json.JSONDecodeError as e:
        print(f"Error parsing JSON: {e}")

if __name__ == "__main__":
    main()