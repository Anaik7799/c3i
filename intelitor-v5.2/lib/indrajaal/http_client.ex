defmodule HTTPClient do
  @moduledoc """
  HTTP client module stub.

  This module provides HTTP request functionality for external API integrations.
  Created as a stub to resolve UNDEFINED_MODULE warnings during Phase 1.

  Functions to be implemented in Phase 2:
  - call/3
  - get/2
  - post/3
  - put/3
  - delete/2
  """

  @doc """
  Make an HTTP request.

  ## Parameters
  - method: HTTP method (:get, :post, :put, :delete)
  - url: Request URL
  - options: Request options (headers, body, etc.)

  ## Returns
  - {:ok, response} on success
  - {:error, reason} on failure
  """
  @spec call(atom(), String.t(), keyword()) :: {:ok, map()} | {:error, String.t()}
  def call(_method, _url, _options \\ []) do
    {:error, "HTTPClient.call/3 not yet implemented - stub only"}
  end

  @doc """
  Make an HTTP GET request.

  ## Parameters
  - url: Request URL
  - options: Request options

  ## Returns
  - {:ok, response} on success
  - {:error, reason} on failure
  """
  @spec get(String.t(), keyword()) :: {:ok, map()} | {:error, String.t()}
  def get(_url, _options \\ []) do
    {:error, "HTTPClient.get/2 not yet implemented - stub only"}
  end

  @doc """
  Make an HTTP POST request.

  ## Parameters
  - url: Request URL
  - body: Request body
  - options: Request options

  ## Returns
  - {:ok, response} on success
  - {:error, reason} on failure
  """
  @spec post(String.t(), any(), keyword()) :: {:ok, map()} | {:error, String.t()}
  def post(_url, _body, _options \\ []) do
    {:error, "HTTPClient.post/3 not yet implemented - stub only"}
  end

  @doc """
  Make an HTTP PUT request.

  ## Parameters
  - url: Request URL
  - body: Request body
  - options: Request options

  ## Returns
  - {:ok, response} on success
  - {:error, reason} on failure
  """
  @spec put(String.t(), any(), keyword()) :: {:ok, map()} | {:error, String.t()}
  def put(_url, _body, _options \\ []) do
    {:error, "HTTPClient.put/3 not yet implemented - stub only"}
  end

  @doc """
  Make an HTTP DELETE request.

  ## Parameters
  - url: Request URL
  - options: Request options

  ## Returns
  - {:ok, response} on success
  - {:error, reason} on failure
  """
  @spec delete(String.t(), keyword()) :: {:ok, map()} | {:error, String.t()}
  def delete(_url, _options \\ []) do
    {:error, "HTTPClient.delete/2 not yet implemented - stub only"}
  end
end
