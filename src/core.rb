require 'socket'
require_relative 'piranha_message'
require_relative 'message_factory'
require_relative 'client_hello_message'
require_relative 'server_hello_message'

puts "⠀⠀⣠⣾⣿⣿⣿⣿⣷⣤⣾⣿⣿⡇⠀⠀⠀⣀⣴⣿⣿⣿⣿⣷⣴⣿⣿⣿⡇⠀⠀⠀⠀⠀⢀⣴⣿⣿⣶⣿⡇⢀⣰⣾⣿⣿⣷⣄⠀"
puts "⠀⣴⣿⣿⣿⣿⣿⠛⠛⢻⣿⣿⣿⡇⠀⢀⣴⣿⣿⣿⣿⠿⠿⠿⣿⣿⣿⣿⡇⢰⣶⣶⣶⡆⢸⣿⣿⠀⠘⠛⠃⢸⣿⣿⡇⢸⣿⣿⡇"
puts "⠀⣿⣿⣿⣿⣿⣿⣤⣤⣤⣭⣍⠉⠁⠀⢸⣿⣿⣿⣿⣿⠀⠀⠀⠿⠿⠿⠿⠇⠸⠿⠿⠿⠇⢸⣿⣿⣀⣰⣶⡆⠸⣿⣿⣇⣸⣿⣿⠇"
puts "⠀⠻⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⣄⠀⢸⣿⣿⣿⣿⣿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠙⠛⠛⠛⠋⠀⠀⠈⠛⠛⠛⠛⠁⠀"
puts "⠀⠀⠈⠛⠛⠛⠛⠛⣿⣿⣿⣿⣿⣿⠀⢸⣿⣿⣿⣿⣿⠀⠀⠀⣾⣿⣿⣿⡇⢰⣶⣶⣶⡆⠸⣿⣿⡿⢿⣿⣦⠀⢿⣿⣿⠿⢿⣿⡆"
puts "⠀⣿⣿⣿⣿⣤⣤⣤⣿⣿⣿⣿⣿⡿⠀⠘⢿⣿⣿⣿⣿⣶⣶⣶⣿⣿⣿⣿⠇⢸⣿⣿⣿⡇⠀⣿⣿⡷⢾⣿⣍⠀⢸⣿⣿⠶⢸⣿⡁"
puts "⠀⣿⣿⣿⠟⢿⣿⣿⣿⣿⣿⣿⠟⠀⠀⠀⠀⠙⢿⣿⣿⣿⣿⣿⣿⡿⠏⠁⠀⠀⠀⠀⠀⠀⢰⣿⣿⣷⢸⣿⣿⡄⣾⣿⣿⣶⣾⣿⠇"
PORT = 9339

server = TCPServer.new(PORT)
puts "[github.com/FMZNkdv/SC-CORE] Running on port: #{PORT}"

loop do
  client = server.accept
  addr = client.peeraddr[3]
  puts "[#{addr}] >> A wild connection appeared!"
  
  Thread.new(client) do |connection|
    begin
      while data = connection.readpartial(4096)
        id = data.unpack('n')[0]
        
        handler_class = MessageFactory.handle(id)
        if handler_class
          puts "[#{addr}] >> Gotcha #{id} packet!"
          packet = handler_class.new(data, connection)
          packet.decode
          packet.process
        else
          puts "[#{addr}] >> Gotcha undefined #{id} packet!"
        end
      end
    rescue EOFError, Errno::ECONNRESET
      puts "[#{addr}] >> Client disconnected."
      connection.close
    end
  end

end



