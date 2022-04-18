require 'bridgeapi/client'

class UsersController < ApplicationController
  def index
    @users = User.all
  end

  def me
    # we should detect current user here (or at least redirect to the correct "show" invocation)
  end

  def show
    @user = User.find(params[:id])
  end

  def destroy
    @user = User.find(params[:id])

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
    new_user = client.create_user(params[:user][:username])
    @user = User.new(username: params[:user][:username], bridgeapi_password: new_user['password'], bridgeapi_uuid: new_user['uuid'])

    if @user.save
      redirect_to(@user)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def connect_bridgeapi_item
    # FIXME: [security] we should validate we are allowed to create a new account
    user = User.find(params[:id])
    connect_response = user.connect_new_bridgeapi_item
    redirect_to(connect_response['redirect_url'], status: :see_other, allow_other_host: true)
  end
end
