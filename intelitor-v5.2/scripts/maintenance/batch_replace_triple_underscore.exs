defmodule BatchReplacer do
  def run(batch_size) do
    # Find files containing at least triple underscores, excluding this script
    script_name = Path.basename(__ENV__.file)
    {output, 0} = System.cmd("grep", ["-rl", "___", "lib/", "scripts/", "test/"])
    
    files = 
      output
      |> String.split("\n", trim: true)
      |> Enum.reject(fn f -> String.contains?(f, script_name) end)
      |> Enum.take(batch_size)

    if Enum.empty?(files) do
      IO.puts("✅ No files found containing triple underscores.")
    else
      IO.puts("🔄 Processing batch of #{length(files)} files...")
      
      Enum.each(files, fn file ->
        content = File.read!(file)
        
        # Use Regex.replace with a function for maximum safety and control
        # We explicitly match 3 or more underscores
        new_content = Regex.replace(~r/(___+)([A-Z0-9_]+)?/, content, fn _full_match, _underscores, suffix ->
          cond do
            # If it's a special macro pattern like ___MODULE__ or ___DIR__
            suffix in ["MODULE", "DIR", "CALLER", "ENV", "STACKTRACE"] ->
              "__" <> suffix
            
            # If it's something else like ___data or ___state
            true ->
              "_" <> (suffix || "")
          end
        end)
        
        if new_content != content do
          File.write!(file, new_content)
          IO.puts("  Fixed: #{file}")
        else
          IO.puts("  Skipped (no change): #{file}")
        end
      end)
      
      IO.puts("✨ Batch complete.")
    end
  end
end

BatchReplacer.run(50)