#!/usr/bin/env elixir

# EP014: Quick fix script for user.ex changeset syntax issues
content = File.read!("lib/indrajaal/accounts/user.ex")

# Fix the malformed patterns
fixed_content =
  content
  |> String.replace(
    ~r/changeset\s*\)\s*\|\>\s*Ash\.Changeset\.change_attribute/,
    "changeset\n        |> Ash.Changeset.change_attribute"
  )
  |> String.replace(
    ~r/\)\s*\|\>\s*Ash\.Changeset\.change_attribute/,
    "\n        |> Ash.Changeset.change_attribute"
  )
  |> String.replace(
    ~r/change_attribute\(:confirmed_at\)\s*\|\>\s*Ash\.Changeset\.change_attribute/,
    "change_attribute(:confirmed_at, DateTime.utc_now())\n        |> Ash.Changeset.change_attribute"
  )

File.write!("lib/indrajaal/accounts/user.ex", fixed_content)
IO.puts("Fixed user.ex syntax issues")
