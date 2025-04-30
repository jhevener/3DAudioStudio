# Script to download all models listed in model_list_links.json from UVR_resources repository
# Original repository: https://github.com/Bebra777228/UVR_resources
# Author: Bebra777228
# Modified by: FretCapo and xAI

import json
import os
import requests
from urllib.parse import urlparse
import argparse

def download_file(url, dest_folder):
    """Download a file from a URL to the specified destination folder."""
    try:
        # Get the filename from the URL
        filename = os.path.basename(urlparse(url).path)
        if not filename:
            filename = "downloaded_file"  # Fallback filename
        dest_path = os.path.join(dest_folder, filename)

        # Stream the download to handle large files
        response = requests.get(url, stream=True)
        response.raise_for_status()  # Check for HTTP errors

        # Write the file to disk
        with open(dest_path, 'wb') as f:
            for chunk in response.iter_content(chunk_size=8192):
                if chunk:
                    f.write(chunk)
        print(f"Downloaded: {filename}")
    except requests.RequestException as e:
        print(f"Failed to download {url}: {e}")

def main():
    # Set up argument parser for destination folder
    parser = argparse.ArgumentParser(description="Download models from UVR_resources repository.")
    parser.add_argument(
        'dest_folder',
        type=str,
        help="Destination folder to save downloaded models"
    )
    args = parser.parse_args()

    # Ensure the destination folder exists
    dest_folder = args.dest_folder
    os.makedirs(dest_folder, exist_ok=True)

    # URL of the model_list_links.json file
    json_url = "https://raw.githubusercontent.com/Bebra777228/UVR_resources/main/model_list_links.json"

    try:
        # Fetch the JSON file
        response = requests.get(json_url)
        response.raise_for_status()
        model_data = json.loads(response.text)

        # Process each category (e.g., demucs_download_list, vr_download_list)
        for category, models in model_data.items():
            print(f"Processing category: {category}")
            if not models:  # Skip empty categories
                print(f"  Category {category} is empty, skipping.")
                continue

            # Process each model in the category
            for model_name, files in models.items():
                print(f"  Processing model: {model_name}")
                # Handle cases where files is a dictionary of file names and URLs
                for file_name, url in files.items():
                    if url:
                        download_file(url, dest_folder)
                    else:
                        print(f"    Skipping empty URL for file {file_name} in {model_name}")

    except requests.RequestException as e:
        print(f"Failed to fetch model list: {e}")
    except json.JSONDecodeError as e:
        print(f"Error parsing JSON: {e}")

if __name__ == "__main__":
    main()