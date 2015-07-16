# DriveBackup
Zips your home folder, stores it in /data, and uploads to GDrive.

## How to use

First, follow "Create a client ID and client secret" in [this page](https://developers.google.com/drive/web/auth/web-server) to get a client ID and client secret for OAuth.
Download it into the root folder as client_secret.json.

### How to change the folder to backup

Change 'BACKUP_DIR', line 18.

### How to change storage location

Change 'BACKUP_OUT', line 19.

### How to change backup file name scheme

Change 'file_name', line 100.
