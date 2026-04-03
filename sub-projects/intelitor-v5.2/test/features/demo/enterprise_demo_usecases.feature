@demo @enterprise @usecases @P0
Feature: Enterprise Demo Use Cases - Full End-to-End Coverage
  As a system demonstrator
  I need comprehensive demo scenarios
  So that I can showcase all enterprise capabilities

  Background:
    Given the Indrajaal system is fully operational
    And all 3 containers are healthy (db, obs, app)
    And the Zenoh mesh is connected
    And demo data has been seeded

  # =============================================================================
  # ALARM RECEIVING CENTER (ARC) DEMO FLOWS
  # =============================================================================

  @arc @alarm-lifecycle @P0
  Scenario: DEMO-ARC-001 - Complete alarm lifecycle demonstration
    Given I am demonstrating the alarm receiving workflow
    When I simulate an intrusion alarm from a commercial site:
      | Field         | Value                      |
      | Site          | Acme Corp HQ               |
      | Zone          | Main Entrance              |
      | Alarm Type    | Intrusion - Motion Sensor  |
      | Severity      | Critical                   |
      | SIA Code      | BA (Burglary Alarm)        |
    Then the alarm should appear in Prajna within 1 second
    And the operator screen should pop with site details
    And the following response actions should be available:
      | Action          | Description               |
      | Call Subscriber | One-click phone call      |
      | Dispatch Guard  | Send armed response       |
      | Police Alert    | Emergency services        |
      | Verify Video    | View live camera feed     |
    When the operator acknowledges and dispatches guard
    Then the alarm status should update to "In Progress"
    And the guard mobile app should receive dispatch
    When the guard reports "All Clear"
    Then the alarm should be resolved
    And a complete audit trail should be available

  @arc @multi-alarm @P0
  Scenario: DEMO-ARC-002 - Multi-alarm handling demonstration
    Given I am demonstrating concurrent alarm handling
    When 5 alarms arrive simultaneously:
      | Site       | Type        | Severity |
      | Site A     | Fire        | Critical |
      | Site B     | Intrusion   | High     |
      | Site C     | Medical     | Critical |
      | Site D     | Technical   | Low      |
      | Site E     | Panic       | Critical |
    Then alarms should be auto-prioritized by severity
    And critical alarms should be highlighted
    And the operator should see clear priority indicators
    And the fire/medical alarms should suggest immediate escalation

  @arc @video-verification @P1
  Scenario: DEMO-ARC-003 - Video verification workflow
    Given an intrusion alarm has been received
    When the operator clicks "Verify Video"
    Then live camera feeds from the site should display
    And the operator should be able to:
      | Action       | Description              |
      | View Live    | Real-time video          |
      | PTZ Control  | Pan/Tilt/Zoom cameras    |
      | Playback     | Review pre-alarm footage |
      | Snapshot     | Capture evidence image   |
      | Record       | Start evidence recording |

  @arc @escalation @P0
  Scenario: DEMO-ARC-004 - Escalation chain demonstration
    Given a critical alarm has not been handled for 60 seconds
    Then the escalation process should trigger:
      | Level | Action                    | Recipient          |
      | 1     | Visual alert              | Primary operator   |
      | 2     | Audio escalation          | Supervisor         |
      | 3     | SMS notification          | On-call manager    |
      | 4     | Automatic dispatch        | Response team      |
    And each escalation should be logged

  @arc @sla @P0 @SC-IMMUNE-007
  Scenario: DEMO-ARC-005 - SLA compliance demonstration
    Given I am demonstrating SLA monitoring
    Then the dashboard should show:
      | Metric             | Target   | Current |
      | Response Time      | <60s     | 45s     |
      | Resolution Rate    | >95%     | 97.2%   |
      | Alarm Accuracy     | >99%     | 99.5%   |
      | Customer Sat       | >4.5/5   | 4.7/5   |
    And SLA breaches should be highlighted in red
    And trending reports should be accessible

  # =============================================================================
  # SITE MANAGEMENT DEMO FLOWS
  # =============================================================================

  @site @onboarding @P0
  Scenario: DEMO-SITE-001 - New site onboarding demonstration
    Given I am demonstrating site onboarding
    When I create a new site with:
      | Field            | Value                  |
      | Name             | New Customer Site      |
      | Address          | 123 Main St, City      |
      | Type             | Commercial             |
      | Contract         | 24/7 Monitoring        |
      | Primary Contact  | John Doe, 555-0100     |
      | Response Plan    | Armed Response + Police|
    Then the site should be created in the system
    And default zones should be configured
    And the site should appear on the map view
    And panel programming details should be generated

  @site @zones @P1
  Scenario: DEMO-SITE-002 - Zone configuration demonstration
    Given I am on the site configuration page
    When I configure zones:
      | Zone ID | Name           | Type       | Schedule      |
      | Z001    | Main Entrance  | Motion     | 24/7          |
      | Z002    | Back Door      | Contact    | Night Only    |
      | Z003    | Server Room    | Temperature| 24/7          |
      | Z004    | Parking        | Camera     | Business Hours|
    Then each zone should be independently monitorable
    And zone-specific response plans should be configurable

  @site @maintenance @P1
  Scenario: DEMO-SITE-003 - Site maintenance workflow
    Given a site requires scheduled maintenance
    When I create a maintenance window:
      | Field       | Value                     |
      | Site        | Acme Corp HQ              |
      | Start       | 2026-01-15 09:00          |
      | End         | 2026-01-15 12:00          |
      | Zones       | All zones                 |
      | Reason      | Annual sensor test        |
    Then alarms from this site should be marked as "Test"
    And the maintenance status should be visible
    And normal monitoring should resume after the window

  # =============================================================================
  # SUBSCRIBER MANAGEMENT DEMO FLOWS
  # =============================================================================

  @subscriber @management @P0
  Scenario: DEMO-SUB-001 - Subscriber CRM demonstration
    Given I am demonstrating subscriber management
    When I view a subscriber profile
    Then I should see comprehensive information:
      | Section        | Content                    |
      | Contact Info   | Phone, Email, Address      |
      | Sites          | All monitored sites        |
      | Contracts      | Active service agreements  |
      | Billing        | Payment history            |
      | History        | Alarm and service history  |
      | Notes          | Operator annotations       |

  @subscriber @communication @P1
  Scenario: DEMO-SUB-002 - Subscriber communication workflow
    Given I need to contact a subscriber
    When I select communication options
    Then the following should be available:
      | Channel     | Features                   |
      | Phone       | Click-to-call, recording   |
      | SMS         | Templates, scheduling      |
      | Email       | Rich formatting, attachments|
      | Portal      | Self-service message       |
    And all communications should be logged

  # =============================================================================
  # GUARD TOUR DEMO FLOWS
  # =============================================================================

  @guard @tour @P1
  Scenario: DEMO-GUARD-001 - Guard tour management
    Given I am demonstrating guard tour functionality
    When I create a patrol route:
      | Checkpoint | Location       | Required Action     |
      | CP1        | Main Gate      | QR Scan + Photo     |
      | CP2        | Building A     | Door Check          |
      | CP3        | Parking Lot    | Perimeter Walk      |
      | CP4        | Server Room    | Temperature Check   |
    Then the guard mobile app should display the route
    And real-time tracking should be available
    And missed checkpoints should trigger alerts

  @guard @incident @P1
  Scenario: DEMO-GUARD-002 - Guard incident reporting
    Given a guard is on patrol
    When the guard encounters an incident
    Then they should be able to:
      | Action        | Description              |
      | Photo/Video   | Capture evidence         |
      | Voice Report  | Audio recording          |
      | GPS Tag       | Exact location           |
      | Escalate      | Immediate dispatch       |
    And the report should appear in Prajna immediately

  # =============================================================================
  # REPORTING & ANALYTICS DEMO FLOWS
  # =============================================================================

  @reports @executive @P0
  Scenario: DEMO-RPT-001 - Executive dashboard demonstration
    Given I am demonstrating executive reporting
    Then the dashboard should display:
      | KPI              | Visualization        |
      | Revenue          | Monthly trend chart  |
      | Active Sites     | Growth graph         |
      | SLA Performance  | Gauge meters         |
      | Alarm Volume     | Heat map by time     |
      | Response Times   | Distribution chart   |

  @reports @operational @P1
  Scenario: DEMO-RPT-002 - Operational reports demonstration
    Given I am generating operational reports
    Then the following reports should be available:
      | Report Type      | Content                   |
      | Daily Activity   | All alarms, resolutions   |
      | Operator Stats   | Performance per operator  |
      | Site Activity    | Per-site alarm history    |
      | SLA Report       | Compliance metrics        |
      | Trend Analysis   | Period-over-period        |

  @reports @scheduling @P1
  Scenario: DEMO-RPT-003 - Automated report scheduling
    Given I configure automated reports
    When I set up a scheduled report:
      | Field       | Value                   |
      | Report      | Weekly SLA Summary      |
      | Schedule    | Every Monday 8:00 AM    |
      | Recipients  | management@example.com  |
      | Format      | PDF + Excel             |
    Then the report should be generated automatically
    And delivered to the specified recipients

  # =============================================================================
  # COMPLIANCE DEMO FLOWS
  # =============================================================================

  @compliance @en50518 @P0
  Scenario: DEMO-CMP-001 - EN 50518 compliance demonstration
    Given I am demonstrating regulatory compliance
    Then the system should show compliance with:
      | Requirement        | Evidence                   |
      | Dual control center| Redundancy configuration   |
      | Response times     | SLA metrics dashboard      |
      | Operator training  | Certification records      |
      | Data retention     | Archival policies          |
      | Audit trails       | Immutable event logs       |

  @compliance @gdpr @P1
  Scenario: DEMO-CMP-002 - GDPR compliance demonstration
    Given I am demonstrating data protection
    Then the following should be demonstrable:
      | Feature           | Implementation             |
      | Data access       | User data export           |
      | Right to delete   | Anonymization workflow     |
      | Consent tracking  | Consent management UI      |
      | Breach reporting  | Incident response plan     |

  # =============================================================================
  # INTEGRATION DEMO FLOWS
  # =============================================================================

  @integration @panels @P0
  Scenario: DEMO-INT-001 - Panel integration demonstration
    Given I am demonstrating panel connectivity
    When I receive signals from different panel types:
      | Panel Type  | Protocol  | Example Event        |
      | DSC         | SIA DC-07 | Zone 1 Burglar       |
      | Honeywell   | Contact ID| Fire Alarm           |
      | Bosch       | SIA IP    | Medical Emergency    |
      | Ajax        | Cloud API | Motion Detection     |
    Then all events should be normalized
    And displayed consistently in Prajna

  @integration @dispatch @P1
  Scenario: DEMO-INT-002 - Dispatch integration demonstration
    Given I am demonstrating dispatch systems
    When a dispatch is created
    Then the following integrations should work:
      | System          | Action                    |
      | Guard App       | Push notification         |
      | GPS Tracking    | Vehicle location update   |
      | CAD System      | Incident creation         |
      | Emergency Svcs  | API notification          |

  @integration @billing @P1
  Scenario: DEMO-INT-003 - Billing integration demonstration
    Given I am demonstrating billing integration
    Then the following should be demonstrable:
      | Feature         | Description               |
      | Usage metering  | Alarm/service counts      |
      | Invoice gen     | Automated billing         |
      | Payment sync    | Gateway integration       |
      | Contract mgmt   | Renewal tracking          |

  # =============================================================================
  # AI/ML DEMO FLOWS
  # =============================================================================

  @ai @copilot @P0 @SC-PRAJNA-002
  Scenario: DEMO-AI-001 - AI Copilot demonstration
    Given I am demonstrating AI capabilities
    When I interact with the AI Copilot:
      | Query                              | Expected Response Type    |
      | "What's the trend for Site A?"     | Analytical summary        |
      | "Suggest staffing for next week"   | Predictive recommendation |
      | "Why did this alarm trigger?"      | Root cause analysis       |
      | "Draft a customer report"          | Generated document        |
    Then responses should be accurate and actionable

  @ai @pattern @P1
  Scenario: DEMO-AI-002 - Pattern detection demonstration
    Given I am demonstrating PatternHunter
    When patterns are detected:
      | Pattern               | Example                    |
      | False alarm sources   | Faulty sensor detection    |
      | Seasonal trends       | Weather-related alarms     |
      | Anomaly detection     | Unusual activity patterns  |
    Then insights should be displayed in dashboard
    And recommendations should be provided

  @ai @prediction @P1
  Scenario: DEMO-AI-003 - Predictive analytics demonstration
    Given I am demonstrating prediction capabilities
    Then the following predictions should be available:
      | Prediction         | Use Case                   |
      | Alarm volume       | Staffing planning          |
      | Equipment failure  | Preventive maintenance     |
      | Churn risk         | Customer retention         |
      | Seasonal patterns  | Resource allocation        |

  # =============================================================================
  # MOBILE APP DEMO FLOWS
  # =============================================================================

  @mobile @operator @P0
  Scenario: DEMO-MOB-001 - Mobile operator app demonstration
    Given I am demonstrating the mobile operator app
    Then the following features should work:
      | Feature          | Description               |
      | Alarm list       | Real-time alarm feed      |
      | Acknowledge      | One-tap acknowledgment    |
      | Call subscriber  | Click-to-call            |
      | Notes            | Voice-to-text notes       |
      | Offline mode     | Queue actions when offline|

  @mobile @guard @P1
  Scenario: DEMO-MOB-002 - Guard mobile app demonstration
    Given I am demonstrating the guard mobile app
    Then the following features should work:
      | Feature          | Description               |
      | Tour tracking    | GPS breadcrumb trail      |
      | Checkpoint scan  | NFC/QR verification       |
      | Incident report  | Photo + voice capture     |
      | Panic button     | Emergency escalation      |

  @mobile @customer @P1
  Scenario: DEMO-MOB-003 - Customer mobile app demonstration
    Given I am demonstrating the customer self-service app
    Then the following features should work:
      | Feature          | Description               |
      | Arm/Disarm       | Remote system control     |
      | Activity log     | Recent events             |
      | Panic alert      | Emergency signal          |
      | Contact ARC      | Direct communication      |

  # =============================================================================
  # HIGH AVAILABILITY DEMO FLOWS
  # =============================================================================

  @ha @failover @P0
  Scenario: DEMO-HA-001 - High availability demonstration
    Given I am demonstrating HA capabilities
    When I simulate a node failure
    Then the following should occur:
      | Phase           | Time      | Action                |
      | Detection       | <5 sec    | Health check fails    |
      | Failover        | <30 sec   | Secondary takes over  |
      | Recovery        | <60 sec   | Failed node restarts  |
      | Sync            | <120 sec  | State synchronized    |
    And no alarms should be lost during failover

  @ha @backup @P1
  Scenario: DEMO-HA-002 - Backup and recovery demonstration
    Given I am demonstrating backup capabilities
    Then the following should be demonstrable:
      | Feature         | RPO       | RTO        |
      | Database        | <5 min    | <15 min    |
      | Configuration   | <1 hour   | <30 min    |
      | Full system     | <24 hours | <4 hours   |

  # =============================================================================
  # PERFORMANCE DEMO FLOWS
  # =============================================================================

  @performance @scale @P0
  Scenario: DEMO-PERF-001 - Scale demonstration
    Given I am demonstrating system capacity
    Then the following scale should be demonstrable:
      | Metric              | Capacity           |
      | Concurrent users    | 1,000+             |
      | Sites monitored     | 100,000+           |
      | Alarms per hour     | 50,000+            |
      | Event throughput    | 10,000/sec         |
      | Storage retention   | 7+ years           |

  @performance @response @P0
  Scenario: DEMO-PERF-002 - Response time demonstration
    Given I am demonstrating system performance
    Then the following response times should be achievable:
      | Operation           | Target    | Demo      |
      | Alarm reception     | <1 sec    | ~500ms    |
      | Screen pop          | <2 sec    | ~1 sec    |
      | Report generation   | <30 sec   | ~15 sec   |
      | Video load          | <3 sec    | ~2 sec    |
