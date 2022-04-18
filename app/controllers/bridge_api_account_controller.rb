class BridgeApiAccountController < ApplicationController
  def refresh
    @account = BridgeApiAccount.find(params[:id])
    authorize(@account, policy_class: UserOwnedPolicy)
    @account.refresh_transactions(Time.now.to_i * 1000)
    redirect_to(@account.bridge_api_item.user, notice: "Transactions updated for '#{@account.name}'!")
  end

  def scratch
    @account = BridgeApiAccount.find(params[:id])
    authorize(@account, policy_class: UserOwnedPolicy)
    @account.transactions.each(&:delete)
    @account.last_successful_fetch = Time.at(0)
    @account.refresh_transactions(Time.now.to_i * 1000)

    redirect_to(@account.bridge_api_item.user, notice: "Transactions synchronized from scratch for '#{@account.name}'!")
  end
end
