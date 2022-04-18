class ApplicationController < ActionController::Base
  include Pundit::Authorization

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  private

  def user_not_authorized(_exception)
    flash[:error] = 'You are not allowed to perform this action'
    redirect_back(fallback_url: root_path)
  end
end
