global:
  logfile: /tmp/smshandler.log
  peoplefile: people-dist.yml
  trigger: ['+49171234567', '+491727654321']
  admin_email: cwh@webeve.de
  enable_email: yes
  enable_sms: no

sms:
  provider: clickatell
  from: '+491717654321'

email:
  host: mail.webeve.de
  port: 25
  user: cwh
  pass: fooblafoo
  domain: localhost
  from: ffw@goessenreuth.de
  subject: SMS received

clickatell:
  apiid: '9876543'
  user:  cwhofmann
  pass:  blafoobla
