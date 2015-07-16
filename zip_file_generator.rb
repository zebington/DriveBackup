require 'zip'

# This is a simple example which uses rubyzip to
# recursively generate a zip file from the contents of
# a specified directory. The directory itself is not
# included in the archive, rather just its contents.
#
# Usage:
#   directoryToZip = "/tmp/input"
#   outputFile = "/tmp/out.zip"
#   zf = ZipFileGenerator.new(directoryToZip, outputFile)
#   zf.write()
class ZipFileGenerator

  # Initialize with the directory to zip and the location of the output archive.
  def initialize(input_dir, output_file)
    @input_dir = input_dir
    @output_file = output_file
  end

  # Zip the input directory.
  def write
    entries = Dir.entries(@input_dir); entries.delete('.'); entries.delete('..')
    io = Zip::File.open(@output_file, Zip::File::CREATE)

    writeEntries(entries, '', io)
    io.close
  end

  # A helper method to make the recursion work.
  private
  def writeEntries(entries, path, io)

    entries.each { |e|
      unless e[0] == '.'
        zip_file_path = path == '' ? e : File.join(path, e)
        disk_file_path = File.join(@input_dir, zip_file_path)
        puts 'Deflating ' + disk_file_path
        if File.directory?(disk_file_path)
          io.mkdir(zip_file_path)
          subdir =Dir.entries(disk_file_path); subdir.delete('.'); subdir.delete('..')
          writeEntries(subdir, zip_file_path, io)
        else
          io.get_output_stream(zip_file_path) { |f| f.puts(File.open(disk_file_path, 'rb').read) }
        end
      end
    }
  end

end
