import sys
import os
from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload

# Define Google Drive folder ID where backups will be uploaded
FOLDER_ID = os.environ.get("GOOGLE_DRIVE_FOLDER_ID")

# Define the credentials file
CREDENTIALS_FILE = os.environ.get("GOOGLE_DRIVE_CREDENTIALS_FILE_PATH")


def upload_to_drive(file_path, folder_id):
    SCOPES = ["https://www.googleapis.com/auth/drive.file"]
    creds = service_account.Credentials.from_service_account_file(
        CREDENTIALS_FILE, scopes=SCOPES
    )
    service = build("drive", "v3", credentials=creds)

    file_metadata = {"name": os.path.basename(file_path), "parents": [folder_id]}
    media = MediaFileUpload(file_path, resumable=True)
    file = (
        service.files()
        .create(body=file_metadata, media_body=media, fields="id")
        .execute()
    )
    print(f"File {file_path} uploaded to Google Drive with file ID: {file.get('id')}")


if __name__ == "__main__":
    files_to_upload = sys.argv[1:]
    for file_path in files_to_upload:
        upload_to_drive(file_path, FOLDER_ID)
