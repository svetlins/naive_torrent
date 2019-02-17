module NaiveTorrent
  class Tracker
    def initialize(tracker_uri)
      @tracker_uri = tracker_uri
    end

    def announce(torrent, downloaded:, uploaded:, left:)
      return [] unless @tracker_uri.start_with? 'http'

      params = {
        info_hash:   torrent.info_hash,
        peer_id:     torrent.peer_id,
        port:        config.listen_port,
        uploaded:    uploaded,
        downloaded:  downloaded,
        left:        left,
        compact: 1,
        numwant: 50,
        event: 'started'
      }

      announce_uri = URI(@tracker_uri)

      if announce_uri.query
        passkey = Hash[URI.decode_www_form announce_uri.query]['passkey']
        params['passkey'] = passkey if passkey
      end

      announce_uri.query = URI.encode_www_form params

      begin
        announce_response = Net::HTTP.get_response(announce_uri)
      rescue Errno::EHOSTUNREACH
        return []
      end

      if announce_response.code == '301'
        announce_response = Net::HTTP.get_response(
          URI(announce_response.header['Location'])
        )
      end

      return [] unless announce_response.code == '200'

      peers_compact = BEncode::Parser.new(StringIO.new(announce_response.body)).parse!['peers']

      return [] unless peers_compact

      peers_compact.bytes.each_slice(6).map do |peer_data|
        Peer.new peer_data[0..3].map(&:ord).map(&:to_s).join('.'),
                 peer_data[4..5].map(&:chr).join.unpack('n').first
      end
    end

    def stop(torrent)
      return unless @tracker_uri.start_with? 'http'

      announce_uri = URI(@tracker_uri)
      announce_uri.query = URI.encode_www_form info_hash:   torrent.info_hash,
                                               peer_id:     torrent.peer_id,
                                               port:        6881,
                                               uploaded:    '0',
                                               downloaded:  '0',
                                               left:        torrent.length,
                                               compact: 1,
                                               numwant: 80,
                                               event: 'stopped'

      begin
        Net::HTTP.get_response(announce_uri)
      rescue Errno::EHOSTUNREACH
        return
      end
    end
  end
end
