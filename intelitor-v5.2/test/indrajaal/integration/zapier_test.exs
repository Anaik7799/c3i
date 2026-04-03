defmodule Indrajaal.Integration.ZapierTest do
  use ExUnit.Case, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]
  alias PropCheck.BasicTypes, as: PC

  alias Indrajaal.Integration.Zapier

  describe "Zapier implementation" do
    test "trigger_webhook/2 succeeds for valid URL" do
      url = "https://hooks.zapier.com/hooks/catch/12345/abcde"
      assert :ok = Zapier.trigger_webhook(url, %{event: "test"})
    end

    test "trigger_webhook/2 fails for invalid URL" do
      assert {:error, "Invalid Zapier Webhook URL"} =
               Zapier.trigger_webhook("http://example.com", %{})
    end
  end

  property "validates URL prefix strictly" do
    forall url <- PC.utf8() do
      result = Zapier.trigger_webhook(url, %{})

      if String.starts_with?(url, "https://hooks.zapier.com/") do
        result == :ok
      else
        result == {:error, "Invalid Zapier Webhook URL"}
      end
    end
  end
end
