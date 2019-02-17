module NaiveTorrent
  module PeerMessages
    CHOKE_MESSAGE_ID          = [0].pack('C')
    UNCHOKE_MESSAGE_ID        = [1].pack('C')
    INTERESTED_MESSAGE_ID     = [2].pack('C')
    NOT_INTERESTED_MESSAGE_ID = [3].pack('C')
    HAVE_MESSAGE_ID           = [4].pack('C')
    BITFIELD_MESSAGE_ID       = [5].pack('C')
    REQUEST_MESSAGE_ID        = [6].pack('C')
    PIECE_MESSAGE_ID          = [7].pack('C')

    LENGTH_PREFIX             = 4 # bytes

    def handshake_message(info_hash, peer_id)
      [
        "\x13",
        "BitTorrent protocol",
        "\x0" * 8,
        info_hash,
        peer_id
      ].join
    end

    def piece_message(index, begn, length)
      File.open("pieces/#{index}.piece") do |file|
        file.seek(begn)
        block = file.read(length)

        [
          [9 + length].pack('N'),
          PIECE_MESSAGE_ID,
          [index].pack('N'),
          [begn].pack('N'),
          block
        ].join
      end
    end

    def request_message(piece, block_start, piece_length)
      block_size =
        if block_start + config.block_size >= piece_length
          piece_length - block_start
        else
          config.block_size
        end

      [
        [13].pack('N'),
        REQUEST_MESSAGE_ID,
        [piece].pack('N'),
        [block_start].pack('N'),
        [block_size].pack('N'),
      ].join
    end

    def interested_message
      [
        [1].pack('N'),
        INTERESTED_MESSAGE_ID
      ].join
    end

    def unchoke_message
      [
        [1].pack('N'),
        UNCHOKE_MESSAGE_ID
      ].join
    end

    def bitfield_message(piece_count, available_pieces)
      bitfield = [0].pack('C') * (piece_count / 8.0).ceil

      available_pieces.each do |piece_index|
        bitfield[piece_index / 8] =
          [
            bitfield[piece_index / 8].unpack('C').first |
            2**(7 - (piece_index % 8))
          ].pack('C')
      end

      [
        [bitfield.size + 1].pack('N'),
        BITFIELD_MESSAGE_ID,
        bitfield
      ].join
    end

  end
end
