require 'ostruct'

class Person < OpenStruct
  def email
    "#{self.name} <#{super}>" if super
  end

  def self.get_all(what)
    vars = Array.new

    ObjectSpace.each_object(Person) { |o|
      vars.push o.send(what) if o.send(what)
    }
    vars
  end

  def self.get_if(what)
    vars = Array.new

    ObjectSpace.each_object(Person) { |o|
      vars.push o.send(what) if o.send(what) && yield(o)
    }
    vars
  end

  def self.inspect_all
    vars = Array.new

    ObjectSpace.each_object(Person) { |o|
      vars.push o.inspect
    }
    vars
  end
end
