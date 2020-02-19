require 'date'
require 'active_support/core_ext/numeric/conversions'

require './config'

class FilenameHandler
  attr_reader :full_filename, :filename, :ext, :basename, :path

  def initialize
    config = Config.new.config
    @date = Date.today + 1
    @sep = File::ALT_SEPARATOR
    @ext = ''
    @basename = ''
    @path = ''
    @filename = ''
    @full_filename = ''
    @load_filename = config[:default_filenames][0]
    @assigned_routes_filename = config[:default_filenames][1]
  end

  def from_download_dir
    download_path = %w[.. .. .. .. Downloads].join @sep
    set_filename(@load_filename)
    set_pathname(download_path, @load_filename)
    @full_filename
  end

  def to_data_dir
    set_filename(@load_filename, insert=@date.strftime("%Y-%m-%d"))
    data_path = %w[.. .. data berlys]
    data_path += [@date.strftime("%Y"), @date.strftime("%m")]
    data_path = data_path.join(@sep)
    set_pathname("#{data_path}#{@sep}", @filename)
    @full_filename
  end

  def to_attachments_dir
    set_filename(@load_filename, insert=@date.strftime("%Y-%m-%d"))
    data_path = %w[.. .. data berlys attachments].join(@sep)
    set_pathname("#{data_path}#{@sep}", @filename)
    @full_filename
  end

  def get_last_downloaded_file
    to_attachments_dir
    files = Dir.entries(@path)
    set_filename files[-1]
    @full_filename = "#{@path}#{@sep}#{@filename}"
    return @full_filename
  end

  def inspect
    "#<FilenameHandler filename='#{@filename}', basename='#{@basename}', ext='#{@ext}', path='#{@path}', " + \
    "full_filename='#{@full_filename}'>"
  end

  private
  def set_pathname(dir, filename)
    @path = File.dirname("#{dir}#{@sep}#{filename}")
    @full_filename = "#{@path}#{@sep}#{@filename}"
  end

  def set_filename(filename, insert='')
    @ext = File.extname(filename)
    @basename = File.basename(filename, @ext)
    @basename = "#{@basename} #{insert}" if !insert.empty?
    @filename = "#{@basename}#{@ext}"
  end
end

def format_number(number)
  number.to_s(:rounded, precision: 3).to_f.to_s(:delimited, delimiter: ".", separator: ",")
end
