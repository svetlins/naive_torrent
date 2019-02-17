require 'bencode'

module NaiveTorrent
  class Torrent
    def initialize(torrent_file_path)
      @torrent = File.open(torrent_file_path) do |file|
        BEncode::Parser.new(file).parse!
      end

      @peer_id = "-NT0666-#{12.times.map { rand(9) }.join}"

      raise 'Invalid pieces' if @torrent['info']['pieces'].size % 20 != 0
    end

    def length
      if @torrent['info']['length']
        @torrent['info']['length']
      else
        @torrent['info']['files'].collect { |file| file["length"] }.sum
      end
    end

    def piece_length(piece_index = 0)
      if piece_index < piece_count - 1
        @torrent['info']['piece length']
      else
        length - (piece_count - 1) * piece_length
      end
    end

    def piece_count
      @torrent['info']['pieces'].size / 20
    end

    def piece_hash(piece_index)
      @torrent['info']['pieces'][20 * piece_index ... 20 * (piece_index + 1)]
    end

    def validate_piece(piece_index, piece_data)
      Digest::SHA1.digest(piece_data) == piece_hash(piece_index)
    end

    def info_hash
      Digest::SHA1.digest(@torrent['info'].bencode)
    end

    def announce_uris
      ([@torrent['announce']] + (@torrent['announce-list'] || [])).flatten.uniq
    end

    def each_file
      if @torrent['info']['files']
        @torrent['info']['files'].each { |file| yield file['path'].first, file['length'] }
      else
        yield @torrent['info']['name'], length
      end
    end

    def storage_dir
      FileUtils.mkdir_p @torrent['info']['name']
      @torrent['info']['name']
    end

    def storage_filename(filename)
      File.join storage_dir, filename
    end

    def store_piece(index, piece_data)
      FileUtils.mkdir_p File.join(@torrent['info']['name'], 'pieces')
      File.write storage_filename("pieces/#{index}.piece"), piece_data
    end

    def each_downloaded_piece
      piece_count.times do |i|
        file_name = storage_filename "pieces/#{i}.piece"
        if File.exists?(file_name) && validate_piece(i, File.read(file_name))
          yield i
        end
      end
    end

    def peer_id
      @peer_id
    end

    def assemble_files
      File.open storage_filename('temp'), 'w' do |file|
        piece_count.times do |i|
          file.write File.read(storage_filename("pieces/#{i}.piece"))
        end
      end

      File.open storage_filename('temp') do |file|
        each_file do |path, length|
          File.write storage_filename(path), file.read(length)
        end
      end

      File.delete storage_filename('temp')
    end
  end
end
