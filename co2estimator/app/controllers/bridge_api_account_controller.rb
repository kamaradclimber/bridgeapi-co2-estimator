class BridgeApiAccountController < ApplicationController
  def refresh
    @account = BridgeApiAccount.find(params[:id])
    @account.refresh_transactions(Time.now.to_i * 1000)
  end
end
