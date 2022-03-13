require 'test_helper'

class BridgeApiAccountControllerTest < ActionDispatch::IntegrationTest
  test 'should get refresh' do
    get bridge_api_account_refresh_url
    assert_response :success
  end
end
