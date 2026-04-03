# Telecom-Grade Services Integration for Indrajaal

**Version**: 1.0.0 | **Date**: 2026-01-03 | **Author**: Claude Opus 4.5
**STAMP**: SC-TELCO-*, SC-ZTP-*, SC-TMF-*, SC-OSS-*, SC-BSS-*, SC-ORCH-*
**Compliance**: TM Forum ODA, ETSI ZSM, MEF 3.0, GSMA RSP, 3GPP SA5

---

## Executive Summary

This document defines the integration strategy for transforming Indrajaal from a security platform into a **Telecom-Grade Managed Services Platform**. By integrating with industry-standard telecom operations frameworks (TMF Forum, ETSI, MEF, GSMA), Indrajaal can offer carrier-grade reliability, automated provisioning, and seamless inter-carrier operations.

### Key Integration Domains

| Domain | Standards | Value Proposition |
|--------|-----------|-------------------|
| **Zero Touch Provisioning** | ETSI ZSM, GSMA RSP | Automated panel/device onboarding |
| **TMF Forum Open APIs** | ODA, TMF621-TMF688 | Billing, ticketing, ordering, catalog |
| **OSS/BSS Integration** | TM Forum SID | Operations & business support |
| **Network Orchestration** | ONAP, OSM, MEF LSO | Automated slice management |
| **eSIM Provisioning** | GSMA SGP.32 | Cellular IoT device management |

---

## Part 1: Zero Touch Provisioning (ZTP)

### 1.1 Overview

Zero Touch Provisioning enables automatic configuration of alarm panels, cameras, and IoT sensors without manual intervention. This is critical for scaling to thousands of sites.

**Market Size**: $2.1B (2021), growing 25% CAGR

### 1.2 ZTP Architecture for Alarm Panels

```
┌─────────────────────────────────────────────────────────────────┐
│                    INDRAJAAL ZTP ARCHITECTURE                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   ┌─────────────┐    ┌─────────────┐    ┌─────────────┐        │
│   │ Alarm Panel │    │  IP Camera  │    │ IoT Sensor  │        │
│   │  (ARM/x86)  │    │  (ONVIF)    │    │  (Zigbee)   │        │
│   └──────┬──────┘    └──────┬──────┘    └──────┬──────┘        │
│          │                  │                  │                │
│          ▼                  ▼                  ▼                │
│   ┌──────────────────────────────────────────────────┐         │
│   │              ZTP BOOTSTRAPPER                     │         │
│   │  • DHCP Option 66/67 (TFTP Server)               │         │
│   │  • DNS SRV Records                               │         │
│   │  • mDNS/Avahi Discovery                          │         │
│   │  • SSDP/UPnP Discovery                           │         │
│   └───────────────────────┬──────────────────────────┘         │
│                           │                                     │
│                           ▼                                     │
│   ┌──────────────────────────────────────────────────┐         │
│   │              ZTP ORCHESTRATOR                     │         │
│   │  • Device Authentication (X.509/TPM)             │         │
│   │  • Configuration Template Engine                 │         │
│   │  • Firmware Version Control                      │         │
│   │  • Zenoh Mesh Registration                       │         │
│   └───────────────────────┬──────────────────────────┘         │
│                           │                                     │
│                           ▼                                     │
│   ┌──────────────────────────────────────────────────┐         │
│   │              IMMUTABLE REGISTER                   │         │
│   │  • Device Identity Binding                       │         │
│   │  • Configuration Hash Chain                      │         │
│   │  • Audit Trail                                   │         │
│   └──────────────────────────────────────────────────┘         │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 1.3 ZTP Device Onboarding Flow

```
T+0s      Device powers on, obtains DHCP lease
T+2s      DHCP Option 66 returns Indrajaal ZTP server URL
T+5s      Device downloads bootstrap config (signed JSON)
T+8s      Device validates signature against embedded CA
T+10s     Device requests full configuration from ZTP orchestrator
T+15s     ZTP authenticates device (X.509 cert + TPM attestation)
T+20s     Configuration template rendered with site-specific params
T+30s     Device applies config, reboots if needed
T+60s     Device registers with Zenoh mesh
T+65s     Device appears in Prajna Cockpit
```

**Total onboarding time: ~65 seconds** (vs. 30-60 minutes manual)

### 1.4 Elixir ZTP Module Design

```elixir
defmodule Indrajaal.ZTP.Orchestrator do
  @moduledoc """
  Zero Touch Provisioning Orchestrator for alarm panels and IoT devices.

  ## STAMP Constraints
  - SC-ZTP-001: Device authentication via X.509 MANDATORY
  - SC-ZTP-002: Configuration signing with Ed25519
  - SC-ZTP-003: TPM attestation for hardware binding
  - SC-ZTP-004: All onboarding events to Immutable Register
  - SC-ZTP-005: Firmware version validation before config
  """

  use GenServer
  require Logger

  @type device_info :: %{
    device_id: String.t(),
    mac_address: String.t(),
    serial_number: String.t(),
    model: String.t(),
    firmware_version: String.t(),
    tpm_attestation: binary() | nil,
    x509_cert: binary()
  }

  @type config_template :: %{
    template_id: String.t(),
    version: String.t(),
    parameters: map(),
    zenoh_config: map(),
    alarm_zones: list(map())
  }

  @spec onboard_device(device_info()) ::
    {:ok, config_template()} | {:error, :auth_failed | :firmware_outdated | :tpm_invalid}
  def onboard_device(device_info) do
    with :ok <- validate_x509_certificate(device_info.x509_cert),
         :ok <- validate_tpm_attestation(device_info),
         :ok <- check_firmware_version(device_info),
         {:ok, template} <- generate_config(device_info),
         :ok <- sign_and_deliver(device_info, template),
         :ok <- register_to_mesh(device_info),
         :ok <- log_to_register(device_info, :onboarded) do
      {:ok, template}
    end
  end

  @spec generate_config(device_info()) :: {:ok, config_template()}
  defp generate_config(device_info) do
    # Render site-specific configuration from template
    {:ok, site} = lookup_site_by_device(device_info.serial_number)

    template = %{
      template_id: "ZTP-#{site.id}-#{device_info.model}",
      version: "1.0.0",
      parameters: %{
        site_id: site.id,
        tenant_id: site.tenant_id,
        arc_endpoints: site.arc_endpoints,
        supervision_interval_ms: 60_000,
        heartbeat_interval_ms: 30_000
      },
      zenoh_config: %{
        mode: :peer,
        connect: site.zenoh_routers,
        key_prefix: "indrajaal/panel/#{site.tenant_id}/#{site.id}"
      },
      alarm_zones: site.zones
    }

    {:ok, template}
  end
end
```

### 1.5 STAMP Constraints (SC-ZTP)

| ID | Constraint | Severity | Verification |
|----|------------|----------|--------------|
| SC-ZTP-001 | Device X.509 authentication MANDATORY | CRITICAL | Runtime |
| SC-ZTP-002 | All configs Ed25519 signed | CRITICAL | Cryptographic |
| SC-ZTP-003 | TPM attestation for critical devices | HIGH | Hardware |
| SC-ZTP-004 | Onboarding events to Immutable Register | CRITICAL | Audit |
| SC-ZTP-005 | Firmware version check before config | HIGH | Version |
| SC-ZTP-006 | DHCP Option 66/67 for bootstrap | MEDIUM | Network |
| SC-ZTP-007 | mDNS fallback if DHCP unavailable | MEDIUM | Discovery |
| SC-ZTP-008 | Max 120s for complete onboarding | HIGH | SLA |
| SC-ZTP-009 | Rollback on config apply failure | CRITICAL | Recovery |
| SC-ZTP-010 | Device quarantine on auth failure | CRITICAL | Security |

---

## Part 2: TM Forum Open APIs Integration

### 2.1 Overview

TM Forum Open APIs provide a standardized interface for telecom operations. Indrajaal integrates with 15+ TMF APIs for billing, ticketing, ordering, and inventory management.

**APIs Available**: 93+ Open APIs in TM Forum catalog
**Industry Adoption**: 800+ companies, 250+ operators

### 2.2 Priority TMF APIs for Indrajaal

| TMF ID | API Name | Indrajaal Use Case |
|--------|----------|-------------------|
| TMF620 | Product Catalog | Service catalog (monitoring tiers) |
| TMF621 | Trouble Ticket | Alarm escalation to ARC |
| TMF622 | Product Ordering | New site provisioning |
| TMF629 | Customer Management | Subscriber management |
| TMF632 | Party Management | Dealer/installer management |
| TMF637 | Product Inventory | Site/device inventory |
| TMF638 | Service Inventory | Active service tracking |
| TMF639 | Resource Inventory | Camera/sensor inventory |
| TMF640 | Service Activation | Automated service turn-up |
| TMF641 | Service Ordering | Monitoring service orders |
| TMF648 | Quote Management | Pricing quotes |
| TMF654 | Prepay Balance | Prepaid monitoring credits |
| TMF666 | Account Management | Billing accounts |
| TMF676 | Payment Management | Payment processing |
| TMF688 | Event Management | Alarm event processing |

### 2.3 TMF621 Trouble Ticket Integration

When a verified alarm requires human dispatch (police, fire, guard), Indrajaal creates a TMF621-compliant trouble ticket:

```elixir
defmodule Indrajaal.TMF.TroubleTicket do
  @moduledoc """
  TMF621 Trouble Ticket Management API integration.

  Creates and manages trouble tickets for alarm events that require
  human intervention or dispatch.

  ## STAMP Constraints
  - SC-TMF-001: All tickets have unique correlation ID
  - SC-TMF-002: Ticket creation < 5 seconds
  - SC-TMF-003: Status callbacks within 30 seconds
  - SC-TMF-004: All ticket ops to Immutable Register
  """

  @type trouble_ticket :: %{
    id: String.t(),
    href: String.t(),
    correlationId: String.t(),
    creationDate: DateTime.t(),
    description: String.t(),
    expectedResolutionDate: DateTime.t() | nil,
    externalId: String.t(),
    lastUpdate: DateTime.t(),
    name: String.t(),
    priority: String.t(),
    requestedResolutionDate: DateTime.t() | nil,
    resolutionDate: DateTime.t() | nil,
    severity: String.t(),
    status: String.t(),
    statusChange: list(map()),
    statusChangeDate: DateTime.t() | nil,
    statusChangeReason: String.t() | nil,
    ticketType: String.t(),
    troubleTicketCharacteristic: list(map()),
    relatedParty: list(map()),
    relatedEntity: list(map()),
    note: list(map()),
    attachment: list(map())
  }

  @spec create_from_alarm(Indrajaal.Zenoh.AlarmMessage.t()) :: {:ok, trouble_ticket()}
  def create_from_alarm(alarm) do
    ticket = %{
      "@type" => "TroubleTicket",
      correlationId: alarm.message_id,
      creationDate: DateTime.utc_now() |> DateTime.to_iso8601(),
      description: "Verified alarm event requiring dispatch",
      externalId: "ALARM-#{alarm.site_id}-#{alarm.message_id}",
      name: "#{alarm.event_code} Alarm - Site #{alarm.site_id}",
      priority: map_priority(alarm.severity),
      severity: map_severity(alarm.severity),
      status: "acknowledged",
      ticketType: "alarmDispatch",
      troubleTicketCharacteristic: [
        %{name: "eventCode", value: alarm.event_code},
        %{name: "zoneId", value: alarm.zone_id},
        %{name: "siteId", value: alarm.site_id},
        %{name: "tenantId", value: alarm.tenant_id},
        %{name: "verificationScore", value: alarm.ai_pre_score},
        %{name: "videoClipUrl", value: get_video_url(alarm)},
        %{name: "audioClipUrl", value: get_audio_url(alarm)}
      ],
      relatedParty: [
        %{
          "@type" => "RelatedParty",
          role: "subscriber",
          id: alarm.tenant_id,
          name: get_subscriber_name(alarm.tenant_id)
        },
        %{
          "@type" => "RelatedParty",
          role: "monitoringCenter",
          id: get_arc_id(alarm.site_id),
          name: get_arc_name(alarm.site_id)
        }
      ],
      relatedEntity: [
        %{
          "@type" => "RelatedEntity",
          role: "alarmSource",
          "@referredType" => "AlarmPanel",
          id: alarm.site_id
        }
      ],
      attachment: build_attachments(alarm)
    }

    {:ok, response} = TMFClient.post("/troubleTicketManagement/v5/troubleTicket", ticket)
    log_to_register(:ticket_created, response)
    {:ok, response}
  end

  defp map_priority(:critical), do: "1"
  defp map_priority(:high), do: "2"
  defp map_priority(:medium), do: "3"
  defp map_priority(_), do: "4"

  defp map_severity(:critical), do: "critical"
  defp map_severity(:high), do: "major"
  defp map_severity(:medium), do: "minor"
  defp map_severity(_), do: "warning"
end
```

### 2.4 TMF622 Product Ordering for Site Provisioning

```elixir
defmodule Indrajaal.TMF.ProductOrder do
  @moduledoc """
  TMF622 Product Ordering API for new site provisioning.

  Handles ordering workflow for new monitoring services, upgrades,
  and equipment additions.
  """

  @type product_order :: %{
    id: String.t(),
    href: String.t(),
    cancellationDate: DateTime.t() | nil,
    cancellationReason: String.t() | nil,
    category: String.t(),
    completionDate: DateTime.t() | nil,
    description: String.t(),
    expectedCompletionDate: DateTime.t(),
    externalId: String.t(),
    notificationContact: String.t(),
    orderDate: DateTime.t(),
    priority: String.t(),
    requestedCompletionDate: DateTime.t(),
    requestedStartDate: DateTime.t(),
    state: String.t(),
    productOrderItem: list(map()),
    billingAccount: map(),
    channel: map(),
    relatedParty: list(map())
  }

  @spec create_new_site_order(map()) :: {:ok, product_order()}
  def create_new_site_order(site_params) do
    order = %{
      "@type" => "ProductOrder",
      category: "alarmMonitoring",
      description: "New alarm monitoring service installation",
      externalId: "ORD-#{site_params.tenant_id}-#{:os.system_time(:millisecond)}",
      orderDate: DateTime.utc_now() |> DateTime.to_iso8601(),
      priority: "normal",
      requestedStartDate: site_params.requested_start |> DateTime.to_iso8601(),
      state: "acknowledged",
      productOrderItem: [
        %{
          "@type" => "ProductOrderItem",
          id: "1",
          action: "add",
          quantity: 1,
          state: "acknowledged",
          product: %{
            "@type" => "Product",
            name: site_params.service_tier,
            productOffering: %{
              id: get_offering_id(site_params.service_tier),
              name: site_params.service_tier
            },
            productCharacteristic: [
              %{name: "panelType", value: site_params.panel_type},
              %{name: "zoneCount", value: site_params.zone_count},
              %{name: "videoChannels", value: site_params.video_channels},
              %{name: "monitoringType", value: site_params.monitoring_type}
            ],
            place: [
              %{
                "@type" => "Place",
                role: "installationAddress",
                streetAddress: site_params.address.street,
                city: site_params.address.city,
                stateOrProvince: site_params.address.state,
                postcode: site_params.address.postal_code,
                country: site_params.address.country,
                geographicLocation: %{
                  latitude: site_params.address.latitude,
                  longitude: site_params.address.longitude
                }
              }
            ]
          }
        }
      ],
      billingAccount: %{
        id: site_params.billing_account_id,
        href: "/billingManagement/v4/billingAccount/#{site_params.billing_account_id}"
      },
      relatedParty: [
        %{
          "@type" => "RelatedParty",
          role: "buyer",
          id: site_params.tenant_id
        },
        %{
          "@type" => "RelatedParty",
          role: "dealer",
          id: site_params.dealer_id
        }
      ]
    }

    {:ok, response} = TMFClient.post("/productOrderingManagement/v4/productOrder", order)

    # Trigger ZTP preparation
    ZTP.Orchestrator.prepare_for_site(site_params)

    {:ok, response}
  end
end
```

### 2.5 TMF688 Event Management for Alarms

```elixir
defmodule Indrajaal.TMF.EventManagement do
  @moduledoc """
  TMF688 Event Management API for alarm event processing.

  Transforms Zenoh alarm messages into TMF688-compliant events
  for integration with OSS/BSS systems.
  """

  @type event :: %{
    id: String.t(),
    href: String.t(),
    correlationId: String.t(),
    description: String.t(),
    domain: String.t(),
    eventId: String.t(),
    eventTime: DateTime.t(),
    eventType: String.t(),
    priority: String.t(),
    title: String.t(),
    event: map(),
    relatedParty: list(map()),
    source: map()
  }

  @spec publish_alarm_event(Indrajaal.Zenoh.AlarmMessage.t()) :: {:ok, event()}
  def publish_alarm_event(alarm) do
    event = %{
      "@type" => "Event",
      correlationId: alarm.message_id,
      description: "Alarm event from #{alarm.site_id}",
      domain: "securityAlarm",
      eventId: alarm.message_id,
      eventTime: alarm.timestamp |> DateTime.to_iso8601(),
      eventType: "AlarmEvent",
      priority: priority_from_severity(alarm.severity),
      title: "#{alarm.event_code} - Zone #{alarm.zone_id}",
      event: %{
        "@type" => "AlarmEventPayload",
        alarmType: alarm.event_code,
        perceivedSeverity: alarm.severity,
        probableCause: get_probable_cause(alarm.event_code),
        specificProblem: alarm.zone_id,
        alarmRaisedTime: alarm.timestamp |> DateTime.to_iso8601(),
        alarmClearedTime: nil,
        ackState: "unacknowledged",
        verificationScore: alarm.ai_pre_score,
        hasVideoEvidence: not is_nil(alarm.video_clip),
        hasAudioEvidence: not is_nil(alarm.audio_clip)
      },
      source: %{
        "@type" => "EntityRef",
        "@referredType" => "AlarmPanel",
        id: alarm.site_id,
        name: "Site #{alarm.site_id}"
      },
      relatedParty: [
        %{
          "@type" => "RelatedParty",
          role: "subscriber",
          id: alarm.tenant_id
        }
      ]
    }

    {:ok, response} = TMFClient.post("/eventManagement/v4/event", event)
    {:ok, response}
  end
end
```

### 2.6 STAMP Constraints (SC-TMF)

| ID | Constraint | Severity | Verification |
|----|------------|----------|--------------|
| SC-TMF-001 | Unique correlation ID per entity | CRITICAL | UUID |
| SC-TMF-002 | Ticket creation < 5 seconds | HIGH | SLA |
| SC-TMF-003 | Status callbacks < 30 seconds | HIGH | Async |
| SC-TMF-004 | All TMF ops to Immutable Register | CRITICAL | Audit |
| SC-TMF-005 | OAuth2 authentication for TMF APIs | CRITICAL | Security |
| SC-TMF-006 | Rate limiting per API endpoint | HIGH | Throttle |
| SC-TMF-007 | TMF621 v5.0.0 compliance | HIGH | Spec |
| SC-TMF-008 | TMF622 v4.0.0 compliance | HIGH | Spec |
| SC-TMF-009 | JSON Schema validation on all payloads | HIGH | Validation |
| SC-TMF-010 | Webhook retry with exponential backoff | MEDIUM | Reliability |

---

## Part 3: OSS/BSS Integration

### 3.1 Overview

OSS (Operations Support Systems) and BSS (Business Support Systems) integration enables Indrajaal to operate as a telecom-grade service provider.

**Market Size**: $65.81B (2024), projected $148.26B (2033)
**CAGR**: 9.4%

### 3.2 OSS Integration Layer

```
┌─────────────────────────────────────────────────────────────────┐
│                    INDRAJAAL OSS INTEGRATION                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   ┌─────────────────────────────────────────────────────────┐   │
│   │                  FAULT MANAGEMENT                        │   │
│   │  • Alarm correlation & root cause analysis              │   │
│   │  • Automated ticket creation (TMF621)                   │   │
│   │  • Escalation workflows                                 │   │
│   │  • SLA breach detection                                 │   │
│   └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│   ┌─────────────────────────────────────────────────────────┐   │
│   │               PERFORMANCE MANAGEMENT                     │   │
│   │  • Real-time KPI monitoring (Prajna Cockpit)            │   │
│   │  • Threshold-based alerting                             │   │
│   │  • Capacity planning analytics (DuckDB)                 │   │
│   │  • Trend analysis & forecasting                         │   │
│   └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│   ┌─────────────────────────────────────────────────────────┐   │
│   │               CONFIGURATION MANAGEMENT                   │   │
│   │  • ZTP orchestrator                                     │   │
│   │  • Device configuration repository                      │   │
│   │  • Version control & rollback                           │   │
│   │  • Golden config templates                              │   │
│   └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│   ┌─────────────────────────────────────────────────────────┐   │
│   │                SERVICE ASSURANCE                         │   │
│   │  • End-to-end service monitoring                        │   │
│   │  • Service availability tracking                        │   │
│   │  • Quality metrics (EN 50136 compliance)                │   │
│   │  • Customer experience scoring                          │   │
│   └─────────────────────────────────────────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 3.3 BSS Integration Layer

```
┌─────────────────────────────────────────────────────────────────┐
│                    INDRAJAAL BSS INTEGRATION                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   ┌─────────────────────────────────────────────────────────┐   │
│   │                 PRODUCT CATALOG                          │   │
│   │  • Service tier definitions (Basic/Pro/Enterprise)      │   │
│   │  • Add-on products (video, guard response)              │   │
│   │  • Pricing rules & promotions                           │   │
│   │  • Bundle management                                    │   │
│   └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│   ┌─────────────────────────────────────────────────────────┐   │
│   │               CUSTOMER MANAGEMENT                        │   │
│   │  • Subscriber profiles (TMF629)                         │   │
│   │  • Contact management                                   │   │
│   │  • Site hierarchies                                     │   │
│   │  • Emergency contact lists                              │   │
│   └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│   ┌─────────────────────────────────────────────────────────┐   │
│   │                 ORDER MANAGEMENT                         │   │
│   │  • New service orders (TMF622)                          │   │
│   │  • Modifications & upgrades                             │   │
│   │  • Cancellations & suspensions                          │   │
│   │  • Dealer commission tracking                           │   │
│   └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│   ┌─────────────────────────────────────────────────────────┐   │
│   │                BILLING & REVENUE                         │   │
│   │  • Usage-based billing (event counts)                   │   │
│   │  • Subscription billing (monthly)                       │   │
│   │  • Invoice generation                                   │   │
│   │  • Payment processing (TMF676)                          │   │
│   │  • Revenue assurance                                    │   │
│   └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│   ┌─────────────────────────────────────────────────────────┐   │
│   │                PARTNER MANAGEMENT                        │   │
│   │  • Dealer onboarding                                    │   │
│   │  • Commission calculation                               │   │
│   │  • White-label portal provisioning                      │   │
│   │  • SLA management                                       │   │
│   └─────────────────────────────────────────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 3.4 Elixir OSS/BSS Module Design

```elixir
defmodule Indrajaal.OSS.FaultManagement do
  @moduledoc """
  OSS Fault Management module for alarm correlation and RCA.

  ## STAMP Constraints
  - SC-OSS-001: All faults correlated within 30 seconds
  - SC-OSS-002: Root cause analysis for correlated faults
  - SC-OSS-003: Automatic ticket creation for P1/P2 faults
  - SC-OSS-004: SLA breach detection and alerting
  """

  use GenServer

  @type fault :: %{
    fault_id: String.t(),
    source: String.t(),
    severity: atom(),
    probable_cause: String.t(),
    specific_problem: String.t(),
    perceived_severity: atom(),
    alarm_raised_time: DateTime.t(),
    alarm_cleared_time: DateTime.t() | nil,
    correlated_faults: list(String.t()),
    root_cause_id: String.t() | nil,
    ticket_id: String.t() | nil
  }

  @correlation_window_ms 30_000

  def handle_info({:alarm_event, alarm}, state) do
    fault = transform_to_fault(alarm)

    # Check for correlation with existing faults
    correlated = find_correlated_faults(fault, state.active_faults)

    case correlated do
      [] ->
        # New root fault
        {:noreply, add_fault(state, fault)}

      parent_faults ->
        # Symptom fault - correlate
        updated_fault = %{fault |
          correlated_faults: Enum.map(parent_faults, & &1.fault_id),
          root_cause_id: determine_root_cause(parent_faults)
        }
        {:noreply, add_fault(state, updated_fault)}
    end
  end

  defp find_correlated_faults(new_fault, active_faults) do
    Enum.filter(active_faults, fn existing ->
      within_correlation_window?(new_fault, existing) and
      same_site?(new_fault, existing) and
      causally_related?(new_fault, existing)
    end)
  end

  defp determine_root_cause(faults) do
    # Use causal graph to find root cause
    faults
    |> Enum.sort_by(& &1.alarm_raised_time)
    |> List.first()
    |> Map.get(:fault_id)
  end
end

defmodule Indrajaal.BSS.Billing do
  @moduledoc """
  BSS Billing module for subscription and usage-based billing.

  ## STAMP Constraints
  - SC-BSS-001: Invoice generation by 5th of month
  - SC-BSS-002: Usage events captured in real-time
  - SC-BSS-003: Revenue assurance reconciliation daily
  - SC-BSS-004: PCI DSS compliance for payments
  """

  @type billing_account :: %{
    account_id: String.t(),
    tenant_id: String.t(),
    billing_cycle: :monthly | :annual,
    payment_method: :credit_card | :direct_debit | :carrier_billing,
    current_balance: Decimal.t(),
    subscription_products: list(map()),
    usage_charges: list(map())
  }

  @spec generate_invoice(String.t(), Date.t()) :: {:ok, map()}
  def generate_invoice(account_id, billing_period) do
    {:ok, account} = get_billing_account(account_id)

    # Calculate subscription charges
    subscription_total = calculate_subscriptions(account, billing_period)

    # Calculate usage charges
    usage_total = calculate_usage(account, billing_period)

    # Apply discounts and promotions
    {discount_total, applied_promotions} = apply_promotions(account, subscription_total + usage_total)

    # Generate invoice
    invoice = %{
      invoice_id: "INV-#{account_id}-#{Date.to_iso8601(billing_period)}",
      account_id: account_id,
      billing_period: billing_period,
      subscription_charges: subscription_total,
      usage_charges: usage_total,
      discounts: discount_total,
      taxes: calculate_taxes(subscription_total + usage_total - discount_total),
      total_due: subscription_total + usage_total - discount_total + taxes,
      due_date: Date.add(billing_period, 30),
      line_items: build_line_items(account, billing_period)
    }

    {:ok, _} = store_invoice(invoice)
    {:ok, _} = send_invoice_notification(account, invoice)

    {:ok, invoice}
  end

  @spec record_usage_event(String.t(), String.t(), map()) :: :ok
  def record_usage_event(account_id, event_type, details) do
    event = %{
      event_id: UUID.uuid4(),
      account_id: account_id,
      event_type: event_type,
      timestamp: DateTime.utc_now(),
      details: details,
      rated_amount: rate_event(event_type, details)
    }

    # Real-time usage capture
    UsageStore.append(event)

    :ok
  end
end
```

### 3.5 STAMP Constraints (SC-OSS/SC-BSS)

| ID | Constraint | Severity | Verification |
|----|------------|----------|--------------|
| SC-OSS-001 | Fault correlation < 30 seconds | HIGH | Timing |
| SC-OSS-002 | Root cause analysis for P1/P2 | HIGH | Logic |
| SC-OSS-003 | Auto-ticket for critical faults | CRITICAL | Automation |
| SC-OSS-004 | SLA breach detection real-time | CRITICAL | Monitoring |
| SC-OSS-005 | Configuration version control | HIGH | CM |
| SC-OSS-006 | Golden config validation | MEDIUM | Compliance |
| SC-BSS-001 | Invoice by 5th of month | HIGH | SLA |
| SC-BSS-002 | Real-time usage capture | CRITICAL | Billing |
| SC-BSS-003 | Daily revenue reconciliation | HIGH | Finance |
| SC-BSS-004 | PCI DSS for payments | CRITICAL | Security |
| SC-BSS-005 | Product catalog consistency | HIGH | Data |
| SC-BSS-006 | Dealer commission accuracy | MEDIUM | Finance |

---

## Part 4: Network Orchestration

### 4.1 Overview

Network orchestration enables automated management of network slices, service functions, and multi-domain connectivity. Indrajaal integrates with ONAP, OSM, and MEF LSO for carrier-grade orchestration.

### 4.2 ONAP Integration for 5G Slicing

```
┌─────────────────────────────────────────────────────────────────┐
│                 INDRAJAAL + ONAP INTEGRATION                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   ┌─────────────────┐    ┌─────────────────┐                   │
│   │    INDRAJAAL    │    │      ONAP       │                   │
│   │   QoS Manager   │◄──►│   SDC / SO      │                   │
│   └────────┬────────┘    └────────┬────────┘                   │
│            │                      │                             │
│            ▼                      ▼                             │
│   ┌─────────────────────────────────────────────────────────┐   │
│   │              NETWORK SLICE ORCHESTRATION                 │   │
│   ├─────────────────────────────────────────────────────────┤   │
│   │  Service Design (SDC):                                  │   │
│   │  • URLLC Slice Template (critical alarms)               │   │
│   │  • eMBB Slice Template (video streaming)                │   │
│   │  • mMTC Slice Template (IoT sensors)                    │   │
│   ├─────────────────────────────────────────────────────────┤   │
│   │  Service Orchestration (SO):                            │   │
│   │  • Slice instantiation on alarm trigger                 │   │
│   │  • Dynamic slice modification                           │   │
│   │  • Slice termination on incident close                  │   │
│   ├─────────────────────────────────────────────────────────┤   │
│   │  Policy Framework:                                      │   │
│   │  • QoS policies per alarm severity                      │   │
│   │  • Bandwidth allocation rules                           │   │
│   │  • Failover policies                                    │   │
│   └─────────────────────────────────────────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 4.3 ETSI ZSM Closed-Loop Automation

```elixir
defmodule Indrajaal.ZSM.ClosedLoop do
  @moduledoc """
  ETSI ZSM-compliant closed-loop automation for network management.

  Implements intent-based networking with autonomous decision-making
  for alarm response and network optimization.

  ## STAMP Constraints
  - SC-ZSM-001: Closed-loop cycle < 100ms
  - SC-ZSM-002: Intent translation accuracy > 99%
  - SC-ZSM-003: Policy conflict resolution
  - SC-ZSM-004: Human override capability
  """

  @type intent :: %{
    intent_id: String.t(),
    intent_type: :availability | :latency | :bandwidth | :security,
    target: String.t(),
    objective: map(),
    constraints: list(map()),
    priority: integer()
  }

  @type observation :: %{
    timestamp: DateTime.t(),
    metric: String.t(),
    value: float(),
    source: String.t()
  }

  @type decision :: %{
    decision_id: String.t(),
    intent_id: String.t(),
    action: atom(),
    parameters: map(),
    confidence: float()
  }

  @closed_loop_interval_ms 100

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    schedule_closed_loop()
    {:ok, %{
      intents: [],
      observations: [],
      decisions: [],
      policies: load_policies()
    }}
  end

  def handle_info(:closed_loop, state) do
    # OODA Loop: Observe -> Orient -> Decide -> Act

    # 1. OBSERVE: Collect current observations
    observations = collect_observations()

    # 2. ORIENT: Analyze against intents
    analysis = analyze_observations(observations, state.intents)

    # 3. DECIDE: Generate decisions based on analysis
    decisions = generate_decisions(analysis, state.policies)

    # 4. ACT: Execute decisions (with Guardian approval)
    execute_decisions(decisions)

    schedule_closed_loop()
    {:noreply, %{state |
      observations: observations,
      decisions: decisions
    }}
  end

  defp analyze_observations(observations, intents) do
    Enum.map(intents, fn intent ->
      relevant_obs = filter_observations(observations, intent.target)

      %{
        intent_id: intent.intent_id,
        current_state: compute_current_state(relevant_obs),
        target_state: intent.objective,
        gap: compute_gap(relevant_obs, intent.objective),
        trend: compute_trend(relevant_obs),
        action_required: gap_exceeds_threshold?(intent)
      }
    end)
  end

  defp generate_decisions(analysis, policies) do
    analysis
    |> Enum.filter(& &1.action_required)
    |> Enum.map(fn gap_analysis ->
      applicable_policies = find_applicable_policies(gap_analysis, policies)
      best_action = select_best_action(gap_analysis, applicable_policies)

      %{
        decision_id: UUID.uuid4(),
        intent_id: gap_analysis.intent_id,
        action: best_action.action,
        parameters: best_action.parameters,
        confidence: best_action.confidence
      }
    end)
    |> resolve_conflicts()
  end

  defp execute_decisions(decisions) do
    Enum.each(decisions, fn decision ->
      # Submit to Guardian for approval
      case GuardianIntegration.submit_proposal(decision) do
        {:ok, :approved} ->
          execute_action(decision)
          log_to_register(:decision_executed, decision)

        {:veto, reason, fallback} ->
          Logger.warning("Decision vetoed: #{reason}")
          if fallback, do: execute_action(fallback)
      end
    end)
  end
end
```

### 4.4 MEF LSO Sonata for Inter-Carrier Services

```elixir
defmodule Indrajaal.MEF.LSOSonata do
  @moduledoc """
  MEF LSO Sonata API integration for inter-carrier connectivity.

  Enables automated ordering of Carrier Ethernet services across
  partner networks for multi-site alarm monitoring deployments.

  ## STAMP Constraints
  - SC-MEF-001: LSO Sonata API v5.0 compliance
  - SC-MEF-002: Quote response < 24 hours
  - SC-MEF-003: Order completion < 72 hours for standard
  - SC-MEF-004: All orders to Immutable Register
  """

  @type serviceability_request :: %{
    buyerId: String.t(),
    sellerId: String.t(),
    requestedResponseDate: DateTime.t(),
    productOfferingQualificationItem: list(map())
  }

  @type quote_request :: %{
    buyerId: String.t(),
    sellerId: String.t(),
    requestedQuoteCompletionDate: DateTime.t(),
    quoteItem: list(map())
  }

  @type product_order :: %{
    buyerId: String.t(),
    sellerId: String.t(),
    orderActivity: :install | :change | :disconnect,
    requestedCompletionDate: DateTime.t(),
    orderItem: list(map())
  }

  @spec check_serviceability(map()) :: {:ok, map()} | {:error, term()}
  def check_serviceability(site_params) do
    # Find available sellers for the location
    request = %{
      buyerId: Application.get_env(:indrajaal, :mef_buyer_id),
      sellerId: "*",  # Query all sellers
      requestedResponseDate: DateTime.add(DateTime.utc_now(), 24 * 3600),
      productOfferingQualificationItem: [
        %{
          id: "1",
          product: %{
            "@type" => "MEFProductRefOrValue",
            productConfiguration: %{
              "@type" => "CarrierEthernetEvcEndPoint",
              identifier: site_params.site_id,
              evcEndPointMap: %{
                mapType: "PointToPoint"
              }
            },
            place: [
              %{
                "@type" => "GeographicAddressRef",
                role: "INSTALL_LOCATION",
                streetAddress: site_params.address.street,
                city: site_params.address.city,
                stateOrProvince: site_params.address.state,
                postcode: site_params.address.postal_code,
                country: site_params.address.country
              }
            ]
          }
        }
      ]
    }

    MEFClient.post("/mef/productOfferingQualificationManagement/v5/productOfferingQualification", request)
  end

  @spec request_quote(String.t(), map()) :: {:ok, map()}
  def request_quote(seller_id, service_params) do
    request = %{
      buyerId: Application.get_env(:indrajaal, :mef_buyer_id),
      sellerId: seller_id,
      requestedQuoteCompletionDate: DateTime.add(DateTime.utc_now(), 24 * 3600),
      quoteItem: [
        %{
          id: "1",
          action: "install",
          product: build_ethernet_product(service_params),
          requestedQuoteItemTerm: %{
            name: "12 Months",
            duration: %{amount: 12, units: "months"}
          }
        }
      ]
    }

    MEFClient.post("/mef/quoteManagement/v5/quote", request)
  end

  @spec place_order(String.t(), String.t()) :: {:ok, map()}
  def place_order(quote_id, accepted_quote_item_id) do
    {:ok, quote} = MEFClient.get("/mef/quoteManagement/v5/quote/#{quote_id}")
    quote_item = Enum.find(quote.quoteItem, & &1.id == accepted_quote_item_id)

    order = %{
      buyerId: Application.get_env(:indrajaal, :mef_buyer_id),
      sellerId: quote.sellerId,
      orderActivity: :install,
      requestedCompletionDate: DateTime.add(DateTime.utc_now(), 72 * 3600),
      orderItem: [
        %{
          id: "1",
          action: "install",
          quote: %{
            quoteId: quote_id,
            quoteItemId: accepted_quote_item_id
          },
          product: quote_item.product
        }
      ]
    }

    {:ok, response} = MEFClient.post("/mef/productOrderManagement/v5/productOrder", order)
    log_to_register(:mef_order_placed, response)

    {:ok, response}
  end
end
```

### 4.5 STAMP Constraints (SC-ORCH)

| ID | Constraint | Severity | Verification |
|----|------------|----------|--------------|
| SC-ORCH-001 | Slice instantiation < 10 seconds | CRITICAL | Timing |
| SC-ORCH-002 | Policy conflict resolution | HIGH | Logic |
| SC-ORCH-003 | Multi-domain coordination | HIGH | Integration |
| SC-ORCH-004 | Rollback on orchestration failure | CRITICAL | Recovery |
| SC-ZSM-001 | Closed-loop cycle < 100ms | CRITICAL | Performance |
| SC-ZSM-002 | Intent translation > 99% | HIGH | Accuracy |
| SC-ZSM-003 | Human override always available | CRITICAL | Safety |
| SC-ZSM-004 | Autonomous action audit trail | CRITICAL | Audit |
| SC-MEF-001 | LSO Sonata v5.0 compliance | HIGH | Spec |
| SC-MEF-002 | Quote response < 24 hours | MEDIUM | SLA |
| SC-MEF-003 | Standard order < 72 hours | MEDIUM | SLA |
| SC-MEF-004 | All orders to Immutable Register | CRITICAL | Audit |

---

## Part 5: eSIM/RSP Integration (GSMA SGP.32)

### 5.1 Overview

eSIM Remote SIM Provisioning enables cellular connectivity for alarm panels and IoT devices without physical SIM card handling.

**Standard**: GSMA SGP.32 (IoT eSIM) - released 2023, deployment-ready 2025
**Projection**: 2.3B RSP-capable connections by 2032

### 5.2 SGP.32 Benefits for Alarm Panels

| Feature | SGP.02 (Legacy M2M) | SGP.32 (IoT eSIM) |
|---------|---------------------|-------------------|
| Vendor lock-in | High | None (open ecosystem) |
| Profile download trigger | SMS | IP-based (no SMS) |
| Memory footprint | Large | Optimized for constrained devices |
| Profile switching | Complex | Simple, remote-controlled |
| Interoperability | Vendor-specific | GSMA standardized |

### 5.3 eSIM Architecture for Alarm Panels

```
┌─────────────────────────────────────────────────────────────────┐
│                  INDRAJAAL eSIM ARCHITECTURE                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   ┌─────────────────┐    ┌─────────────────┐                   │
│   │   ALARM PANEL   │    │   eIM (eSIM     │                   │
│   │   (eUICC)       │◄──►│   IoT Remote    │                   │
│   │                 │    │   Manager)      │                   │
│   └────────┬────────┘    └────────┬────────┘                   │
│            │                      │                             │
│            │                      ▼                             │
│            │             ┌─────────────────┐                   │
│            │             │    SM-DP+       │                   │
│            │             │  (Data Prep)    │                   │
│            │             └────────┬────────┘                   │
│            │                      │                             │
│            ▼                      ▼                             │
│   ┌──────────────────────────────────────────────────┐         │
│   │              PROFILE LIFECYCLE                    │         │
│   ├──────────────────────────────────────────────────┤         │
│   │  1. Download: eIM triggers profile download      │         │
│   │  2. Enable: Activate new carrier profile         │         │
│   │  3. Disable: Suspend current profile             │         │
│   │  4. Delete: Remove unused profiles               │         │
│   │  5. Switch: Change between carriers              │         │
│   └──────────────────────────────────────────────────┘         │
│                                                                 │
│   ┌──────────────────────────────────────────────────┐         │
│   │              CARRIER PARTNERS                     │         │
│   │  • Primary: T-Mobile / Deutsche Telekom          │         │
│   │  • Backup: Vodafone / Verizon                    │         │
│   │  • Failover: Local MVNOs                         │         │
│   └──────────────────────────────────────────────────┘         │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 5.4 Elixir eSIM Manager

```elixir
defmodule Indrajaal.eSIM.Manager do
  @moduledoc """
  GSMA SGP.32 eSIM Manager for IoT device connectivity.

  Manages eSIM profiles on alarm panels and IoT sensors,
  enabling remote carrier switching and connectivity assurance.

  ## STAMP Constraints
  - SC-ESIM-001: Profile download < 60 seconds
  - SC-ESIM-002: Carrier failover < 30 seconds
  - SC-ESIM-003: All profile ops to Immutable Register
  - SC-ESIM-004: Backup profile always available
  """

  use GenServer

  @type euicc :: %{
    eid: String.t(),
    device_id: String.t(),
    site_id: String.t(),
    profiles: list(profile()),
    active_profile_iccid: String.t() | nil
  }

  @type profile :: %{
    iccid: String.t(),
    carrier: String.t(),
    state: :enabled | :disabled | :deleted,
    apn: String.t(),
    data_usage_mb: float(),
    last_seen: DateTime.t()
  }

  @spec download_profile(String.t(), String.t()) :: {:ok, profile()} | {:error, term()}
  def download_profile(eid, carrier_id) do
    # 1. Request profile from SM-DP+
    {:ok, smdp_response} = SMDP.request_profile(carrier_id, eid)

    # 2. Send download command to eIM
    {:ok, download_result} = eIM.download_profile(eid, smdp_response.activation_code)

    # 3. Wait for confirmation
    {:ok, profile} = wait_for_download_complete(eid, download_result.transaction_id)

    # 4. Log to register
    log_to_register(:profile_downloaded, %{eid: eid, iccid: profile.iccid, carrier: carrier_id})

    {:ok, profile}
  end

  @spec switch_carrier(String.t(), String.t()) :: {:ok, profile()} | {:error, term()}
  def switch_carrier(eid, new_carrier_id) do
    {:ok, euicc} = get_euicc(eid)

    # Find or download target profile
    target_profile = case find_profile_by_carrier(euicc, new_carrier_id) do
      nil ->
        {:ok, profile} = download_profile(eid, new_carrier_id)
        profile
      profile ->
        profile
    end

    # Disable current profile
    if euicc.active_profile_iccid do
      {:ok, _} = eIM.disable_profile(eid, euicc.active_profile_iccid)
    end

    # Enable new profile
    {:ok, enabled_profile} = eIM.enable_profile(eid, target_profile.iccid)

    # Update state
    log_to_register(:carrier_switched, %{
      eid: eid,
      from: euicc.active_profile_iccid,
      to: enabled_profile.iccid
    })

    {:ok, enabled_profile}
  end

  @spec handle_connectivity_failure(String.t()) :: {:ok, profile()} | {:error, :no_backup}
  def handle_connectivity_failure(eid) do
    {:ok, euicc} = get_euicc(eid)

    # Find backup profile
    backup = euicc.profiles
    |> Enum.filter(& &1.iccid != euicc.active_profile_iccid)
    |> Enum.filter(& &1.state != :deleted)
    |> List.first()

    case backup do
      nil ->
        {:error, :no_backup}

      backup_profile ->
        Logger.warning("Connectivity failure on #{eid}, switching to #{backup_profile.carrier}")
        switch_carrier(eid, backup_profile.carrier)
    end
  end
end
```

### 5.5 STAMP Constraints (SC-ESIM)

| ID | Constraint | Severity | Verification |
|----|------------|----------|--------------|
| SC-ESIM-001 | Profile download < 60 seconds | HIGH | Timing |
| SC-ESIM-002 | Carrier failover < 30 seconds | CRITICAL | Timing |
| SC-ESIM-003 | All profile ops to Register | CRITICAL | Audit |
| SC-ESIM-004 | Backup profile always available | HIGH | Redundancy |
| SC-ESIM-005 | SGP.32 compliance | HIGH | Spec |
| SC-ESIM-006 | eUICC certificate validation | CRITICAL | Security |
| SC-ESIM-007 | Profile encryption in transit | CRITICAL | Security |
| SC-ESIM-008 | Multi-carrier strategy per site | MEDIUM | Availability |

---

## Part 6: Integrated Telecom Services Architecture

### 6.1 Complete Integration View

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    INDRAJAAL TELECOM-GRADE ARCHITECTURE                      │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │                        FIELD LAYER                                   │   │
│   │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐ │   │
│   │  │ Alarm Panel │  │  IP Camera  │  │ IoT Sensor  │  │   Gateway   │ │   │
│   │  │   (eUICC)   │  │   (WiFi)    │  │  (Zigbee)   │  │   (5G/LTE)  │ │   │
│   │  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘ │   │
│   │         │                │                │                │         │   │
│   │         └────────────────┴────────────────┴────────────────┘         │   │
│   │                                  │                                   │   │
│   │                                  ▼                                   │   │
│   │                    ┌─────────────────────────┐                       │   │
│   │                    │   ZTP BOOTSTRAPPER      │                       │   │
│   │                    │   (DHCP + mDNS + SSDP)  │                       │   │
│   │                    └────────────┬────────────┘                       │   │
│   └─────────────────────────────────┼───────────────────────────────────┘   │
│                                     │                                        │
│   ┌─────────────────────────────────┼───────────────────────────────────┐   │
│   │                     CONNECTIVITY LAYER                               │   │
│   │                                 │                                    │   │
│   │  ┌──────────────────┐  ┌────────┴────────┐  ┌──────────────────┐    │   │
│   │  │   GSMA SGP.32    │  │   CAMARA QoD    │  │   MEF LSO        │    │   │
│   │  │   eSIM Manager   │  │   QoS Manager   │  │   Inter-Carrier  │    │   │
│   │  └────────┬─────────┘  └────────┬────────┘  └────────┬─────────┘    │   │
│   │           │                     │                    │               │   │
│   │           └─────────────────────┴────────────────────┘               │   │
│   │                                 │                                    │   │
│   │                                 ▼                                    │   │
│   │           ┌─────────────────────────────────────────────┐            │   │
│   │           │     NETWORK ORCHESTRATION (ONAP/OSM/ZSM)    │            │   │
│   │           │  • Slice Management                         │            │   │
│   │           │  • Closed-Loop Automation                   │            │   │
│   │           │  • Intent-Based Networking                  │            │   │
│   │           └─────────────────────┬───────────────────────┘            │   │
│   └─────────────────────────────────┼───────────────────────────────────┘   │
│                                     │                                        │
│   ┌─────────────────────────────────┼───────────────────────────────────┐   │
│   │                     PLATFORM LAYER                                   │   │
│   │                                 │                                    │   │
│   │    ┌────────────────────────────┼────────────────────────────┐       │   │
│   │    │                  ZENOH MESH NETWORK                     │       │   │
│   │    │  key: indrajaal/{domain}/{tenant}/{site}/{resource}    │       │   │
│   │    └────────────────────────────┬────────────────────────────┘       │   │
│   │                                 │                                    │   │
│   │    ┌─────────────┐  ┌──────────┴─────────┐  ┌─────────────┐         │   │
│   │    │   Prajna    │  │   Alarm Processor  │  │  Video      │         │   │
│   │    │   Cockpit   │  │   (AI Verification)│  │  Analytics  │         │   │
│   │    └──────┬──────┘  └──────────┬─────────┘  └──────┬──────┘         │   │
│   │           │                    │                    │                │   │
│   │           └────────────────────┴────────────────────┘                │   │
│   │                                │                                     │   │
│   │                                ▼                                     │   │
│   │           ┌─────────────────────────────────────────────┐            │   │
│   │           │            IMMUTABLE REGISTER               │            │   │
│   │           │  (SQLite/DuckDB + Ed25519 + SHA3-256)       │            │   │
│   │           └─────────────────────────────────────────────┘            │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │                       OSS/BSS LAYER                                  │   │
│   │                                                                      │   │
│   │   ┌──────────────────────────────────────────────────────────────┐  │   │
│   │   │                    TM FORUM OPEN APIs                        │  │   │
│   │   │                                                              │  │   │
│   │   │  TMF620  TMF621  TMF622  TMF629  TMF637  TMF638  TMF688     │  │   │
│   │   │  Catalog Ticket  Order   Customer Prod    Svc    Event      │  │   │
│   │   │                         Mgmt     Inventory Inventory Mgmt    │  │   │
│   │   └──────────────────────────────────────────────────────────────┘  │   │
│   │                                                                      │   │
│   │   ┌──────────────┐  ┌──────────────┐  ┌──────────────┐              │   │
│   │   │  Fault Mgmt  │  │  Config Mgmt │  │   Billing    │              │   │
│   │   │  (OSS)       │  │  (OSS)       │  │   (BSS)      │              │   │
│   │   └──────────────┘  └──────────────┘  └──────────────┘              │   │
│   │                                                                      │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 6.2 Implementation Roadmap

| Phase | Quarter | Focus | Key Deliverables |
|-------|---------|-------|------------------|
| **1** | Q1 2026 | ZTP Foundation | ZTP Orchestrator, DHCP/mDNS bootstrap, X.509 PKI |
| **2** | Q1-Q2 2026 | TMF Core APIs | TMF621 (Ticketing), TMF622 (Ordering), TMF688 (Events) |
| **3** | Q2 2026 | OSS/BSS Integration | Fault Management, Billing Engine, Product Catalog |
| **4** | Q2-Q3 2026 | eSIM/RSP | SGP.32 integration, Multi-carrier profiles, Failover |
| **5** | Q3 2026 | Network Orchestration | ONAP/OSM integration, ZSM closed-loop, MEF LSO |
| **6** | Q4 2026 | Full Integration | End-to-end testing, Carrier certification, Production |

### 6.3 STAMP Constraint Summary

| Domain | Constraint Count | Critical | High | Medium |
|--------|------------------|----------|------|--------|
| ZTP | 10 | 3 | 5 | 2 |
| TMF | 10 | 2 | 6 | 2 |
| OSS/BSS | 12 | 3 | 6 | 3 |
| Orchestration | 10 | 5 | 4 | 1 |
| eSIM | 8 | 4 | 3 | 1 |
| **TOTAL** | **50** | **17** | **24** | **9** |

---

## Part 7: Competitive Differentiation

### 7.1 Telecom-Grade Capabilities vs. Competitors

| Capability | Indrajaal | Milestone | Genetec | Eagle Eye |
|------------|-----------|-----------|---------|-----------|
| ZTP Device Onboarding | Full ETSI ZSM | Manual | Partial | None |
| TMF Forum APIs | 15+ APIs | None | None | None |
| eSIM Management | SGP.32 | None | None | None |
| Network Slicing | ONAP/OSM | None | None | None |
| Carrier QoS | CAMARA QoD | None | None | None |
| Inter-Carrier Orchestration | MEF LSO | None | None | None |
| Closed-Loop Automation | ETSI ZSM | None | None | None |

### 7.2 Value Proposition

**For Operators/CSPs**:
- White-label alarm platform with full OSS/BSS integration
- New revenue stream from security vertical
- Leverage existing 5G/LTE infrastructure

**For Dealers/Integrators**:
- Automated device provisioning (ZTP)
- Simplified multi-site deployments
- Carrier-agnostic connectivity (eSIM)

**For Enterprise Customers**:
- Carrier-grade reliability (99.999%)
- Guaranteed QoS for critical alarms
- Single pane of glass operations

---

## References

### Standards Organizations
- [TM Forum Open APIs](https://www.tmforum.org/oda/open-apis/)
- [ETSI ZSM](https://www.etsi.org/technologies/zero-touch-network-service-management)
- [MEF LSO Sonata](https://www.mef.net/service-automation/lso-apis/inter-provider-apis/lso-sonata/)
- [GSMA eSIM](https://www.gsma.com/solutions-and-impact/technologies/esim/)
- [ONAP](https://docs.onap.org/)
- [OSM](https://osm.etsi.org/)

### Technical References
- [TMF621 Trouble Ticket v5.0.0](https://www.tmforum.org/resources/specifications/tmf621-trouble-ticket-management-api-user-guide-v5-0-0/)
- [TMF622 Product Ordering v4.0.0](https://tmf-open-api-table-documents.s3.eu-west-1.amazonaws.com/)
- [GSMA SGP.32 Specification](https://www.telit.com/blog/gsma-sgp32-specification-esim/)
- [ETSI ZSM Closed-Loop](https://zsmwiki.etsi.org/index.php?title=Topic_3_-_Intent-driven_Closed-Loop_automation)
- [MEF LSO Sonata/Cantata](https://amartus.com/digitalization-of-inter-partner-processes-using-mef-lso-sonata-cantata-standard/)

---

**Document Statistics**:
- **New STAMP Constraints**: 50 (SC-ZTP-10, SC-TMF-10, SC-OSS-6, SC-BSS-6, SC-ORCH-4, SC-ZSM-4, SC-MEF-4, SC-ESIM-8)
- **New Elixir Modules**: 8 (ZTP, TMF621, TMF622, TMF688, OSS, BSS, ZSM, eSIM)
- **Integration Points**: 15+ TMF APIs, ETSI ZSM, MEF LSO, GSMA SGP.32, ONAP, OSM
- **Compliance**: TM Forum ODA, ETSI ZSM, MEF 3.0, GSMA RSP, 3GPP SA5
