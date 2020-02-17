# frozen_string_literal: false

require 'date'
require 'optparse'

require './config'
require './getmail'

# Llegim de la carpeta de descàrregues
# Si no hi ha el fitxer "Volumen Rutas.txt" aleshores el llegim dels fitxers
# a la carpeta de recursos ../../data/berlys/<ANY ACTUAL>/<MES ACTUAL> i triem el més recent.
# si passem l'opció de descarregar el fitxer (-g), llavors obrim el correu i el descarreguem
# a la carpeta de recursos ../../data/berlys/attachments, ens quedem amb el contingut
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
end

class FileSource
  attr_accessor :new_filename
  attr_writer :show_counter, :assigned_routes

  def initialize
    # local
    sep = File::ALT_SEPARATOR
    now = Time.now
    day = Date.today

    # Attributes
    @config = Config.new.config
    @show_counter = true
    @assigned_routes = %w[680]
    @rootpath = %w[.. .. data berlys].join sep
    @sourcepath = %w[.. .. .. Downloads].join sep
    @old_filename = @config[:default_filenames][0]
    @allowed_routes = %w[678 679 680 681 682 686 688 696]
    abssourcefilename = [@sourcepath, @old_filename].join sep

    day += 1 if now.hour >= 19 || now.hour < 3

    destfilename = [
      now.strftime('%Y'),
      now.strftime('%m'),
      day.strftime('%Y-%m-%d.txt')
    ].join sep
    @new_filename = [@rootpath, destfilename].join sep
    if File.exist?(abssourcefilename)
      @file = File.open(abssourcefilename, 'r')
    elsif File.exist?(@new_filename)
      @file = File.open(@new_filename, 'r')
    else
      files = Dir.entries([@rootpath, now.strftime('%Y'), now.strftime('%m')].join(sep))
      @file = File.open(
        [
          @rootpath, now.strftime('%Y'), now.strftime('%m'), files[-1]
        ].join(sep),
        'r'
      )
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
    route_list = Array.new
    route_pattern = /25\s+BERLYS ALIMENTACION S\.A\.U\s+[\d:]+\s+[\d.]+\s+\
Volumen de pedidos de la ruta :\s+(?<routeID>\d+)\s+25 (?<routeName>[^\n]+)\s+\
Día de entrega :\s+(?<unloadDate>[^ ]{10})(?<customers>.+?)\
NUMERO DE CLIENTES\s+:\s+(?<costNum>\d+).+?\
SUMA VOLUMEN POR RUTA\s+:\s+(?<volAmt>[\d,.]+) (?<um1>(?:PVL|KG)).+?\
SUMA KG POR RUTA\s+:\s+(?<weightAmt>[\d,.]+) (?<um2>(?:PVL|KG)).+?\
(?:CAPACIDAD TOTAL CAMIÓN\s+:\s+(?<truckCap>[\d,.]+) (?<um3>(?:PVL|KG)))?
/m

    content = @file.read
    matches = content.scan route_pattern
    matches.each do |match|
      next unless @allowed_routes.include? match[0]

      route = Route.new
      route.id = match[0].to_i
      route.name = match[1]
      route.date = match[2]
      route.volume = match[5]
      route.weight = match[7]
      route.customers = fetch_customers(match[3])
      route_list.append(route)
    end
    puts @file.path
    route_list
  end

  def read
    @file.readlines.each do |line|
      puts line
    end
  end

  def main
    line_number = 0
    f = FileSource.new
    route_list = f.fetch_routes
    wd = Date.today.strftime("%a")
    route_list.each do |route|
      if $options[:routes] && $options[:routes].is_a?(Array) then next unless $options[:routes].include? route.id.to_s end
      if $options[:dayly] then next unless @config[:week_days][wd].include? route.id end
      route_load = 0.0
      puts "#{route.date}\t#{route.id}\t#{route.name}"
      route.customers.keys.collect!.with_index do |key, idx|
        customer = route.customers[key]
        line_number += 1
        puts "#{@show_counter ? line_number : idx + 1}\t#{customer.name}\t#{customer.address}\t#{customer.load}"
        route_load += customer.load
      end
      puts "\t\t\t#{route.volume}"
    end
  end
end

$options = {}
OptionParser.new do |opt|
  opt.on('-a', '--all') { |o| $options[:all] = o }
  opt.on('-d', '--dayly') { |o| $options[:dayly] = o }
  opt.on('-g', '--getmail') { |o| $options[:getmail] = o }
  opt.on('-r', '--routes', Array, 'string of ints') do |o|
    $options[:routes] ||= [*o]
    end
end.parse!
$options[:routes] |= ARGV

if $options[:getmail] then
  get_mail = GetMail.new
  get_mail.days_ago = 1
  get_mail.save_downloads = true
  get_mail.run
end

if $options[:all] then
  source = FileSource.new
  source.show_counter = false
  source.main
elsif $options[:dayly] then
  source = FileSource.new
  source.show_counter = true
  source.main
elsif $options[:routes] then
  puts options[:routes]
end