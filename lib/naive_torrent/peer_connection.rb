module NaiveTorrent
  class PeerConnection
    include PeerMessages

    def initialize(connection, torrent, delegate)
      @connection = connection
      @torrent = torrent
      @delegate = delegate

      @am_choking, @am_interested, @peer_choking, @peer_interested = true, false, true, false
      @send_buffer = [].pack("C*")
      @bitfield = [].pack("C*")

      @last_received_at = nil
      @current_speed = 0
    end

    def connection_loop
      catch(:quit) do
        begin
          buf = ""
          message_length = nil

          send handshake_message(@torrent.info_hash, @torrent.peer_id)

          loop do
            buf += @connection.read

            if handshaked? buf
              message_length = read_length(buf) if
                message_length.nil? && buf.size >= LENGTH_PREFIX

              if message_length && (buf.size >= message_length)
                dispatch_received_message read_message(buf, message_length)
                message_length = nil
              end

              update_interest

              request unless @requesting
            end

            write

            @connection.wait

            throw :quit unless @connection.healthy?
          end
        rescue *Connection.errors
        ensure
          @delegate.report_peer_status peer_ip, status: 'Disconnected'
          @delegate.checkin_piece @current_piece_index
          @connection&.close
        end
      end
    end

    def update_interest
      if @delegate.downloading?
        unless @am_interested
          send interested_message
          @am_interested = true
        end
      end

      if @am_choking
        send bitfield_message(@torrent.piece_count, @delegate.available_pieces)
        send unchoke_message

        @am_choking = false
      end
    end

    def handshaked?(buf)
      return true if @handshaked

      if buf.size >= 68 && buf.include?('BitTorrent protocol') && buf.include?(@torrent.info_hash)
        @delegate.report_peer_status peer_ip, status: 'Handshaked'
        @handshaked = true
        buf.slice!(0, 68)

        true
      end
    end

    def checkout_piece
      @delegate.checkin_piece(@current_piece_index) if @current_piece_index

      @torrent.piece_count.times do |i|
        piece_index = i

        if has?(piece_index)
          if @delegate.checkout_piece piece_index
            @current_piece_data  = ([]).pack("C*")
            @current_piece_index = piece_index

            return
          end
        end
      end
    end

    def request
      return if @peer_choking
      return unless @current_piece_index

      send request_message(
             @current_piece_index,
             @current_piece_data.size,
             @torrent.piece_length(@current_piece_index)
           )

      @requesting = true
    end

    def dispatch_received_message(message)
      message_type = read_byte(message)

      case message_type
      when CHOKE_MESSAGE_ID
        @peer_choking = true
      when UNCHOKE_MESSAGE_ID
        checkout_piece if @peer_choking

        @peer_choking = false
      when INTERESTED_MESSAGE_ID
        @peer_interested = true
        send bitfield_message(@torrent.piece_count, @delegate.available_pieces)
      when NOT_INTERESTED_MESSAGE_ID
        @peer_interested = false
      when HAVE_MESSAGE_ID
        have read_length(message)
      when BITFIELD_MESSAGE_ID
        @bitfield = message
      when REQUEST_MESSAGE_ID
        index  = read_length(message)
        begn   = read_length(message)
        length = read_length(message)

        throw :quit if length > config.block_size
        throw :quit unless @delegate.available_pieces.include? index

        send piece_message(index, begn, length)

        @delegate.report_peer_status peer_ip,
                                     status: "Sending #{index}, #{begn}, #{length}"

      when PIECE_MESSAGE_ID
        index = read_length(message)
        begn  = read_length(message)
        block = message

        @current_piece_data[begn..begn+block.size] = block
        @requesting = nil

        if @last_received_at
          @delegate.report_peer_status peer_ip,
                                       status: "Receiving \##{@current_piece_index}",
                                       download_speed: block.size / (Time.now - @last_received_at).to_f
        end

        @last_received_at = Time.now

        if [
          (@current_piece_data.size >= @torrent.piece_length(@current_piece_index)),
          (block.size < config.block_size)
        ].any?
          throw :quit unless @torrent.validate_piece(index, @current_piece_data)
          @torrent.store_piece index, @current_piece_data

          @delegate.downloaded_piece @current_piece_index
          @current_piece_index = nil

          checkout_piece
        end
      end
    end

    def write
      return if @send_buffer.empty?

      sent = @connection.write @send_buffer
      @send_buffer.slice!(0, sent)

      if @last_wrote_at
        @delegate.report_peer_status peer_ip,
                                     status: "Sending",
                                     upload_speed: sent / (Time.now - @last_wrote_at).to_f
      end

      @last_wrote_at = Time.now
    end

    def send(message)
      @send_buffer << message
    end

    def has?(piece_index)
      @bitfield[piece_index / 8].unpack('C').first &
        2**(7 - (piece_index % 8))
    end

    def have(piece_index)
      @bitfield[piece_index / 8] =
        [
          @bitfield[piece_index / 8].unpack('C').first |
          2**(7 - (piece_index % 8))
        ].pack('C')
    end

    def peer_ip
      @_peer_ip ||= @connection.remote_address
    end

    private

    def read_byte(buf)
      buf.slice!(0, 1)
    end

    def read_length(buf)
      length = buf[0 ... LENGTH_PREFIX].unpack('N').first
      buf.slice!(0, LENGTH_PREFIX)

      length
    end

    def read_message(buf, length)
      message = buf[0 ... length]
      buf.slice!(0, length)

      message
    end
  end
end
