class Person
  attr_accessor :name, :phone, :email, :enable_email, :enable_sms

  def initialize(name, phone, email, enable_email, enable_sms)
    @name = name
    @phone = phone
    @email = email
    @enable_email = enable_email
    @enable_sms = enable_sms
  end

  def inspect
    "<name: #{self.name} phone: #{self.phone} email: #{self.email}
            #enable_email: #{self.enable_email}, enable_sms: #{self.enable_sms}>"
  end

  def self.get_all(what)
    vars = Array.new

    ObjectSpace.each_object(Person) { |o|
      m = o.method(what.to_sym)
      vars.push m.call if m.call
    }
    vars
  end

  def self.get_all_email
    vars = Array.new

    ObjectSpace.each_object(Person) { |o|
      vars.push "#{o.name} <#{o.email}>" if o.email
    }
    vars
  end

  def self.get_enabled(what)
    vars = Array.new

    ObjectSpace.each_object(Person) { |o|
      what_sym = o.method(what.to_sym)
      enable_what_sym = o.method("enable_#{what}".to_sym)
      vars.push what_sym.call if what_sym.call && enable_what_sym.call
    }
    vars
  end

  def self.get_enabled_sms
    vars = Array.new

    ObjectSpace.each_object(Person) { |o|
      vars.push o.phone if o.phone && o.enable_sms
    }
    vars
  end

  def self.get_enabled_email
    vars = Array.new

    ObjectSpace.each_object(Person) { |o|
      vars.push "#{o.name} <#{o.email}>" if o.email && o.enable_email
    }
    vars
  end
end
