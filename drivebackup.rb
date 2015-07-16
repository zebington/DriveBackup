require 'google/api_client'
require 'google/api_client/client_secrets'
require 'google/api_client/auth/installed_app'
require 'google/api_client/auth/storage'
require 'google/api_client/auth/storages/file_store'
require 'active_support'
require 'zip'
require 'fileutils'
require_relative 'zip_file_generator'

APPLICATION_NAME = 'Drive API Quickstart'
CLIENT_SECRETS_PATH = 'client_secret.json'
CREDENTIALS_PATH = File.join(Dir.home, '.credentials', 'drive-backup.json')
SCOPE = 'https://www.googleapis.com/auth/drive.file'
BACKUP_NAME = 'backups'
FOLDER_MIME_TYPE = 'application/vnd.google-apps.folder'
ZIP_MIME_TYPE = 'application/zip'
BACKUP_DIR = '/home/charlotte'
BACKUP_OUT = '/data/'

##
# Ensure valid credentials, either by restoring from the saved credentials
# files or intitiating an OAuth2 authorization request via InstalledAppFlow.
# If authorization is required, the user's default browser will be launched
# to approve the request.
#
# @return [Signet::OAuth2::Client] OAuth2 credentials
def authorize
  FileUtils.mkdir_p(File.dirname(CREDENTIALS_PATH))

  file_store = Google::APIClient::FileStore.new(CREDENTIALS_PATH)
  storage = Google::APIClient::Storage.new(file_store)
  auth = storage.authorize

  if auth.nil? || (auth.expired? && auth.refresh_token.nil?)
    app_info = Google::APIClient::ClientSecrets.load(CLIENT_SECRETS_PATH)
    flow = Google::APIClient::InstalledAppFlow.new({
                                                     :client_id => app_info.client_id,
                                                     :client_secret => app_info.client_secret,
                                                     :scope => SCOPE})
    auth = flow.authorize(storage)
    puts "Credentials saved to #{CREDENTIALS_PATH}" unless auth.nil?
  end
  auth
end

def create_file(name, drive_api, client, parent_id, mime_type, payload_path)
  file = drive_api.files.insert.request_schema.new({
                                                     :title => name,
                                                     :description => name,
                                                     :mimeType => mime_type
                                                   })
  unless parent_id == 0
    file.parents = [{:id => parent_id}]
  end
  if payload_path == ''
    result = client.execute(
      :api_method => drive_api.files.insert,
      :body_object => file
    )
  else
    media = Google::APIClient::UploadIO.new payload_path, mime_type
    result = client.execute(
      :api_method => drive_api.files.insert,
      :body_object => file,
      :media => media,
      :parameters => {
        :uploadType => 'multipart'
      }
    )
  end
  result.status
end

# Initialize the API
client = Google::APIClient.new(:application_name => APPLICATION_NAME)
client.authorization = authorize
drive_api = client.discovered_api('drive', 'v2')

i = 1
MAX_TRIES = 5

until i >= MAX_TRIES
  # Gets all folders.
  results = client.execute!(
    :api_method => drive_api.files.list)

  # Attempts to find the backup folder.
  backup_folder = nil
  results.data.items.each do |file|
    if file.title == BACKUP_NAME
      backup_folder = file
      break
    end
  end

  if !backup_folder.nil?
    puts 'Backup home exists.'
    time = Time.new
    file_name = "#{time.year}#{time.month}#{time.day}.zip"
    backup_path = "#{BACKUP_OUT}#{file_name}"
    # Generate the zip file
    zf = ZipFileGenerator.new(BACKUP_DIR, backup_path)
    zf.write
    puts 'Uploading backup.'
    queue = Queue.new
    upload_thread = Thread.new do
      Thread.current[:output] = create_file file_name, drive_api, client, backup_folder.id, ZIP_MIME_TYPE, backup_path
      queue << 'finished'
    end
    write_thread = Thread.new do
      orig = STDOUT.sync
      STDOUT.sync = true
      out = ['.  ', '.. ', '...']
      until queue.size > 0
        out.each do |o|
          print o
          print "\r"
          sleep 0.2
        end
      end
      print "\n"
      STDOUT.sync = orig
    end
    upload_thread.join
    write_thread.join
    result = upload_thread[:output]
      if result == 200
        i = MAX_TRIES
        puts 'Backup uploaded successfully.'
      else
        puts 'Error uploading backup.'
        i += 1
        if i == MAX_TRIES
          puts 'Tried and failed to upload the backup, exiting.'
        else
          puts "Trying backup upload attempt ##{i}."
        end
      end
  else # Attempt to create the folder
    puts 'No backup exists.'
    result = create_file BACKUP_NAME, drive_api, client, 0, FOLDER_MIME_TYPE, ''
    if result == 200 # Creation succeeded
      puts 'Backup folder created successfully.'
      i = 1
    else # Creation failed
      puts 'Error creating the backup folder.'
      i += 1
      if i == MAX_TRIES
        puts 'Tried and failed to create the backup folder, exiting.'
      else
        puts "Trying backup folder creation attempt ##{i}."
      end
    end
  end
end