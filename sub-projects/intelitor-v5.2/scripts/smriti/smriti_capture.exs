#!/usr/bin/env elixir

# smriti-capture: CLI for SMRITI Sensory Ingestion
# Usage: ./smriti_capture.exs "https://example.com"
#        ./smriti_capture.exs --text "My random thought"

Mix.install([{:req, "~> 0.4"}])

defmodule SmritiCapture do
  require Logger

  def main(args) do
    {opts, argv, _} = OptionParser.parse(args, switches: [text: :string])

    case {opts, argv} do
      {[text: text], _} -> capture_text(text)
      {_, [url]} -> capture_url(url)
      _ -> usage()
    end
  end

  defp capture_text(text) do
    IO.puts("🧠 Capturing thought: #{text}")
    # Call SMRITI API (Mocked for now)
    # Req.post("http://localhost:4000/api/capture", json: %{content: text, type: "text"})
    IO.puts("✅ Captured (Simulated)")
  end

  defp capture_url(url) do
    IO.puts("🌐 Capturing URL: #{url}")
    # Req.post("http://localhost:4000/api/capture", json: %{url: url, type: "web"})
    IO.puts("✅ Captured (Simulated)")
  end

  defp usage do
    IO.puts """
    Usage:
      smriti_capture.exs <URL>
      smriti_capture.exs --text "Your thought"
    """
  end
end

SmritiCapture.main(System.argv())
