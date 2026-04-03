defmodule Indrajaal.Deployment.ImageBuilder do
  @moduledoc """
  ACE Image Builder (Library Module)

  Responsible for building all container images defined in the configuration.
  """

  require Logger
  alias Indrajaal.Deployment.Config

  def build_all do
    Logger.info("🏗️  STARTING ACE IMAGE REBUILD")

    build_base_image()
    build_app_image()

    Logger.info("✅ ALL IMAGES BUILT SUCCESSFULLY")
    :ok
  end

  defp build_base_image do
    Logger.info("📦 BUILDING BASE IMAGE: localhost/sopv51-base:latest")

    cmd = "podman"
    args = ["build", "-t", "localhost/sopv51-base:latest", "-f", "Dockerfile.sopv51-base", "."]
    execute_build(cmd, args)
  end

  defp build_app_image do
    containers = Config.containers(:prod)
    app_config = containers |> Enum.find(&(&1.service_name == "indrajaal-app"))
    image_tag = "localhost/#{app_config.image_name}:#{app_config.image_tag}"

    Logger.info("📦 BUILDING APP IMAGE: #{image_tag}")

    cmd = "podman"
    args = ["build", "-t", image_tag, "-f", "Dockerfile.sopv51-app", "."]
    execute_build(cmd, args)
  end

  defp execute_build(cmd, args) do
    Logger.info("Executing: #{cmd} #{Enum.join(args, " ")}")

    # We stream to IO so the user sees progress, but we catch errors
    case System.cmd(cmd, args, into: IO.stream(:stdio, :line)) do
      {_, 0} ->
        Logger.info("Build successful.")
        :ok

      {_, code} ->
        raise "Build failed with exit code #{code}"
    end
  end
end
