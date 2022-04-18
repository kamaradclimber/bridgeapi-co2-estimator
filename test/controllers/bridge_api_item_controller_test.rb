require 'test_helper'

class BridgeApiItemControllerTest < ActionDispatch::IntegrationTest
  test 'should get destroy' do
    get bridge_api_item_destroy_url
    assert_response :success
  end
end
