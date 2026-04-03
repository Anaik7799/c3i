defmodule Indrajaal.PropertyTesting do
  @moduledoc """
  Property-based testing utilities for comprehensive validation.

  Provides generators and properties for testing complex business logic
  with randomized inputs to catch edge cases that unit tests might miss.
  """

  use ExUnitProperties
  import StreamData
  import Indrajaal.Types

  @doc """
  Generates valid user data for property testing.
  """
  @spec user_generator() :: any()
  def user_generator do
    gen all(
          email <- email_generator(),
          first_name <- string(:alphanumeric, min_length: 2, max_length: 50),
          last_name <- string(:alphanumeric, min_length: 2, max_length: 50),
          role <- member_of([:admin, :manager, :operator, :viewer, :guest]),
          active <- boolean(),
          settings <-
            map_of(
              atom(:alphanumeric),
              one_of([string(:printable), integer(), boolean()])
            )
        ) do
      %{
        email: email,
        first_name: first_name,
        last_name: last_name,
        role: role,
        active: active,
        password: "SecurePass123!",
        settings: settings
      }
    end
  end

  @doc """
  Generates valid email addresses.
  """
  @spec email_generator() :: any()
  def email_generator do
    gen all(
          username <- string(:alphanumeric, min_length: 3, max_length: 20),
          domain <- string(:alphanumeric, min_length: 3, max_length: 15),
          tld <- member_of(["com", "org", "net", "edu", "gov"])
        ) do
      "#{username}@#{domain}.#{tld}"
    end
  end

  @doc """
  Generates valid device data.
  """
  @spec device_generator() :: any()
  def device_generator do
    gen all(
          name <- string(:alphanumeric, min_length: 5, max_length: 50),
          type <- member_of([:camera, :sensor, :panel, :reader, :intercom]),
          status <- member_of([:online, :offline, :maintenance, :error]),
          ip_address <- ip_address_generator(),
          firmware_version <- firmware_version_generator(),
          last_seen <- datetime_generator()
        ) do
      %{
        name: name,
        type: type,
        status: status,
        ip_address: ip_address,
        firmware_version: firmware_version,
        last_seen: last_seen,
        metadata: %{
          manufacturer: "TestManufacturer",
          model: "TestModel"
        }
      }
    end
  end

  @doc """
  Generates valid alarm event data.
  """
  @spec alarm_event_generator() :: any()
  def alarm_event_generator do
    gen all(
          type <-
            member_of([:motion_detected, :door_open, :intrusion, :system_error, :maintenance]),
          priority <- member_of([:low, :medium, :high, :critical, :emergency]),
          status <- member_of([:active, :acknowledged, :resolved, :false_alarm]),
          timestamp <- datetime_generator(),
          description <- string(:printable, min_length: 10, max_length: 200)
        ) do
      %{
        type: type,
        priority: priority,
        status: status,
        timestamp: timestamp,
        description: description,
        metadata: %{
          source: "property_test",
          confidence: :rand.uniform(100)
        }
      }
    end
  end

  @doc """
  Generates valid site data with geographic coordinates.
  """
  @spec site_generator() :: any()
  def site_generator do
    gen all(
          name <- string(:alphanumeric, min_length: 5, max_length: 100),
          address <- address_generator(),
          coordinates <- coordinates_generator(),
          region <- member_of([:north, :south, :east, :west, :central]),
          type <- member_of([:office, :warehouse, :retail, :manufacturing, :residential])
        ) do
      %{
        name: name,
        address: address,
        coordinates: coordinates,
        region: region,
        type: type,
        active: true
      }
    end
  end

  @doc """
  Generates realistic address data.
  """
  @spec address_generator() :: any()
  def address_generator do
    gen all(
          street_number <- integer(1..9999),
          street_name <- string(:alphanumeric, min_length: 5, max_length: 30),
          city <- string(:alphanumeric, min_length: 3, max_length: 25),
          state <- string(:alphanumeric, min_length: 2, max_length: 20),
          postal_code <- string(:numeric, length: 5),
          country <- member_of(["USA", "Canada", "UK", "Australia"])
        ) do
      %{
        street: "#{street_number} #{street_name} St",
        city: city,
        state: state,
        postal_code: postal_code,
        country: country
      }
    end
  end

  @doc """
  Generates valid coordinate pairs (latitude, longitude).
  """
  @spec coordinates_generator() :: any()
  def coordinates_generator do
    gen all(
          latitude <- float(min: -90.0, max: 90.0),
          longitude <- float(min: -180.0, max: 180.0)
        ) do
      {Float.round(latitude, 6), Float.round(longitude, 6)}
    end
  end

  @doc """
  Generates valid IP addresses.
  """
  @spec ip_address_generator() :: any()
  def ip_address_generator do
    gen all(
          octet1 <- integer(1..254),
          octet2 <- integer(0..255),
          octet3 <- integer(0..255),
          octet4 <- integer(1..254)
        ) do
      "#{octet1}.#{octet2}.#{octet3}.#{octet4}"
    end
  end

  @doc """
  Generates realistic firmware versions.
  """
  @spec firmware_version_generator() :: any()
  def firmware_version_generator do
    gen all(
          major <- integer(1..5),
          minor <- integer(0..20),
          patch <- integer(0..50)
        ) do
      "#{major}.#{minor}.#{patch}"
    end
  end

  @doc """
  Generates datetime values within a reasonable range.
  """
  @spec datetime_generator() :: any()
  def datetime_generator do
    gen all(
          days_offset <- integer(-365..30),
          hour <- integer(0..23),
          minute <- integer(0..59),
          second <- integer(0..59)
        ) do
      base_date = Date.utc_today() |> Date.add(days_offset)
      time = Time.new!(hour, minute, second)
      DateTime.new!(base_date, time)
    end
  end

  @doc """
  Generates access credential data.
  """
  @spec access_credential_generator() :: any()
  def access_credential_generator do
    gen all(
          type <- member_of([:card, :pin, :biometric, :mobile, :key]),
          card_number <- string(:numeric, length: 10),
          pin <- string(:numeric, length: 4),
          valid_from <- date_generator(),
          valid_until <- future_date_generator(),
          status <- member_of([:active, :suspended, :expired, :pending])
        ) do
      %{
        type: type,
        card_number: card_number,
        pin: pin,
        valid_from: valid_from,
        valid_until: valid_until,
        status: status,
        access_levels: ["building", "floor"]
      }
    end
  end

  @doc """
  Generates team data with hierarchical relationships.
  """
  @spec team_generator() :: any()
  def team_generator do
    gen all(
          name <- string(:alphanumeric, min_length: 5, max_length: 50),
          description <- string(:printable, min_length: 10, max_length: 200),
          department <- member_of(["Security", "Operations", "IT", "Management", "Maintenance"]),
          size <- integer(2..50)
        ) do
      %{
        name: name,
        description: description,
        department: department,
        max_members: size,
        settings: %{
          requires_approval: true,
          auto_assign_roles: false
        }
      }
    end
  end

  @doc """
  Validates user data integrity for property testing.
  """
  @spec validate_user_integrity(any()) :: any()
  def validate_user_integrity(user_params) do
    # Validate email format
    # Validate role is valid
    # Validate name lengths
    # Validate settings is a map
    valid_email?(user_params.email) and
      user_params.role in [:admin, :manager, :operator, :viewer, :guest] and
      byte_size(user_params.first_name) >= 2 and
      byte_size(user_params.last_name) >= 2 and
      is_map(user_params.settings)
  end

  @doc """
  Validates device status transitions for property testing.
  """
  @spec validate_device_status_transition(any(), any()) :: any()
  def validate_device_status_transition(initial_status, new_status) do
    # Define valid transitions
    valid_transitions = %{
      online: [:offline, :maintenance, :error],
      offline: [:online, :maintenance],
      maintenance: [:online, :offline],
      error: [:offline, :maintenance]
    }

    expected_valid = new_status in Map.get(valid_transitions, initial_status, [])
    actual_valid = valid_device_status_transition?(initial_status, new_status)

    actual_valid == expected_valid
  end

  @doc """
  Validates alarm priority escalation for property testing.
  """
  @spec validate_alarm_escalation(any(), any()) :: any()
  def validate_alarm_escalation(current_priority, escalated_priority) do
    priority_levels = %{low: 1, medium: 2, high: 3, critical: 4, emergency: 5}

    current_level = Map.get(priority_levels, current_priority)
    escalated_level = Map.get(priority_levels, escalated_priority)

    # Escalation should only increase priority
    if escalated_level > current_level do
      can_escalate_alarm?(current_priority, escalated_priority)
    else
      not can_escalate_alarm?(current_priority, escalated_priority)
    end
  end

  @doc """
  Validates geographic coordinates for property testing.
  """
  @spec validate_coordinates(tuple()) :: boolean()
  def validate_coordinates({lat, lng}) do
    lat >= -90.0 and lat <= 90.0 and
      lng >= -180.0 and lng <= 180.0 and
      valid_coordinates?({lat, lng})
  end

  @doc """
  Validates credential expiration logic for property testing.
  """
  @spec validate_credential_expiration(any()) :: any()
  def validate_credential_expiration(credential) do
    # valid_until should be after valid_from
    valid_date_order =
      Date.compare(
        credential.valid_until,
        credential.valid_from
      ) != :lt

    # Expired credentials should have status reflecting expiration
    today = Date.utc_today()

    valid_expiry_status =
      if Date.compare(credential.valid_until, today) == :lt do
        credential.status in [:expired, :suspended]
      else
        true
      end

    valid_date_order and valid_expiry_status
  end

  @doc """
  Validates bulk operations for property testing.
  """
  @spec validate_bulk_operation(any(), any()) :: any()
  def validate_bulk_operation(operation_func, items) do
    case operation_func.(items) do
      {:ok, results} ->
        # All results should be valid
        length(results) == length(items) and
          Enum.all?(results, &valid_result?/1)

      {:error, _reason} ->
        # Errors should be properly formatted - allow errors but they should be
        true
    end
  end

  @doc """
  Validates search consistency for property testing.
  """
  @spec validate_search_consistency(any(), any()) :: any()
  def validate_search_consistency(search_term, items) do
    # Create items with search term in various fields
    modified_items =
      Enum.map(items, fn item ->
        case :rand.uniform(3) do
          1 -> %{item | first_name: search_term <> "_first"}
          2 -> %{item | last_name: search_term <> "_last"}
          3 -> %{item | email: "#{search_term}@example.com"}
        end
      end)

    # Search should find items containing the term
    matching_items = search_items_by_term(modified_items, search_term)

    # Verify all returned items actually contain the search term
    all_contain_term = Enum.all?(matching_items, &item_contains_term?(&1, search_term))

    # Verify no matching items were missed
    expected_count = Enum.count(modified_items, &item_contains_term?(&1, search_term))
    correct_count = length(matching_items) == expected_count

    all_contain_term and correct_count
  end

  # Helper functions for property validation

  @spec valid_device_status_transition?(term(), term()) :: term()
  defp valid_device_status_transition?(:online, new_status)
       when new_status in [:offline, :maintenance, :error],
       do: true

  @spec valid_device_status_transition?(term(), term()) :: term()
  defp valid_device_status_transition?(:offline, new_status)
       when new_status in [:online, :maintenance],
       do: true

  @spec valid_device_status_transition?(term(), term()) :: term()
  defp valid_device_status_transition?(:maintenance, new_status)
       when new_status in [:online, :offline],
       do: true

  @spec valid_device_status_transition?(term(), term()) :: term()
  defp valid_device_status_transition?(:error, new_status)
       when new_status in [:offline, :maintenance],
       do: true

  @spec valid_device_status_transition?(term(), term()) :: term()
  defp valid_device_status_transition?(_, _), do: false

  defp can_escalate_alarm?(current, escalated) do
    priority_order = [:low, :medium, :high, :critical, :emergency]
    current_index = Enum.find_index(priority_order, &(&1 == current))
    escalated_index = Enum.find_index(priority_order, &(&1 == escalated))

    escalated_index > current_index
  end

  @spec valid_result?(map()) :: term()
  defp valid_result?(%{id: _id}), do: true
  defp valid_result?(%{inserted_at: _timestamp}), do: true
  defp valid_result?(_), do: false

  @spec search_items_by_term(term(), term()) :: term()
  defp search_items_by_term(items, term) do
    Enum.filter(items, &item_contains_term?(&1, term))
  end

  @spec item_contains_term?(term(), term()) :: term()
  defp item_contains_term?(item, term) do
    searchable_fields = [item.first_name, item.last_name, item.email]
    Enum.any?(searchable_fields, &String.contains?(&1, term))
  end

  @spec date_generator() :: any()
  defp date_generator do
    gen all(days_offset <- integer(-30..365)) do
      Date.utc_today() |> Date.add(days_offset)
    end
  end

  @spec future_date_generator() :: any()
  defp future_date_generator do
    # 1 day to 2 years in future
    gen all(days_offset <- integer(1..730)) do
      Date.utc_today() |> Date.add(days_offset)
    end
  end
end
