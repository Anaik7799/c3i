#!/usr/bin/env elixir

defmodule ASSPEnforcer do
  @lock_header "<!-- LOCKED BY ASSP: DO NOT EDIT MANUALLY. USE mix todo COMMANDS ONLY. -->"
  @todolist "PROJECT_TODOLIST.md"

  def verify do
    IO.puts("🔒 Verifying ASSP Lock on #{@todolist}...")
    
    if File.exists?(@todolist) do
      first_line = 
        File.open!(@todolist, [:read], fn file -> 
          IO.read(file, :line) 
        end)
        |> String.trim()

      if first_line == @lock_header do
        IO.puts("✅ ASSP Lock Active: File is protected.")
        System.halt(0)
      else
        IO.puts("❌ ASSP VIOLATION: Lock header missing!")
        IO.puts("Expected: #{@lock_header}")
        IO.puts("Found:    #{first_line}")
        System.halt(1)
      end
    else
      IO.puts("❌ Error: #{@todolist} not found!")
      System.halt(1)
    end
  end
end

ASSPEnforcer.verify()
