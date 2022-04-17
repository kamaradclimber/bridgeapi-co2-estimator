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
      redirect_to(transaction, notice: 'Updated!')
    else
      # FIXME: I'm not sure if this is ever called because the code raises when defining the permitted variable
      redirect_to(transaction, alert: 'Missing parameters for the update')
    end
  end
end
