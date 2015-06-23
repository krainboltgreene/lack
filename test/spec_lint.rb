require 'stringio'
require 'rack/lint'
require 'rack/mock'

describe Lack::Lint do
  def env(*args)
    Lack::MockRequest.env_for("/", *args)
  end

  should "pass valid request" do
    lambda {
      Lack::Lint.new(lambda { |env|
                       [200, {"Content-type" => "test/plain", "Content-length" => "3"}, ["foo"]]
                     }).call(env({}))
    }.should.not.raise
  end

  should "notice fatal errors" do
    lambda { Lack::Lint.new(nil).call }.should.raise(Lack::Lint::LintError).
      message.should.match(/No env given/)
  end

  should "notice environment errors" do
    lambda { Lack::Lint.new(nil).call 5 }.should.raise(Lack::Lint::LintError).
      message.should.match(/not a Hash/)

    lambda {
      e = env
      e.delete("REQUEST_METHOD")
      Lack::Lint.new(nil).call(e)
    }.should.raise(Lack::Lint::LintError).
      message.should.match(/missing required key REQUEST_METHOD/)

    lambda {
      e = env
      e.delete("SERVER_NAME")
      Lack::Lint.new(nil).call(e)
    }.should.raise(Lack::Lint::LintError).
      message.should.match(/missing required key SERVER_NAME/)


    lambda {
      Lack::Lint.new(nil).call(env("HTTP_CONTENT_TYPE" => "text/plain"))
    }.should.raise(Lack::Lint::LintError).
      message.should.match(/contains HTTP_CONTENT_TYPE/)

    lambda {
      Lack::Lint.new(nil).call(env("HTTP_CONTENT_LENGTH" => "42"))
    }.should.raise(Lack::Lint::LintError).
      message.should.match(/contains HTTP_CONTENT_LENGTH/)

    lambda {
      Lack::Lint.new(nil).call(env("FOO" => Object.new))
    }.should.raise(Lack::Lint::LintError).
      message.should.match(/non-string value/)

    lambda {
      Lack::Lint.new(nil).call(env("rack.version" => "0.2"))
    }.should.raise(Lack::Lint::LintError).
      message.should.match(/must be an Array/)

    lambda {
      Lack::Lint.new(nil).call(env("rack.url_scheme" => "gopher"))
    }.should.raise(Lack::Lint::LintError).
      message.should.match(/url_scheme unknown/)

    lambda {
      Lack::Lint.new(nil).call(env("rack.session" => []))
    }.should.raise(Lack::Lint::LintError).
      message.should.equal("session [] must respond to store and []=")

    lambda {
      Lack::Lint.new(nil).call(env("rack.logger" => []))
    }.should.raise(Lack::Lint::LintError).
      message.should.equal("logger [] must respond to info")

    lambda {
      Lack::Lint.new(nil).call(env("REQUEST_METHOD" => "FUCKUP?"))
    }.should.raise(Lack::Lint::LintError).
      message.should.match(/REQUEST_METHOD/)

    lambda {
      Lack::Lint.new(nil).call(env("SCRIPT_NAME" => "howdy"))
    }.should.raise(Lack::Lint::LintError).
      message.should.match(/must start with/)

    lambda {
      Lack::Lint.new(nil).call(env("PATH_INFO" => "../foo"))
    }.should.raise(Lack::Lint::LintError).
      message.should.match(/must start with/)

    lambda {
      Lack::Lint.new(nil).call(env("CONTENT_LENGTH" => "xcii"))
    }.should.raise(Lack::Lint::LintError).
      message.should.match(/Invalid CONTENT_LENGTH/)

    lambda {
      e = env
      e.delete("PATH_INFO")
      e.delete("SCRIPT_NAME")
      Lack::Lint.new(nil).call(e)
    }.should.raise(Lack::Lint::LintError).
      message.should.match(/One of .* must be set/)

    lambda {
      Lack::Lint.new(nil).call(env("SCRIPT_NAME" => "/"))
    }.should.raise(Lack::Lint::LintError).
      message.should.match(/cannot be .* make it ''/)
  end

  should "notice input errors" do
    lambda {
      Lack::Lint.new(nil).call(env("rack.input" => ""))
    }.should.raise(Lack::Lint::LintError).
      message.should.match(/does not respond to #gets/)

    lambda {
      input = Object.new
      def input.binmode?
        false
      end
      Lack::Lint.new(nil).call(env("rack.input" => input))
    }.should.raise(Lack::Lint::LintError).
      message.should.match(/is not opened in binary mode/)

    lambda {
      input = Object.new
      def input.external_encoding
        result = Object.new
        def result.name
          "US-ASCII"
        end
        result
      end
      Lack::Lint.new(nil).call(env("rack.input" => input))
    }.should.raise(Lack::Lint::LintError).
      message.should.match(/does not have ASCII-8BIT as its external encoding/)
  end

  should "notice error errors" do
    lambda {
      Lack::Lint.new(nil).call(env("rack.errors" => ""))
    }.should.raise(Lack::Lint::LintError).
      message.should.match(/does not respond to #puts/)
  end

  should "notice status errors" do
    lambda {
      Lack::Lint.new(lambda { |env|
                       ["cc", {}, ""]
                     }).call(env({}))
    }.should.raise(Lack::Lint::LintError).
      message.should.match(/must be >=100 seen as integer/)

    lambda {
      Lack::Lint.new(lambda { |env|
                       [42, {}, ""]
                     }).call(env({}))
    }.should.raise(Lack::Lint::LintError).
      message.should.match(/must be >=100 seen as integer/)
  end

  should "notice header errors" do
    lambda {
      Lack::Lint.new(lambda { |env|
                       [200, Object.new, []]
                     }).call(env({}))
    }.should.raise(Lack::Lint::LintError).
      message.should.equal("headers object should respond to #each, but doesn't (got Object as headers)")

    lambda {
      Lack::Lint.new(lambda { |env|
                       [200, {true=>false}, []]
                     }).call(env({}))
    }.should.raise(Lack::Lint::LintError).
      message.should.equal("header key must be a string, was TrueClass")

    lambda {
      Lack::Lint.new(lambda { |env|
                       [200, {"Status" => "404"}, []]
                     }).call(env({}))
    }.should.raise(Lack::Lint::LintError).
      message.should.match(/must not contain Status/)

    lambda {
      Lack::Lint.new(lambda { |env|
                       [200, {"Content-Type:" => "text/plain"}, []]
                     }).call(env({}))
    }.should.raise(Lack::Lint::LintError).
      message.should.match(/must not contain :/)

    lambda {
      Lack::Lint.new(lambda { |env|
                       [200, {"Content-" => "text/plain"}, []]
                     }).call(env({}))
    }.should.raise(Lack::Lint::LintError).
      message.should.match(/must not end/)

    lambda {
      Lack::Lint.new(lambda { |env|
                       [200, {"..%%quark%%.." => "text/plain"}, []]
                     }).call(env({}))
    }.should.raise(Lack::Lint::LintError).
      message.should.equal("invalid header name: ..%%quark%%..")

    lambda {
      Lack::Lint.new(lambda { |env|
                       [200, {"Foo" => Object.new}, []]
                     }).call(env({}))
    }.should.raise(Lack::Lint::LintError).
      message.should.equal("a header value must be a String, but the value of 'Foo' is a Object")

    lambda {
      Lack::Lint.new(lambda { |env|
                       [200, {"Foo" => [1, 2, 3]}, []]
                     }).call(env({}))
    }.should.raise(Lack::Lint::LintError).
      message.should.equal("a header value must be a String, but the value of 'Foo' is a Array")


    lambda {
      Lack::Lint.new(lambda { |env|
                       [200, {"Foo-Bar" => "text\000plain"}, []]
                     }).call(env({}))
    }.should.raise(Lack::Lint::LintError).
      message.should.match(/invalid header/)

    # line ends (010) should be allowed in header values.
    lambda {
      Lack::Lint.new(lambda { |env|
                       [200, {"Foo-Bar" => "one\ntwo\nthree", "Content-Length" => "0", "Content-Type" => "text/plain" }, []]
                     }).call(env({}))
    }.should.not.raise(Lack::Lint::LintError)

    # non-Hash header responses should be allowed
    lambda {
      Lack::Lint.new(lambda { |env|
                       [200, [%w(Content-Type text/plain), %w(Content-Length 0)], []]
                     }).call(env({}))
    }.should.not.raise(TypeError)
  end

  should "notice content-type errors" do
    # lambda {
    #   Lack::Lint.new(lambda { |env|
    #                    [200, {"Content-length" => "0"}, []]
    #                  }).call(env({}))
    # }.should.raise(Lack::Lint::LintError).
    #   message.should.match(/No Content-Type/)

    [100, 101, 204, 205, 304].each do |status|
      lambda {
        Lack::Lint.new(lambda { |env|
                         [status, {"Content-type" => "text/plain", "Content-length" => "0"}, []]
                       }).call(env({}))
      }.should.raise(Lack::Lint::LintError).
        message.should.match(/Content-Type header found/)
    end
  end

  should "notice content-length errors" do
    [100, 101, 204, 205, 304].each do |status|
      lambda {
        Lack::Lint.new(lambda { |env|
                         [status, {"Content-length" => "0"}, []]
                       }).call(env({}))
      }.should.raise(Lack::Lint::LintError).
        message.should.match(/Content-Length header found/)
    end

    lambda {
      Lack::Lint.new(lambda { |env|
                       [200, {"Content-type" => "text/plain", "Content-Length" => "1"}, []]
                     }).call(env({}))[2].each { }
    }.should.raise(Lack::Lint::LintError).
      message.should.match(/Content-Length header was 1, but should be 0/)
  end

  should "notice body errors" do
    lambda {
      body = Lack::Lint.new(lambda { |env|
                               [200, {"Content-type" => "text/plain","Content-length" => "3"}, [1,2,3]]
                             }).call(env({}))[2]
      body.each { |part| }
    }.should.raise(Lack::Lint::LintError).
      message.should.match(/yielded non-string/)
  end

  should "notice input handling errors" do
    lambda {
      Lack::Lint.new(lambda { |env|
                       env["rack.input"].gets("\r\n")
                       [201, {"Content-type" => "text/plain", "Content-length" => "0"}, []]
                     }).call(env({}))
    }.should.raise(Lack::Lint::LintError).
      message.should.match(/gets called with arguments/)

    lambda {
      Lack::Lint.new(lambda { |env|
                       env["rack.input"].read(1, 2, 3)
                       [201, {"Content-type" => "text/plain", "Content-length" => "0"}, []]
                     }).call(env({}))
    }.should.raise(Lack::Lint::LintError).
      message.should.match(/read called with too many arguments/)

    lambda {
      Lack::Lint.new(lambda { |env|
                       env["rack.input"].read("foo")
                       [201, {"Content-type" => "text/plain", "Content-length" => "0"}, []]
                     }).call(env({}))
    }.should.raise(Lack::Lint::LintError).
      message.should.match(/read called with non-integer and non-nil length/)

    lambda {
      Lack::Lint.new(lambda { |env|
                       env["rack.input"].read(-1)
                       [201, {"Content-type" => "text/plain", "Content-length" => "0"}, []]
                     }).call(env({}))
    }.should.raise(Lack::Lint::LintError).
      message.should.match(/read called with a negative length/)

    lambda {
      Lack::Lint.new(lambda { |env|
                       env["rack.input"].read(nil, nil)
                       [201, {"Content-type" => "text/plain", "Content-length" => "0"}, []]
                     }).call(env({}))
    }.should.raise(Lack::Lint::LintError).
      message.should.match(/read called with non-String buffer/)

    lambda {
      Lack::Lint.new(lambda { |env|
                       env["rack.input"].read(nil, 1)
                       [201, {"Content-type" => "text/plain", "Content-length" => "0"}, []]
                     }).call(env({}))
    }.should.raise(Lack::Lint::LintError).
      message.should.match(/read called with non-String buffer/)

    lambda {
      Lack::Lint.new(lambda { |env|
                       env["rack.input"].rewind(0)
                       [201, {"Content-type" => "text/plain", "Content-length" => "0"}, []]
                     }).call(env({}))
    }.should.raise(Lack::Lint::LintError).
      message.should.match(/rewind called with arguments/)

    weirdio = Object.new
    class << weirdio
      def gets
        42
      end

      def read
        23
      end

      def each
        yield 23
        yield 42
      end

      def rewind
        raise Errno::ESPIPE, "Errno::ESPIPE"
      end
    end

    eof_weirdio = Object.new
    class << eof_weirdio
      def gets
        nil
      end

      def read(*args)
        nil
      end

      def each
      end

      def rewind
      end
    end

    lambda {
      Lack::Lint.new(lambda { |env|
                       env["rack.input"].gets
                       [201, {"Content-type" => "text/plain", "Content-length" => "0"}, []]
                     }).call(env("rack.input" => weirdio))
    }.should.raise(Lack::Lint::LintError).
      message.should.match(/gets didn't return a String/)

    lambda {
      Lack::Lint.new(lambda { |env|
                       env["rack.input"].each { |x| }
                       [201, {"Content-type" => "text/plain", "Content-length" => "0"}, []]
                     }).call(env("rack.input" => weirdio))
    }.should.raise(Lack::Lint::LintError).
      message.should.match(/each didn't yield a String/)

    lambda {
      Lack::Lint.new(lambda { |env|
                       env["rack.input"].read
                       [201, {"Content-type" => "text/plain", "Content-length" => "0"}, []]
                     }).call(env("rack.input" => weirdio))
    }.should.raise(Lack::Lint::LintError).
      message.should.match(/read didn't return nil or a String/)

    lambda {
      Lack::Lint.new(lambda { |env|
                       env["rack.input"].read
                       [201, {"Content-type" => "text/plain", "Content-length" => "0"}, []]
                     }).call(env("rack.input" => eof_weirdio))
    }.should.raise(Lack::Lint::LintError).
      message.should.match(/read\(nil\) returned nil on EOF/)

    lambda {
      Lack::Lint.new(lambda { |env|
                       env["rack.input"].rewind
                       [201, {"Content-type" => "text/plain", "Content-length" => "0"}, []]
                     }).call(env("rack.input" => weirdio))
    }.should.raise(Lack::Lint::LintError).
      message.should.match(/rewind raised Errno::ESPIPE/)


    lambda {
      Lack::Lint.new(lambda { |env|
                       env["rack.input"].close
                       [201, {"Content-type" => "text/plain", "Content-length" => "0"}, []]
                     }).call(env({}))
    }.should.raise(Lack::Lint::LintError).
      message.should.match(/close must not be called/)
  end

  should "notice error handling errors" do
    lambda {
      Lack::Lint.new(lambda { |env|
                       env["rack.errors"].write(42)
                       [201, {"Content-type" => "text/plain", "Content-length" => "0"}, []]
                     }).call(env({}))
    }.should.raise(Lack::Lint::LintError).
      message.should.match(/write not called with a String/)

    lambda {
      Lack::Lint.new(lambda { |env|
                       env["rack.errors"].close
                       [201, {"Content-type" => "text/plain", "Content-length" => "0"}, []]
                     }).call(env({}))
    }.should.raise(Lack::Lint::LintError).
      message.should.match(/close must not be called/)
  end

  should "notice HEAD errors" do
    lambda {
      Lack::Lint.new(lambda { |env|
                       [200, {"Content-type" => "test/plain", "Content-length" => "3"}, []]
                     }).call(env({"REQUEST_METHOD" => "HEAD"}))
    }.should.not.raise

    lambda {
      Lack::Lint.new(lambda { |env|
                       [200, {"Content-type" => "test/plain", "Content-length" => "3"}, ["foo"]]
                     }).call(env({"REQUEST_METHOD" => "HEAD"}))[2].each { }
    }.should.raise(Lack::Lint::LintError).
      message.should.match(/body was given for HEAD/)
  end

  should "pass valid read calls" do
    hello_str = "hello world"
    hello_str.force_encoding("ASCII-8BIT") if hello_str.respond_to? :force_encoding
    lambda {
      Lack::Lint.new(lambda { |env|
                       env["rack.input"].read
                       [201, {"Content-type" => "text/plain", "Content-length" => "0"}, []]
                     }).call(env({"rack.input" => StringIO.new(hello_str)}))
    }.should.not.raise(Lack::Lint::LintError)

    lambda {
      Lack::Lint.new(lambda { |env|
                       env["rack.input"].read(0)
                       [201, {"Content-type" => "text/plain", "Content-length" => "0"}, []]
                     }).call(env({"rack.input" => StringIO.new(hello_str)}))
    }.should.not.raise(Lack::Lint::LintError)

    lambda {
      Lack::Lint.new(lambda { |env|
                       env["rack.input"].read(1)
                       [201, {"Content-type" => "text/plain", "Content-length" => "0"}, []]
                     }).call(env({"rack.input" => StringIO.new(hello_str)}))
    }.should.not.raise(Lack::Lint::LintError)

    lambda {
      Lack::Lint.new(lambda { |env|
                       env["rack.input"].read(nil)
                       [201, {"Content-type" => "text/plain", "Content-length" => "0"}, []]
                     }).call(env({"rack.input" => StringIO.new(hello_str)}))
    }.should.not.raise(Lack::Lint::LintError)

    lambda {
      Lack::Lint.new(lambda { |env|
                       env["rack.input"].read(nil, '')
                       [201, {"Content-type" => "text/plain", "Content-length" => "0"}, []]
                     }).call(env({"rack.input" => StringIO.new(hello_str)}))
    }.should.not.raise(Lack::Lint::LintError)

    lambda {
      Lack::Lint.new(lambda { |env|
                       env["rack.input"].read(1, '')
                       [201, {"Content-type" => "text/plain", "Content-length" => "0"}, []]
                     }).call(env({"rack.input" => StringIO.new(hello_str)}))
    }.should.not.raise(Lack::Lint::LintError)
  end
end

describe "Lack::Lint::InputWrapper" do
  should "delegate :rewind to underlying IO object" do
    io = StringIO.new("123")
    wrapper = Lack::Lint::InputWrapper.new(io)
    wrapper.read.should.equal "123"
    wrapper.read.should.equal ""
    wrapper.rewind
    wrapper.read.should.equal "123"
  end
end
