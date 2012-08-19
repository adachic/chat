require 'eventmachine'
require 'msgpack'

class Chat < EM::Connection

  @@chat_channel = EM::Channel.new
  @@rooms = {}

  def post_init
  end 

  def receive_data(msg)
    data = MessagePack.unpack(msg)
    puts "receive: #{data.inspect}"

    case data[0]

    # list
    when "list"
      send_data({:cmd => :list, :rooms => @@rooms.keys}.to_msgpack)

    # create <room_name>
    when "create"
      unless room_name = data[1]
        send_data({:cmd => :create, :success => false, :msg => "params error"}.to_msgpack)
        return
      end
      if @@rooms[room_name]
        send_data({:cmd => :create, :success => false, :msg => "#{room_name} already exist"}.to_msgpack)
        return
      end
      @@rooms[room_name] = {
        :channel => EM::Channel.new,
        :users => {} #key=name, value=sid
      } 
      send_data({:cmd => :create, :success => true}.to_msgpack)

    # join <user_name> <room_name>
    when "join"
      unless (user_name = data[1]) && (room_name = data[2])
        send_data({:cmd => :join, :success => false, :msg => "params error"}.to_msgpack)
        return
      end
      unless room = @@rooms[room_name]
        send_data({:cmd => :join, :success => false, :msg => "#{room_name} is not exist"}.to_msgpack)
        return
      end
      if room[:users][user_name]
        send_data({:cmd => :join, :success => false, :msg => "#{user_name} is already exist in #{room_name}"}.to_msgpack)
        return
      end
      sid = room[:channel].subscribe do |m|
        send_data m
      end
      room[:users][user_name] = sid
      send_data({:cmd => :join, :success => true, :msg => "#{user_name} join to #{room_name}"}.to_msgpack)
    
    # talk <user_name> <room_name> <msg>
    when "talk"
      unless (user_name = data[1]) && (room_name = data[2])
        send_data({:cmd => :talk, :success => false, :msg => "params error"}.to_msgpack)
        return
      end
      msg = data[3]
      if @@rooms[room_name] && @@rooms[room_name][:users][user_name]
        @@rooms[room_name][:channel] << {:cmd => :talk, :room_name => room_name, :user_name => user_name, :msg => msg}.to_msgpack
      else
        send_data({:cmd => :talk, :success => false, :msg => "Invalid params: #{user_name}@#{room_name}"}.to_msgpack)
      end

    # users <room_name>
    when "users"
      unless room_name = data[1]
        send_data({:cmd => :users, :success => false, :msg => "params error"}.to_msgpack)
        return
      end
      unless room = @@rooms[room_name]
        send_data({:cmd => :users, :success => false, :msg => "room #{room_name} is not exit"}.to_msgpack)
        return
      end
      send_data({:cmd => :users, :success => true, :room_name => room_name, :user_names => room[:users].keys}.to_msgpack)

    # other
    else
      puts "else cmd #{data[0]}"
    end
  end 

  def unbind
    @@chat_channel.unsubscribe @sid
    puts "leave: #{@sid}"
  end

end

EM.run do
  EM.start_server("0.0.0.0", 10000, Chat)
end
