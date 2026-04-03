defmodule IndrajaalWeb.Api.Mobile.Mixins.ConfigurationMixin do
  @moduledoc """
  Common configuration patterns for mobile API controllers.
  Reduces duplicate code in configuration endpoints.
  """

  defmacro __using__(_opts) do
    quote do
      import IndrajaalWeb.Api.Mobile.Mixins.ConfigurationMixin

      @doc "Standard configuration validation"
      def validate_configuration(params) do
        __required_fields = [:tenant_id, :user_id, :device_id]
        validate_required_configuration_fields(params, __required_fields)
      end

      @doc "Standard configuration response"
      def format_configuration_response(data) do
        %{
          configuration: data,
          version: Application.spec(:indrajaal, :vsn),
          updated_at: DateTime.utc_now()
        }
      end
    end
  end

  @spec validate_required_configuration_fields(term(), term()) :: term()
  def validate_required_configuration_fields(params, required_fields) do
    missing_fields =
      required_fields
      |> Enum.filter(fn field -> is_nil(params[field]) end)

    if Enum.empty?(missing_fields) do
      {:ok, params}
    else
      {:error, %{missing_fields: missing_fields}}
    end
  end
end
