module Angelo

  class Base
    include ParamsParser
    include Celluloid::Logger

    extend Forwardable
    def_delegators :@responder, :content_type, :headers, :request

    @@addr = DEFAULT_ADDR
    @@port = DEFAULT_PORT

    if ARGV.any?
      require 'optparse'
      OptionParser.new { |op|
        op.on('-p port',   'set the port (default is 4567)')      { |val| @@port = Integer(val) }
        op.on('-o addr',   "set the host (default is #{@@addr})") { |val| @@addr = val }
      }.parse!(ARGV.dup)
    end

    attr_accessor :responder

    class << self

      attr_accessor :app_file

      def inherited subclass
        subclass.app_file = caller(1).map {|l| l.split(/:(?=|in )/, 3)[0,1]}.flatten[0]

        def subclass.root
          @root ||= File.expand_path '..', app_file
        end

        def subclass.view_dir
          v = self.class_variable_get(:@@views) rescue DEFAULT_VIEW_DIR
          File.join root, v
        end

        def subclass.public_dir
          p = self.class_variable_get(:@@public_dir) rescue DEFAULT_PUBLIC_DIR
          File.join root, p
        end

      end

      def compile! name, &block
        define_method name, &block
        method = instance_method name
        remove_method name
        method
      end

      def routes
        @routes ||= {}
        ROUTABLE.each do |m|
          @routes[m] ||= {}
        end
        @routes
      end

      def before opts = {}, &block
        define_method :before, &block
      end

      def after opts = {}, &block
        define_method :after, &block
      end

      HTTPABLE.each do |m|
        define_method m do |path, &block|
          routes[m][path] = Responder.new &block
        end
      end

      def socket path, &block
        routes[:socket][path] = WebsocketResponder.new &block
      end

      def websockets
        @websockets ||= WebsocketsArray.new
        @websockets.reject! &:closed?
        @websockets
      end

      def content_type type
        Responder.content_type type
      end

      def run addr = @@addr, port = @@port
        @server = Angelo::Server.new self, addr, port
        trap "INT" do
          @server.terminate if @server and @server.alive?
          exit
        end
        sleep
      end

    end

    def params
      @params ||= case request.method
                  when GET;  parse_query_string
                  when POST; parse_post_body
                  when PUT;  parse_post_body
                  end
    end

    def websockets; self.class.websockets; end

    class WebsocketsArray < Array

      def each &block
        super do |ws|
          begin
            yield ws
          rescue Reel::SocketError => rse
            warn "#{rse.class} - #{rse.message}"
            delete ws
          end
        end
      end

      def [] context
        @@websockets ||= {}
        @@websockets[context] ||= self.class.new
      end

    end

  end

end
