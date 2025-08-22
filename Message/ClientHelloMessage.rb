require_relative 'PiranhaMessage'
require_relative 'ServerHelloMessage'

class ClientHelloMessage < PiranhaMessage
  ID = 10100
  
  def initialize(bytes, client)
    super(bytes, client)
    @id = ID
    @version = 0
  end

  def decode
    read_int
  end

  def process
    ServerHelloMessage.new(@client).send
  end
end

MessageFactory.register(ClientHelloMessage::ID, ClientHelloMessage)