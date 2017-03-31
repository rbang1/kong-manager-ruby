require 'net/http'
require 'json'
require 'yaml'
require 'optparse'

def create_plugin(api, plugin_name, plugin_config)
  Net::HTTP.start(ADMIN_URI.host, ADMIN_URI.port) do |http|
    #fetch list of all plugins
    request = Net::HTTP::Get.new("/apis/#{api}/plugins/")

    response = http.request request
    if response.code != '200'
      puts "Error fetching plugins for api #{api}"
      return
    end
    plugins = JSON.parse(response.body)["data"]
    plugin = plugins.find {|plugin| plugin['name'] == plugin_name}

    config = {}
    plugin_config.each do |key, value|
      config["config.#{key}"] = value
    end

    if plugin
      request = Net::HTTP::Patch.new("/apis/#{api}/plugins/#{plugin['id']}")      
    else
      request = Net::HTTP::Post.new("/apis/#{api}/plugins/")
      config["name"] = plugin_name
    end

    request.set_form_data(config)
    response = http.request request
    if response.code == '200' || response.code == '201'
      puts "#{response.code == '201' ? 'Created' : 'Updated'} plugin #{plugin_name} on API #{api}"
    else
      puts "Error creating/updating plugin #{plugin_name} on API #{api}"
      puts response.body
    end
  end
end

def remove_plugins(api, retain_plugins)
  Net::HTTP.start(ADMIN_URI.host, ADMIN_URI.port) do |http|
    #fetch list of all plugins
    request = Net::HTTP::Get.new("/apis/#{api}/plugins/")

    response = http.request request
    if response.code != '200'
      puts "Error fetching plugins for api #{api}"
      return
    end

    to_remove = {}
    JSON.parse(response.body)["data"].each do |plugin|
      to_remove[plugin['name']] = plugin['id'] unless retain_plugins.include?(plugin['name'])
    end

    to_remove.each do |name, id|
      request = Net::HTTP::Delete.new("/apis/#{api}/plugins/#{id}")
      response = http.request request
      if response.code != '204'
        puts "Error removing plugin #{name} from api #{api}"
        return
      else
        puts "Removed plugin #{name} from api #{api}"
      end
    end
  end
end

def create_api(name, config, plugins)
  Net::HTTP.start(ADMIN_URI.host, ADMIN_URI.port) do |http|
    request = Net::HTTP::Get.new("/apis/#{name}/")

    response = http.request request
    if response.code == '404'
      request = Net::HTTP::Post.new("/apis/")
      config.merge!("name" => name)
    elsif response.code == '200'
      request = Net::HTTP::Patch.new("/apis/#{name}/")
    end

    request.set_form_data(config)
    response = http.request request
    if response.code == '200' || response.code == '201'
      puts "#{response.code == '201' ? 'Created' : 'Updated'} API #{name}"
      retain_plugins = []
      plugins.each do |plugin_name, plugin_config|
        create_plugin(name, plugin_name, plugin_config || {})
        retain_plugins << plugin_name
      end

      remove_plugins(name, retain_plugins)
    else
      puts "Error creating/updating api #{name}"
    end
  end
end

#load options
options = {adminuri: 'http://localhost:8001', config: 'kong.yml'}
optparser = OptionParser.new do |opts|
  opts.banner = "Usage: ruby apimanager.rb [options]"

  opts.on("-a", "--adminuri [URI]", String, "Kong Admin Uri Base, default #{options[:adminuri]}") do |opt|
    options[:adminuri] = opt
  end
  opts.on("-c", "--config [CONFIG]", String, "Config YAML/JSON file with api definitions, default #{options[:config]}") do |opt|
    options[:config] = opt
  end
  opts.on_tail("-h", "--help", "Show this message") do
    puts opts
    exit
  end
end
optparser.parse!

ADMIN_URI = URI(options[:adminuri])
if options[:config].end_with?('.json')
  apis = JSON.parse(File.read(options[:config]))
elsif options[:config].end_with?('.yml') || options[:config].end_with?('.yaml')
  apis = YAML.load(File.read(options[:config]))
else
  abort("Config file #{options[:config]} is not a JSON or YAML file")
end
apis.each do |name, api|
  create_api(name, api['config'], api['plugins'])
end
