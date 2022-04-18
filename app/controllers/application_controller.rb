class ApplicationController < ActionController::Base
  include Pundit::Authorization

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  private

  def user_not_authorized(_exception)
    flash[:error] = 'You are not allowed to perform this action'
    redirect_back(fallback_url: root_path)
  end

  # this method is conventionnaly used by Pundit gem to determine the first argument passed it Policy object constructor
  def current_user
    # we blindly trust the reverse proxy to set this correctly.
    # FIXME: we should probably find a way to validate the header has been set by the proxy
    PunditControllerContext.new(request.headers['HTTP_REMOTE_USER'], method(:flash))
  end
end
