module Lack
  # *Handlers* connect web servers with Lack.
  #
  # Handlers usually are activated by calling <tt>MyHandler.run(myapp)</tt>.
  # A second optional hash can be passed to include server-specific
  # configuration.
  module Handler
    require_relative "handler/webrick"
    def self.get(server)
      return unless server
      server = server.to_s

      unless @handlers.include? server
        load_error = try_require("rack/handler", server)
      end

      if klass = @handlers[server]
        klass.split("::").inject(Object) { |o, x| o.const_get(x) }
      else
        const_get(server)
      end

    rescue NameError => name_error
      raise load_error || name_error
    end

    def self.default(options = {})
      # Guess.
      if ENV.include?("RACK_HANDLER")
        get(ENV["RACK_HANDLER"])
      else
        "webrick"
      end
    end

    # Transforms server-name constants to their canonical form as filenames,
    # then tries to require them but silences the LoadError if not found
    #
    # Naming convention:
    #
    #   Foo # => 'foo'
    #   FooBar # => 'foo_bar.rb'
    #   FooBAR # => 'foobar.rb'
    #   FOObar # => 'foobar.rb'
    #   FOOBAR # => 'foobar.rb'
    #   FooBarBaz # => 'foo_bar_baz.rb'
    def self.try_require(prefix, const_name)
      file = const_name.gsub(/^[A-Z]+/) { |pre| pre.downcase }.
        gsub(/[A-Z]+[^A-Z]/, '_\&').downcase

      require(::File.join(prefix, file))
      nil
    rescue LoadError => error
      error
    end

    def self.register(server, klass)
      @handlers ||= {}
      @handlers[server.to_s] = klass.to_s
    end
    register "webrick", "Lack::Handler::WEBrick"
  end
end
