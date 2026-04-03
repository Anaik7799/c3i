defmodule Indrajaal.Generators do
  @moduledoc """
  Property-based testing generators for StreamData.
  """

  use ExUnitProperties

  @doc """
  Generates a valid email address
  """
  @spec email_generator() :: any()
  def email_generator do
    gen all(
          username <- string(:alphanumeric, min_length: 1, max_length: 20),
          domain <- string(:alphanumeric, min_length: 1, max_length: 10)
        ) do
      "#{username}@#{domain}.com"
    end
  end

  @doc """
  Generates a valid password meeting complexity requirements
  """
  @spec password_generator() :: any()
  def password_generator do
    gen all(
          lower <- string(?a..?z, min_length: 1),
          upper <- string(?A..?Z, min_length: 1),
          digit <- string(?0..?9, min_length: 1),
          special <- string([?!, ?@, ?#, ?$], min_length: 1),
          extra <- string(:ascii, min_length: 5, max_length: 10)
        ) do
      lower <> upper <> digit <> special <> extra
    end
  end

  @doc """
  Generates a valid UUID
  """
  @spec uuid_generator() :: any()
  def uuid_generator do
    gen all(_uuid <- constant(nil)) do
      Ecto.UUID.generate()
    end
  end

  @doc """
  Generates a valid tenant configuration
  """
  @spec tenant_config_generator() :: any()
  def tenant_config_generator do
    gen all(
          timezone <- member_of(["UTC", "America/New_York", "Europe/London"]),
          locale <- member_of(["en", "es", "fr"]),
          features <- map_of(atom(:alphanumeric), boolean())
        ) do
      %{
        timezone: timezone,
        locale: locale,
        features: features
      }
    end
  end

  @doc """
  Generates valid GPS coordinates
  """
  @spec coordinates_generator() :: any()
  def coordinates_generator do
    gen all(
          lat <- float(min: -90.0, max: 90.0),
          lng <- float(min: -180.0, max: 180.0)
        ) do
      %{latitude: lat, longitude: lng}
    end
  end

  @doc """
  Generates a valid IP address
  """
  @spec ip_address_generator() :: any()
  def ip_address_generator do
    gen all(octets <- list_of(integer(0..255), length: 4)) do
      Enum.join(octets, ".")
    end
  end
end
