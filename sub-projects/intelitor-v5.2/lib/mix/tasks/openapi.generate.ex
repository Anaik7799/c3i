defmodule Mix.Tasks.Openapi.Generate do
  @moduledoc """
  Generates OpenAPI 3.1 specification for the Mobile API.

  ## Usage

      mix openapi.generate
      mix openapi.generate --format yaml
      mix openapi.generate --output docs / openapi.json
      mix openapi.generate --validate

  ## Options

    * `--format` - Output format: json (default) or yaml
    * `--output` - Output file path (default: priv / static / openapi.json)
    * `--validate` - Validate the specification after generation
    * `--serve` - Start a web server to view the documentation

  Agent: Supervisor manages OpenAPI generation
  SOPv5.1 Complianc,e: ✅
  """

  use Mix.Task

  alias Indrajaal.OpenAPI.{Specification, Validator}

  @shortdoc "Generates OpenAPI 3.1 specification"

  @impl Mix.Task
  @spec run(any()) :: any()
  def run(args) do
    {opts, _} =
      OptionParser.parse!(args,
        strict: [
          format: :string,
          output: :string,
          validate: :boolean,
          serve: :boolean
        ]
      )

    # Start the application
    Mix.Task.run("app.start")

    IO.puts("[LAUNCH] Generating OpenAPI 3.1 specification...")

    format = Keyword.get(opts, :format, "json")
    output = Keyword.get(opts, :output)
    validate = Keyword.get(opts, :validate, false)
    serve = Keyword.get(opts, :serve, false)

    # Generate specification
    try do
      # Export functions always return {:ok, path}, no error case possible
      {:ok, path} =
        case format do
          "yaml" ->
            path = output || "priv / static / openapi.yaml"
            Specification.export_to_yaml(path)

          _ ->
            path = output || "priv / static / openapi.json"
            Specification.export_to_file(path)
        end

      IO.puts("OpenAPI specification generated at: #{path}")

      # Validate if __requested
      if validate do
        IO.puts("Validating specification...")

        case Validator.validate() do
          {:ok, message} ->
            IO.puts("#{message}")

            # Generate validation report
            report = Validator.generate_report()
            IO.puts("\n[STATS] Validation Report:")
            IO.puts("  Version: #{report.version}")
            IO.puts("  Title: #{report.info.title} v#{report.info.version}")
            IO.puts("  Statistics:")
            IO.puts("    - Paths: #{report.statistics.paths}")
            IO.puts("    - Operations: #{report.statistics.operations}")
            IO.puts("    - Schemas: #{report.statistics.schemas}")
            IO.puts("    - Examples: #{report.statistics.examples}")
            IO.puts("  Documentation Coverage: #{report.coverage}%")

          {:error, reason} ->
            IO.puts("Validation failed: #{reason}")
            exit({:shutdown, 1})
        end
      end

      # Serve documentation if __requested
      if serve do
        serve_documentation(path)
      end
    rescue
      e ->
        IO.puts("Error generating specification: #{inspect(e)}")
        IO.puts(Exception.format_stacktrace())
        exit({:shutdown, 1})
    end
  end

  @spec serve_documentation(term()) :: term()
  defp serve_documentation(specpath) do
    IO.puts("\nStarting documentation server...")

    # Generate HTML documentation page
    html_path = Path.join(Path.dirname(specpath), "api - docs.html")
    html_content = generate_swagger_ui_html(specpath)
    File.write!(html_path, html_content)

    port = 8080
    IO.puts("📚 API documentation available at: http://localhost:#{port}/api - docs.html")
    IO.puts("📄 OpenAPI spec available at: http://localhost:#{port}/#{Path.basename(specpath)}")
    IO.puts("\nPress Ctrl + C to stop the server...")

    # Start simple HTTP server
    {:ok, _} = :inets.start()

    {:ok, _} =
      :httpd.start(
        port: port,
        server_root: ~c".",
        document_root: to_charlist(Path.dirname(specpath)),
        server_name: ~c"openapi - docs",
        directory_index: [~c"api - docs.html"]
      )

    # Keep the process alive
    Process.sleep(:infinity)
  end

  @spec generate_swagger_ui_html(term()) :: term()
  defp generate_swagger_ui_html(specpath) do
    spec_filename = Path.basename(specpath)

    """
    <!DOCTYPE html>
    <html _lang ="en">
    <head>
      <meta _charset ="UTF - 8">
      <title > Indrajaal Mobile API Documentation</title>
      <link _rel ="stylesheet" _type ="text / css" _href ="https://cdn.jsdelivr.net / npm / swagger - ui - dist@5 / swagger - ui.css" />
      <style>
        html { box - sizing: border - box; overflow: -moz - scrollbars - vertical; overflow - y: scroll; }
        *, *:before, *:after { box - sizing: inherit; }
        body { margin:0; background: #fafafa; }
      </style>
    </head>
    <body>
      <div _id ="swagger - ui"></div>
      <script src="https://cdn.jsdelivr.net / npm / swagger - ui - dist@5 / swagger - ui - bundle.js"></script>
      <script src="https://cdn.jsdelivr.net / npm / swagger - ui - dist@5 / swagger - ui - standalone - preset.js"></script>
      <script>
        window._onload = function() {
          window.ui = SwaggerUIBundle({
            url: "./#{spec_filename}",
            dom_id: '#swagger - ui',
            deepLinking: true,
            presets: [
              SwaggerUIBundle.presets.apis,
              SwaggerUIStandalonePreset
            ],
            plugins: [
              SwaggerUIBundle.plugins.DownloadUrl
            ],
            layout: "StandaloneLayout",
            validatorUrl: null,
            tryItOutEnabled: true,
            supportedSubmitMethods: ['get', 'post', 'put', 'delete', 'patch'],
            onComplete: function() {
              console.log("Swagger UI loaded successfully");
            }
          });
        };
      </script>
    </body>
    </html>
    """
  end
end
