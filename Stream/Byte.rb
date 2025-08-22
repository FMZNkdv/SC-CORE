class ByteStream
  attr_accessor :buffer, :offset, :bit_offset, :client, :id, :version

  def initialize(data = nil)
    @buffer = data || ""
    @offset = 0
    @bit_offset = 0
    @id = 0
    @version = 0
  end

  def read_int
    @bit_offset = 0
    value = (@buffer.getbyte(@offset) << 24) |
            (@buffer.getbyte(@offset + 1) << 16) |
            (@buffer.getbyte(@offset + 2) << 8) |
            @buffer.getbyte(@offset + 3)
    @offset += 4
    value
  end

  def skip(len)
    @bit_offset += len
  end

  def read_short
    @bit_offset = 0
    value = (@buffer.getbyte(@offset) << 8) | @buffer.getbyte(@offset + 1)
    @offset += 2
    value
  end

  def write_short(value)
    @bit_offset = 0
    ensure_capacity(2)
    @buffer.setbyte(@offset, value >> 8)
    @buffer.setbyte(@offset + 1, value & 0xFF)
    @offset += 2
  end

  def write_int(value)
    @bit_offset = 0
    ensure_capacity(4)
    @buffer.setbyte(@offset, value >> 24)
    @buffer.setbyte(@offset + 1, (value >> 16) & 0xFF)
    @buffer.setbyte(@offset + 2, (value >> 8) & 0xFF)
    @buffer.setbyte(@offset + 3, value & 0xFF)
    @offset += 4
  end

  def get_hex
    @buffer.unpack('H*').first
  end

  def read_string
    length = read_int
    return '' if length <= 0 || length >= 90000
    str = @buffer[@offset, length]
    @offset += length
    str.force_encoding('UTF-8')
  end

  def read_vint
    result = 0
    shift = 0
    loop do
      byte = @buffer.getbyte(@offset)
      @offset += 1
      if shift == 0
        a1 = (byte & 0x40) >> 6
        a2 = (byte & 0x80) >> 7
        s = (byte << 1) & ~0x181
        byte = s | (a2 << 7) | a1
      end
      result |= (byte & 0x7F) << shift
      shift += 7
      break if (byte & 0x80) == 0
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
      ensure_capacity(1)
      @buffer.setbyte(@offset, 0)
      @offset += 1
    end
    if value
      last_byte = @buffer.getbyte(@offset - 1)
      @buffer.setbyte(@offset - 1, last_byte | (1 << @bit_offset))
    end
    @bit_offset = (@bit_offset + 1) & 7
  end

  def read_boolean
    read_vint >= 1
  end

  def write_string(value)
    if value.nil? || value.length > 90000
      write_int(-1)
      return
    end
    encoded = value.encode('UTF-8')
    write_int(encoded.bytesize)
    ensure_capacity(encoded.bytesize)
    encoded.bytes.each_with_index do |byte, i|
      @buffer.setbyte(@offset + i, byte)
    end
    @offset += encoded.bytesize
  end

  alias write_string_reference write_string

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
    ensure_capacity(1)
    @buffer.setbyte(@offset, value)
    @offset += 1
  end

  def write_bytes(data)
    if data
      write_int(data.bytesize)
      ensure_capacity(data.bytesize)
      data.bytes.each_with_index do |byte, i|
        @buffer.setbyte(@offset + i, byte)
      end
      @offset += data.bytesize
    else
      write_int(-1)
    end
  end

  def ensure_capacity(capacity)
    needed = @offset + capacity - @buffer.bytesize
    if needed > 0
      @buffer << "\x00" * needed
    end
  end

  def send
    return if @id < 20000
    encode
    header = [
      @id >> 8, @id & 0xFF,
      @buffer.bytesize >> 16,
      (@buffer.bytesize >> 8) & 0xFF,
      @buffer.bytesize & 0xFF,
      @version >> 8, @version & 0xFF
    ].pack('C5n')
    footer = [0xFF, 0xFF, 0x00, 0x00, 0x00, 0x00, 0x00].pack('C7')
    @client.write(header + @buffer + footer)
    puts "Packet #{@id} was sent"
  end
end
