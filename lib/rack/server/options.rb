module Lack
  class Server
    class Options
      def parse!(args)
        options = {}
        opt_parser = OptionParser.new("", 24, "  ") do |opts|
          opts.banner = "Usage: rackup [ruby options] [rack options] [rackup config]"
          opts.separator ""
          opts.separator "Ruby options:"

          lineno = 1

          opts.on("--eval LINE", "evaluate a LINE of code") do |line|
            eval line, TOPLEVEL_BINDING, "-e", lineno
            lineno += 1
          end

          opts.on("--builder BUILDER_LINE", "evaluate a BUILDER_LINE of code as a builder script") do |line|
            options[:builder] = line
          end

          opts.on("--debug", "set debugging flags (set $DEBUG to true)") do
            options[:debug] = true
          end

          opts.on("--warn", "turn warnings on for your script") do
            options[:warn] = true
          end

          opts.on("--quiet", "turn off logging") do
            options[:quiet] = true
          end

          opts.on("--include PATH",
                  "specify $LOAD_PATH (may be used more than once)") do |path|
            (options[:include] ||= []).concat(path.split(":"))
          end

          opts.on("--require LIBRARY", "require the library, before executing your script") do |library|
            options[:require] = library
          end

          opts.separator ""
          opts.separator "Lack options:"

          opts.on("-s", "--server SERVER", "serve using SERVER (thin/puma/webrick/mongrel)") do |s|
            options[:server] = s
          end

          opts.on("-o", "--host HOST", "listen on HOST (default: 0.0.0.0)") do |host|
            options[:Host] = host
          end

          opts.on("-p", "--port PORT", "use PORT (default: 9292)") do |port|
            options[:Port] = port
          end

          opts.on("-O", "--option NAME[=VALUE]", "pass VALUE to the server as option NAME. If no VALUE, sets it to true. Run '#{$0} -s SERVER -h' to get a list of options for SERVER") do |name|
            name, value = name.split('=', 2)
            value = true if value.nil?
            options[name.to_sym] = value
          end

          opts.on("--env ENVIRONMENT", "use ENVIRONMENT for defaults (default: development)") do |e|
            options[:environment] = e
          end

          opts.on("--pid FILE", "file to store PID") do |file|
            options[:pid] = ::File.expand_path(file)
          end

          opts.separator ""
          opts.separator "Common options:"

          opts.on_tail("-h", "-?", "--help", "Show this message") do
            puts opts
            puts handler_opts(options)
            exit
          end

          opts.on_tail("--version", "Show version") do
            puts "Lack #{Lack.version} (Release: #{Lack.release})"
            exit
          end
        end

        begin
          opt_parser.parse! args
        rescue OptionParser::InvalidOption => e
          warn e.message
          abort opt_parser.to_s
        end

        options[:config] = args.last if args.last
        options
      end

      def handler_opts(options)
        begin
          info = []
          server = Lack::Handler.get(options[:server]) || Lack::Handler.default(options)
          if server && server.respond_to?(:valid_options)
            info << ""
            info << "Server-specific options for #{server.name}:"

            has_options = false
            server.valid_options.each do |name, description|
              next if name.to_s.match(/^(Host|Port)[^a-zA-Z]/) # ignore handler's host and port options, we do our own.
              info << "  -O %-21s %s" % [name, description]
              has_options = true
            end
            return "" if !has_options
          end
          info.join("\n")
        rescue NameError
          return "Warning: Could not find handler specified (#{options[:server] || 'default'}) to determine handler-specific options"
        end
      end
    end
  end
end
