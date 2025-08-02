class ByteArray
  def self.bytes_to_string(arr)
    arr.pack('C*').force_encoding('UTF-8')
  end

  def self.string_to_bytes(str)
    str.bytes
  end

  def self.bytes_to_hex(arr)
    arr.map { |b| b.to_s(16).rjust(2, '0') }.join
  end

  def self.hex_to_bytes(hex_str)
    hex_str.scan(/../).map(&:hex)
  end

  def self.array_to_bytes(arr)
    arr.pack('C*')
  end

  def self.int_to_bytes(x)
    [x].pack('N').bytes
  end

  def self.get_int(bytes)
    case bytes.size
    when 1 then bytes[0]
    when 2 then (bytes[0] << 8) | bytes[1]
    when 3 then (bytes[0] << 16) | (bytes[1] << 8) | bytes[2]
    when 4 then (bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3]
    else -1
    end
  end
end
