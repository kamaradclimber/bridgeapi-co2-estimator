require 'bridgeapi/client'

class BridgeApiAccessToken < ApplicationRecord
  belongs_to :user

  def refreshed_value
    refresh! if expires_at < Time.new
    value
  end

  def refresh!
    puts "Refreshing access token for #{username}"
    client = BridgeApi::Client.new
    result = client.authenticate(username, password)
    self.value = result['access_token']
    self.expires_at = Time.parse(result['expires_at'])
  end
end
