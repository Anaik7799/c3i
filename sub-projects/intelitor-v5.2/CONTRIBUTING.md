# Contributing to Indrajaal Security Monitoring System

Welcome to the Indrajaal project! We're excited that you're interested in contributing to our SOPv5.1 Cybernetic Framework-powered security monitoring system.

## 🚀 SOPv5.1 Framework Overview

Indrajaal uses the SOPv5.1 (Standard Operating Procedure version 5.1) Cybernetic Goal-Oriented Execution Framework, which includes:

- **SOPv5.1**: Cybernetic Goal-Oriented Execution with 6-phase execution
- **TPS**: Toyota Production System with 5-Level Root Cause Analysis
- **STAMP**: Safety Constraint Validation with real-time monitoring
- **TDG**: Test-Driven Generation methodology compliance
- **GDE**: Goal-Directed Execution with adaptive strategy selection
- **Patient Mode**: NO_TIMEOUT policy with infinite patience execution
- **Container-Only**: Mandatory NixOS container execution with PHICS integration
- **11-Agent Architecture**: Supervisor-Helper-Worker coordination support

## 📋 Prerequisites

Before contributing, ensure you have:

### Required Environment
- **NixOS 25.05** or compatible Nix environment
- **DevEnv**: Development environment manager
- **Podman 5.4.1+**: Container runtime (Docker is forbidden)
- **Elixir 1.19+**: Programming language
- **PostgreSQL 17+**: Database system
- **Git**: Version control system

### Container-Only Development Rule
🚨 **MANDATORY**: ALL development MUST occur within NixOS containers. Host development is forbidden.

```bash
# Setup development environment
devenv shell

# Validate container compliance
elixir scripts/validation/container_policy_validator.exs --comprehensive
```

## 🛠️ Development Setup

### 1. Clone and Setup
```bash
git clone https://github.com/your-org/indrajaal-demo.git
cd indrajaal-demo

# Setup development environment
devenv shell

# Install dependencies and setup database
mix setup
```

### 2. Container Environment Validation
```bash
# MANDATORY: Validate container compliance before any work
elixir scripts/pcis/validation_cli.exs --phics-compliance

# Ensure PHICS hot-reloading is enabled
elixir scripts/pcis/containers/setup_phoenix_container.exs --enable-phics
```

### 3. Verify SOPv5.1 Framework Integration
```bash
# Check SOPv5.1 compliance
mix sopv51.validate

# Run comprehensive quality checks
mix quality.full
```

## 🧪 Test-Driven Generation (TDG) Methodology

🚨 **CRITICAL**: ALL contributions MUST follow TDG methodology.

### TDG Workflow (MANDATORY)
1. **Write Tests FIRST**: Create comprehensive tests before any code
2. **Generate Code**: Write minimal code to make tests pass
3. **Validate**: Ensure all tests pass with generated code
4. **Refactor**: Improve code quality while maintaining test coverage
5. **Document**: Update documentation with TDG compliance evidence

### TDG Validation Commands
```bash
# Pre-implementation TDG validation
elixir scripts/testing/tdg_validator.exs --pre-generation-check

# Post-implementation TDG validation
elixir scripts/testing/tdg_validator.exs --post-generation-validation

# Comprehensive TDG audit
elixir scripts/testing/tdg_validator.exs --comprehensive-audit
```

## 🏭 Toyota Production System (TPS) Integration

### 5-Level Root Cause Analysis (MANDATORY)
For any issues or improvements, apply TPS 5-Level RCA:

1. **Level 1**: Symptom identification (what happened?)
2. **Level 2**: Surface cause analysis (why did it happen?)
3. **Level 3**: System behavior patterns (how does this relate to patterns?)
4. **Level 4**: Configuration gaps (what processes allowed this?)
5. **Level 5**: Design analysis (what architectural decisions enabled this?)

### TPS Quality Standards
- **Jidoka**: Stop development at first compilation warning
- **Just-In-Time**: Deliver features when needed, not before
- **Continuous Improvement**: Apply Kaizen methodology to all work
- **Respect for People**: Collaborative approach with human oversight

## 🛡️ STAMP Safety Constraints

### Safety-First Development
All contributions must validate STAMP safety constraints:

```bash
# Validate safety constraints
elixir scripts/stamp/integrated_stamp_safety_implementation.exs --validate-all

# Monitor real-time safety metrics
elixir scripts/stamp/integrated_stamp_safety_implementation.exs --monitor-safety

# Emergency response validation
elixir scripts/stamp/integrated_stamp_safety_implementation.exs --emergency-response
```

### Safety Constraint Categories
- **System Safety**: No system crashes or data corruption
- **Security Safety**: No unauthorized access or data breaches
- **Performance Safety**: No unacceptable response times or resource usage
- **Data Safety**: No data loss or corruption
- **Container Safety**: No container escapes or privilege escalation

## 📊 Development Workflow

### 1. Issue Assignment and Planning
```bash
# Check todo list status
mix todo.status

# Create comprehensive task plan
mix todo.update --comprehensive

# Validate task dependencies
mix todo.validate --strict
```

### 2. Development Process
```bash
# Start development with container validation
elixir scripts/pcis/validation_cli.exs --all

# Patient mode compilation (NO_TIMEOUT)
mix compile --strategy patient --warnings-as-errors

# 11-Agent coordination for complex tasks
mix claude compilation --supervisor 1 --helpers 4 --workers 6 --dynamic-tokens
```

### 3. Quality Validation
```bash
# Comprehensive quality pipeline
mix quality.full

# TDG compliance validation
elixir scripts/testing/tdg_validator.exs --comprehensive-audit

# Container security validation
elixir scripts/validation/container_policy_validator.exs --security-audit

# STAMP safety validation
elixir scripts/stamp/integrated_stamp_safety_implementation.exs --validate-all
```

### 4. Testing Requirements
```bash
# Comprehensive test execution
mix test --comprehensive --coverage --parallel

# Dual property-based testing (MANDATORY)
mix test --only property_testing

# E2E testing with Wallaby
mix test --only wallaby

# Performance testing
mix test --only performance
```

## 🔧 Code Standards

### Elixir Code Style
- Follow Elixir community conventions
- Use `mix format` for consistent formatting
- Pass `mix credo --strict` analysis
- Pass `mix dialyzer` type checking
- Maintain >95% test coverage

### Documentation Requirements
- Document all public functions with `@doc`
- Include examples in documentation
- Update README.md for user-facing changes
- Follow SOPv5.1 documentation standards
- Include TDG compliance evidence

### Container Compliance
- ALL scripts must enforce container-only execution
- Use `Indrajaal.ContainerCompliance` for validation
- Include PHICS integration for development scripts
- Validate container security policies

## 🚨 Quality Gates (MANDATORY)

### Pre-Commit Validation
```bash
# Format check
mix format --check-formatted

# Code quality
mix credo --strict

# Type checking
mix dialyzer

# Security audit
mix sobelow --exit

# Test coverage
mix coveralls.github

# Container compliance
elixir scripts/validation/container_policy_validator.exs --audit

# TDG compliance
elixir scripts/testing/tdg_validator.exs --comprehensive-audit
```

### Zero Tolerance Policies
- **No Warnings**: All compilation warnings must be fixed
- **No Test Failures**: All tests must pass
- **No Security Issues**: All security scans must pass
- **No Container Violations**: All container policies must be followed
- **No TDG Violations**: All code must follow Test-Driven Generation

## 📝 Pull Request Process

### 1. Pre-PR Checklist
- [ ] All quality gates pass
- [ ] TDG methodology followed
- [ ] Container compliance validated
- [ ] STAMP safety constraints verified
- [ ] 5-Level RCA documentation for significant changes
- [ ] Test coverage >95%
- [ ] Documentation updated

### 2. PR Description Template
```markdown
## SOPv5.1 Framework Compliance

**Framework**: SOPv5.1 + TPS + STAMP + TDG + GDE + Patient Mode + Container-Only
**Agent**: [Your Role] - [Change Type] Coordinator
**Phase**: [Development Phase] - [Task Description]

## Summary
[Brief description of changes]

## TDG Methodology Evidence
- [ ] Tests written before implementation
- [ ] All tests pass with implementation
- [ ] TDG validation commands executed successfully

## Quality Validation
- [ ] `mix quality.full` passes
- [ ] Container compliance validated
- [ ] STAMP safety constraints verified
- [ ] Performance impact assessed

## Test Plan
[Describe testing approach and coverage]

## Breaking Changes
[List any breaking changes]

## Security Considerations
[Describe any security implications]
```

### 3. Review Process
- **Automated Checks**: All CI/CD pipelines must pass
- **Peer Review**: At least 2 approvals from maintainers
- **Security Review**: Security team review for sensitive changes
- **Architecture Review**: Architecture team review for significant changes

## 🎯 Contribution Areas

### High Priority Areas
- **Container Security**: Enhance container isolation and security
- **Performance Optimization**: Improve system performance and scalability
- **Test Coverage**: Increase test coverage and quality
- **Documentation**: Improve user and developer documentation
- **Monitoring**: Enhance system monitoring and observability

### Medium Priority Areas
- **UI/UX Improvements**: Enhance user interface and experience
- **API Enhancements**: Improve API functionality and documentation
- **Integration**: Add new integrations and connectors
- **Mobile Support**: Enhance mobile application features
- **Analytics**: Improve analytics and reporting capabilities

### Research Areas
- **AI/ML Integration**: Explore AI/ML capabilities for security monitoring
- **Edge Computing**: Investigate edge deployment scenarios
- **Blockchain**: Research blockchain integration for audit trails
- **IoT Integration**: Enhance IoT device management and monitoring

## 🤝 Community Guidelines

### Code of Conduct
- **Respectful Communication**: Treat all contributors with respect
- **Collaborative Approach**: Work together towards common goals
- **Constructive Feedback**: Provide helpful and constructive feedback
- **Inclusive Environment**: Foster an inclusive and welcoming environment
- **Professional Standards**: Maintain professional communication and behavior

### Communication Channels
- **GitHub Issues**: Bug reports and feature requests
- **GitHub Discussions**: General questions and discussions
- **Discord**: Real-time chat and collaboration (invite-only)
- **Email**: security@indrajaal.com for security-related contributions

## 📚 Learning Resources

### SOPv5.1 Framework
- [SOPv5.1 Documentation](docs/architecture/MASTER_ARCHITECTURE_IMPLEMENTATION_ALIGNED.md)
- [TPS Methodology Guide](docs/planning/toyota_production_system_guide.md)
- [STAMP Safety Guide](docs/templates/stpa_container_build_analysis.md)
- [TDG Implementation Guide](docs/testing/tdg_methodology_guide.md)

### Elixir & Phoenix
- [Elixir Official Documentation](https://elixir-lang.org/docs.html)
- [Phoenix Framework Guide](https://phoenixframework.org/docs/overview)
- [Ash Framework Documentation](https://ash-hq.org/)
- [LiveView Guide](https://hexdocs.pm/phoenix_live_view/)

### Container Development
- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- [Podman Documentation](https://docs.podman.io/)
- [DevEnv Guide](https://devenv.sh/)
- [Container Security Best Practices](docs/containers/COMPREHENSIVE_CONTAINER_ARCHITECTURE.md)

## 🚀 Getting Started

Ready to contribute? Start here:

1. **Read this document thoroughly**
2. **Set up your development environment**
3. **Validate SOPv5.1 framework compliance**
4. **Pick an issue from GitHub Issues**
5. **Create a feature branch**
6. **Follow TDG methodology**
7. **Submit a pull request**

Welcome to the team! 🎉

---

**Last Updated**: 2025-08-02
**Version**: 1.0.0 GA
**Framework**: SOPv5.1 + TPS + STAMP + TDG + GDE + Patient Mode + Container-Only
**Classification**: Public Contribution Guidelines