class TransactionsController < ApplicationController
  def show
    @transaction = Transaction.find(params[:id])
    authorize(@transaction, policy_class: UserOwnedPolicy)
  end

  def update
    transaction = Transaction.find(params[:id])
    authorize(transaction, policy_class: UserOwnedPolicy)

    permitted = params.require(:transaction).permit(:category_id, :description, :date)
    if permitted.permitted?
      transaction.update!(permitted)
      transaction.refresh_subclass
      redirect_back_or_to(transaction.bridge_api_account.user, allow_other_host: false, notice: 'Updated!')
    else
      # FIXME: I'm not sure if this is ever called because the code raises when defining the permitted variable
      redirect_back_or_to(transaction.bridge_api_account.user, allow_other_host: false, alert: 'Missing parameter for the update')
    end
  end

  def set_pristine
    transaction = Transaction.find(params[:id])
    transaction = transaction.pristine!
    redirect_back_or_to(transaction.bridge_api_account.user, allow_other_host: false, notice: 'Transaction set back to pristine condition')
  end
end
