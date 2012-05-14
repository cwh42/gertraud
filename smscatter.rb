#!/usr/bin/ruby

##############################################################################
#
# smscatter - a RunOnReceive script being used with gammu-smsd for forwarding
#             SMS to SMS and/or email
# Version     0.99
#
# Copyright (C) 2012 Christopher Hofmann <cwh@webeve.de>
#
# ---------------------------------------------------------------------------
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the Free
# Software Foundation; either version 2 of the License, or (at your option)
# any later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, write to the Free Software Foundation, Inc., 51
# Franklin St, Fifth Floor, Boston, MA 02110, USA
#
###############################################################################

$LOAD_PATH << File.join(File.dirname(__FILE__))
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
#logger = Logger.new(STDOUT)
logger = Logger.new(conf[:global][:logfile], 'monthly')
logger.datetime_format = "%Y-%m-%d %H:%M:%S"
logger.level = Logger::INFO

if options[:debug]
  logger.level = Logger::DEBUG
end

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
people = Array.new

begin
  YAML.load_file( conf[:global][:peoplefile] ).each{ |data|
    people.push Person.new(data)
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
#p Person.inspect_all    
    if conf[:global][:enable_email]
      logger.debug 'Email sending globally enabled'
      # get all email addresses except of those who have an explicit "enable_email: no"
      email_recipients = Person.get_if('email') { |x| x.enable_email != false }
    else
      logger.debug 'Email sending globally disabled'
      # get only email addresses who have an explicit "enable_email: yes"
      email_recipients = Person.get_if('email') { |x| x.enable_email }
    end
    
    if !email_recipients.empty?
      logger.info "Sending email to #{email_recipients.size} recipients"
      begin
        Pony.mail(:to => email_recipients,
                  :subject => conf[:email][:subject],
                  :body => msg_text)
      rescue
        logger.fatal "Sending email failed: #{$!}"
        exit 1
      end
    end
    
    # send SMS (if any recipients)
    sms_recipients = Array.new
#p Person.inspect_all
    if conf[:global][:enable_sms]
      logger.debug 'Sms sending globally enabled'
      # get all phone numbers except of those who have an explicit "enable_sms: no"
      sms_recipients = Person.get_if('phone') { |x| x.enable_sms != false }
    else
      logger.debug 'Sms sending globally disabled'
      # get only phone numbers who have an explicit "enable_sms: yes"
      sms_recipients = Person.get_if('phone') { |x| x.enable_sms }
    end

    if !sms_recipients.empty?
      logger.info "Sending sms to #{sms_recipients.size} recipients"
      logger.debug "Message length: #{msg_text.length} characters"
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
                :subject => conf[:email][:subject],
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
