module NaiveTorrent
  class PeersTable
    def initialize
      @table = {}
    end

    def add_outgoing(peer_ip)
      @table[peer_ip] = {kind: 'Outgoing', status: 'New'}
    end

    def add_incoming(peer_ip)
      @table[peer_ip] = {kind: 'Incoming', status: 'New'}
    end

    def report_peer_status(peer_ip, report)
      @table[peer_ip] ||= {kind: 'Unknown'}
      @table[peer_ip].merge! report
    end

    def print
      rows = @table.map do |peer_ip, peer_status|
        [
          peer_ip,
          peer_status[:kind],
          peer_status[:status],
          humanize_transfer_speed(peer_status[:download_speed]),
          humanize_transfer_speed(peer_status[:upload_speed])
        ]
      end.sort_by do |ip, kind, status, download_speed|
        ip
      end

      rows << [
        '',
        '',
        'Total',
        humanize_transfer_speed(@table.values.collect { |s| s[:download_speed] }.compact.inject(&:+)),
        humanize_transfer_speed(@table.values.collect { |s| s[:upload_speed] }.compact.inject(&:+))
      ]

      puts "\e[H\e[2J"
      table = Terminal::Table.new rows: rows
      table.align_column(2, :right)
      puts table
    end

    def humanize_transfer_speed(speed_in_bytes_per_second)
      return "N/A" unless speed_in_bytes_per_second

      case speed_in_bytes_per_second
      when (0..1024)
        format '%dB/s', speed_in_bytes_per_second
      when (1024..1024**2)
        format '%.2fKB/s', (speed_in_bytes_per_second / 1024)
      else
        format '%.2fMB/s', (speed_in_bytes_per_second / 1024**2)
      end
    end
  end
end
