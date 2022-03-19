class BridgeApiAccountController < ApplicationController
  def refresh
    @account = BridgeApiAccount.find(params[:id])
    @account.refresh_transactions(Time.now.to_i * 1000)
  end

  def scratch
    @account = BridgeApiAccount.find(params[:id])
    @account.transactions.each(&:delete)
    @account.last_successful_fetch = Time.at(0)
    @account.refresh_transactions(Time.now.to_i * 1000)
  end
end
