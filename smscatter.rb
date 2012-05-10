#!/usr/bin/ruby

require 'person'

require 'logger'
require 'yaml'
require 'optparse'

require 'rubygems' 
require 'pony'
require 'clickatell'

# try to check whether we are called by gammu-smsd
if ENV['SMS_MESSAGES'] == nil
  puts "Environment variable SMS_MESSAGES not set."
  puts "This script is only useful to be called by gammu-smsd."
  exit 1
end

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

  options[:debug] = false
  opts.on( '-d', '--debug', 'Be more verbose and log to STDOUT.' ) do
    options[:debug] = true
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
if options[:debug] 
  logger = Logger.new(STDOUT)
else
  logger = Logger.new(conf[:global][:logfile], 'monthly')
end

logger.datetime_format = "%Y-%m-%d %H:%M:%S"
#logger.level = Logger::WARN
#logger.progname  = File.basename($0)

Pony.options = {
  :from => conf[:email][:from],
  :via => :smtp,
  :via_options => {
    :address => conf[:email][:host],
    :port => conf[:email][:port],
    :user_name => conf[:email][:user],
    :password => conf[:email][:pass],
    :domain => conf[:email][:domain],
    :authentication => :plain,
    :enable_starttls_auto => true
  }
}

clickatell = Clickatell::API.authenticate( conf[:clickatell][:apiid],
                                           conf[:clickatell][:user],
                                           conf[:clickatell][:pass] )
#Clickatell::API.debug_mode = true if options[:debug]
#Clickatell::API.test_mode = true if options[:debug]

# read people
begin
  YAML.load_file( conf[:global][:peoplefile] ).each{|data|
    Person.new(data['name'],
               data['phone'],
               data['email'],
               data['enable_email'],
               data['enable_sms']);
  }
rescue
  puts "Opening #{conf[:global][:peoplefile]} failed: #{$!}"
  puts $@ if options[:debug]
  exit 1
end

# Do what has to be done
ENV['SMS_MESSAGES'].to_i.times { |msg_count|

  msg_sender = ENV["SMS_#{msg_count+1}_NUMBER"]
  msg_text = ENV["SMS_#{msg_count+1}_TEXT"]

  logger.info 'Received from ' + msg_sender + ': ' + msg_text

  if msg_sender == conf[:global][:trigger]
    logger.info 'From trigger'
    
    # send email (if any recipients)
    email_recipients = Array.new
    
    if conf[:global][:enable_email]
      logger.debug 'Email sending globally enabled'
      email_recipients = Person.get_all_email
    else
      logger.debug 'Email sending globally disabled'
      email_recipients = Person.get_enabled_email
    end
    
    if !email_recipients.empty?
      logger.info "Sending email to #{email_recipients.size} recipients"
      begin
        Pony.mail(:to => email_recipients,
                  :subject => 'SMS received',
                  :body => msg_sender + ': ' + msg_text)
      rescue
        logger.fatal "Sending email failed: #{$!}"
        exit 1
      end
    end
    
    # send SMS (if any recipients)
    sms_recipients = Array.new

    if conf[:global][:enable_sms]
      logger.debug 'Sms sending globally enabled'
      sms_recipients = Person.get_all('phone')
    else
      logger.debug 'Sms sending globally disabled'
      sms_recipients = Person.get_enabled_sms
    end

    if !sms_recipients.empty?
      logger.info "Sending sms to #{sms_recipients.size} recipients"
      begin
        result = clickatell.send_message( sms_recipients,
                                          msg_text,
                                          {:from => conf[:sms][:from]} )
        logger.debug( "Clickatell result: #{result}" )
        logger.info("Remaining Clickatell balance: #{clickatell.account_balance}") 
      rescue
        logger.fatal "Sending sms failed: #{$!}"
        exit 1
      end
    end
  else
    logger.info 'Unknown sender; forwarding to admin via email'
    begin
      Pony.mail(:to => conf[:global][:admin_email],
                :subject => 'SMS received',
                :body => msg_sender + ': ' + msg_text)
    rescue
      logger.fatal "Sending email to admin failed: #{$!}"
      exit 1
    end
  end
}

#logger.debug("just a debug message") 
#logger.info("important information") 
#logger.warn("you better be prepared") 
#logger.error("now you are in trouble") 
#logger.fatal("this is the end...")

logger.close
