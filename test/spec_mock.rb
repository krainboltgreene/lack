require 'yaml'
require 'rack/lint'
require 'rack/mock'
require 'stringio'

app = Lack::Lint.new(lambda { |env|
  req = Lack::Request.new(env)

  env["mock.postdata"] = env["rack.input"].read
  if req.GET["error"]
    env["rack.errors"].puts req.GET["error"]
    env["rack.errors"].flush
  end

  body = req.head? ? "" : env.to_yaml
  Lack::Response.new(body,
                     req.GET["status"] || 200,
                     "Content-Type" => "text/yaml").finish
})

describe Lack::MockRequest do
  should "return a MockResponse" do
    res = Lack::MockRequest.new(app).get("")
    res.should.be.kind_of Lack::MockResponse
  end

  should "be able to only return the environment" do
    env = Lack::MockRequest.env_for("")
    env.should.be.kind_of Hash
    env.should.include "rack.version"
  end

  should "return an environment with a path" do
    env = Lack::MockRequest.env_for("http://www.example.com/parse?location[]=1&location[]=2&age_group[]=2")
    env["QUERY_STRING"].should.equal "location[]=1&location[]=2&age_group[]=2"
    env["PATH_INFO"].should.equal "/parse"
    env.should.be.kind_of Hash
    env.should.include "rack.version"
  end

  should "provide sensible defaults" do
    res = Lack::MockRequest.new(app).request

    env = YAML.load(res.body)
    env["REQUEST_METHOD"].should.equal "GET"
    env["SERVER_NAME"].should.equal "example.org"
    env["SERVER_PORT"].should.equal "80"
    env["QUERY_STRING"].should.equal ""
    env["PATH_INFO"].should.equal "/"
    env["SCRIPT_NAME"].should.equal ""
    env["rack.url_scheme"].should.equal "http"
    env["mock.postdata"].should.be.empty
  end

  should "allow GET/POST/PUT/DELETE/HEAD" do
    res = Lack::MockRequest.new(app).get("", :input => "foo")
    env = YAML.load(res.body)
    env["REQUEST_METHOD"].should.equal "GET"

    res = Lack::MockRequest.new(app).post("", :input => "foo")
    env = YAML.load(res.body)
    env["REQUEST_METHOD"].should.equal "POST"

    res = Lack::MockRequest.new(app).put("", :input => "foo")
    env = YAML.load(res.body)
    env["REQUEST_METHOD"].should.equal "PUT"

    res = Lack::MockRequest.new(app).patch("", :input => "foo")
    env = YAML.load(res.body)
    env["REQUEST_METHOD"].should.equal "PATCH"

    res = Lack::MockRequest.new(app).delete("", :input => "foo")
    env = YAML.load(res.body)
    env["REQUEST_METHOD"].should.equal "DELETE"
    
    Lack::MockRequest.env_for("/", :method => "HEAD")["REQUEST_METHOD"].
      should.equal "HEAD"

    Lack::MockRequest.env_for("/", :method => "OPTIONS")["REQUEST_METHOD"].
      should.equal "OPTIONS"
  end

  should "set content length" do
    env = Lack::MockRequest.env_for("/", :input => "foo")
    env["CONTENT_LENGTH"].should.equal "3"
  end

  should "allow posting" do
    res = Lack::MockRequest.new(app).get("", :input => "foo")
    env = YAML.load(res.body)
    env["mock.postdata"].should.equal "foo"

    res = Lack::MockRequest.new(app).post("", :input => StringIO.new("foo"))
    env = YAML.load(res.body)
    env["mock.postdata"].should.equal "foo"
  end

  should "use all parts of an URL" do
    res = Lack::MockRequest.new(app).
      get("https://bla.example.org:9292/meh/foo?bar")
    res.should.be.kind_of Lack::MockResponse

    env = YAML.load(res.body)
    env["REQUEST_METHOD"].should.equal "GET"
    env["SERVER_NAME"].should.equal "bla.example.org"
    env["SERVER_PORT"].should.equal "9292"
    env["QUERY_STRING"].should.equal "bar"
    env["PATH_INFO"].should.equal "/meh/foo"
    env["rack.url_scheme"].should.equal "https"
  end

  should "set SSL port and HTTP flag on when using https" do
    res = Lack::MockRequest.new(app).
      get("https://example.org/foo")
    res.should.be.kind_of Lack::MockResponse

    env = YAML.load(res.body)
    env["REQUEST_METHOD"].should.equal "GET"
    env["SERVER_NAME"].should.equal "example.org"
    env["SERVER_PORT"].should.equal "443"
    env["QUERY_STRING"].should.equal ""
    env["PATH_INFO"].should.equal "/foo"
    env["rack.url_scheme"].should.equal "https"
    env["HTTPS"].should.equal "on"
  end

  should "prepend slash to uri path" do
    res = Lack::MockRequest.new(app).
      get("foo")
    res.should.be.kind_of Lack::MockResponse

    env = YAML.load(res.body)
    env["REQUEST_METHOD"].should.equal "GET"
    env["SERVER_NAME"].should.equal "example.org"
    env["SERVER_PORT"].should.equal "80"
    env["QUERY_STRING"].should.equal ""
    env["PATH_INFO"].should.equal "/foo"
    env["rack.url_scheme"].should.equal "http"
  end

  should "properly convert method name to an uppercase string" do
    res = Lack::MockRequest.new(app).request(:get)
    env = YAML.load(res.body)
    env["REQUEST_METHOD"].should.equal "GET"
  end

  should "accept params and build query string for GET requests" do
    res = Lack::MockRequest.new(app).get("/foo?baz=2", :params => {:foo => {:bar => "1"}})
    env = YAML.load(res.body)
    env["REQUEST_METHOD"].should.equal "GET"
    env["QUERY_STRING"].should.include "baz=2"
    env["QUERY_STRING"].should.include "foo[bar]=1"
    env["PATH_INFO"].should.equal "/foo"
    env["mock.postdata"].should.equal ""
  end

  should "accept raw input in params for GET requests" do
    res = Lack::MockRequest.new(app).get("/foo?baz=2", :params => "foo[bar]=1")
    env = YAML.load(res.body)
    env["REQUEST_METHOD"].should.equal "GET"
    env["QUERY_STRING"].should.include "baz=2"
    env["QUERY_STRING"].should.include "foo[bar]=1"
    env["PATH_INFO"].should.equal "/foo"
    env["mock.postdata"].should.equal ""
  end

  should "accept params and build url encoded params for POST requests" do
    res = Lack::MockRequest.new(app).post("/foo", :params => {:foo => {:bar => "1"}})
    env = YAML.load(res.body)
    env["REQUEST_METHOD"].should.equal "POST"
    env["QUERY_STRING"].should.equal ""
    env["PATH_INFO"].should.equal "/foo"
    env["CONTENT_TYPE"].should.equal "application/x-www-form-urlencoded"
    env["mock.postdata"].should.equal "foo[bar]=1"
  end

  should "accept raw input in params for POST requests" do
    res = Lack::MockRequest.new(app).post("/foo", :params => "foo[bar]=1")
    env = YAML.load(res.body)
    env["REQUEST_METHOD"].should.equal "POST"
    env["QUERY_STRING"].should.equal ""
    env["PATH_INFO"].should.equal "/foo"
    env["CONTENT_TYPE"].should.equal "application/x-www-form-urlencoded"
    env["mock.postdata"].should.equal "foo[bar]=1"
  end

  should "accept params and build multipart encoded params for POST requests" do
    files = Lack::Multipart::UploadedFile.new(File.join(File.dirname(__FILE__), "multipart", "file1.txt"))
    res = Lack::MockRequest.new(app).post("/foo", :params => { "submit-name" => "Larry", "files" => files })
    env = YAML.load(res.body)
    env["REQUEST_METHOD"].should.equal "POST"
    env["QUERY_STRING"].should.equal ""
    env["PATH_INFO"].should.equal "/foo"
    env["CONTENT_TYPE"].should.equal "multipart/form-data; boundary=AaB03x"
    # The gsub accounts for differences in YAMLs affect on the data.
    env["mock.postdata"].gsub("\r", "").length.should.equal 206
  end

  should "behave valid according to the Lack spec" do
    lambda {
      Lack::MockRequest.new(app).
        get("https://bla.example.org:9292/meh/foo?bar", :lint => true)
    }.should.not.raise(Lack::Lint::LintError)
  end

  should "call close on the original body object" do
    called = false
    body   = Lack::BodyProxy.new(['hi']) { called = true }
    capp   = proc { |e| [200, {'Content-Type' => 'text/plain'}, body] }
    called.should.equal false
    Lack::MockRequest.new(capp).get('/', :lint => true)
    called.should.equal true
  end
end

describe Lack::MockResponse do
  should "provide access to the HTTP status" do
    res = Lack::MockRequest.new(app).get("")
    res.should.be.successful
    res.should.be.ok

    res = Lack::MockRequest.new(app).get("/?status=404")
    res.should.not.be.successful
    res.should.be.client_error
    res.should.be.not_found

    res = Lack::MockRequest.new(app).get("/?status=501")
    res.should.not.be.successful
    res.should.be.server_error

    res = Lack::MockRequest.new(app).get("/?status=307")
    res.should.be.redirect

    res = Lack::MockRequest.new(app).get("/?status=201", :lint => true)
    res.should.be.empty
  end

  should "provide access to the HTTP headers" do
    res = Lack::MockRequest.new(app).get("")
    res.should.include "Content-Type"
    res.headers["Content-Type"].should.equal "text/yaml"
    res.original_headers["Content-Type"].should.equal "text/yaml"
    res["Content-Type"].should.equal "text/yaml"
    res.content_type.should.equal "text/yaml"
    res.content_length.should.not.equal 0
    res.location.should.be.nil
  end

  should "provide access to the HTTP body" do
    res = Lack::MockRequest.new(app).get("")
    res.body.should =~ /rack/
    res.should =~ /rack/
    res.should.match(/rack/)
    res.should.satisfy { |r| r.match(/rack/) }
  end

  should "provide access to the Lack errors" do
    res = Lack::MockRequest.new(app).get("/?error=foo", :lint => true)
    res.should.be.ok
    res.errors.should.not.be.empty
    res.errors.should.include "foo"
  end

  should "allow calling body.close afterwards" do
    # this is exactly what rack-test does
    body = StringIO.new("hi")
    res = Lack::MockResponse.new(200, {}, body)
    body.close if body.respond_to?(:close)
    res.body.should == 'hi'
  end

  should "optionally make Lack errors fatal" do
    lambda {
      Lack::MockRequest.new(app).get("/?error=foo", :fatal => true)
    }.should.raise(Lack::MockRequest::FatalWarning)
  end
end
