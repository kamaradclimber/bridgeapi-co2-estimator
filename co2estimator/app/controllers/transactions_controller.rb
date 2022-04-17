class TransactionsController < ApplicationController
  def index
    user_id = params['user_id']
    @user = User.find(user_id)
    @transactions = Transaction.where(user_id: @user.id)
  end

  def show
    @transaction = Transaction.find(params[:id])
  end

  def update
    transaction = Transaction.find(params[:id])
    # FIXME: it is likely that we should filter:
    # - who can update this transaction
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
end
