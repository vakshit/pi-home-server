import sys
import os
from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload

# Define Google Drive folder ID where backups will be uploaded
FOLDER_ID = os.environ.get("GOOGLE_DRIVE_FOLDER_ID")

# Define the credentials file
CREDENTIALS_FILE = os.environ.get("GOOGLE_DRIVE_CREDENTIALS_FILE_PATH")

def get_service():
    SCOPES = ['https://www.googleapis.com/auth/drive.file']
    creds = service_account.Credentials.from_service_account_file(CREDENTIALS_FILE, scopes=SCOPES)
    return build('drive', 'v3', credentials=creds)

def search_file(service, file_name, folder_id):
    query = f"name = '{file_name}' and '{folder_id}' in parents and trashed = false"
    results = service.files().list(q=query, spaces='drive', fields='files(id, name)').execute()
    items = results.get('files', [])
    return items[0] if items else None

def upload_to_drive(service, file_path, folder_id):
    file_name = os.path.basename(file_path)
    existing_file = search_file(service, file_name, folder_id)

    file_metadata = {
        'name': file_name,
        'parents': [folder_id]
    }
    media = MediaFileUpload(file_path, resumable=True)

    if existing_file:
        # print(f"File {file_name} exists. Updating it.")
        file_id = existing_file['id']
        updated_file = service.files().update(
            fileId=file_id,
            media_body=media
        ).execute()
        # print(f"File {file_path} updated on Google Drive with file ID: {updated_file.get('id')}")
    else:
        # print(f"Uploading new file {file_name}.")
        new_file = service.files().create(
            body=file_metadata,
            media_body=media,
            fields='id'
        ).execute()
        # print(f"File {file_path} uploaded to Google Drive with file ID: {new_file.get('id')}")

if __name__ == '__main__':
    # Initialize the Google Drive service
    service = get_service()

    # Assume the Bash script produces these backup files
    files_to_upload = sys.argv[1:]
    for file_path in files_to_upload:
        upload_to_drive(service, file_path, FOLDER_ID)

