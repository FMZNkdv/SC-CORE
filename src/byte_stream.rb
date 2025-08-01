class ByteStream
  attr_accessor :buffer, :offset, :bit_offset, :client, :id, :version
  
  def initialize(data = nil)
    @buffer = data || []
    @offset = 0
    @bit_offset = 0
  end

  def read_int
    @bit_offset = 0
    value = (@buffer[@offset].ord << 24) |
            (@buffer[@offset + 1].ord << 16) |
            (@buffer[@offset + 2].ord << 8) |
            @buffer[@offset + 3].ord
    @offset += 4
    value
  end

  def skip(len)
    @bit_offset += len
  end

  def read_short
    @bit_offset = 0
    value = (@buffer[@offset].ord << 8) | @buffer[@offset + 1].ord
    @offset += 2
    value
  end

  def write_short(value)
    @bit_offset = 0
    @buffer << (value >> 8).chr
    @buffer << (value & 0xFF).chr
    @offset += 2
  end

  def write_int(value)
    @bit_offset = 0
    @buffer << (value >> 24).chr
    @buffer << (value >> 16).chr
    @buffer << (value >> 8).chr
    @buffer << (value & 0xFF).chr
    @offset += 4
  end

  def read_string
    length = read_int
    return '' if length <= 0 || length >= 90000
    
    str = @buffer[@offset, length].pack('C*').force_encoding('UTF-8')
    @offset += length
    str
  end

  def read_vint
    result = 0
    shift = 0
    s = 0
    a1 = 0
    a2 = 0
    
    loop do
      byte = @buffer[@offset].ord
      @offset += 1
      
      if shift == 0
        a1 = (byte & 0x40) >> 6
        a2 = (byte & 0x80) >> 7
        s = (byte << 1) & ~0x181
        byte = s | (a2 << 7) | a1
      end
      
      result |= (byte & 0x7F) << shift
      shift += 7
      break unless (byte & 0x80) != 0
    end
    
    (result >> 1) ^ (-(result & 1))
  end

  def read_data_reference
    a1 = read_vint
    [a1, a1 == 0 ? 0 : read_vint]
  end

  def write_data_reference(value1, value2)
    if value1 < 1
      write_vint(0)
    else
      write_vint(value1)
      write_vint(value2)
    end
  end

  def write_vint(value)
    @bit_offset = 0
    temp = (value >> 25) & 0x40
    flipped = value ^ (value >> 31)
    temp |= value & 0x3F
    value >>= 6
    flipped >>= 6
    
    if flipped == 0
      write_byte(temp)
      return
    end
    
    write_byte(temp | 0x80)
    flipped >>= 7
    r = flipped != 0 ? 0x80 : 0
    write_byte(((value & 0x7F) | r))
    value >>= 7
    
    while flipped != 0
      flipped >>= 7
      r = flipped != 0 ? 0x80 : 0
      write_byte(((value & 0x7F) | r))
      value >>= 7
    end
  end

  def write_boolean(value)
    if @bit_offset == 0
      @buffer << 0.chr
      @offset += 1
    end
    
    if value
      last_byte = @buffer[-1].ord
      @buffer[-1] = (last_byte | (1 << @bit_offset)).chr
    end
    
    @bit_offset = (@bit_offset + 1) & 7
  end

  def write_string(value)
    return write_int(-1) if value.nil? || value.bytesize > 90000
    
    data = value.bytes
    write_int(data.size)
    @buffer += data
    @offset += data.size
  end

  def write_long_long(value)
    write_int(value >> 32)
    write_int(value & 0xFFFFFFFF)
  end

  def write_logic_long(value1, value2)
    write_vint(value1)
    write_vint(value2)
  end

  def read_logic_long
    [read_vint, read_vint]
  end

  def write_long(value1, value2)
    write_int(value1)
    write_int(value2)
  end

  def read_long
    [read_int, read_int]
  end

  def write_byte(value)
    @bit_offset = 0
    @buffer << value.chr
    @offset += 1
  end

  def write_bytes(data)
    if data.nil?
      write_int(-1)
    else
      write_int(data.bytesize)
      @buffer += data
      @offset += data.bytesize
    end
  end

  def ensure_capacity(capacity)
    # ebaldo vs pensia
  end

  def send
    return if @id < 20000
    
    encode if respond_to?(:encode)
    
    header = [
      @id >> 8, @id & 0xFF,
      @buffer.size >> 16,
      (@buffer.size >> 8) & 0xFF,
      @buffer.size & 0xFF,
      @version >> 8, @version & 0xFF
    ].pack('CCCCCnn')
    
    footer = [0xFF, 0xFF, 0x00, 0x00, 0x00, 0x00, 0x00].pack('C7')
    packet = header + @buffer.pack('C*') + footer
    
    @client.write(packet)
    puts "[#{@client.peeraddr[3]}] >> Packet #{@id} was sent"
  end
end