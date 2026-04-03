defmodule Indrajaal.Integration.OAuthTest do
  use ExUnit.Case, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.Integration.OAuth

  describe "OAuth implementation" do
    test "authorize_url/2 returns a valid URL for supported provider" do
      assert {:ok, url} = OAuth.authorize_url(:google, redirect_uri: "http://localhost/callback")
      assert String.contains?(url, "accounts.google.com")
      assert String.contains?(url, "client_id=")
    end

    test "authorize_url/2 returns error for unsupported provider" do
      assert {:error, :unsupported_provider} = OAuth.authorize_url(:unknown)
    end

    test "exchange_token/3 returns tokens" do
      assert {:ok, tokens} =
               OAuth.exchange_token(:google, "auth_code", "http://localhost/callback")

      assert Map.has_key?(tokens, :access_token)
    end
  end

  property "handles arbitrary provider names safely" do
    forall provider <- PC.atom() do
      case OAuth.authorize_url(provider, redirect_uri: "http://test") do
        {:ok, _url} -> provider == :google
        {:error, :unsupported_provider} -> provider != :google
      end
    end
  end
end
