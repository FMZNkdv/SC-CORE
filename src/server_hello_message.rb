require_relative 'piranha_message'

class ServerHelloMessage < PiranhaMessage
  ID = 20100
  
  def initialize(client)
    super(nil, client)
    @id = ID
    @version = 0
  end

  def encode
    write_int(24)
    24.times { write_byte(1) }
  end
end

MessageFactory.register(ServerHelloMessage::ID, ServerHelloMessage)