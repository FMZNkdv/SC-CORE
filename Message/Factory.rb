class MessageFactory
  @@packets = {}
  
  def self.register(id, klass)
    @@packets[id] = klass
  end

  def self.handle(id)
    @@packets[id]
  end
end