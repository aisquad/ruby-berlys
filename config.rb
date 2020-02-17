require 'json'

class Config
  attr_reader :config
  def initialize
    json = JSON.load File.open "../../resources/ruby-berlys-config.json"
    @config = {
        :username => json["username"],
        :password => json["password"],
        :default_filenames => json["default_filenames"],
        :week_days => json["week_days"]
    }
  end
end
