IO.puts("--- Testing all users ---")
for username <- ["admin", "phc", "cardio", "elig", "ems"] do
  result = Stemi.Accounts.authenticate(username, "123123")
  IO.puts("#{username}: #{inspect(result)}")
end
