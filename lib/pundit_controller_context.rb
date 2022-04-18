# this class serves two purpose:
# - access the username acting at the moment
# - access the controller context to be able to flash message
# it is supposed to be instanciated from the current_user method in a controller
class PunditControllerContext
  def initialize(username, flash_method)
    @flash_method = flash_method
    @username = username
  end
  attr_reader :username

  def flash(message)
    @flash_method.call.now[:alert] = message
  end
end
