# Download IMDb static database content to an Azure storage account
import requests                                        # HTTP request module
import os                                              # Operating system services, including environment variables
from azure.storage.blob import BlobServiceClient       # Azure module to access storage blobs
from azure.identity import DefaultAzureCredential      # Azure module to access managed identities

# Constants
imdb_base_uri = "https://datasets.imdbws.com/"
imdb_data_files = [ "name.basics.tsv.gz", "title.akas.tsv.gz", "title.basics.tsv.gz", "title.crew.tsv.gz", "title.episode.tsv.gz", "title.principals.tsv.gz", "title.ratings.tsv.gz" ]

print("Starting script")

# Get the Azure managed identity
azure_credential = DefaultAzureCredential()
print("Got Azure credentials")

# Download each file
for f in imdb_data_files:
  uri = imdb_base_uri + f
  print(f"Downloading {f} from {uri}")
  response = requests.get(uri)
  if response.status_code == 200:
    filename = os.getenv("TEMP") + "\\" + f
    with open(filename, 'wb') as file_handle:
      file_handle.write(response.content)
    print(f"File {f} downloaded to {filename}")
  else:
    print("Download failed")

