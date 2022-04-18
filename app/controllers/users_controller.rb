require 'bridgeapi/client'

class UsersController < ApplicationController
  def index
    authorize(User)
    @users = User.all
  end

  def me
    # we should detect current user here (or at least redirect to the correct "show" invocation)
    username = request.headers['HTTP_REMOTE_USER']
    user = User.find_by(username: username)
    if user
      redirect_to(action: :show, id: user.id)
    else
      redirect_to(new_user_path, notice: "You don't have a user at the moment")
    end
  end

  def show
    @user = User.find(params[:id])
    authorize(@user)
  end

  def destroy
    @user = User.find(params[:id])
    authorize(@user)

    client = BridgeApi::Dependencies.resolve(:client)
    # delete on bridgeapi
    client.delete_user(@user.bridgeapi_uuid, @user.bridgeapi_password)

    @user.destroy

    redirect_to(root_path, status: :see_other)
  end

  def new
    @user = User.new
  end

  def create
    client = BridgeApi::Dependencies.resolve(:client)
    email = "#{params[:user][:username]}@#{ENV['EXPOSED_HOST']}"
    authorize(User.new(username: params[:user][:username])) # we need to authorize before the call to bridgeapi
    new_user = client.create_user(email)
    @user = User.new(
      username: params[:user][:username],
      bridgeapi_password: new_user['password'],
      bridgeapi_uuid: new_user['uuid'],
      email: email
    )

    if @user.save
      redirect_to(@user)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def connect_bridgeapi_item
    # FIXME: [security] we should validate we are allowed to create a new account
    user = User.find(params[:id])
    authorize(user)
    connect_response = user.connect_new_bridgeapi_item
    redirect_to(connect_response['redirect_url'], status: :see_other, allow_other_host: true)
  end

  def current_user
    # we blindly trust the reverse proxy to set this correctly.
    # FIXME: we should probably find a way to validate the header has been set by the proxy
    PunditControllerContext.new(request.headers['HTTP_REMOTE_USER'], method(:flash))
  end
end
