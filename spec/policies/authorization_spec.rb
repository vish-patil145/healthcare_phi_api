# spec/policies/authorization_spec.rb
RSpec.describe Authorization do
  describe ".authorize!" do
    let(:user) { instance_double("User", role: "doctor") }

    context "when user role is included in allowed roles" do
      it "does not raise an error for an exact role match" do
        expect { Authorization.authorize!(user, [ "doctor" ]) }.not_to raise_error
      end

      it "does not raise an error when role is one of many allowed roles" do
        expect { Authorization.authorize!(user, [ "admin", "doctor", "nurse" ]) }.not_to raise_error
      end
    end

    context "when user role is not included in allowed roles" do
      it "raises a Forbidden error" do
        expect { Authorization.authorize!(user, [ "admin" ]) }.to raise_error("Forbidden")
      end

      it "raises a Forbidden error when allowed roles list is empty" do
        expect { Authorization.authorize!(user, []) }.to raise_error("Forbidden")
      end

      it "raises a Forbidden error for a completely different role set" do
        expect { Authorization.authorize!(user, [ "nurse", "lab_technician" ]) }.to raise_error("Forbidden")
      end
    end

    context "with different roles defined in the system" do
      %w[admin doctor nurse lab_technician].each do |role|
        it "allows access when user has role '#{role}' and it is permitted" do
          user = instance_double("User", role: role)
          expect { Authorization.authorize!(user, [ role ]) }.not_to raise_error
        end

        it "denies access when user has role '#{role}' and it is not permitted" do
          other_roles = %w[admin doctor nurse lab_technician] - [ role ]
          user = instance_double("User", role: role)
          expect { Authorization.authorize!(user, other_roles) }.to raise_error("Forbidden")
        end
      end
    end

    context "edge cases" do
      it "is case-sensitive — 'Doctor' does not match 'doctor'" do
        user = instance_double("User", role: "Doctor")
        expect { Authorization.authorize!(user, [ "doctor" ]) }.to raise_error("Forbidden")
      end

      it "does not allow nil role to match any permitted role" do
        user = instance_double("User", role: nil)
        expect { Authorization.authorize!(user, [ "doctor" ]) }.to raise_error("Forbidden")
      end

      it "does not allow nil role to match a nil entry in the roles list" do
        user = instance_double("User", role: nil)
        expect { Authorization.authorize!(user, [ nil ]) }.not_to raise_error
      end
    end
  end
end
