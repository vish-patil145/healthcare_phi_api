# app/policies/authorization.rb
class Authorization
  def self.authorize!(user, roles)
    raise "Forbidden" unless roles.include?(user.role)
  end
end
