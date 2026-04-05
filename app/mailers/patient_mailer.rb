# app/mailers/patient_mailer.rb
class PatientMailer < ApplicationMailer
  def registration_email(patient)
    @patient = patient
    mail(
      to:      @patient.email,
      subject: "Welcome to Our Hospital"
    )
  end
end
