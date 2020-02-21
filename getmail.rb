require 'gmail'

class GetMail
  attr_reader :last_data, :last_filename
  attr_writer :days_ago, :save_downloads

  def initialize
    @days_ago = 1
    @config = Config.new.config
    @attachments = {}
    @allowed_filenames = @config[:default_filenames]
    @save_downloads = false
    @last_data = ''
    @last_filename = ''
  end

  def get_creation_date(attachment)
    fields = attachment.header["Content-Disposition"].field.to_s
    fields = fields.gsub('"', '')
    fields.split("; ").each do |item|
      key, val =  item.split("=") if item.include?('=')
      next unless key == 'creation-date'
      date = Date.strptime(val, "%a, %d %b %Y %H:%M:%S %Z")
      return date.strftime("%Y-%m-%d")
    end
  end

  def save_load_file(attachment)
    data = attachment.decoded
    filename = set_new_filename(data)
    @last_data = data if @last_data.empty?
    @last_filename = filename if @last_filename.empty?
    File.open(filename, 'wb') { |file| file.write(data)} if File.exist?(filename)
  end

  def save_assigned_routes_file(attachment)
    data = attachment.decoded
    fh = FilenameHandler.new
    filename = attachment.filename.sub(/ç/, '')
    filename = fh.to_attachments_dir(filename)
    # Always overwrite last file.
    File.open(filename, 'wb') { |file| file.write(data) }
  end

  def save_attachments(attachment)
    fh = FilenameHandler.new
    filename = fh.to_attachments_dir(attachment.filename)
    File.open(filename, 'wb') { |file| file.write(attachment.decoded)}
  end

  def run
    gmail = Gmail.new(@config[:username], @config[:password])

    berlys = gmail.in_label('Berlys')

    date = Date.today
    since = date - @days_ago
    puts "SINCE: #{since.strftime("%d-%b-%Y")} DATE: #{date.strftime("%d-%b-%Y")}"

    assigned_routes_filename = :unsaved
    in_berlys_label = berlys.emails(opts ={:after => since}).reverse!
    in_berlys_label.each do |mail|
      mail.message.attachments.each do |attachment|
        next unless @allowed_filenames.include? attachment.filename

        creation_date = get_creation_date(attachment)
        puts "MAIL DATE: #{creation_date} #{attachment.filename}"

        case attachment.filename
        when  @allowed_filenames[0]
          save_load_file(attachment)
        when @allowed_filenames[1]
          if assigned_routes_filename == :unsaved
            assigned_routes_filename = :saved
            save_assigned_routes_file(attachment)
          end
        else
          # This default condition is never reached because statement
          # "next unless @allowed_filenames.include? attachment.filename"
          # doesn't allow it, but IDE likes to get it.
          save_attachments(attachment)
        end
      end
    end

    gmail.logout
    gmail.disconnect
  end
end