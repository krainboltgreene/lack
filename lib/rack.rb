# Copyright (C) 2007, 2008, 2009, 2010 Christian Neukirchen <purl.org/net/chneukirchen>
#
# Lack is freely distributable under the terms of an MIT-style license.
# See COPYING or http://www.opensource.org/licenses/mit-license.php.

# The Lack main module, serving as a namespace for all core Lack
# modules and classes.
require "optparse"
require "fileutils"
require "set"
require "tempfile"
require "rack/multipart"
require "time"
require "uri/common"

module Lack
  require_relative "rack/version"
  require_relative "rack/body_proxy"
  require_relative "rack/builder"
  require_relative "rack/handler"
  require_relative "rack/mime"
  require_relative "rack/request"
  require_relative "rack/response"
  require_relative "rack/server"
  require_relative "rack/utils"
end
