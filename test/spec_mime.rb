require 'rack/mime'

describe Lack::Mime do

  it "should return the fallback mime-type for files with no extension" do
    fallback = 'image/jpg'
    Lack::Mime.mime_type(File.extname('no_ext'), fallback).should.equal fallback
  end

  it "should always return 'application/octet-stream' for unknown file extensions" do
    unknown_ext = File.extname('unknown_ext.abcdefg')
    Lack::Mime.mime_type(unknown_ext).should.equal 'application/octet-stream'
  end

  it "should return the mime-type for a given extension" do
    # sanity check. it would be infeasible test every single mime-type.
    Lack::Mime.mime_type(File.extname('image.jpg')).should.equal 'image/jpeg'
  end

  it "should support null fallbacks" do
    Lack::Mime.mime_type('.nothing', nil).should.equal nil
  end

  it "should match exact mimes" do
    Lack::Mime.match?('text/html', 'text/html').should.equal true
    Lack::Mime.match?('text/html', 'text/meme').should.equal false
    Lack::Mime.match?('text', 'text').should.equal true
    Lack::Mime.match?('text', 'binary').should.equal false
  end

  it "should match class wildcard mimes" do
    Lack::Mime.match?('text/html', 'text/*').should.equal true
    Lack::Mime.match?('text/plain', 'text/*').should.equal true
    Lack::Mime.match?('application/json', 'text/*').should.equal false
    Lack::Mime.match?('text/html', 'text').should.equal true
  end

  it "should match full wildcards" do
    Lack::Mime.match?('text/html', '*').should.equal true
    Lack::Mime.match?('text/plain', '*').should.equal true
    Lack::Mime.match?('text/html', '*/*').should.equal true
    Lack::Mime.match?('text/plain', '*/*').should.equal true
  end

  it "should match type wildcard mimes" do
    Lack::Mime.match?('text/html', '*/html').should.equal true
    Lack::Mime.match?('text/plain', '*/plain').should.equal true
  end

end

