defmodule TodoUpdater do
  def run do
    file_path = "PROJECT_TODOLIST.md"
    content = File.read!(file_path)

    ids = [
      "22.2.1.2.1", "22.2.1.2.2",
      "22.2.2.2.1", "22.2.2.2.2",
      "22.2.3.1.1", "22.2.3.1.2",
      "22.2.3.2.1", "22.2.3.2.2",
      "22.2.1", "22.2.2", "22.2.3", "22.2"
    ]

    new_content = Enum.reduce(ids, content, fn id, acc ->
      regex = ~r/(#{Regex.escape(id)} - .+?\n\*\*Status\*\*: )pending/
      Regex.replace(regex, acc, "\\1completed")
    end)

    File.write!(file_path, new_content)
    IO.puts("Updated #{length(ids)} tasks to completed.")
  end
end

TodoUpdater.run()