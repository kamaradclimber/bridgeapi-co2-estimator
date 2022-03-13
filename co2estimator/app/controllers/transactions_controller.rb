class TransactionsController < ApplicationController
  def index
    user_id = params['user_id']
    @user = User.find(user_id)
    @transactions = Transaction.where(user_id: @user.id)
  end

  def show
    @transaction = Transaction.find(params[:id])
  end
end
