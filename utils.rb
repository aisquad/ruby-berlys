require 'date'
require 'active_support/core_ext/numeric/conversions'

require './config'

class FilenameHandler
  attr_reader :full_filename, :filename, :ext, :basename, :path

  def initialize(date=nil)
    config = Config.new.config
    @date = date != nil ? date : Date.today
    @sep = File::ALT_SEPARATOR
    @ext = ''
    @basename = ''
    @path = ''
    @filename = ''
    @full_filename = ''
    @load_filename = config[:default_filenames][0]
  end

  def from_download_dir
    download_path = %w[.. .. .. .. Downloads].join @sep
    set_filename(@load_filename)
    set_pathname(download_path, @load_filename)
    @full_filename
  end

  def to_data_dir
    set_filename
    set_pathname("#{set_data_path}#{@sep}", @filename)
    @full_filename
  end

  def to_attachments_dir(filename)
    set_filename(filename)
    data_path = %w[.. .. data berlys attachments].join(@sep)
    set_pathname("#{data_path}#{@sep}", @filename)
    @full_filename
  end

  def get_last_downloaded_file
    @path = "#{set_data_path}#{@sep}"
    files = Dir.entries(@path)
    set_filename files[-1]
    @full_filename = "#{@path}#{@filename}"
    return @full_filename
  end

  def inspect
    "#<FilenameHandler filename='#{@filename}', basename='#{@basename}', ext='#{@ext}', path='#{@path}', " + \
    "full_filename='#{@full_filename}'>"
  end

  private
  def set_data_path
    data_path = %w[.. .. data berlys]
    data_path += [@date.strftime("%Y"), @date.strftime("%m")]
    data_path.join(@sep)
  end

  def set_pathname(dir, filename)
    @path = File.dirname("#{dir}#{@sep}#{filename}")
    @full_filename = "#{@path}#{@sep}#{@filename}"
  end

  def set_filename(filename='')
    filename = "#{@date.to_s}.txt" if filename == ''
    @ext = File.extname(filename)
    @basename = File.basename(filename, @ext)
    @filename = "#{@basename}#{@ext}"
  end
end

def set_new_filename(data)
  date_match = /(?<date>\d{2}\.\d{2}\.\d{4})/.match(data)
  load_date = Date.strptime(date_match[:date], '%d.%m.%Y')
  fh = FilenameHandler.new(load_date)
  fh.to_data_dir
end

def format_number(number)
  number.to_s(:rounded, precision: 3).to_f.to_s(:delimited, delimiter: ".", separator: ",")
end
