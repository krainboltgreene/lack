require 'rack/handler'

class Lack::Handler::Lobster; end
class RockLobster; end

describe Lack::Handler do
  it "has registered default handlers" do
    Lack::Handler.get('cgi').should.equal Lack::Handler::CGI
    Lack::Handler.get('webrick').should.equal Lack::Handler::WEBrick

    begin
      Lack::Handler.get('fastcgi').should.equal Lack::Handler::FastCGI
    rescue LoadError
    end

    begin
      Lack::Handler.get('mongrel').should.equal Lack::Handler::Mongrel
    rescue LoadError
    end
  end

  should "raise LoadError if handler doesn't exist" do
    lambda {
      Lack::Handler.get('boom')
    }.should.raise(LoadError)
  end

  should "get unregistered, but already required, handler by name" do
    Lack::Handler.get('Lobster').should.equal Lack::Handler::Lobster
  end

  should "register custom handler" do
    Lack::Handler.register('rock_lobster', 'RockLobster')
    Lack::Handler.get('rock_lobster').should.equal RockLobster
  end

  should "not need registration for properly coded handlers even if not already required" do
    begin
      $LOAD_PATH.push File.expand_path('../unregistered_handler', __FILE__)
      Lack::Handler.get('Unregistered').should.equal Lack::Handler::Unregistered
      lambda {
        Lack::Handler.get('UnRegistered')
      }.should.raise LoadError
      Lack::Handler.get('UnregisteredLongOne').should.equal Lack::Handler::UnregisteredLongOne
    ensure
      $LOAD_PATH.delete File.expand_path('../unregistered_handler', __FILE__)
    end
  end

  should "allow autoloaded handlers to be registered properly while being loaded" do
    path = File.expand_path('../registering_handler', __FILE__)
    begin
      $LOAD_PATH.push path
      Lack::Handler.get('registering_myself').should.equal Lack::Handler::RegisteringMyself
    ensure
      $LOAD_PATH.delete path
    end
  end
end
