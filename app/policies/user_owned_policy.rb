class UserOwnedPolicy < ApplicationPolicy
  attr_reader :user_acting, :record

  # @param user_acting [PunditControllerContext]
  # @param record [#user] a record which has access to a User object through user method
  def initialize(user_acting, record)
    super
    @user_acting = user_acting
    @record = record
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

  def method_missing(name, *args, &block)
    if name.to_s =~ /\?$/
      # we always answer with the same permission level than update?
      update?
    else
      super
    end
  end

  def respond_to_missing?(name, include_private = false)
    name.to_s =~ /\?$/ || super
  end

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
    user_acting.username == record.user.username
  end
end
