Gem::Specification.new do |s|
  s.name        = 'naive_torrent'
  s.version     = '0.0.1'
  s.date        = '2019-02-17'
  s.summary     = 'A naive BitTorrent client in Ruby'
  s.description = ''
  s.authors     = ['Svetlin Simonyan']
  s.email       = 'svetlin.s@gmail.com'
  s.files       = ['lib/naive_torrent.rb'] + Dir['lib/naive_torrent/**/*.rb']
  s.executables << 'naive_torrent'
  s.homepage    = 'http://github.com/svetlins/naive_torrent'
  s.license     = 'MIT'

  s.add_runtime_dependency 'bencode',         '~> 0.8'
  s.add_runtime_dependency 'concurrent-ruby', '~> 1.1'
  s.add_runtime_dependency 'terminal-table',  '~> 1.8'
  s.add_runtime_dependency 'ruby-terminfo',   '~> 0.1'
end
