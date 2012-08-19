require "msgpack"
require "eventmachine"

class Client < EM::Connection
  attr_reader :queue

  def initialize(q)
    @queue = q
    cb = Proc.new do |msg|
      send_data(msg)
      q.pop &cb
    end
    q.pop &cb
  end

  def post_init
  end

  def receive_data(data)
    puts MessagePack.unpack(data)
  end

  def unbind
    puts "disconnect"
    exit
  end
end

class KeyHandler < EM::Connection
  include EM::Protocols::LineText2
  attr_reader :queue
  
  def initialize(q)
    @queue = q
  end

  def receive_line(data)
    if data == 'exit'
      exit
    end
    msg = data.split.to_msgpack
    @queue.push(msg)
  end
end

EM.run do
  q = EM::Queue.new
  EM.connect("localhost", 10000, Client, q)
  EM.open_keyboard(KeyHandler, q)
end


