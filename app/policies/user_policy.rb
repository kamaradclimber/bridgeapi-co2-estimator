class UserPolicy < ApplicationPolicy
  attr_reader :user_acting, :acted_user

  # @param user_acting [String] the username of the user acting
  def initialize(user_acting, acted_user)
    super
    @user_acting = user_acting
    @acted_user = acted_user
  end

  def index?
    admin?
  end

  def update?
    owner? || admin?
  end

  alias create? update?
  alias show? update?
  alias destroy? update?
  alias connect_bridgeapi_item? update?

  private

  def admin?
    (user_acting.username == ENV['SUPERADMIN_USERNAME']).tap do |is_admin|
      if is_admin
        puts "🦸 #{user_acting} is using superpowers to bypass authorization"
        user_acting.flash('You are using admin 🦸powers')
      end
    end
  end

  def owner?
    user_acting.username == acted_user.username
  end
end
