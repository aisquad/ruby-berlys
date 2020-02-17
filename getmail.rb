require 'gmail'

class GetMail
  attr_reader :attachments
  attr_writer :days_ago, :save_downloads
  attr_reader :allowed_filenames

  def initialize
    @days_ago = 1
    @config = Config.new.config
    @attachments = {}
    @allowed_filenames = @config[:default_filenames]
    @save_downloads = false
  end

  def get_creation_date(attachment, for_save=false)
    fields = attachment.header["Content-Disposition"].field.to_s
    fields = fields.gsub('"', '')
    fields.split("; ").each do |item|
      key, val =  item.split("=") if item.include?('=')
      next unless key == 'creation-date'
      date = Date.strptime(val, "%a, %d %b %Y %H:%M:%S %Z")
      date += 1 if for_save
      return date.strftime("%Y-%m-%d")
    end
  end

  def save
    unless @attachments.empty?
      attachments.each_pair do |filename, content|
        File.open(['..', '..', 'data', 'berlys', 'attachments', filename].join(File::ALT_SEPARATOR), 'wb') do |file|
          file.write(content)
        end
      end
    end
  end

  def run
    gmail = Gmail.new(@config[:username], @config[:password])
    gmail.login

    berlys = gmail.in_label('Berly\'s')

    date = Date.today
    since = date - @days_ago
    puts "SINCE: #{since.strftime("%d-%b-%Y")} DATE: #{date.strftime("%d-%b-%Y")}"

    in_berlys_label = berlys.emails(opts ={:after => since})
    in_berlys_label.each do |mail|
      mail.message.attachments.each do |attachment|
        puts "MAIL DATE: #{get_creation_date(attachment)}"
        next unless @allowed_filenames.include?(attachment.filename)

        ext = File.extname(attachment.filename)
        basename = File.basename(attachment.filename, ext)
        date = get_creation_date(attachment, true)
        filename = basename.start_with?("Volumen") ? \
          "#{basename} #{date}#{ext}" : \
          "#{basename.sub(/ç/, '')}#{ext}"
        @attachments[filename] = attachment.decoded
      end
    end

    if @save_downloads; save; end
    gmail.logout
    gmail.disconnect
  end
end