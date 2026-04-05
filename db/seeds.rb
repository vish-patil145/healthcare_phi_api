# db/seeds.rb

puts "🌱 Seeding Users..."

users = [
  {
    email: "admin@hospital.com",
    password: "password123",
    role: :admin
  },
  {
    email: "doctor@hospital.com",
    password: "password123",
    role: :doctor
  },
  {
    email: "nurse@hospital.com",
    password: "password123",
    role: :nurse
  },
  {
    email: "lab@hospital.com",
    password: "password123",
    role: :lab_technician
  }
]

users.each do |user_data|
  user = User.find_or_initialize_by(email: user_data[:email])
  user.password = user_data[:password]
  user.role = user_data[:role]
  user.save!
end

puts "✅ Users seeded successfully!"

# ---------------------------------------------------------------------------

puts "🌱 Seeding Patients..."

patients = [
  { name: "Aarav Sharma",  age: 34, gender: "male" },
  { name: "Priya Patel",   age: 28, gender: "female" },
  { name: "Rohit Mehta",   age: 45, gender: "male" },
  { name: "Sneha Iyer",    age: 31, gender: "female" },
  { name: "Vikram Singh",  age: 52, gender: "male" },
  { name: "Ananya Gupta",  age: 24, gender: "female" },
  { name: "Manish Joshi",  age: 38, gender: "male" },
  { name: "Kavya Nair",    age: 29, gender: "female" },
  { name: "Arjun Reddy",   age: 41, gender: "male" },
  { name: "Deepika Verma", age: 36, gender: "female" }
]

patients.each do |attrs|
  Patient.find_or_create_by!(name: attrs[:name]) do |p|
    p.age    = attrs[:age]
    p.gender = attrs[:gender]
  end
end

puts "✅ #{Patient.count} patients seeded"

# ---------------------------------------------------------------------------

puts "🌱 Seeding PHI Records..."

admin = User.find_by!(email: "admin@hospital.com")

phi_seed_data = [
  {
    patient_name: "Aarav Sharma",
    record_type:  "general",
    status:       "completed",
    encrypted_data: {
      diagnosis:    "Type 2 Diabetes",
      symptoms:     [ "fatigue", "excessive thirst", "frequent urination" ],
      medications:  [ { name: "Metformin", dosage: "500mg" } ],
      doctor_notes: "Monitor blood sugar weekly. Needs diet control.",
      lab_results:  { glucose: "180 mg/dL", HbA1c: "7.8%" }
    }
  },
  {
    patient_name: "Priya Patel",
    record_type:  "lab",
    status:       "completed",
    encrypted_data: {
      diagnosis:    "Iron Deficiency Anemia",
      symptoms:     [ "fatigue", "pallor", "shortness of breath" ],
      medications:  [ { name: "Ferrous Sulfate", dosage: "325mg" } ],
      doctor_notes: "Repeat CBC in 6 weeks.",
      lab_results:  { hemoglobin: "9.2 g/dL", ferritin: "6 ng/mL" }
    }
  },
  {
    patient_name: "Rohit Mehta",
    record_type:  "general",
    status:       "completed",
    encrypted_data: {
      diagnosis:    "Hypertension",
      symptoms:     [ "headache", "dizziness", "blurred vision" ],
      medications:  [
        { name: "Lisinopril", dosage: "10mg" },
        { name: "Amlodipine", dosage: "5mg" }
      ],
      doctor_notes: "BP target < 130/80. Monitor BP daily.",
      lab_results:  { systolic: "148 mmHg", diastolic: "94 mmHg" }
    }
  },
  {
    patient_name: "Sneha Iyer",
    record_type:  "general",
    status:       "pending",
    encrypted_data: {
      diagnosis:    "Hypothyroidism",
      symptoms:     [ "weight gain", "fatigue", "cold intolerance" ],
      medications:  [ { name: "Levothyroxine", dosage: "50mcg" } ],
      doctor_notes: "TSH recheck in 8 weeks.",
      lab_results:  { TSH: "6.8 mIU/L", T4: "0.7 ng/dL" }
    }
  },
  {
    patient_name: "Vikram Singh",
    record_type:  "general",
    status:       "processing",
    encrypted_data: {
      diagnosis:    "Chronic Kidney Disease Stage 3",
      symptoms:     [ "swelling", "fatigue", "nausea", "decreased urine output" ],
      medications:  [
        { name: "Furosemide", dosage: "40mg" },
        { name: "Sodium Bicarbonate", dosage: "650mg" }
      ],
      doctor_notes: "Restrict fluid and protein intake. Nephrology referral placed.",
      lab_results:  { creatinine: "2.3 mg/dL", eGFR: "38 mL/min", BUN: "28 mg/dL" }
    }
  },
  {
    patient_name: "Ananya Gupta",
    record_type:  "lab",
    status:       "completed",
    encrypted_data: {
      diagnosis:    "Vitamin D Deficiency",
      symptoms:     [ "bone pain", "muscle weakness", "fatigue" ],
      medications:  [ { name: "Cholecalciferol", dosage: "60000 IU weekly" } ],
      doctor_notes: "Recheck 25-OH Vitamin D after 8 weeks of supplementation.",
      lab_results:  { "25-OH Vitamin D": "11 ng/mL", calcium: "8.6 mg/dL" }
    }
  },
  {
    patient_name: "Manish Joshi",
    record_type:  "general",
    status:       "failed",
    encrypted_data: {
      diagnosis:    "Atrial Fibrillation",
      symptoms:     [ "palpitations", "shortness of breath", "chest discomfort" ],
      medications:  [
        { name: "Warfarin", dosage: "5mg" },
        { name: "Metoprolol", dosage: "25mg" }
      ],
      doctor_notes: "INR check required. Cardiology follow-up scheduled.",
      lab_results:  { INR: "2.8", heart_rate: "98 bpm (irregular)" }
    }
  },
  {
    patient_name: "Kavya Nair",
    record_type:  "lab",
    status:       "pending",
    encrypted_data: {
      diagnosis:    "Polycystic Ovary Syndrome",
      symptoms:     [ "irregular periods", "acne", "weight gain" ],
      medications:  [
        { name: "Metformin", dosage: "500mg" },
        { name: "Spironolactone", dosage: "50mg" }
      ],
      doctor_notes: "Lifestyle modification advised. Endocrine panel ordered.",
      lab_results:  { LH: "12 mIU/mL", FSH: "5 mIU/mL", testosterone: "68 ng/dL" }
    }
  },
  {
    patient_name: "Arjun Reddy",
    record_type:  "general",
    status:       "completed",
    encrypted_data: {
      diagnosis:    "Gastroesophageal Reflux Disease",
      symptoms:     [ "heartburn", "regurgitation", "chest pain" ],
      medications:  [ { name: "Omeprazole", dosage: "20mg" } ],
      doctor_notes: "Avoid spicy food and late meals. Elevate head of bed.",
      lab_results:  { H_pylori_test: "Negative" }
    }
  },
  {
    patient_name: "Deepika Verma",
    record_type:  "general",
    status:       "processing",
    encrypted_data: {
      diagnosis:    "Rheumatoid Arthritis",
      symptoms:     [ "joint pain", "morning stiffness", "swelling" ],
      medications:  [
        { name: "Methotrexate", dosage: "15mg weekly" },
        { name: "Folic Acid", dosage: "1mg" }
      ],
      doctor_notes: "Monitor LFTs monthly. Rheumatology follow-up in 4 weeks.",
      lab_results:  { RF: "Positive", CRP: "18 mg/L", ESR: "42 mm/hr" }
    }
  }
]

phi_seed_data.each do |attrs|
  patient = Patient.find_by!(name: attrs[:patient_name])

  record = PhiRecord.find_or_initialize_by(
    patient:     patient,
    record_type: attrs[:record_type],
    status:      attrs[:status]
  )

  if record.new_record?
    record.encrypted_data  = attrs[:encrypted_data]
    record.created_by = admin
    record.request_id = SecureRandom.uuid
    record.save!
  end
end

puts "✅ #{PhiRecord.count} PHI records seeded"
