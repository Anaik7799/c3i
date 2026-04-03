# Module 1: STAMP Safety Foundations

**Duration:** 4 hours
**Prerequisites:** Basic software development knowledge
**Learning Objectives:** Understand STAMP principles and perform basic STPA analysis

---

## 📚 Learning Objectives

By the end of this module, you will be able to:

1. **Explain STAMP Theory**: Articulate the fundamental principles of systems-theoretic safety
2. **Identify Control Structures**: Map the control relationships in software systems
3. **Recognize Unsafe Control Actions**: Systematically identify potential safety violations
4. **Perform Basic STPA**: Complete a simple Systems-Theoretic Process Analysis
5. **Apply Safety Constraints**: Define and implement safety requirements in code

## 🎯 Module Overview

### Session 1: Introduction to Systems Safety (60 minutes)

#### Traditional vs. Systems Thinking
**Traditional Approach:**
- Focus on component failures
- Linear cause-and-effect chains
- Fault trees and failure modes
- Reactive analysis after accidents

**Systems Approach (STAMP):**
- Focus on component interactions
- Complex causality and emergence
- Control structures and constraints
- Proactive prevention before accidents

#### Core STAMP Concepts

**1. Safety as Emergent Property**
```
Safety is not a component property but emerges from:
- System structure and relationships
- Component interactions and behaviors
- Environmental constraints and conditions
- Human-system interactions
```

**2. Accidents as Control Problems**
```
Accidents occur when:
- Safety constraints are violated
- Control actions are inadequate
- Feedback loops are broken
- System behavior becomes unpredictable
```

**3. Hierarchical Control Structures**
```
Systems are organized in control hierarchies:
- Higher levels set goals and constraints
- Lower levels implement and execute
- Control flows down, feedback flows up
- Each level has specific responsibilities
```

#### 🎮 **Exercise 1.1: Safety Thinking Shift** (15 minutes)
**Scenario**: A web application occasionally loses user data during form submission.

**Traditional Analysis**: Database connection timeout → Data loss
1. What component failed?
2. How can we make it more reliable?

**Systems Analysis**: Control structure breakdown → Safety constraint violation
1. What control actions should prevent data loss?
2. What safety constraints were violated?
3. Where did the control structure fail?

**Discussion Points:**
- Which approach provides deeper insights?
- How would solutions differ?
- What systemic issues might be missed?

### Session 2: Control Structures and Safety Constraints (60 minutes)

#### Modeling Control Structures

**Control Structure Elements:**
```
- Controllers: Components that issue control actions
- Controlled Processes: Components that receive control actions
- Control Actions: Commands, signals, or instructions
- Feedback: Information about process state
- Reference Inputs: Goals, commands from higher levels
- Disturbances: External influences on the process
```

**Example: User Authentication System**
```elixir
@control_structure %{
  controllers: [
    %{name: "AuthController",
      controls: ["UserSession", "PermissionGrants"],
      receives_feedback: ["SessionState", "FailureAlerts"]},
    %{name: "SecurityMonitor",
      controls: ["ThreatDetection", "AccountLocking"],
      receives_feedback: ["LoginAttempts", "SecurityEvents"]}
  ],
  controlled_processes: [
    "UserAuthentication",
    "SessionManagement",
    "PermissionValidation"
  ],
  safety_constraints: [
    "SC1: Only authenticated users may access protected resources",
    "SC2: Failed authentication attempts must be logged and monitored",
    "SC3: Suspicious activity must trigger automatic protection measures"
  ]
}
```

#### Defining Safety Constraints

**Safety Constraint Categories:**
1. **Access Control**: Who can do what, when, and where
2. **Data Integrity**: Information must remain accurate and consistent
3. **System Availability**: Services must remain accessible when needed
4. **Performance**: Response times must meet specified requirements
5. **Audit**: All security-relevant actions must be logged

#### 🎮 **Exercise 1.2: Control Structure Mapping** (20 minutes)
**Scenario**: E-commerce payment processing system

**Your Task**: Map the control structure for payment processing
1. Identify 3-5 controllers (e.g., PaymentController, FraudDetector)
2. Define controlled processes (e.g., TransactionValidation, PaymentGateway)
3. Specify control actions (e.g., ProcessPayment, BlockTransaction)
4. List feedback mechanisms (e.g., TransactionStatus, FraudAlerts)
5. Define 5 safety constraints

**Template:**
```elixir
@payment_control_structure %{
  controllers: [
    # Your controllers here
  ],
  controlled_processes: [
    # Your processes here
  ],
  control_actions: [
    # Your actions here
  ],
  safety_constraints: [
    # Your constraints here
  ]
}
```

### Session 3: STPA Step-by-Step (90 minutes)

#### STPA Overview
**STPA (System-Theoretic Process Analysis)** is a proactive hazard analysis technique with four main steps:

1. **Define Purpose**: What are we analyzing and why?
2. **Model Control Structure**: How is the system organized?
3. **Identify UCAs**: What control actions could be unsafe?
4. **Generate Scenarios**: How could UCAs occur?

#### Step 1: Define Purpose of Analysis

**Components:**
- **System boundary**: What's included/excluded
- **Accidents/losses**: What bad things could happen
- **Hazards**: System states that could lead to accidents
- **Safety constraints**: Requirements to prevent hazards

**Example: File Upload System**
```elixir
defmodule FileUpload.StpaAnalysis do
  @system_boundary "Web application file upload functionality"

  @accidents [
    "A1: Malicious file execution compromises server",
    "A2: Large files cause system performance degradation",
    "A3: Sensitive data uploaded to wrong location"
  ]

  @hazards [
    "H1: Executable files are processed without validation",
    "H2: File size limits are not enforced",
    "H3: File access permissions are incorrectly set"
  ]

  @safety_constraints [
    "SC1: Only approved file types may be uploaded",
    "SC2: File sizes must not exceed defined limits",
    "SC3: Files must be stored with appropriate access restrictions"
  ]
end
```

#### Step 2: Model Control Structure

**Key Relationships:**
```elixir
@file_upload_control %{
  human_controller: %{
    name: "User",
    control_actions: ["UploadFile", "SelectFileType", "ConfirmUpload"],
    feedback: ["UploadProgress", "ValidationResults", "ErrorMessages"]
  },

  automated_controllers: [
    %{name: "UploadController",
      control_actions: ["ValidateFile", "ProcessUpload", "StoreFile"],
      feedback: ["ValidationStatus", "StorageConfirmation"]},
    %{name: "SecurityScanner",
      control_actions: ["ScanFile", "QuarantineFile"],
      feedback: ["ScanResults", "ThreatDetection"]}
  ],

  controlled_processes: [
    "FileValidation",
    "FileStorage",
    "SecurityScanning"
  ]
}
```

#### Step 3: Identify Unsafe Control Actions (UCAs)

**UCA Categories:**
1. **Not Providing**: Required control action not given
2. **Providing**: Control action given when unsafe
3. **Wrong Timing**: Control action given too early/late
4. **Stopped Too Soon**: Control action stopped prematurely

**UCA Analysis Template:**
```
Control Action: [Action Name]
Context: [When this might happen]
UCA Type: [Not Providing/Providing/Wrong Timing/Stopped Too Soon]
Hazard: [Which hazard could result]
Rationale: [Why this leads to the hazard]
```

#### 🎮 **Exercise 1.3: UCA Identification** (30 minutes)
**Scenario**: User file upload system

**Your Task**: Identify UCAs for the control action "ValidateFile"

**Template:**
```
1. ValidateFile NOT PROVIDED when:
   Context: ________________________________
   Hazard: ________________________________
   Rationale: ____________________________

2. ValidateFile PROVIDED when:
   Context: ________________________________
   Hazard: ________________________________
   Rationale: ____________________________

3. ValidateFile WRONG TIMING:
   Context: ________________________________
   Hazard: ________________________________
   Rationale: ____________________________

4. ValidateFile STOPPED TOO SOON:
   Context: ________________________________
   Hazard: ________________________________
   Rationale: ____________________________
```

#### Step 4: Generate Loss Scenarios

**Scenario Elements:**
- **How** could the UCA occur?
- **Why** might the controller behave unsafely?
- **What** process model flaws could contribute?
- **Which** feedback failures could be involved?

### Session 4: Implementation in Elixir (30 minutes)

#### STAMP-Aware Code Patterns

**1. Safety Constraint Validation**
```elixir
defmodule Indrajaal.Upload.Safety do
  @safety_constraints [
    "SC1: Only approved file types may be uploaded",
    "SC2: File sizes must not exceed defined limits",
    "SC3: Files must be stored with appropriate access restrictions"
  ]

  def validate_upload(file_params) do
    with :ok <- validate_file_type(file_params),
         :ok <- validate_file_size(file_params),
         :ok <- validate_access_permissions(file_params) do
      {:ok, file_params}
    else
      {:error, constraint} ->
        # Log safety constraint violation
        :telemetry.execute(
          [:stamp, :safety, :constraint_violation],
          %{constraint: constraint},
          %{severity: :high, module: __MODULE__}
        )
        {:error, constraint}
    end
  end

  defp validate_file_type(%{content_type: type}) do
    approved_types = Application.get_env(:indrajaal, :approved_file_types)

    if type in approved_types do
      :ok
    else
      {:error, "SC1: Unapproved file type #{type}"}
    end
  end
end
```

**2. Control Action Logging**
```elixir
defmodule Indrajaal.Upload.Controller do
  require Logger

  def upload_file(conn, %{"file" => file_params}) do
    # Log control action
    Logger.info("Control Action: ValidateFile",
      context: %{user_id: get_current_user_id(conn),
                file_size: file_params.size,
                timestamp: DateTime.utc_now()})

    case Indrajaal.Upload.Safety.validate_upload(file_params) do
      {:ok, validated_params} ->
        # Continue with upload
        process_upload(validated_params)

      {:error, constraint_violation} ->
        # Handle safety constraint violation
        handle_safety_violation(conn, constraint_violation)
    end
  end
end
```

**3. Safety Monitoring**
```elixir
defmodule Indrajaal.Upload.Monitor do
  use GenServer

  def init(_) do
    # Monitor safety constraint violations
    :telemetry.attach(
      "upload-safety-monitor",
      [:stamp, :safety, :constraint_violation],
      &handle_safety_violation/4,
      %{}
    )
    {:ok, %{violations: 0}}
  end

  def handle_safety_violation(_event, measurements, metadata, state) do
    # Increment violation count
    new_state = %{state | violations: state.violations + 1}

    # Alert if threshold exceeded
    if new_state.violations > 5 do
      send_safety_alert(metadata)
    end

    {:noreply, new_state}
  end
end
```

## 🧪 Hands-On Practice

### Practice Exercise: Complete STPA Analysis (45 minutes)

**Scenario**: User Registration System
Design a STPA analysis for a user registration system that must:
- Validate email addresses
- Enforce password requirements
- Prevent duplicate accounts
- Comply with data protection regulations

**Your Deliverable**: Complete STPA document including:
1. **Purpose Definition**
   - System boundary
   - Accidents and losses
   - Hazards
   - Safety constraints

2. **Control Structure Model**
   - Controllers and controlled processes
   - Control actions and feedback
   - Human and automated elements

3. **UCA Analysis**
   - At least 10 unsafe control actions
   - All four UCA categories covered
   - Clear hazard linkages

4. **Implementation Plan**
   - Elixir module structure
   - Safety constraint validation
   - Monitoring and alerting

### Group Discussion: STAMP Benefits (15 minutes)

**Discussion Questions:**
1. How does STAMP thinking change your approach to system design?
2. What safety issues might traditional methods miss?
3. How can STPA improve team communication about risks?
4. What challenges do you foresee in adopting STAMP?

## 📝 Knowledge Check

### Quiz Questions

1. **Multiple Choice**: What is the primary focus of STAMP compared to traditional safety approaches?
   - A) Component reliability
   - B) System interactions and control
   - C) Fault tolerance
   - D) Error handling

2. **True/False**: Safety constraints should be defined after the system is implemented.

3. **Short Answer**: Explain the difference between a hazard and an accident in STAMP terminology.

4. **Application**: Given a login system, identify one UCA for the control action "GrantAccess".

### Practical Assessment

**Task**: Perform a mini-STPA on your current project
- Choose one feature or component
- Define 3 safety constraints
- Identify 5 UCAs
- Submit your analysis for review

## 🎯 Key Takeaways

1. **Safety is Systemic**: Focus on interactions, not just components
2. **Control Matters**: Map who controls what and how
3. **Constraints Guide Design**: Safety constraints should drive architecture
4. **UCAs Reveal Risks**: Systematic analysis uncovers hidden dangers
5. **Implementation Integration**: STAMP insights must be built into code

## 📚 Additional Resources

### Required Reading
- [STAMP Handbook Chapter 1-3](https://stamp-handbook.pdf)
- [STPA Primer](https://stpa-primer.pdf)

### Recommended Reading
- [Engineering a Safer World (Leveson)](https://mit.edu/book)
- [STPA in Practice](https://stpa-examples.com)

### Tools and Software
- [STPA Tool](https://github.com/stamp-team/stpa-tool)
- [STAMP Simulator](https://stamp-sim.org)

### Next Steps
- **Module 2**: [TDG Quality Framework](tdg_framework.md)
- **Workshop**: [STPA Analysis Workshop](../workshops/stpa_analysis_workshop.md)
- **Assessment**: [Foundation Assessment](../assessments/foundation_assessment.md)

---

**Questions or Need Help?**
- Office Hours: Tuesday/Thursday 2-3pm
- Slack: #stamp-foundations
- Email: stamp-support@indrajaal.dev

**Ready for the next challenge?** Continue to [Module 2: TDG Quality Framework](tdg_framework.md)