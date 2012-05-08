#!/usr/bin/ruby

require 'logger'
require 'yaml'

# Config
TRIGGER="+491751830425"
LOGFILE="/tmp/#{File.basename($0, '.rb')}.log"
CONFFILE="#{File.basename($0, '.rb')}.yml"

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

conf = YAML.load_file( CONFFILE ) if File::exist?( CONFFILE )
p conf

# Do what has to be done

ENV['SMS_MESSAGES'].to_i.times { |msg_count|

  msg_sender = ENV["SMS_#{msg_count+1}_NUMBER"]
  msg_text = ENV["SMS_#{msg_count+1}_TEXT"]

  if msg_sender == TRIGGER
    print msg_sender, ': ', msg_text, "\n"
  else
    puts 'bulk message'
  end
}

logger.close
