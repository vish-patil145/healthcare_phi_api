# spec/support/jwt_test_helper.rb
module JwtTestHelper
  def auth_headers(user)
    token = JwtService.encode({ user_id: user.id })
    { "Authorization" => "Bearer #{token}" }
  end

  def admin_auth_headers
    user = FactoryBot.create(:user, role: :admin)
    auth_headers(user)
  end

  def doctor_auth_headers
    user = FactoryBot.create(:user, role: :doctor)
    auth_headers(user)
  end

  def nurse_auth_headers
    user = FactoryBot.create(:user, role: :nurse)
    auth_headers(user)
  end
end
