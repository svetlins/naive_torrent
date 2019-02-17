module NaiveTorrent
  class Connection

    class << self
      def connect(ip, port)
        socket = Socket.new(:INET, :STREAM)
        remote_addr = Socket.pack_sockaddr_in(port, ip)

        begin
          socket.connect_nonblock(remote_addr)
        rescue IO::EINPROGRESSWaitWritable
          IO.select(nil, [socket], nil, config.connect_timeout)

          begin
            socket.connect_nonblock(remote_addr)
          rescue Errno::EISCONN
            return new(socket)
          rescue Errno::ECONNREFUSED, Errno::EALREADY, Errno::EADDRNOTAVAIL
          end
        end

        nil
      end

      def errors
        [EOFError, Errno::ECONNRESET, Errno::EPIPE]
      end
    end

    def initialize(socket)
      @socket = socket
      @sickness_level = 0
    end

    def read
      begin
        @socket.read_nonblock(config.read_chunk_size)
      rescue IO::EAGAINWaitReadable
        '' # Did not receive anything
      end
    end

    def write(buffer)
      begin
        @socket.write_nonblock buffer
      rescue IO::EAGAINWaitWritable
        0 # Did not write anything
      end
    end

    def wait
      ready_socket = IO.select([@socket], [@socket], [], config.wait_timeout)

      if ready_socket
        @sickness_level -= 1
      else
        @sickness_level += 1
      end
    end

    def close
      @socket.close
    end

    def remote_address
      @socket.remote_address.ip_address
    rescue Errno::EINVAL
      'N/A'
    end

    def healthy?
      @sickness_level < 200
    end
  end
end
