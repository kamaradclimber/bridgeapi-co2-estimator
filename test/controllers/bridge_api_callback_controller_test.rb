require 'test_helper'

class BridgeApiCallbackControllerTest < ActionDispatch::IntegrationTest
  test 'should get item_refresh' do
    get bridge_api_callback_item_refresh_url
    assert_response :success
  end
end
