Peer = Struct.new(:ip, :port)

module NaiveTorrent
  class Swarm
    def initialize(torrent_file_path)
      @torrent = Torrent.new torrent_file_path

      @pieces_to_download = Concurrent::Set.new (0...@torrent.piece_count)
      @downloaded_pieces  = Concurrent::Array.new

      @torrent.each_downloaded_piece do |piece|
        @pieces_to_download.delete piece
        @downloaded_pieces.push piece
      end

      @torrent.assemble_files if @downloaded_pieces.size == @torrent.piece_count

      @peer_connections = []

      @peers_table = PeersTable.new

      @server = Server.new

      trap 'SIGINT' do
        trackers.each { |tracker| tracker.stop @torrent }
        exit(0)
      end
    end

    def start
      peers = Queue.new
      bad_peers = Queue.new

      fetch_peers.shuffle.map do |peer|
        peers.push peer
        @peers_table.add_outgoing peer.ip
      end

      worker_threads = 15.times.map do |i|
        Thread.new do
          loop do
            connection = @server.accept

            if connection
              c = PeerConnection.new(connection, @torrent, self)
              @peers_table.add_incoming c.peer_ip
              c.connection_loop
            else
              peer = peers.pop
              @peers_table.report_peer_status peer.ip, status: 'Connecting'
              connection = Connection.connect peer.ip, peer.port
              if connection
                c = PeerConnection.new(connection, @torrent, self)
                c.connection_loop
              else
                @peers_table.report_peer_status peer.ip, status: 'Refused/Timeout'
              end

              bad_peers.push peer
            end
          end
        end
      end

      start_status_thread

      loop do
        peers.push(bad_peers.pop) if bad_peers.size > 0 && rand(3) == 0
        sleep 1
      end

      sleep
    end

    def start_status_thread
      Thread.new do
        loop do
          @peers_table.print

          screen_width = TermInfo.screen_size[1] / 2
          puts '#' * (screen_width * (@downloaded_pieces.size / @torrent.piece_count.to_f))

          sleep 1
        end
      end
    end

    def average_speed
      50 * 1024
    end

    def trackers
      @_trackers ||= @torrent.announce_uris.map { |uri| Tracker.new(uri) }
    end

    def fetch_peers
      trackers.flat_map do |tracker|
        tracker.announce(
          @torrent,
          downloaded: @downloaded_pieces.size * @torrent.piece_length,
          uploaded: 0,
          left: @torrent.length - @downloaded_pieces.size * @torrent.piece_length
        )
      end.uniq
    end

    # PeerConnection Delegate
    def checkout_piece(piece_index)
      @pieces_to_download.delete?(piece_index)
    end

    def checkin_piece(piece_index)
      return unless piece_index

      @pieces_to_download.add(piece_index)
    end

    def report_peer_status(peer_ip, report)
      @peers_table.report_peer_status peer_ip, report
    end

    def downloaded_piece(piece_index)
      @downloaded_pieces.push(piece_index)

      @torrent.assemble_files if @downloaded_pieces.size == @torrent.piece_count
    end

    def available_pieces
      @downloaded_pieces.to_a
    end

    def seeding?
      @downloaded_pieces.size == @torrent.piece_count
    end

    def downloading?
      @downloaded_pieces.size < @torrent.piece_count
    end
  end
end
