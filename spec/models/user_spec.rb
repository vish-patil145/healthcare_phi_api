# spec/models/user_spec.rb
require 'rails_helper'

RSpec.describe User, type: :model do
  subject { build(:user) }

  describe 'validations' do
    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_uniqueness_of(:email).case_insensitive }
    it { is_expected.to allow_value("test@example.com").for(:email) }
    it { is_expected.not_to allow_value("invalid_email").for(:email) }
    it { is_expected.not_to allow_value("test@").for(:email) }
    it { is_expected.not_to allow_value("test.com").for(:email) }

    it 'has valid roles' do
      expect(User.roles.keys).to match_array(%w[admin doctor nurse lab_technician])
    end

    it 'is invalid with an unknown role' do
      expect { build(:user, role: :hacker) }.to raise_error(ArgumentError)
    end

    it 'is valid with a known role' do
      %i[admin doctor nurse lab_technician].each do |role|
        expect(build(:user, role: role)).to be_valid
      end
    end
  end

  describe 'associations' do
    it { is_expected.to have_many(:phi_records).with_foreign_key(:created_by_id) }
  end

  describe 'authentication' do
    let(:user) { create(:user, password: 'password123') }

    it 'authenticates with correct password' do
      expect(user.authenticate('password123')).to eq(user)
    end

    it 'fails with wrong password' do
      expect(user.authenticate('wrongpassword')).to be_falsey
    end
  end
end
