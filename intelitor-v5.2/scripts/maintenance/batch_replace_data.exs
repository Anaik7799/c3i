defmodule BatchReplacer do
  def run(batch_size \\ 50) do
    # Find files containing "_data" in lib/ and scripts/
    {output, 0} = System.cmd("grep", ["-rl", "_data", "lib/", "scripts/", "test/"])
    
    files = 
      output
      |> String.split("\n", trim: true)
      |> Enum.take(batch_size)

    if Enum.empty?(files) do
      IO.puts("✅ No files found containing '_data'.")
    else
      IO.puts("🔄 Processing batch of #{length(files)} files...")
      
      Enum.each(files, fn file ->
        content = File.read!(file)
        # Safe replacement of _data with _data
        # This handles cases like:
        # historical_data -> historical_data
        # _data -> _data
        new_content = String.replace(content, "_data", "_data")
        
        File.write!(file, new_content)
        IO.puts("  Fixed: #{file}")
      end)
      
      IO.puts("✨ Batch complete.")
    end
  end
end

BatchReplacer.run(50)
