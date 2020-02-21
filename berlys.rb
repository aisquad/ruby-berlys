# frozen_string_literal: false

require 'date'
require 'optparse'

require './config'
require './getmail'
require './utils'

# Llegim de la carpeta de descàrregues
# Si no hi ha el fitxer "Volumen Rutas.txt" aleshores el llegim dels fitxers
# a la carpeta de recursos ../../data/berlys/<ANY ACTUAL>/<MES ACTUAL> i triem el més recent.
# Si passem l'opció de descarregar el fitxer (-g), llavors obrim el correu i el descarreguem
# a la carpeta de recursos ../../data/berlys/attachments, ens quedem amb el contingut,
# n'agafem les dades i alcem còpia a l'altra carpeta de recursos ../data/berlys/<ANY ACTUAL>/<MES ACTUAL>


class Route
  attr_accessor :id, :customers, :date, :name, :weight, :volume, :customers
  def initialize
    @id = 0
    @name = ''
    @date = Time.new
    @weight = 0.0
    @volume = 0.0
    @customers = {}
  end

  def to_s
    "#<Route: id=#{@id} name='#{@name}' date='#{@date}' weight=#{@weight} volume=#{@volume} costumers=#{@customers.length}>"
  end
end

class Customer
  attr_accessor :id, :name, :load, :ord_num, :address
  def initialize
    @id = 0
    @name = ''
    @ord_num = 0
    @address = ''
    @load = 0.0
  end

  def to_s
    "#<Customer: id=#{@id} name='#{@name}', ordnum=#{@ord_num}, town='#{@address}' load=#{@load}>"
  end
end

class FileSource
  attr_writer :global_counter, :content

  def initialize
    @config = Config.new.config
    @global_counter = true
    @allowed_routes = [678, 679, 680, 681, 682, 686, 688, 696]
    @content = ''
  end

  def get_data_file_and_read
    filename = FilenameHandler.new
    old_filename = filename.from_download_dir
    last_dld_filename = filename.get_last_downloaded_file
    @file = File.open(File.exist?(old_filename) ? old_filename : last_dld_filename, 'r')
    @content = @file.read
    if File.exist?(old_filename)
      new_filename = set_new_filename(@content)
      @file.close
      File.rename(old_filename, new_filename)
      @file = File.open(new_filename, 'r')
    end
  end

  def fetch_customers(customers)
    customer_hash = Hash.new
    customer_pattern = /(?<id>\d{10}) (?<name>.{35}) (?<town>.{20}) (?<ordNum>\d{10}) (?<vol>[\d,.\s]{11})(?<um> PVL)?/m
    customers.scan customer_pattern do |customer_array|
      match = customer_array.join(' ').match customer_pattern
      id = match[:id].to_i
      volume = match[:vol].sub(/\./, '').sub(/,/, '.').to_f
      if customer_hash.has_key? id
        customer_hash[id].load += volume
      else
        customer = Customer.new
        customer.id = id
        customer.name = match[:name].rstrip
        customer.address = match[:town].rstrip
        customer.ord_num = match[:ordNum].to_i
        customer.load = volume
        customer_hash[id] = customer
      end
    end
    customer_hash
  end

  def fetch_routes
    route_hash = Hash.new
    route_pattern = /25\s+BERLYS ALIMENTACION S\.A\.U\s+[\d:]+\s+[\d.]+\s+\
Volumen de pedidos de la ruta :\s+(?<routeID>\d+)\s+25 (?<routeName>[^\n]+)\s+\
Día de entrega :\s+(?<unloadDate>[^ ]{10})(?<customers>.+?)\
NUMERO DE CLIENTES\s+:\s+(?<costNum>\d+).+?\
SUMA VOLUMEN POR RUTA\s+:\s+(?<volAmt>[\d,.]+) (?<um1>(?:PVL|KG)).+?\
SUMA KG POR RUTA\s+:\s+(?<weightAmt>[\d,.]+) (?<um2>(?:PVL|KG)).+?\
(?:CAPACIDAD TOTAL CAMIÓN\s+:\s+(?<truckCap>[\d,.]+) (?<um3>(?:PVL|KG)))?\
/m

    if @content.empty? then get_data_file_and_read; end
    matches = @content.scan route_pattern
    matches.each do |match|
      next unless @allowed_routes.include? match[0].to_i

      route = Route.new
      route.id = match[0].to_i
      route.name = match[1]
      route.date = match[2]
      route.volume = match[5]
      route.weight = match[7]
      route.customers = fetch_customers(match[3])
      route_hash[route.id] = route
    end
    puts @file.path
    @file.close
    route_hash
  end

  def dispatch(set=@allowed_routes)
    line_number = 0
    f = FileSource.new
    route_hash = f.fetch_routes
    routes_volume = 0.0
    set.each do |routeid|
      next unless route_hash.has_key? routeid
      route = route_hash[routeid]
      route_load = 0.0
      puts "#{route.date}\t#{route.id}\t#{route.name}"
      route.customers.keys.collect!.with_index do |key, idx|
        customer = route.customers[key]
        line_number += 1
        puts "#{@global_counter ? line_number : idx + 1}\t#{customer.name}\t#{customer.address}\t#{format_number customer.load}"
        route_load += customer.load
        routes_volume += customer.load
      end
      puts "\t\troute volume:\t\t#{format_number route_load}"
    end
    puts "\t\tall routes total:\t#{format_number routes_volume}"
  end

  def daily
    weekday = Date.today.strftime("%a")
    if @config[:week_days].has_key?(weekday)
      dispatch(@config[:week_days][weekday])
    else
      raise KeyError("Today you must take a pause!")
    end
  end
end

options = {}
OptionParser.new do |opt|
  opt.on('-a', '--all') { |o| options[:all] = o }
  opt.on('-d', '--daily') { |o| options[:daily] = o }
  opt.on('-g', '--getmail') { |o| options[:getmail] = o }
  opt.on('-r', '--routes', Array, 'string of ints') do |o|
    options[:routes] ||= [*o]
  end
end.parse!
options[:routes] |= ARGV


source = FileSource.new
if options[:getmail]
  get_mail = GetMail.new
  get_mail.days_ago = 7
  get_mail.save_downloads = true
  get_mail.run
  source.content = get_mail.last_data
end

if options[:all]
  source.global_counter = false
  source.dispatch
elsif options[:daily] then
  source.global_counter = true
  source.daily
elsif options[:routes] then
  routes = []
  source.global_counter = true
  options[:routes].each { |r| routes.append(r.to_i) }
  source.dispatch(routes)
end
