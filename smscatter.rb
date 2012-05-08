#!/usr/bin/ruby

require 'logger'
require 'yaml'
require 'optparse'

# Helper to convert config keys to symbols
class Hash
  def symbolize_keys!
    t=self.dup
    self.clear
    t.each_pair do |k,v|
      if v.kind_of?(Hash)
        v.symbolize_keys!
      end
      self[k.to_sym] = v
      self
    end
    self
  end
end

# Command line options
options = {}

optparse = OptionParser.new do|opts|
  opts.banner = "Usage: #{File.basename $0} [options] messagefile"
  
  options[:configfile] = "/etc/#{File.basename $0, ".rb"}.conf"
  opts.on( '-c', '--configfile FILE', 'Read configuration from FILE' ) do|file|
    options[:configfile] = file
  end
  
  opts.on( '-h', '--help', 'Display this screen' ) do
    puts opts
    exit
  end
end
 
optparse.parse!
 
# Read config
begin
  conf = YAML.load_file( options[:configfile] )
rescue
  puts "Opening #{options[:configfile]} failed."
  exit 1
end

conf.symbolize_keys!

# Init

#logger = Logger.new(LOGFILE, 'monthly')
logger = Logger.new(STDOUT)
logger.datetime_format = "%Y-%m-%d %H:%M:%S"
#logger.level = Logger::WARN
#logger.progname  = File.basename($0)

#logger.debug("just a debug message") 
#logger.info("important information") 
#logger.warn("you better be prepared") 
#logger.error("now you are in trouble") 
#logger.fatal("this is the end...")

# Do what has to be done

ENV['SMS_MESSAGES'].to_i.times { |msg_count|

  msg_sender = ENV["SMS_#{msg_count+1}_NUMBER"]
  msg_text = ENV["SMS_#{msg_count+1}_TEXT"]

  logger.info 'Received from ' + msg_sender + ': ' + msg_text

  if msg_sender == conf[:global][:trigger]
    logger.info 'From trigger; forwarding'
  else
    logger.info 'Unknown sender; forwarding to admin'
    #conf['global']['admin']
  end
}

logger.close
