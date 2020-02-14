# frozen_string_literal: false

require 'date'

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
  attr_accessor :id, :name, :load, :address
  def initialize
    @id = 0
    @name = ''
    @address = ''
    @load = 0.0
  end
end

class FileSource
  attr_accessor :newfilename

  def initialize
    # local
    sep = File::ALT_SEPARATOR
    now = Time.now
    day = Date.today

    # Attributes
    @rootpath = %w[C: Users igorr OneDrive Eclipse Python Berlys data].join sep
    @sourcepath = %w[C: Users igorr Downloads].join sep
    @basename = 'Volumen Rutas.txt'
    @routes = %w[678 679 680 681 682 686 688 696]
    abssourcefilename = [@sourcepath, @basename].join sep

    day += 1 if now.hour >= 19 || now.hour < 3

    destfilename = [
      now.strftime('%Y'),
      now.strftime('%m'),
      day.strftime('%Y-%m-%d.txt')
    ].join sep
    @newfilename = [@rootpath, destfilename].join sep

    if File.exist?(abssourcefilename)
      @file = File.open(abssourcefilename, 'r')
    elsif File.exist?(@newfilename)
      @file = File.open(@newfilename, 'r')
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
    customer_pattern = /(?<id>\d{10}) (?<name>.{35}) (?<town>.{20}) (?<ordnum>\d{10}) (?<vol>[\d,.\s]{11})(?<um> PVL)?/m
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
        customer.load = volume
        customer_hash[id] = customer
      end
    end
    customer_hash
  end

  def fetch_routes
    route_list = Array.new
    route_pattern = /25\s+BERLYS ALIMENTACION S\.A\.U\s+[\d:]+\s+[\d.]+\s+
Volumen de pedidos de la ruta :\s+(?<routeid>\d+)\s+25 (?<routedesc>[^\n]+)\s+Día de entrega :\s+(?<date>[^ ]{10})(?<customers>.+?)NUMERO DE CLIENTES\s+:\s+(?<costnum>\d+).+?SUMA VOLUMEN POR RUTA\s+:\s+(?<volamt>[\d,.]+) (?<um1>(?:PVL|KG)).+?SUMA KG POR RUTA\s+:\s+(?<weightamt>[\d,.]+) (?<um2>(?:PVL|KG)).+?(?:CAPACIDAD TOTAL CAMIÓN\s+:\s+(?<truckcap>[\d,.]+) (?<um3>(?:PVL|KG)))?
/m

    content = @file.read
    matches = content.scan route_pattern
    matches.each do |match|
      next unless @routes.include? match[0]

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
end

f = FileSource.new
route_list = f.fetch_routes
route_list.each do |route|
  route_load = 0.0
  puts "#{route.date}\t#{route.id}\t#{route.name}"
  route.customers.keys.collect!.with_index do |key, idx|
    customer = route.customers[key]
    puts "#{idx+1}\t#{customer.name}\t#{customer.address}\t#{customer.load}"
    route_load += customer.load
  end
  puts "\t\t\t#{route.volume}"
end
