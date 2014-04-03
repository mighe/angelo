require 'openssl'
require 'mime-types'

module Angelo

  class Server < Reel::Server::HTTP
    extend Forwardable
    include Celluloid::Logger
    include ServerMixin

    def_delegator :@base, :websockets

    attr_reader :responder_pool

    def initialize base, host = DEFAULT_ADDR, port = DEFAULT_PORT, pool = false
      @base = base
      info "Angelo #{VERSION}"
      info "listening on #{host}:#{port}"

      callback = if pool
        @responder_pool = ResponderPool.pool_link args: [@base]
        info "pooling: #{@responder_pool.size} reactors"

        ->(connection) {
          connection.detach
          @responder_pool.async.on_connection connection
        }
      else
        method(:on_connection)
      end

      super host, port, &callback
    end

  end

  class ResponderPool
    extend Forwardable
    include Celluloid::IO
    include Celluloid::Logger
    include ServerMixin

    def_delegator :@base, :websockets

    def initialize base
      @base = base
    end
  end

end
