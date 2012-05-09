class Person
  def initialize(name, phone, email)
    @name = name
    @phone = phone
    @email = email
  end

  def name=(name)
    @name = name
  end

  def name
    @name ? @name : "nobody"
  end

  def phone=(phone)
    @phone = phone
  end
  
  def phone
    @phone ? @phone : "none"
  end

  def email=(email)
    @email = email
  end
  
  def email
    @email ? @email : "none"
  end

  def inspect
    "<name: #{self.name} phone: #{self.phone} email: #{self.email}>"
  end
end
