# SONNET 4 EXECUTION CHECKLIST - 8 DOMAIN IMPLEMENTATION

**Purpose**: Step-by-step checklist for Sonnet 4 to execute the comprehensive 8-domain implementation plan
**Timeline**: 14 days total
**Resources**: 88 new resources across 8 domains
**Outcome**: Transform Indrajaal from 68+ to 156+ resources

---

## PRE-IMPLEMENTATION CHECKLIST

### Environment Verification
- [ ] PostgreSQL 17 running on port 5433
- [ ] Elixir 1.19.1 + OTP 27 verified
- [ ] All 12 existing domains operational
- [ ] Factory system fixed and working
- [ ] Test coverage baseline established

### Project Setup
- [ ] Create all domain directories
  ```bash
  mkdir -p lib/indrajaal/{access_control,guard_tour,analytics,communication,asset_management,risk_management,visitor_management,training}
  ```
- [ ] Create test directories
  ```bash
  mkdir -p test/indrajaal/{access_control,guard_tour,analytics,communication,asset_management,risk_management,visitor_management,training}
  ```
- [ ] Verify multi-tenant patterns in BaseResource

---

## DOMAIN 1: ACCESS CONTROL (Days 2-4)

### Day 2: Core Resources
- [ ] Create `lib/indrajaal/access_control.ex` domain module
- [ ] Implement AccessCredential resource
  - [ ] All attributes defined
  - [ ] Relationships configured
  - [ ] Actions implemented
  - [ ] Policies set up
  - [ ] Code interface defined
- [ ] Implement AccessLevel resource
  - [ ] Hierarchical levels support
  - [ ] Time restrictions
  - [ ] Access point mapping
- [ ] Create tests for both resources
- [ ] Run tests, fix any issues

### Day 3: Request & Grant System
- [ ] Implement AccessSchedule resource
  - [ ] Weekly schedules
  - [ ] Holiday support
  - [ ] Exception handling
- [ ] Implement AccessRequest resource
  - [ ] Approval workflow
  - [ ] Multi-level approvals
- [ ] Implement AccessGrant resource
  - [ ] Grant lifecycle
  - [ ] Use count tracking
- [ ] Integration tests for request→approval→grant flow

### Day 4: Logging & Advanced Features
- [ ] Implement AccessLog resource
  - [ ] High-performance indexes
  - [ ] Security event detection
  - [ ] Alarm integration
- [ ] Implement remaining 4 resources:
  - [ ] AccessRevocation
  - [ ] VisitorPass
  - [ ] AntiPassback
  - [ ] AccessException
- [ ] Generate migration: `mix ash_postgres.generate_migrations create_access_control --domains Indrajaal.AccessControl`
- [ ] Run migration: `mix ecto.migrate`
- [ ] Full domain integration test

**Success Criteria**: 10 resources operational, integration with Sites/Devices domains verified

---

## DOMAIN 2: ANALYTICS (Days 5-7)

### Day 5: Metrics Foundation
- [ ] Create `lib/indrajaal/analytics.ex` domain module
- [ ] Implement SecurityMetric resource
  - [ ] Time-series optimization
  - [ ] Multi-dimensional metrics
  - [ ] Threshold calculations
- [ ] Implement TrendAnalysis resource
  - [ ] Statistical calculations
  - [ ] Prediction models
- [ ] Implement HeatMap resource
  - [ ] Geographic visualization
  - [ ] Temporal patterns
- [ ] Set up TimescaleDB extension

### Day 6: Dashboards & Real-time
- [ ] Implement SecurityDashboard resource
  - [ ] Widget configuration
  - [ ] Layout management
  - [ ] Sharing controls
- [ ] Implement RiskScore resource
  - [ ] Real-time calculation
  - [ ] Multi-factor scoring
- [ ] Implement AlertCorrelation resource
  - [ ] Cross-domain correlation
  - [ ] Pattern matching
- [ ] Create Phoenix LiveView dashboard components

### Day 7: Advanced Analytics
- [ ] Implement remaining 6 resources:
  - [ ] PredictiveModel
  - [ ] AnomalyDetection
  - [ ] BehaviorProfile
  - [ ] IncidentPrediction
  - [ ] PerformanceMetric
  - [ ] ComplianceScore
- [ ] Generate and run migration
- [ ] Performance testing with sample data
- [ ] Real-time dashboard testing

**Success Criteria**: 12 resources operational, real-time dashboards working, TimescaleDB integrated

---

## DOMAIN 3: GUARD TOUR (Day 8)

### All Resources in One Day
- [ ] Create domain module
- [ ] Implement all 8 resources:
  - [ ] TourRoute (with checkpoints)
  - [ ] Checkpoint (QR/NFC/GPS support)
  - [ ] TourSchedule (recurrence patterns)
  - [ ] TourExecution (actual patrols)
  - [ ] CheckpointScan (verification)
  - [ ] TourException (deviations)
  - [ ] GuardAssignment (scheduling)
  - [ ] TourReport (completion reports)
- [ ] Integration with Sites and Dispatch domains
- [ ] Generate and run migration
- [ ] End-to-end patrol workflow test

**Success Criteria**: 8 resources operational, patrol workflow verified

---

## DOMAIN 4: COMMUNICATION (Day 9)

### All Resources in One Day
- [ ] Create domain module
- [ ] Implement all 9 resources:
  - [ ] MessageTemplate (multi-channel)
  - [ ] BroadcastMessage (mass notifications)
  - [ ] CommunicationChannel (SMS/Email/Push/Voice)
  - [ ] ContactList (groups)
  - [ ] MessageLog (audit trail)
  - [ ] DeliveryStatus (tracking)
  - [ ] CommunicationPreference (user settings)
  - [ ] EmergencyContact (crisis contacts)
  - [ ] IncidentUpdate (real-time updates)
- [ ] Integration with existing notification system
- [ ] Generate and run migration
- [ ] Multi-channel delivery test

**Success Criteria**: 9 resources operational, multi-channel notifications working

---

## DOMAIN 5-8: REMAINING DOMAINS (Day 10)

### Asset Management Domain
- [ ] Create domain module
- [ ] Implement 10 resources (Asset, AssetCategory, etc.)
- [ ] Depreciation calculations
- [ ] Movement tracking

### Risk Management Domain
- [ ] Create domain module
- [ ] Implement 10 resources (RiskAssessment, RiskMatrix, etc.)
- [ ] Risk scoring algorithms
- [ ] Control effectiveness

### Visitor Management Domain
- [ ] Create domain module
- [ ] Implement 10 resources (Visitor, PreRegistration, etc.)
- [ ] Watch list integration
- [ ] Badge printing support

### Training & Documentation Domain
- [ ] Create domain module
- [ ] Implement 8 resources (TrainingModule, Certification, etc.)
- [ ] Completion tracking
- [ ] Compliance reporting

**Success Criteria**: All 38 resources operational across 4 domains

---

## INTEGRATION & TESTING (Days 11-12)

### Day 11: Migration & Database
- [ ] Generate migrations for domains 5-8
- [ ] Run all migrations
- [ ] Verify all 88 new tables created
- [ ] Check indexes and foreign keys
- [ ] Performance baseline testing

### Day 12: Integration Testing
- [ ] Cross-domain workflow tests:
  - [ ] Access request → Grant → Log → Analytics
  - [ ] Alarm → Communication → Dispatch
  - [ ] Asset → Maintenance → Risk Assessment
  - [ ] Visitor → Access → Audit Log
- [ ] API documentation generation
- [ ] Load testing key resources
- [ ] Security audit of new domains

---

## WORKFLOW ENGINE INTEGRATION (Day 13)

### Cross-Cutting Implementation
- [ ] Create workflow engine tables
- [ ] Implement 5 workflow resources:
  - [ ] WorkflowDefinition
  - [ ] WorkflowInstance
  - [ ] WorkflowStep
  - [ ] WorkflowTransition
  - [ ] WorkflowVariable
- [ ] Retrofit into existing domains:
  - [ ] Access approval workflows
  - [ ] Incident response workflows
  - [ ] Maintenance workflows
  - [ ] Risk assessment workflows
- [ ] Test complex multi-step workflows

---

## FINAL VALIDATION (Day 14)

### System-Wide Verification
- [ ] All 88 new resources operational
- [ ] Total resource count: 156+
- [ ] All tests passing (80%+ coverage)
- [ ] Zero compilation warnings
- [ ] Performance benchmarks met
- [ ] Multi-tenant isolation verified
- [ ] API documentation complete
- [ ] Factory system updated for all domains

### Business Validation
- [ ] Access Control domain demos
- [ ] Analytics dashboards demonstration
- [ ] Guard Tour workflow demonstration
- [ ] Risk Management reports
- [ ] Visitor Management flow

---

## CRITICAL SUCCESS FACTORS

### Code Quality Standards
- [ ] Every resource has multi-tenant isolation
- [ ] All actions use actor context
- [ ] Proper indexes on high-query fields
- [ ] Foreign key relationships verified
- [ ] Calculations optimized (no N+1)

### Testing Standards
- [ ] Unit tests for each resource
- [ ] Integration tests per domain
- [ ] Cross-domain workflow tests
- [ ] Performance tests for high-volume resources
- [ ] Multi-tenant isolation tests

### Documentation Standards
- [ ] Code comments on complex logic
- [ ] API documentation generated
- [ ] Integration examples provided
- [ ] Migration rollback tested

---

## COMMON COMMANDS REFERENCE

```bash
# Generate migration for a domain
mix ash_postgres.generate_migrations create_[domain_name] --domains Indrajaal.[DomainName]

# Run migrations
mix ecto.migrate

# Run domain-specific tests
mix test test/indrajaal/[domain_name]

# Check compilation
mix compile --warnings-as-errors

# Generate coverage report
mix test.coverage --html

# Start interactive console
iex -S mix phx.server
```

---

## TROUBLESHOOTING QUICK FIXES

### Tenant Isolation Issues
```elixir
# Always in create actions:
change relate_actor(:tenant)

# Always in relationships:
belongs_to :tenant, Indrajaal.Core.Tenant do
  allow_nil? false
  always_select? true
end
```

### Factory Issues
```elixir
# Create with proper actor context:
{:ok, resource} = ResourceModule.create(attrs, actor: %{tenant_id: tenant.id})
```

### Migration Issues
```bash
# Rollback if needed:
mix ecto.rollback

# Fix and regenerate:
mix ash_postgres.generate_migrations create_[domain_name]_fixed --domains Indrajaal.[DomainName]
```

---

## COMPLETION CONFIRMATION

Upon successful implementation:
- [ ] 8 new domains fully operational
- [ ] 88 new resources created and tested
- [ ] Cross-domain integrations working
- [ ] Performance benchmarks maintained
- [ ] Business value demonstrations ready

**Final Outcome**: Indrajaal transformed into comprehensive enterprise security ecosystem with 156+ resources across 20 domains.

---

*This checklist ensures systematic, error-free implementation of the 8-domain expansion plan by Sonnet 4.*