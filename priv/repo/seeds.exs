# Recreate all users + clear cases
alias Stemi.{Repo, Accounts}
alias Stemi.Accounts.User
alias Stemi.Cases.Case
alias Stemi.Hospitals.Hospital
import Ecto.Query

# Delete cases first (FK: cases.phc_user_id → users is NOT NULL, no cascade)
Repo.delete_all(Case)
IO.puts("Deleted all cases.")

# Delete ALL users (including admin) to start clean
Repo.delete_all(User)
IO.puts("Deleted all users.")

# Create fresh users with simple usernames
users = [
  %{username: "admin", password: "123123", full_name: "System Admin", role: "admin", is_active: true},
  %{username: "erc", password: "123123", full_name: "Dr. Sara (ER Consultant)", role: "er_consultant", is_active: true},
  %{username: "cardio", password: "123123", full_name: "Dr. Khalid (Cardiology)", role: "cardiologist", is_active: true},
  %{username: "elig", password: "123123", full_name: "Noura (Eligibility)", role: "eligibility", is_active: true},
  %{username: "ems", password: "123123", full_name: "Fahad (EMS)", role: "ems", is_active: true}
]

for attrs <- users do
  {:ok, user} = Accounts.create_user(attrs)
  IO.puts("Created: #{user.username} / 123123 (#{user.role})")
end

# PHC users — each tied to a different Primary Health Care facility
# Hospitals must already be seeded (mix run priv/repo/seed_hospitals.exs)
phc_entries = [
  {"PHC One",   "PHC - Al-Khaleej 1",          "phc_one"},
  {"PHC Two",   "PHC - Al Yasmin",              "phc_two"},
  {"PHC Three", "PHC - Western Al-Yarmouk",     "phc_three"},
  {"PHC Four",  "PHC - Alnuzha",                "phc_four"},
  {"PHC Five",  "PHC - Al-Nadwah",              "phc_five"},
  {"PHC Six",   "PHC - Al-Izdihar",             "phc_six"}
]

for {full_name, hospital_name, username} <- phc_entries do
  hospital = Repo.get_by(Hospital, name: hospital_name)
  base = %{username: username, password: "123123", full_name: full_name, role: "phc", is_active: true}
  attrs = if hospital, do: Map.put(base, :hospital_id, hospital.id), else: base
  {:ok, user} = Accounts.create_user(attrs)
  facility = (hospital && hospital.name) || "(hospital not yet seeded)"
  IO.puts("Created: #{user.username} / 123123 (phc) — #{facility}")
end
