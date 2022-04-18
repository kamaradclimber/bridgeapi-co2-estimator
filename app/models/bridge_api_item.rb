class BridgeApiItem < ApplicationRecord
  belongs_to :user
  has_many :bridge_api_accounts, dependent: :destroy
end
