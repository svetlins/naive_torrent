def config
  @_config ||= OpenStruct.new(
    block_size: 2**14, # bytes
    read_chunk_size: 2**12, # bytes
    connect_timeout: 3, # seconds
    listen_port: 6881,
    wait_timeout: 0.1,
  )
end
