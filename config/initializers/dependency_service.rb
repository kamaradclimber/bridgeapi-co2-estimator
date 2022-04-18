require 'bridgeapi/dependencies'
require 'bridgeapi/client'

client = BridgeApi::Client.new
BridgeApi::Dependencies.setup(client)
