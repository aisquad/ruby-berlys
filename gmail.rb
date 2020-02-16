require 'gmail'
require 'json'

class GetMail
  attr_reader :attachments
  def initialize
    json = JSON.load File.open "./resources/config.json"
    @config = {:username => json["username"], :password => json["password"]}
    @attachments = {}
  end

  def get_creation_date(string)
    string = string.gsub('"', '')
    string.split("; ").each do |item|
      key, val =  item.split("=") if item.include?('=')
      next unless key == 'creation-date'
      return Date.strptime(val, "%a, %d %b %Y %H:%M:%S %Z").strftime("%Y-%m-%d")
    end
  end

  def run
    gmail = Gmail.new(@config[:username], @config[:password])
    gmail.login

    berlys = gmail.in_label('Berly\'s')

    date = Date.today
    since = date -20
    puts date.strftime("%d-%b-%Y"), since.strftime("%d-%b-%Y")

    in_berlys_label = berlys.emails(opts ={:after => since})
    in_berlys_label.each do |mail|
      puts "MSG INSPECT:\n\t#{mail.inspect}"

      mail.message.attachments.each do |attachment|
        # attachment.decoded === mail.message.attachments[index].decoded
        ext = File.extname(attachment.filename)
        basename = File.basename(attachment.filename, ext)
        fields = attachment.header["Content-Disposition"].field
        cdate = get_creation_date fields.to_s
        filename = "#{basename} #{cdate}#{ext}"
        @attachments[filename] = attachment.decoded
      end
    end
    gmail.logout
    gmail.disconnect
  end
end

def main
  mail_reader = GetMail.new
  mail_reader.run
  mail_reader.attachments.each_pair do |filename, content|
    File.open([".", "data", filename].join(File::ALT_SEPARATOR), 'wb') do |file|
      file.write(content)
    end
  end
end

main