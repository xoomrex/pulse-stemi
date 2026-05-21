# Recreate all users
alias Stemi.{Repo, Accounts}
alias Stemi.Accounts.User
import Ecto.Query

# Delete ALL users (including admin) to start clean
Repo.delete_all(User)
IO.puts("Deleted all users.")

# Create fresh users with simple usernames
users = [
  %{username: "admin", password: "123123", full_name: "System Admin", role: "admin", is_active: true},
  %{username: "phc", password: "123123", full_name: "Dr. Ahmed (PHC)", role: "phc", is_active: true},
  %{username: "erc", password: "123123", full_name: "Dr. Sara (ER Consultant)", role: "er_consultant", is_active: true},
  %{username: "cardio", password: "123123", full_name: "Dr. Khalid (Cardiology)", role: "cardiologist", is_active: true},
  %{username: "elig", password: "123123", full_name: "Noura (Eligibility)", role: "eligibility", is_active: true},
  %{username: "ems", password: "123123", full_name: "Fahad (EMS)", role: "ems", is_active: true}
]

for attrs <- users do
  {:ok, user} = Accounts.create_user(attrs)
  IO.puts("Created: #{user.username} / 123123 (#{user.role})")
end
