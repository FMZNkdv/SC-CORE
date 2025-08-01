require_relative 'byte_stream'

class PiranhaMessage < ByteStream
  attr_accessor :id, :client, :version
  
  def initialize(bytes = nil, client = nil)
    super(bytes || [])
    @id = 0
    @client = client
    @version = 0
  end

  def encode; end
  def decode; end
  def process; end

  def send
    return if @id < 20000
    
    encode
    
    header = [
      @id >> 8, @id & 0xFF,
      @buffer.size >> 16,
      (@buffer.size >> 8) & 0xFF,
      @buffer.size & 0xFF,
      @version >> 8, @version & 0xFF
    ].pack('CCCCCnn')
    
    # Подготовка футера пакета
    footer = [0xFF, 0xFF, 0x00, 0x00, 0x00, 0x00, 0x00].pack('C7')
    
    # Сборка полного пакета
    packet = header + @buffer.pack('C*') + footer
    
    # Отправка пакета
    @client.write(packet)
    puts "[#{@client.peeraddr[3]}] >> Packet #{@id} was sent"
  end
end