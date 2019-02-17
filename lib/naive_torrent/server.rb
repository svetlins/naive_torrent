module NaiveTorrent
  class Server
    def initialize
      @listener = TCPServer.new('0.0.0.0', config.listen_port)
      @lock = Mutex.new
    end

    def accept
      @lock.synchronize do
        begin
          Connection.new @listener.accept_nonblock
        rescue IO::EAGAINWaitReadable
        end
      end
    end
  end
end
