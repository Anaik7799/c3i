/// CEPAF F# Compilation Error Pattern Catalog
/// Provides comprehensive error pattern matching for F#/dotnet compilation output.
///
/// WHAT: Regex-based error pattern definitions for F# compilation validation
/// WHY: Enables automated error classification and FPPS consensus validation
/// CONSTRAINTS:
///   - SC-FSH-140: Error patterns must be pure regex matching
///   - SC-FSH-141: All patterns must have severity classification
///   - SC-FSH-142: STAMP constraint mapping required for critical patterns
///
/// Pattern Categories:
///   EP-001 to EP-020: Compilation Errors (syntax, parsing)
///   EP-021 to EP-040: Variable/Function Errors (scope, binding)
///   EP-041 to EP-060: Type Errors (inference, mismatch)
///   EP-061 to EP-080: Module/Dependency Errors (namespaces, references)
///   EP-081 to EP-100: Syntax Errors (brackets, operators)
///   WP-001 to WP-100: Warning Patterns
///
/// STAMP Compliance: SC-FSH-140 to SC-FSH-145
/// Version: 1.0.0
module Cepaf.Validation.ErrorPatterns

open System
open System.Text.RegularExpressions

// ============================================================================
// TYPES
// ============================================================================

/// Severity levels for error patterns
type PatternSeverity =
    | Critical    // Blocks compilation, must fix immediately
    | Error       // Standard compilation error
    | Warning     // Compiler warning
    | Info        // Informational message
    | Suggestion  // IDE suggestion

/// Category of error pattern
type PatternCategory =
    | Compilation     // EP-001 to EP-020
    | VariableScope   // EP-021 to EP-040
    | TypeSystem      // EP-041 to EP-060
    | ModuleDep       // EP-061 to EP-080
    | Syntax          // EP-081 to EP-100
    | WarningGeneral  // WP-001 to WP-050
    | WarningStyle    // WP-051 to WP-100

/// Error pattern definition
type ErrorPattern = {
    Id: string               // e.g., "EP-001"
    Name: string             // Human-readable name
    Pattern: Regex           // Compiled regex pattern
    Category: PatternCategory
    Severity: PatternSeverity
    StampConstraint: string option  // Related SC-* constraint
    Description: string
    Resolution: string       // Suggested fix
}

/// Match result from pattern detection
type PatternMatch = {
    Pattern: ErrorPattern
    FilePath: string
    Line: int
    Column: int
    Message: string
    RawText: string
    Groups: Map<string, string>
}

// ============================================================================
// PATTERN BUILDER HELPERS
// ============================================================================

let private createPattern id name pattern category severity stampOpt description resolution =
    {
        Id = id
        Name = name
        Pattern = Regex(pattern, RegexOptions.Compiled ||| RegexOptions.Multiline)
        Category = category
        Severity = severity
        StampConstraint = stampOpt
        Description = description
        Resolution = resolution
    }

// ============================================================================
// EP-001 to EP-020: COMPILATION ERRORS
// ============================================================================

/// Basic file not found error
let EP001_FileNotFound =
    createPattern
        "EP-001"
        "File Not Found"
        @"error\s+FS\d+:\s+.*[Ff]ile['""]?([^'""]+)['""]?\s+.*not\s+found"
        Compilation
        Critical
        (Some "SC-CMP-025")
        "Referenced file does not exist in the project"
        "Verify file path and ensure file is included in .fsproj"

/// Assembly reference missing
let EP002_AssemblyMissing =
    createPattern
        "EP-002"
        "Assembly Reference Missing"
        @"error\s+FS\d+:\s+.*[Aa]ssembly\s+['""]?([^'""]+)['""]?\s+.*could\s+not\s+be\s+found"
        Compilation
        Critical
        (Some "SC-CMP-026")
        "Required assembly reference is not available"
        "Add missing package reference to .fsproj or restore packages"

/// Module signature mismatch
let EP003_SignatureMismatch =
    createPattern
        "EP-003"
        "Module Signature Mismatch"
        @"error\s+FS\d+:\s+.*[Mm]odule\s+['""]?([^'""]+)['""]?\s+.*does\s+not\s+match"
        Compilation
        Error
        None
        "Module implementation does not match signature file (.fsi)"
        "Update signature file or implementation to match"

/// Invalid F# syntax structure
let EP004_InvalidSyntax =
    createPattern
        "EP-004"
        "Invalid Syntax Structure"
        @"error\s+FS0010:\s+Unexpected\s+(.+)\s+in\s+(.+)"
        Compilation
        Error
        None
        "Unexpected token in F# syntax"
        "Check for missing operators, brackets, or keywords"

/// Incomplete pattern match
let EP005_IncompletePatternMatch =
    createPattern
        "EP-005"
        "Incomplete Pattern Match"
        @"warning\s+FS0025:\s+Incomplete\s+pattern\s+matches"
        Compilation
        Warning
        (Some "SC-FSH-050")
        "Match expression does not cover all possible cases"
        "Add missing pattern cases or use wildcard _ pattern"

/// Namespace not found
let EP006_NamespaceNotFound =
    createPattern
        "EP-006"
        "Namespace Not Found"
        @"error\s+FS0039:\s+The\s+namespace\s+or\s+module\s+['""]?([^'""]+)['""]?\s+is\s+not\s+defined"
        Compilation
        Error
        None
        "Referenced namespace or module is not defined"
        "Add open statement or check namespace spelling"

/// Value not defined
let EP007_ValueNotDefined =
    createPattern
        "EP-007"
        "Value Not Defined"
        @"error\s+FS0039:\s+The\s+value\s+or\s+constructor\s+['""]?([^'""]+)['""]?\s+is\s+not\s+defined"
        Compilation
        Error
        None
        "Referenced value or constructor does not exist in scope"
        "Check spelling or add required open statement"

/// Type mismatch error
let EP008_TypeMismatch =
    createPattern
        "EP-008"
        "Type Mismatch"
        @"error\s+FS0001:\s+.*[Tt]ype\s+['""]?([^'""]+)['""]?\s+.*does\s+not\s+match.*['""]?([^'""]+)['""]?"
        Compilation
        Error
        (Some "SC-FSH-100")
        "Type mismatch in expression"
        "Fix type annotations or conversion between types"

/// Duplicate definition
let EP009_DuplicateDefinition =
    createPattern
        "EP-009"
        "Duplicate Definition"
        @"error\s+FS0037:\s+Duplicate\s+definition\s+of\s+['""]?([^'""]+)['""]?"
        Compilation
        Error
        None
        "Same name defined multiple times in scope"
        "Rename one of the duplicate definitions"

/// Indentation error
let EP010_IndentationError =
    createPattern
        "EP-010"
        "Indentation Error"
        @"error\s+FS0058:\s+.*[Ii]ndentation"
        Compilation
        Error
        None
        "Incorrect indentation in F# light syntax"
        "Fix whitespace indentation to align with block structure"

/// Member access on wrong type
let EP011_MemberAccessError =
    createPattern
        "EP-011"
        "Member Access Error"
        @"error\s+FS0039:\s+The\s+field,\s+constructor\s+or\s+member\s+['""]?([^'""]+)['""]?\s+is\s+not\s+defined"
        Compilation
        Error
        None
        "Attempted to access non-existent member"
        "Check member name spelling or type definition"

/// Constraint solving failure
let EP012_ConstraintSolveError =
    createPattern
        "EP-012"
        "Constraint Solve Error"
        @"error\s+FS0043:\s+.*[Cc]onstraint.*could\s+not\s+be\s+satisfied"
        Compilation
        Error
        None
        "Generic type constraints cannot be satisfied"
        "Review generic constraints and type usage"

/// Required member not implemented
let EP013_NotImplemented =
    createPattern
        "EP-013"
        "Required Member Not Implemented"
        @"error\s+FS0366:\s+.*not\s+.*implement.*abstract"
        Compilation
        Error
        None
        "Abstract member not implemented in type"
        "Implement all required abstract members"

/// Let binding in wrong context
let EP014_LetBindingContext =
    createPattern
        "EP-014"
        "Let Binding Context Error"
        @"error\s+FS0039:\s+[Ll]et\s+.*not\s+allowed"
        Compilation
        Error
        None
        "Let binding used in incorrect context"
        "Use member binding or move let to appropriate scope"

/// Record field missing
let EP015_RecordFieldMissing =
    createPattern
        "EP-015"
        "Record Field Missing"
        @"error\s+FS0039:\s+.*[Ff]ield\s+['""]?([^'""]+)['""]?\s+.*not\s+defined"
        Compilation
        Error
        None
        "Required record field is not provided"
        "Add missing field to record expression"

/// Union case error
let EP016_UnionCaseError =
    createPattern
        "EP-016"
        "Union Case Error"
        @"error\s+FS0039:\s+.*[Uu]nion\s+case\s+['""]?([^'""]+)['""]?\s+is\s+not\s+defined"
        Compilation
        Error
        None
        "Referenced union case does not exist"
        "Check union case name and type definition"

/// Recursive binding without rec
let EP017_RecursiveWithoutRec =
    createPattern
        "EP-017"
        "Recursive Without Rec"
        @"error\s+FS0039:\s+The\s+value\s+['""]?([^'""]+)['""]?\s+.*recursive"
        Compilation
        Error
        None
        "Function references itself without let rec"
        "Add 'rec' keyword: let rec functionName ="

/// Invalid operator usage
let EP018_InvalidOperator =
    createPattern
        "EP-018"
        "Invalid Operator Usage"
        @"error\s+FS0001:\s+The\s+type\s+.*does\s+not\s+support\s+the\s+operator\s+['""]?([^'""]+)['""]?"
        Compilation
        Error
        None
        "Operator not supported for this type"
        "Use appropriate operator or convert types"

/// Attribute error
let EP019_AttributeError =
    createPattern
        "EP-019"
        "Attribute Error"
        @"error\s+FS\d+:\s+.*[Aa]ttribute.*not\s+valid"
        Compilation
        Error
        None
        "Attribute used incorrectly"
        "Check attribute syntax and target"

/// Object expression error
let EP020_ObjectExprError =
    createPattern
        "EP-020"
        "Object Expression Error"
        @"error\s+FS0366:\s+.*object\s+expression"
        Compilation
        Error
        None
        "Invalid object expression"
        "Review object expression syntax and interface requirements"

// ============================================================================
// EP-021 to EP-040: VARIABLE/FUNCTION ERRORS
// ============================================================================

/// Unused variable warning
let EP021_UnusedVariable =
    createPattern
        "EP-021"
        "Unused Variable"
        @"warning\s+FS1182:\s+.*unused"
        VariableScope
        Warning
        None
        "Variable is defined but never used"
        "Prefix with underscore (_) or remove if not needed"

/// Variable shadowing
let EP022_VariableShadowing =
    createPattern
        "EP-022"
        "Variable Shadowing"
        @"warning\s+FS0049:\s+.*shadow"
        VariableScope
        Warning
        None
        "Variable shadows another variable in outer scope"
        "Rename variable to avoid confusion"

/// Mutable variable not modified
let EP023_MutableNotModified =
    createPattern
        "EP-023"
        "Mutable Not Modified"
        @"warning\s+FS1125:\s+.*mutable.*never\s+mutated"
        VariableScope
        Warning
        None
        "Mutable variable is never modified"
        "Remove mutable keyword or implement mutation"

/// Function parameter count mismatch
let EP024_ParamCountMismatch =
    createPattern
        "EP-024"
        "Parameter Count Mismatch"
        @"error\s+FS0001:\s+.*expects\s+(\d+)\s+.*but.*given\s+(\d+)"
        VariableScope
        Error
        None
        "Wrong number of arguments passed to function"
        "Check function signature and call site"

/// Unit value expected
let EP025_UnitExpected =
    createPattern
        "EP-025"
        "Unit Value Expected"
        @"warning\s+FS0020:\s+.*result.*ignored"
        VariableScope
        Warning
        None
        "Expression result is being ignored"
        "Use |> ignore or assign to variable"

/// Partial application error
let EP026_PartialApplication =
    createPattern
        "EP-026"
        "Partial Application Error"
        @"error\s+FS0001:\s+.*partial.*application"
        VariableScope
        Error
        None
        "Function partially applied where full application expected"
        "Provide all required arguments"

/// Closure capture issue
let EP027_ClosureCapture =
    createPattern
        "EP-027"
        "Closure Capture Issue"
        @"warning\s+FS\d+:\s+.*capture.*closure"
        VariableScope
        Warning
        None
        "Potential issue with variable capture in closure"
        "Review closure behavior and variable lifetime"

/// Unused function
let EP028_UnusedFunction =
    createPattern
        "EP-028"
        "Unused Function"
        @"warning\s+FS1182:\s+.*function.*unused"
        VariableScope
        Warning
        None
        "Function is defined but never called"
        "Remove function or call where needed"

/// Recursive call issue
let EP029_RecursiveCall =
    createPattern
        "EP-029"
        "Recursive Call Issue"
        @"warning\s+FS0040:\s+.*recursive.*call"
        VariableScope
        Warning
        None
        "Potential issue with recursive function"
        "Check termination conditions"

/// Byref parameter error
let EP030_ByrefError =
    createPattern
        "EP-030"
        "Byref Parameter Error"
        @"error\s+FS0001:\s+.*byref.*not\s+allowed"
        VariableScope
        Error
        None
        "Byref parameter used incorrectly"
        "Check byref usage context"

/// Inline function constraint error
let EP031_InlineConstraint =
    createPattern
        "EP-031"
        "Inline Function Constraint"
        @"error\s+FS0073:\s+.*inline.*constraint"
        VariableScope
        Error
        None
        "Inline function has constraint issues"
        "Check SRTP constraints on inline function"

/// Static member constraint error
let EP032_StaticMemberConstraint =
    createPattern
        "EP-032"
        "Static Member Constraint"
        @"error\s+FS0001:\s+.*static.*member.*constraint"
        VariableScope
        Error
        None
        "Static member constraint not satisfied"
        "Add required static member to type"

/// Ambiguous overload resolution
let EP033_AmbiguousOverload =
    createPattern
        "EP-033"
        "Ambiguous Overload"
        @"error\s+FS0041:\s+.*[Aa]mbiguous.*overload"
        VariableScope
        Error
        None
        "Multiple overloads match the arguments"
        "Add type annotations to resolve ambiguity"

/// Unused binding warning
let EP034_UnusedBinding =
    createPattern
        "EP-034"
        "Unused Binding"
        @"warning\s+FS1182:\s+.*binding.*unused"
        VariableScope
        Warning
        None
        "Let binding is never used"
        "Remove unused binding or prefix with underscore"

/// Implicit conversion error
let EP035_ImplicitConversion =
    createPattern
        "EP-035"
        "Implicit Conversion Error"
        @"error\s+FS0193:\s+.*implicit.*conversion"
        VariableScope
        Error
        None
        "Implicit type conversion not allowed"
        "Use explicit conversion function"

/// Measure unit error
let EP036_MeasureUnitError =
    createPattern
        "EP-036"
        "Measure Unit Error"
        @"error\s+FS0001:\s+.*unit\s+of\s+measure"
        VariableScope
        Error
        None
        "Unit of measure mismatch"
        "Check units in arithmetic operations"

/// Quotation error
let EP037_QuotationError =
    createPattern
        "EP-037"
        "Quotation Error"
        @"error\s+FS0020:\s+.*quotation"
        VariableScope
        Error
        None
        "Invalid code quotation"
        "Check quotation syntax and context"

/// Computation expression binding error
let EP038_CompExprBinding =
    createPattern
        "EP-038"
        "Computation Expression Binding"
        @"error\s+FS0708:\s+.*computation\s+expression.*bind"
        VariableScope
        Error
        None
        "Invalid binding in computation expression"
        "Use let! or do! for effectful operations"

/// Active pattern error
let EP039_ActivePatternError =
    createPattern
        "EP-039"
        "Active Pattern Error"
        @"error\s+FS0722:\s+.*active\s+pattern"
        VariableScope
        Error
        None
        "Invalid active pattern definition"
        "Check active pattern syntax and return types"

/// Extension method error
let EP040_ExtensionMethodError =
    createPattern
        "EP-040"
        "Extension Method Error"
        @"error\s+FS0670:\s+.*extension.*method"
        VariableScope
        Error
        None
        "Invalid extension method definition"
        "Ensure correct extension member syntax"

// ============================================================================
// EP-041 to EP-060: TYPE SYSTEM ERRORS
// ============================================================================

/// Generic type inference failure
let EP041_TypeInferenceFail =
    createPattern
        "EP-041"
        "Type Inference Failure"
        @"error\s+FS0030:\s+.*[Vv]alue\s+restriction"
        TypeSystem
        Error
        None
        "Compiler cannot infer type due to value restriction"
        "Add explicit type annotation"

/// Interface not implemented
let EP042_InterfaceNotImpl =
    createPattern
        "EP-042"
        "Interface Not Implemented"
        @"error\s+FS0039:\s+.*interface.*not\s+implemented"
        TypeSystem
        Error
        None
        "Required interface not implemented"
        "Implement all interface members"

/// Type annotation required
let EP043_TypeAnnotationReq =
    createPattern
        "EP-043"
        "Type Annotation Required"
        @"error\s+FS0072:\s+.*[Tt]ype\s+annotation\s+.*required"
        TypeSystem
        Error
        None
        "Compiler needs explicit type annotation"
        "Add type annotation to resolve ambiguity"

/// Tuple size mismatch
let EP044_TupleMismatch =
    createPattern
        "EP-044"
        "Tuple Size Mismatch"
        @"error\s+FS0001:\s+.*[Tt]uple.*(\d+).*expected.*(\d+)"
        TypeSystem
        Error
        None
        "Tuple has wrong number of elements"
        "Match tuple size in pattern and expression"

/// Option type error
let EP045_OptionTypeError =
    createPattern
        "EP-045"
        "Option Type Error"
        @"error\s+FS0001:\s+.*[Oo]ption.*expected"
        TypeSystem
        Error
        None
        "Option type expected but different type provided"
        "Wrap value in Some or handle None case"

/// Result type error
let EP046_ResultTypeError =
    createPattern
        "EP-046"
        "Result Type Error"
        @"error\s+FS0001:\s+.*[Rr]esult.*expected"
        TypeSystem
        Error
        None
        "Result type expected but different type provided"
        "Use Ok or Error constructors"

/// Async type error
let EP047_AsyncTypeError =
    createPattern
        "EP-047"
        "Async Type Error"
        @"error\s+FS0001:\s+.*[Aa]sync.*expected"
        TypeSystem
        Error
        None
        "Async type expected in async workflow"
        "Use async { } or Async.* functions"

/// Seq type error
let EP048_SeqTypeError =
    createPattern
        "EP-048"
        "Sequence Type Error"
        @"error\s+FS0001:\s+.*[Ss]eq.*expected"
        TypeSystem
        Error
        None
        "Sequence type expected"
        "Convert to sequence with Seq.ofList/ofArray"

/// List type error
let EP049_ListTypeError =
    createPattern
        "EP-049"
        "List Type Error"
        @"error\s+FS0001:\s+.*[Ll]ist.*expected"
        TypeSystem
        Error
        None
        "List type expected"
        "Convert to list with List.ofSeq/ofArray"

/// Array type error
let EP050_ArrayTypeError =
    createPattern
        "EP-050"
        "Array Type Error"
        @"error\s+FS0001:\s+.*[Aa]rray.*expected"
        TypeSystem
        Error
        None
        "Array type expected"
        "Convert to array with Array.ofList/ofSeq"

/// Map type error
let EP051_MapTypeError =
    createPattern
        "EP-051"
        "Map Type Error"
        @"error\s+FS0001:\s+.*[Mm]ap.*expected"
        TypeSystem
        Error
        None
        "Map type expected"
        "Convert to Map with Map.ofList/ofSeq"

/// Set type error
let EP052_SetTypeError =
    createPattern
        "EP-052"
        "Set Type Error"
        @"error\s+FS0001:\s+.*[Ss]et.*expected"
        TypeSystem
        Error
        None
        "Set type expected"
        "Convert to Set with Set.ofList/ofSeq"

/// Choice type error
let EP053_ChoiceTypeError =
    createPattern
        "EP-053"
        "Choice Type Error"
        @"error\s+FS0001:\s+.*[Cc]hoice.*expected"
        TypeSystem
        Error
        None
        "Choice type pattern mismatch"
        "Handle all Choice cases"

/// Generic constraint mismatch
let EP054_GenericConstraintMismatch =
    createPattern
        "EP-054"
        "Generic Constraint Mismatch"
        @"error\s+FS0001:\s+.*constraint.*not\s+satisfied"
        TypeSystem
        Error
        None
        "Generic type constraint not satisfied"
        "Ensure type meets all constraints"

/// Nullable reference type error
let EP055_NullableRefError =
    createPattern
        "EP-055"
        "Nullable Reference Error"
        @"error\s+FS0001:\s+.*nullable.*reference"
        TypeSystem
        Error
        None
        "Nullable reference type issue"
        "Use Option type or handle null explicitly"

/// Void return error
let EP056_VoidReturnError =
    createPattern
        "EP-056"
        "Void Return Error"
        @"error\s+FS0001:\s+.*unit.*void"
        TypeSystem
        Error
        None
        "Expected unit but got void or vice versa"
        "Convert between unit and void appropriately"

/// Task type error
let EP057_TaskTypeError =
    createPattern
        "EP-057"
        "Task Type Error"
        @"error\s+FS0001:\s+.*[Tt]ask.*expected"
        TypeSystem
        Error
        None
        "Task type expected in task workflow"
        "Use task { } or Task.* functions"

/// ValueTask type error
let EP058_ValueTaskTypeError =
    createPattern
        "EP-058"
        "ValueTask Type Error"
        @"error\s+FS0001:\s+.*ValueTask.*expected"
        TypeSystem
        Error
        None
        "ValueTask type expected"
        "Use ValueTask for performance-critical async"

/// Discriminated union case error
let EP059_UnionCaseMismatch =
    createPattern
        "EP-059"
        "Union Case Mismatch"
        @"error\s+FS0039:\s+.*union\s+case.*not\s+defined"
        TypeSystem
        Error
        None
        "Discriminated union case not found"
        "Check union case name and type"

/// Record field type mismatch
let EP060_RecordFieldTypeMismatch =
    createPattern
        "EP-060"
        "Record Field Type Mismatch"
        @"error\s+FS0001:\s+.*record.*field.*type"
        TypeSystem
        Error
        None
        "Record field has wrong type"
        "Match field type in record expression"

// ============================================================================
// EP-061 to EP-080: MODULE/DEPENDENCY ERRORS
// ============================================================================

/// Cyclic dependency
let EP061_CyclicDependency =
    createPattern
        "EP-061"
        "Cyclic Dependency"
        @"error\s+FS\d+:\s+.*[Cc]yclic.*dependenc"
        ModuleDep
        Critical
        (Some "SC-CMP-028")
        "Modules have circular dependency"
        "Refactor to break dependency cycle"

/// File ordering error
let EP062_FileOrdering =
    createPattern
        "EP-062"
        "File Ordering Error"
        @"error\s+FS\d+:\s+.*file.*order"
        ModuleDep
        Error
        (Some "SC-CMP-026")
        "Files in .fsproj are in wrong order"
        "Reorder files in .fsproj so dependencies come first"

/// Missing project reference
let EP063_MissingProjectRef =
    createPattern
        "EP-063"
        "Missing Project Reference"
        @"error\s+FS\d+:\s+.*[Pp]roject.*reference.*not\s+found"
        ModuleDep
        Critical
        (Some "SC-CMP-026")
        "Referenced project is not available"
        "Add ProjectReference to .fsproj"

/// Package version conflict
let EP064_PackageVersionConflict =
    createPattern
        "EP-064"
        "Package Version Conflict"
        @"error\s+NU\d+:\s+.*[Vv]ersion.*conflict"
        ModuleDep
        Error
        None
        "Different versions of same package required"
        "Resolve version conflict in package references"

/// AutoOpen module issue
let EP065_AutoOpenIssue =
    createPattern
        "EP-065"
        "AutoOpen Module Issue"
        @"warning\s+FS\d+:\s+.*AutoOpen"
        ModuleDep
        Warning
        None
        "AutoOpen attribute usage concern"
        "Review if AutoOpen is necessary"

/// Module abbreviation collision
let EP066_ModuleAbbrevCollision =
    createPattern
        "EP-066"
        "Module Abbreviation Collision"
        @"error\s+FS\d+:\s+.*abbreviation.*conflict"
        ModuleDep
        Error
        None
        "Module abbreviation conflicts with existing name"
        "Use different abbreviation"

/// Required qualifier
let EP067_RequiredQualifier =
    createPattern
        "EP-067"
        "Required Qualifier"
        @"error\s+FS\d+:\s+.*[Rr]equires.*qualifier"
        ModuleDep
        Error
        None
        "Name requires full qualification"
        "Use fully qualified name"

/// Obsolete module
let EP068_ObsoleteModule =
    createPattern
        "EP-068"
        "Obsolete Module"
        @"warning\s+FS\d+:\s+.*[Oo]bsolete"
        ModuleDep
        Warning
        None
        "Module or member is marked obsolete"
        "Migrate to recommended replacement"

/// NuGet restore failure
let EP069_NuGetRestoreFail =
    createPattern
        "EP-069"
        "NuGet Restore Failure"
        @"error\s+NU\d+:\s+.*[Rr]estore.*failed"
        ModuleDep
        Critical
        None
        "Package restore failed"
        "Run dotnet restore and check network connectivity"

/// Target framework mismatch
let EP070_TargetFrameworkMismatch =
    createPattern
        "EP-070"
        "Target Framework Mismatch"
        @"error\s+NETSDK\d+:\s+.*[Tt]arget\s+framework"
        ModuleDep
        Critical
        (Some "SC-NET-001")
        "Target framework incompatibility"
        "Ensure all projects use net10.0"

/// Runtime identifier mismatch
let EP071_RuntimeIdMismatch =
    createPattern
        "EP-071"
        "Runtime Identifier Mismatch"
        @"error\s+NETSDK\d+:\s+.*runtime\s+identifier"
        ModuleDep
        Error
        None
        "Runtime identifier incompatibility"
        "Check RuntimeIdentifier in project file"

/// Platform target error
let EP072_PlatformTargetError =
    createPattern
        "EP-072"
        "Platform Target Error"
        @"error\s+MSB\d+:\s+.*platform.*target"
        ModuleDep
        Error
        None
        "Platform target mismatch between projects"
        "Align PlatformTarget across solution"

/// SDK version mismatch
let EP073_SdkVersionMismatch =
    createPattern
        "EP-073"
        "SDK Version Mismatch"
        @"error\s+NETSDK\d+:\s+.*SDK.*version"
        ModuleDep
        Critical
        None
        "Required SDK version not installed"
        "Install correct .NET SDK version"

/// Assembly version conflict
let EP074_AssemblyVersionConflict =
    createPattern
        "EP-074"
        "Assembly Version Conflict"
        @"error\s+CS\d+:\s+.*assembly.*version.*conflict"
        ModuleDep
        Error
        None
        "Multiple versions of same assembly"
        "Use binding redirects or update references"

/// Missing native library
let EP075_MissingNativeLib =
    createPattern
        "EP-075"
        "Missing Native Library"
        @"error\s+.*DllNotFoundException|native.*library.*not\s+found"
        ModuleDep
        Critical
        None
        "Required native library not found"
        "Install or restore native dependencies"

/// F# Core version mismatch
let EP076_FSharpCoreVersionMismatch =
    createPattern
        "EP-076"
        "FSharp.Core Version Mismatch"
        @"error\s+FS\d+:\s+.*FSharp\.Core.*version"
        ModuleDep
        Error
        None
        "FSharp.Core version incompatibility"
        "Align FSharp.Core version across projects"

/// Internal compiler error
let EP077_InternalCompilerError =
    createPattern
        "EP-077"
        "Internal Compiler Error"
        @"error\s+FS\d+:\s+[Ii]nternal\s+error"
        ModuleDep
        Critical
        None
        "F# compiler internal error"
        "Report bug and try workaround"

/// Transitive dependency conflict
let EP078_TransitiveDependencyConflict =
    createPattern
        "EP-078"
        "Transitive Dependency Conflict"
        @"error\s+NU\d+:\s+.*[Tt]ransitive.*conflict"
        ModuleDep
        Error
        None
        "Transitive package dependency conflict"
        "Add explicit package reference to resolve"

/// Source generator error
let EP079_SourceGeneratorError =
    createPattern
        "EP-079"
        "Source Generator Error"
        @"error\s+CS\d+:\s+.*[Ss]ource\s+[Gg]enerator"
        ModuleDep
        Error
        None
        "Source generator failed"
        "Check source generator compatibility"

/// Analyzer error
let EP080_AnalyzerError =
    createPattern
        "EP-080"
        "Analyzer Error"
        @"error\s+AD\d+:\s+.*[Aa]nalyzer"
        ModuleDep
        Warning
        None
        "Code analyzer error"
        "Check analyzer package compatibility"

// ============================================================================
// EP-081 to EP-100: SYNTAX ERRORS
// ============================================================================

/// Missing closing bracket
let EP081_MissingBracket =
    createPattern
        "EP-081"
        "Missing Bracket"
        @"error\s+FS\d+:\s+.*[Mm]issing.*[\)\]\}]"
        Syntax
        Error
        None
        "Missing closing bracket"
        "Add matching closing bracket"

/// Unexpected end of input
let EP082_UnexpectedEOF =
    createPattern
        "EP-082"
        "Unexpected End of Input"
        @"error\s+FS\d+:\s+[Uu]nexpected\s+end\s+of\s+input"
        Syntax
        Error
        None
        "File ends unexpectedly"
        "Check for unclosed blocks or missing expressions"

/// Invalid character
let EP083_InvalidCharacter =
    createPattern
        "EP-083"
        "Invalid Character"
        @"error\s+FS\d+:\s+.*[Ii]nvalid.*character"
        Syntax
        Error
        None
        "Invalid character in source"
        "Remove or replace invalid character"

/// String literal not terminated
let EP084_StringNotTerminated =
    createPattern
        "EP-084"
        "String Not Terminated"
        @"error\s+FS\d+:\s+.*[Ss]tring.*not\s+terminated"
        Syntax
        Error
        None
        "String literal missing closing quote"
        "Add closing quote to string"

/// Unmatched #if/#endif
let EP085_UnmatchedPreprocessor =
    createPattern
        "EP-085"
        "Unmatched Preprocessor"
        @"error\s+FS\d+:\s+.*#if.*#endif"
        Syntax
        Error
        None
        "Preprocessor directive mismatch"
        "Match #if with #endif"

/// Invalid numeric literal
let EP086_InvalidNumericLiteral =
    createPattern
        "EP-086"
        "Invalid Numeric Literal"
        @"error\s+FS\d+:\s+.*[Ii]nvalid.*numeric.*literal"
        Syntax
        Error
        None
        "Malformed number literal"
        "Fix numeric literal format"

/// Reserved keyword as identifier
let EP087_ReservedKeyword =
    createPattern
        "EP-087"
        "Reserved Keyword"
        @"error\s+FS\d+:\s+.*reserved.*keyword"
        Syntax
        Error
        None
        "Reserved keyword used as identifier"
        "Use double backticks or different name"

/// Invalid operator definition
let EP088_InvalidOperatorDef =
    createPattern
        "EP-088"
        "Invalid Operator Definition"
        @"error\s+FS\d+:\s+.*[Oo]perator.*definition"
        Syntax
        Error
        None
        "Operator definition syntax error"
        "Check operator definition syntax"

/// Computation expression error
let EP089_CompExprError =
    createPattern
        "EP-089"
        "Computation Expression Error"
        @"error\s+FS\d+:\s+.*computation\s+expression"
        Syntax
        Error
        None
        "Computation expression syntax error"
        "Check builder and keyword usage"

/// Pattern syntax error
let EP090_PatternSyntax =
    createPattern
        "EP-090"
        "Pattern Syntax Error"
        @"error\s+FS\d+:\s+.*[Pp]attern.*syntax"
        Syntax
        Error
        None
        "Pattern matching syntax error"
        "Fix pattern syntax"

/// Lambda expression error
let EP091_LambdaSyntax =
    createPattern
        "EP-091"
        "Lambda Syntax Error"
        @"error\s+FS\d+:\s+.*lambda.*expression"
        Syntax
        Error
        None
        "Lambda expression syntax error"
        "Check fun or -> syntax"

/// Record expression error
let EP092_RecordSyntax =
    createPattern
        "EP-092"
        "Record Syntax Error"
        @"error\s+FS\d+:\s+.*record.*expression.*syntax"
        Syntax
        Error
        None
        "Record expression syntax error"
        "Check { field = value } syntax"

/// Object expression error
let EP093_ObjectExprSyntax =
    createPattern
        "EP-093"
        "Object Expression Syntax Error"
        @"error\s+FS\d+:\s+.*object\s+expression"
        Syntax
        Error
        None
        "Object expression syntax error"
        "Check interface implementation syntax"

/// Type definition syntax error
let EP094_TypeDefSyntax =
    createPattern
        "EP-094"
        "Type Definition Syntax Error"
        @"error\s+FS\d+:\s+.*type\s+definition.*syntax"
        Syntax
        Error
        None
        "Type definition syntax error"
        "Check type, and, with keywords"

/// Module definition syntax error
let EP095_ModuleDefSyntax =
    createPattern
        "EP-095"
        "Module Definition Syntax Error"
        @"error\s+FS\d+:\s+.*module.*syntax"
        Syntax
        Error
        None
        "Module definition syntax error"
        "Check module declaration syntax"

/// Namespace syntax error
let EP096_NamespaceSyntax =
    createPattern
        "EP-096"
        "Namespace Syntax Error"
        @"error\s+FS\d+:\s+.*namespace.*syntax"
        Syntax
        Error
        None
        "Namespace syntax error"
        "Check namespace declaration syntax"

/// Match expression incomplete
let EP097_MatchIncomplete =
    createPattern
        "EP-097"
        "Match Expression Incomplete"
        @"error\s+FS\d+:\s+.*match.*incomplete"
        Syntax
        Error
        None
        "Match expression incomplete"
        "Add all pattern cases"

/// If expression error
let EP098_IfExprSyntax =
    createPattern
        "EP-098"
        "If Expression Syntax Error"
        @"error\s+FS\d+:\s+.*if.*then.*syntax"
        Syntax
        Error
        None
        "If expression syntax error"
        "Check if/then/else structure"

/// For loop syntax error
let EP099_ForLoopSyntax =
    createPattern
        "EP-099"
        "For Loop Syntax Error"
        @"error\s+FS\d+:\s+.*for.*loop.*syntax"
        Syntax
        Error
        None
        "For loop syntax error"
        "Check for/in/to/do keywords"

/// While loop syntax error
let EP100_WhileLoopSyntax =
    createPattern
        "EP-100"
        "While Loop Syntax Error"
        @"error\s+FS\d+:\s+.*while.*loop"
        Syntax
        Error
        None
        "While loop syntax error"
        "Check while/do keywords"

// ============================================================================
// WARNING PATTERNS (WP-001 to WP-050)
// ============================================================================

/// Nullability warning
let WP001_Nullability =
    createPattern
        "WP-001"
        "Nullability Warning"
        @"warning\s+FS\d+:\s+.*null"
        WarningGeneral
        Warning
        None
        "Potential null reference"
        "Add null check or use Option type"

/// Deprecated API
let WP002_Deprecated =
    createPattern
        "WP-002"
        "Deprecated API"
        @"warning\s+FS\d+:\s+.*[Dd]eprecated"
        WarningGeneral
        Warning
        None
        "Using deprecated API"
        "Migrate to replacement API"

/// Possible performance issue
let WP003_Performance =
    createPattern
        "WP-003"
        "Performance Warning"
        @"warning\s+FS\d+:\s+.*[Pp]erformance"
        WarningGeneral
        Warning
        None
        "Potential performance issue"
        "Review and optimize"

/// Implicit conversion
let WP004_ImplicitConversion =
    createPattern
        "WP-004"
        "Implicit Conversion"
        @"warning\s+FS\d+:\s+.*[Ii]mplicit.*conversion"
        WarningGeneral
        Warning
        None
        "Implicit type conversion"
        "Add explicit conversion"

/// Equality constraint
let WP005_EqualityConstraint =
    createPattern
        "WP-005"
        "Equality Constraint"
        @"warning\s+FS\d+:\s+.*[Ee]quality"
        WarningGeneral
        Warning
        None
        "Equality constraint issue"
        "Review equality usage"

// ============================================================================
// PATTERN COLLECTION
// ============================================================================

/// All error patterns (EP-001 to EP-100)
let allErrorPatterns = [
    // Compilation (EP-001 to EP-020)
    EP001_FileNotFound
    EP002_AssemblyMissing
    EP003_SignatureMismatch
    EP004_InvalidSyntax
    EP005_IncompletePatternMatch
    EP006_NamespaceNotFound
    EP007_ValueNotDefined
    EP008_TypeMismatch
    EP009_DuplicateDefinition
    EP010_IndentationError
    EP011_MemberAccessError
    EP012_ConstraintSolveError
    EP013_NotImplemented
    EP014_LetBindingContext
    EP015_RecordFieldMissing
    EP016_UnionCaseError
    EP017_RecursiveWithoutRec
    EP018_InvalidOperator
    EP019_AttributeError
    EP020_ObjectExprError

    // Variable/Function (EP-021 to EP-040)
    EP021_UnusedVariable
    EP022_VariableShadowing
    EP023_MutableNotModified
    EP024_ParamCountMismatch
    EP025_UnitExpected
    EP026_PartialApplication
    EP027_ClosureCapture
    EP028_UnusedFunction
    EP029_RecursiveCall
    EP030_ByrefError
    EP031_InlineConstraint
    EP032_StaticMemberConstraint
    EP033_AmbiguousOverload
    EP034_UnusedBinding
    EP035_ImplicitConversion
    EP036_MeasureUnitError
    EP037_QuotationError
    EP038_CompExprBinding
    EP039_ActivePatternError
    EP040_ExtensionMethodError

    // Type System (EP-041 to EP-060)
    EP041_TypeInferenceFail
    EP042_InterfaceNotImpl
    EP043_TypeAnnotationReq
    EP044_TupleMismatch
    EP045_OptionTypeError
    EP046_ResultTypeError
    EP047_AsyncTypeError
    EP048_SeqTypeError
    EP049_ListTypeError
    EP050_ArrayTypeError
    EP051_MapTypeError
    EP052_SetTypeError
    EP053_ChoiceTypeError
    EP054_GenericConstraintMismatch
    EP055_NullableRefError
    EP056_VoidReturnError
    EP057_TaskTypeError
    EP058_ValueTaskTypeError
    EP059_UnionCaseMismatch
    EP060_RecordFieldTypeMismatch

    // Module/Dependency (EP-061 to EP-080)
    EP061_CyclicDependency
    EP062_FileOrdering
    EP063_MissingProjectRef
    EP064_PackageVersionConflict
    EP065_AutoOpenIssue
    EP066_ModuleAbbrevCollision
    EP067_RequiredQualifier
    EP068_ObsoleteModule
    EP069_NuGetRestoreFail
    EP070_TargetFrameworkMismatch
    EP071_RuntimeIdMismatch
    EP072_PlatformTargetError
    EP073_SdkVersionMismatch
    EP074_AssemblyVersionConflict
    EP075_MissingNativeLib
    EP076_FSharpCoreVersionMismatch
    EP077_InternalCompilerError
    EP078_TransitiveDependencyConflict
    EP079_SourceGeneratorError
    EP080_AnalyzerError

    // Syntax (EP-081 to EP-100)
    EP081_MissingBracket
    EP082_UnexpectedEOF
    EP083_InvalidCharacter
    EP084_StringNotTerminated
    EP085_UnmatchedPreprocessor
    EP086_InvalidNumericLiteral
    EP087_ReservedKeyword
    EP088_InvalidOperatorDef
    EP089_CompExprError
    EP090_PatternSyntax
    EP091_LambdaSyntax
    EP092_RecordSyntax
    EP093_ObjectExprSyntax
    EP094_TypeDefSyntax
    EP095_ModuleDefSyntax
    EP096_NamespaceSyntax
    EP097_MatchIncomplete
    EP098_IfExprSyntax
    EP099_ForLoopSyntax
    EP100_WhileLoopSyntax
]

/// All F# warning patterns (WP-001 to WP-005)
/// Note: Elixir warning patterns (WP-006 to WP-100) are collected in allElixirWarningPatterns
let allWarningPatterns = [
    WP001_Nullability
    WP002_Deprecated
    WP003_Performance
    WP004_ImplicitConversion
    WP005_EqualityConstraint
]

/// All patterns combined
let allPatterns =
    allErrorPatterns @ allWarningPatterns

/// Get patterns by category
let getPatternsByCategory (category: PatternCategory) =
    allPatterns |> List.filter (fun p -> p.Category = category)

/// Get patterns by severity
let getPatternsForSeverity (severity: PatternSeverity) =
    allPatterns |> List.filter (fun p -> p.Severity = severity)

/// Get patterns with STAMP constraints
let getStampConstrainedPatterns () =
    allPatterns |> List.filter (fun p -> p.StampConstraint.IsSome)

// ============================================================================
// PATTERN MATCHING ENGINE
// ============================================================================

/// Match a single line against all patterns
let matchLine (line: string) : PatternMatch list =
    allPatterns
    |> List.choose (fun pattern ->
        let m = pattern.Pattern.Match(line)
        if m.Success then
            let groups =
                [ for g in m.Groups -> g.Name, g.Value ]
                |> List.filter (fun (name, _) -> not (String.IsNullOrEmpty name) && name <> "0")
                |> Map.ofList
            Some {
                Pattern = pattern
                FilePath = ""
                Line = 0
                Column = 0
                Message = m.Value
                RawText = line
                Groups = groups
            }
        else
            None)

/// Match compilation output (multiple lines)
let matchOutput (output: string) : PatternMatch list =
    output.Split([|'\n'; '\r'|], StringSplitOptions.RemoveEmptyEntries)
    |> Array.toList
    |> List.collect matchLine

/// Parse file path and line from error message
let parseLocation (line: string) : (string * int * int) option =
    let pattern = Regex(@"([^(]+)\((\d+),(\d+)\):")
    let m = pattern.Match(line)
    if m.Success then
        Some (m.Groups.[1].Value, int m.Groups.[2].Value, int m.Groups.[3].Value)
    else
        None

/// Enhanced match with location parsing
let matchWithLocation (line: string) : PatternMatch list =
    let location = parseLocation line
    matchLine line
    |> List.map (fun pm ->
        match location with
        | Some (path, ln, col) ->
            { pm with FilePath = path; Line = ln; Column = col }
        | None -> pm)

/// Match and categorize full build output
let analyzeBuildOutput (output: string) =
    let matches = matchOutput output
    let errors = matches |> List.filter (fun m -> m.Pattern.Severity = Error || m.Pattern.Severity = Critical)
    let warnings = matches |> List.filter (fun m -> m.Pattern.Severity = Warning)

    {|
        TotalMatches = List.length matches
        ErrorCount = List.length errors
        WarningCount = List.length warnings
        CriticalPatterns = matches |> List.filter (fun m -> m.Pattern.Severity = Critical)
        StampViolations = matches |> List.filter (fun m -> m.Pattern.StampConstraint.IsSome)
        ByCategory = matches |> List.groupBy (fun m -> m.Pattern.Category)
    |}

// ============================================================================
// ELIXIR ERROR PATTERNS (EX-001 to EX-020)
// Sprint 46.1.1.0.0: Ported from Elixir error_pattern_engine.ex
// These patterns detect Elixir/Ash compilation errors in mix compile output
// ============================================================================

/// Extended category for Elixir-specific patterns
type ElixirPatternCategory =
    | AshFramework       // EX-001 to EX-010: Ash DSL errors
    | AshResource        // EX-011 to EX-015: Ash resource errors
    | PropCheck          // EX-016 to EX-018: Property testing conflicts
    | ElixirVariable     // EX-019 to EX-020: Variable naming issues
    | ElixirCredo        // EX-021 to EX-030: Credo warnings
    | FactoryTest        // EX-031 to EX-035: Factory/Test patterns
    | SyntaxError        // EX-036 to EX-040: Syntax/Compilation patterns
    | TypeSpec           // EX-041 to EX-050: Dialyzer type/spec errors
    | CompilationError   // EX-051 to EX-060: Module/dependency errors
    | ModuleImport       // EX-061 to EX-070: Import/alias/use errors
    | DependencyConfig   // EX-071 to EX-080: Mix/config/database errors
    | SyntaxAdvanced     // EX-081 to EX-100: Advanced syntax/macro/guard errors
    // Warning Pattern Categories (WP-001 to WP-100)
    | WarningCompilation // WP-001 to WP-025: Compilation warnings
    | WarningUnused      // WP-026 to WP-050: Unused code warnings
    | WarningDeprecation // WP-051 to WP-075: Deprecation warnings
    | WarningStyle       // WP-076 to WP-100: Style/best practice warnings

/// Elixir error pattern definition
type ElixirErrorPattern = {
    Id: string               // e.g., "EX-001"
    Name: string             // Human-readable name
    Pattern: Regex           // Compiled regex pattern
    Category: ElixirPatternCategory
    Severity: PatternSeverity
    StampConstraint: string option
    AorRule: string option   // Related AOR-* rule
    Description: string
    Resolution: string
    TpsAnalysis: Map<string, string>  // 5-Level RCA
}

let private createElixirPattern id name pattern category severity stampOpt aorOpt description resolution tpsAnalysis =
    {
        Id = id
        Name = name
        Pattern = Regex(pattern, RegexOptions.Compiled ||| RegexOptions.Multiline)
        Category = category
        Severity = severity
        StampConstraint = stampOpt
        AorRule = aorOpt
        Description = description
        Resolution = resolution
        TpsAnalysis = tpsAnalysis
    }

// ----------------------------------------------------------------------------
// EX-001 to EX-010: ASH FRAMEWORK PATTERNS
// Ported from comprehensive_error_pattern_database.exs EP001-EP010
// ----------------------------------------------------------------------------

/// EX-001: Missing :update in code_interface defaults
let EX001_MissingUpdateDefault =
    createElixirPattern
        "EX-001"
        "Missing :update in code_interface defaults"
        @"error.*action\s+:update\s+is\s+unknown"
        AshFramework
        Error
        (Some "SC-ASH-001")
        (Some "AOR-ASH-001")
        "Compilation error: action :update is unknown in code_interface"
        "Add :update to defaults list: defaults [:read, :update]"
        (Map.ofList [
            ("symptom", "Compilation error: action :update is unknown")
            ("surface_cause", "Missing :update in defaults list")
            ("system_behavior", "Ash requires explicit action declarations")
            ("config_gap", "Incomplete code_interface configuration")
            ("design_flaw", "No validation of required actions in code_interface")
        ])

/// EX-002: require_atomic? false needed for function-based changes
let EX002_RequireAtomicFalse =
    createElixirPattern
        "EX-002"
        "require_atomic? false needed"
        @"error.*function-based\s+changes\s+require\s+require_atomic\?\s+false"
        AshFramework
        Error
        (Some "SC-ASH-004")
        (Some "AOR-ASH-002")
        "Function-based changes in update action require require_atomic? false"
        "Add require_atomic? false to update action with function-based changes"
        (Map.ofList [
            ("symptom", "Compilation error: function-based changes require require_atomic? false")
            ("surface_cause", "Missing require_atomic? false declaration")
            ("system_behavior", "Ash requires explicit atomic control for function changes")
            ("config_gap", "Atomic operation configuration missing")
            ("design_flaw", "Default atomic behavior incompatible with function changes")
        ])

/// EX-003: force_change_attribute in before_action
let EX003_ForceChangeAttribute =
    createElixirPattern
        "EX-003"
        "force_change_attribute in before_action"
        @"error.*force_change_attribute.*before_action"
        AshFramework
        Error
        (Some "SC-ASH-001")
        None
        "force_change_attribute must be used in before_action hook"
        "Move force_change_attribute call to before_action block"
        (Map.ofList [
            ("symptom", "force_change_attribute used outside before_action")
            ("surface_cause", "Incorrect placement of attribute change")
            ("system_behavior", "Ash requires attribute changes in lifecycle hooks")
            ("config_gap", "Misunderstanding of Ash action lifecycle")
            ("design_flaw", "No compile-time validation of attribute change location")
        ])

/// EX-004: Ash resource missing BaseResource
let EX004_MissingBaseResource =
    createElixirPattern
        "EX-004"
        "Missing BaseResource usage"
        @"error.*undefined\s+function\s+.*BaseResource"
        AshResource
        Error
        (Some "SC-DB-001")
        (Some "AOR-DB-001")
        "Ash resource does not use Indrajaal.BaseResource"
        "Add 'use Indrajaal.BaseResource' to resource module"
        (Map.ofList [
            ("symptom", "undefined function error for BaseResource functions")
            ("surface_cause", "Missing use Indrajaal.BaseResource")
            ("system_behavior", "BaseResource provides standard resource configuration")
            ("config_gap", "Resource not using project conventions")
            ("design_flaw", "No enforcement of BaseResource usage")
        ])

/// EX-005: Missing uuid_primary_key
let EX005_MissingUuidPrimaryKey =
    createElixirPattern
        "EX-005"
        "Missing uuid_primary_key"
        @"error.*primary_key.*not\s+defined"
        AshResource
        Error
        (Some "SC-DB-005")
        None
        "Ash resource missing uuid_primary_key :id"
        "Add 'uuid_primary_key :id' to attributes block"
        (Map.ofList [
            ("symptom", "Resource has no primary key defined")
            ("surface_cause", "Missing uuid_primary_key declaration")
            ("system_behavior", "All resources need primary key for persistence")
            ("config_gap", "Standard UUID key not configured")
            ("design_flaw", "No auto-generation of primary key")
        ])

/// EX-006: Actor not passed to for_update
let EX006_ActorNotPassed =
    createElixirPattern
        "EX-006"
        "Actor not passed to for_update"
        @"error.*actor.*for_update"
        AshFramework
        Error
        (Some "SC-ASH3-004")
        None
        "Actor must be passed to Ash.Changeset.for_update opts"
        "Add actor: actor to for_update options: for_update(..., actor: actor)"
        (Map.ofList [
            ("symptom", "Actor missing in for_update call")
            ("surface_cause", "Actor not passed in options")
            ("system_behavior", "Ash 3.x requires explicit actor for authorization")
            ("config_gap", "Missing actor parameter")
            ("design_flaw", "Easy to forget actor in Ash 3.x migration")
        ])

/// EX-007: query.tenant instead of context
let EX007_QueryTenantContext =
    createElixirPattern
        "EX-007"
        "Use query.tenant instead of context"
        @"error.*Ash\.Query\.get_context.*tenant"
        AshFramework
        Error
        (Some "SC-ASH3-001")
        None
        "Access tenant via query.tenant, NOT Ash.Query.get_context"
        "Replace Ash.Query.get_context(query, :tenant) with query.tenant"
        (Map.ofList [
            ("symptom", "Incorrect tenant access pattern")
            ("surface_cause", "Using deprecated context access")
            ("system_behavior", "Ash 3.x provides direct tenant access")
            ("config_gap", "Code not migrated to Ash 3.x pattern")
            ("design_flaw", "Breaking change in Ash 3.x API")
        ])

/// EX-008: Pagination returns struct
let EX008_PaginationStruct =
    createElixirPattern
        "EX-008"
        "Pagination returns struct"
        @"error.*\.results.*pagination"
        AshFramework
        Error
        None
        None
        "Ash pagination returns struct - use .results to access data"
        "Change direct access to paginated.results"
        (Map.ofList [
            ("symptom", "Cannot access list from pagination result")
            ("surface_cause", "Pagination returns %Ash.Page{} struct")
            ("system_behavior", "Ash wraps paginated results in struct")
            ("config_gap", "Missing .results accessor")
            ("design_flaw", "Struct vs list confusion")
        ])

/// EX-009: create_if_not_exists for indexes
let EX009_CreateIfNotExists =
    createElixirPattern
        "EX-009"
        "create_if_not_exists for indexes"
        @"error.*index.*already\s+exists"
        AshResource
        Error
        (Some "SC-DB-012")
        None
        "Index already exists - use create_if_not_exists"
        "Change create(index(...)) to create_if_not_exists(index(...))"
        (Map.ofList [
            ("symptom", "Index creation fails - already exists")
            ("surface_cause", "Using create instead of create_if_not_exists")
            ("system_behavior", "Migrations run on existing databases")
            ("config_gap", "Not idempotent index creation")
            ("design_flaw", "Should default to idempotent")
        ])

/// EX-010: Table name with domain prefix
let EX010_TableNamePrefix =
    createElixirPattern
        "EX-010"
        "Table name should not have domain prefix"
        @"warning.*table.*name.*domain.*prefix"
        AshResource
        Warning
        None
        None
        "Table names should be snake_case without domain prefix"
        "Remove domain prefix from table name"
        (Map.ofList [
            ("symptom", "Table name has redundant domain prefix")
            ("surface_cause", "Following incorrect naming pattern")
            ("system_behavior", "Ash resources already scoped by module")
            ("config_gap", "Naming convention not enforced")
            ("design_flaw", "Redundant prefixing")
        ])

// ----------------------------------------------------------------------------
// EX-011 to EX-015: ASH RESOURCE ERRORS
// Additional Ash-specific patterns from production experience
// ----------------------------------------------------------------------------

/// EX-011: Missing domain reference
let EX011_MissingDomainRef =
    createElixirPattern
        "EX-011"
        "Missing domain reference"
        @"error.*resource.*not.*registered.*domain"
        AshResource
        Error
        None
        None
        "Resource not registered in Ash domain"
        "Add resource to domain's resources list"
        (Map.ofList [
            ("symptom", "Resource not found in domain")
            ("surface_cause", "Resource not added to domain module")
            ("system_behavior", "Ash requires explicit resource registration")
            ("config_gap", "Forgot to add to domain")
            ("design_flaw", "No auto-discovery of resources")
        ])

/// EX-012: Invalid attribute type
let EX012_InvalidAttributeType =
    createElixirPattern
        "EX-012"
        "Invalid attribute type"
        @"error.*invalid.*attribute.*type"
        AshResource
        Error
        None
        None
        "Attribute type is not valid Ash type"
        "Use valid Ash type: :string, :integer, :utc_datetime_usec, etc."
        (Map.ofList [
            ("symptom", "Compilation error on attribute type")
            ("surface_cause", "Using non-Ash type name")
            ("system_behavior", "Ash has specific type atoms")
            ("config_gap", "Type name mismatch")
            ("design_flaw", "Limited type documentation")
        ])

/// EX-013: Relationship without destination
let EX013_RelationshipNoDestination =
    createElixirPattern
        "EX-013"
        "Relationship missing destination"
        @"error.*relationship.*destination.*required"
        AshResource
        Error
        None
        None
        "Relationship requires destination resource"
        "Add destination: resource to relationship"
        (Map.ofList [
            ("symptom", "Relationship definition incomplete")
            ("surface_cause", "Missing destination option")
            ("system_behavior", "Relationships need target resource")
            ("config_gap", "Incomplete relationship definition")
            ("design_flaw", "Not required in DSL syntax")
        ])

/// EX-014: Action without accept
let EX014_ActionNoAccept =
    createElixirPattern
        "EX-014"
        "Action missing accept list"
        @"error.*action.*accept.*required"
        AshResource
        Error
        None
        None
        "Create/update action requires accept list"
        "Add accept [:field1, :field2] to action"
        (Map.ofList [
            ("symptom", "Action cannot accept any attributes")
            ("surface_cause", "Missing accept declaration")
            ("system_behavior", "Ash requires explicit attribute acceptance")
            ("config_gap", "Security by default - nothing accepted")
            ("design_flaw", "Secure but easy to forget")
        ])

/// EX-015: Calculation without expression
let EX015_CalculationNoExpression =
    createElixirPattern
        "EX-015"
        "Calculation missing expression"
        @"error.*calculation.*expression.*required"
        AshResource
        Error
        None
        None
        "Calculation requires expression or calculate option"
        "Add expr()/calculate: option to calculation"
        (Map.ofList [
            ("symptom", "Calculation has no definition")
            ("surface_cause", "Missing expression or calculate option")
            ("system_behavior", "Calculations need implementation")
            ("config_gap", "Incomplete calculation definition")
            ("design_flaw", "No default expression")
        ])

// ----------------------------------------------------------------------------
// EX-016 to EX-018: PROPCHECK/STREAMDATA PATTERNS
// From CLAUDE.md EP-GEN-014
// ----------------------------------------------------------------------------

/// EX-016: PropCheck/StreamData generator conflict (EP-GEN-014)
let EX016_PropCheckStreamDataConflict =
    createElixirPattern
        "EX-016"
        "PropCheck/StreamData Generator Conflict"
        @"function\s+(map|list|atom|any|binary|integer|float|number|boolean|tuple)/\d+\s+imported\s+from\s+both\s+StreamData\s+and\s+PropCheck"
        PropCheck
        Error
        (Some "SC-PROP-023")
        (Some "AOR-PROP-001")
        "Dual property testing imports both PropCheck and StreamData with identical generator names"
        "Use aliases: alias PropCheck.BasicTypes, as: PC; alias StreamData, as: SD"
        (Map.ofList [
            ("symptom", "Import conflict between StreamData and PropCheck.BasicTypes")
            ("surface_cause", "Both libraries export same function names")
            ("system_behavior", "Elixir cannot disambiguate imports")
            ("config_gap", "Dual testing mandate creates conflict")
            ("design_flaw", "Libraries use same names for generators")
        ])

/// EX-017: Raw utf8() generator usage
let EX017_RawUtf8Generator =
    createElixirPattern
        "EX-017"
        "Raw utf8() generator usage"
        @"utf8\(\)"
        PropCheck
        Warning
        (Some "SC-PROP-021")
        None
        "Avoid raw utf8() - use more specific generators"
        "Use let/vector/range for controlled string generation"
        (Map.ofList [
            ("symptom", "Unbounded string generation")
            ("surface_cause", "Using raw utf8() generator")
            ("system_behavior", "Can generate very long strings")
            ("config_gap", "No size constraints")
            ("design_flaw", "Too permissive default")
        ])

/// EX-018: Header name with spaces
let EX018_HeaderNameSpaces =
    createElixirPattern
        "EX-018"
        "Header name contains spaces"
        @"header.*name.*contains?\s+space"
        PropCheck
        Error
        (Some "SC-PROP-025")
        None
        "Header names must not contain spaces"
        "Remove spaces from header name strings"
        (Map.ofList [
            ("symptom", "Invalid header name in property test")
            ("surface_cause", "Space character in header name")
            ("system_behavior", "HTTP headers cannot have spaces")
            ("config_gap", "No validation of header names")
            ("design_flaw", "String type too permissive")
        ])

// ----------------------------------------------------------------------------
// EX-019 to EX-020: VARIABLE NAMING PATTERNS
// From CLAUDE.md EP-VAR-001, EP-VAR-002
// ----------------------------------------------------------------------------

/// EX-019: Underscore prefix variable mismatch (EP-VAR-001)
let EX019_UnderscorePrefixMismatch =
    createElixirPattern
        "EX-019"
        "Underscore Prefix Variable Mismatch"
        @"undefined\s+(function|variable)\s+(\w+)"
        ElixirVariable
        Error
        (Some "SC-VAR-001")
        (Some "AOR-VAR-001")
        "Variable defined with _prefix but used without underscore"
        "Remove underscore prefix if variable is used: _var -> var"
        (Map.ofList [
            ("symptom", "undefined variable 'var' when '_var' exists")
            ("surface_cause", "Variable defined as unused but then referenced")
            ("system_behavior", "Underscore prefix indicates intentionally unused")
            ("config_gap", "No warning when _var is later referenced as var")
            ("design_flaw", "Easy typo when variable becomes needed")
        ])

/// EX-020: Double underscore typo (EP-VAR-002)
let EX020_DoubleUnderscoreTypo =
    createElixirPattern
        "EX-020"
        "Double Underscore Typo"
        @"undefined\s+variable\s+\w+__\w+"
        ElixirVariable
        Error
        (Some "SC-VAR-002")
        (Some "AOR-VAR-002")
        "Accidental double underscore in variable name"
        "Fix typo: sync__data -> sync_data"
        (Map.ofList [
            ("symptom", "undefined variable 'foo__bar'")
            ("surface_cause", "Double underscore from copy-paste or typo")
            ("system_behavior", "Variable names are exact matches")
            ("config_gap", "No warning for suspicious variable names")
            ("design_flaw", "Easy typo during editing")
        ])

// ----------------------------------------------------------------------------
// EX-021 to EX-025: WALLABY TESTING PATTERNS
// Ported from comprehensive_error_pattern_database.exs EP021-EP025
// ----------------------------------------------------------------------------

/// EX-021: Browser.assert_has/3 doesn't exist
let EX021_BrowserAssertHasArity =
    createElixirPattern
        "EX-021"
        "Browser.assert_has/3 doesn't exist"
        @"undefined\s+function\s+Browser\.assert_has/3"
        ElixirCredo
        Error
        None
        None
        "Wallaby DSL provides assert_has/2, not Browser.assert_has/3"
        "Use |> assert_has(selector) without wait parameter"
        (Map.ofList [
            ("symptom", "undefined function Browser.assert_has/3")
            ("surface_cause", "Incorrect Wallaby function arity")
            ("system_behavior", "Wallaby DSL provides assert_has/2")
            ("config_gap", "Misunderstanding of Wallaby DSL imports")
            ("design_flaw", "Inconsistent API documentation")
        ])

/// EX-022: Ambiguous text/1 import
let EX022_AmbiguousTextImport =
    createElixirPattern
        "EX-022"
        "Ambiguous text/1 import"
        @"function\s+text/1\s+imported\s+from\s+both"
        ElixirCredo
        Error
        None
        None
        "Function text/1 imported from both Wallaby.Query and Wallaby.Browser"
        "Use Wallaby.DSL which properly manages imports and aliases"
        (Map.ofList [
            ("symptom", "function text/1 imported from both modules")
            ("surface_cause", "Conflicting imports from Wallaby modules")
            ("system_behavior", "Elixir doesn't allow ambiguous function imports")
            ("config_gap", "Improper module import structure")
            ("design_flaw", "Wallaby modules have overlapping function names")
        ])

/// EX-023: Browser.has?/3 doesn't exist
let EX023_BrowserHasArity =
    createElixirPattern
        "EX-023"
        "Browser.has?/3 doesn't exist"
        @"undefined\s+function\s+Browser\.has\?/3"
        ElixirCredo
        Error
        None
        None
        "Wallaby DSL provides has?/2, not Browser.has?/3"
        "Use has?/2 from Wallaby.DSL, handle timeouts separately"
        (Map.ofList [
            ("symptom", "undefined function Browser.has?/3")
            ("surface_cause", "Incorrect function arity with wait option")
            ("system_behavior", "Wallaby DSL provides has?/2 without wait option")
            ("config_gap", "Misunderstanding of Wallaby timeout handling")
            ("design_flaw", "Inconsistent wait parameter support")
        ])

/// EX-024: Logger.warning requires Logger
let EX024_LoggerNotRequired =
    createElixirPattern
        "EX-024"
        "Logger.warning requires Logger"
        @"undefined\s+function\s+Logger\.(warning|info|error|debug)/\d+"
        ElixirCredo
        Error
        None
        None
        "Logger macros require 'require Logger' statement"
        "Add 'require Logger' at the top of the module"
        (Map.ofList [
            ("symptom", "undefined function Logger.warning/1")
            ("surface_cause", "Logger not required")
            ("system_behavior", "Logger.warning is a macro requiring explicit require")
            ("config_gap", "Missing require statement")
            ("design_flaw", "Macros require explicit module requirement")
        ])

/// EX-025: Wallaby session not started
let EX025_WallabySessionNotStarted =
    createElixirPattern
        "EX-025"
        "Wallaby session not started"
        @"Wallaby\.Session.*not\s+started"
        ElixirCredo
        Error
        None
        None
        "Wallaby browser session not properly initialized"
        "Ensure Wallaby.start_session/0 is called in test setup"
        (Map.ofList [
            ("symptom", "Wallaby session not started")
            ("surface_cause", "Missing session initialization")
            ("system_behavior", "Wallaby requires explicit session start")
            ("config_gap", "Setup not calling start_session")
            ("design_flaw", "No auto-start for sessions")
        ])

// ----------------------------------------------------------------------------
// EX-026 to EX-030: CREDO ANTI-PATTERNS
// From CLAUDE.md EP-CREDO-001 and related patterns
// ----------------------------------------------------------------------------

/// EX-026: apply/2 anti-pattern (EP-CREDO-001)
let EX026_ApplyAntiPattern =
    createElixirPattern
        "EX-026"
        "apply/2 Anti-Pattern"
        @"apply\(\s*\w+,\s*:\w+,\s*\["
        ElixirCredo
        Warning
        (Some "SC-CREDO-001")
        (Some "AOR-CREDO-001")
        "Dynamic dispatch used where static dispatch is appropriate"
        "Replace apply(Module, :function, [args]) with Module.function(args)"
        (Map.ofList [
            ("symptom", "Credo warning about apply/3 usage")
            ("surface_cause", "Using dynamic dispatch unnecessarily")
            ("system_behavior", "Static dispatch is faster and clearer")
            ("config_gap", "Code style not enforced")
            ("design_flaw", "Easy to reach for dynamic dispatch")
        ])

/// EX-027: Duplicate code blocks
let EX027_DuplicateCodeBlocks =
    createElixirPattern
        "EX-027"
        "Duplicate Code Blocks"
        @"Credo\.Check\.Refactor\.LongQuoteBlocks"
        ElixirCredo
        Warning
        (Some "SC-CREDO-002")
        (Some "AOR-CREDO-002")
        "Duplicate code blocks (3+ lines) should be extracted"
        "Extract duplicate code to private helper function"
        (Map.ofList [
            ("symptom", "Credo warning about code duplication")
            ("surface_cause", "Copy-pasted code blocks")
            ("system_behavior", "Duplication increases maintenance burden")
            ("config_gap", "DRY principle not enforced")
            ("design_flaw", "Easy to copy instead of refactor")
        ])

/// EX-028: Complex function
let EX028_ComplexFunction =
    createElixirPattern
        "EX-028"
        "Complex Function"
        @"Credo\.Check\.Refactor\.CyclomaticComplexity"
        ElixirCredo
        Warning
        None
        None
        "Function has high cyclomatic complexity"
        "Break down into smaller, focused functions"
        (Map.ofList [
            ("symptom", "Credo complexity warning")
            ("surface_cause", "Too many branches in function")
            ("system_behavior", "Complex functions are hard to test")
            ("config_gap", "Complexity limit not enforced")
            ("design_flaw", "Functions grow organically")
        ])

/// EX-029: Nesting too deep
let EX029_NestingTooDeep =
    createElixirPattern
        "EX-029"
        "Nesting Too Deep"
        @"Credo\.Check\.Refactor\.Nesting"
        ElixirCredo
        Warning
        None
        None
        "Code nesting is too deep"
        "Extract nested logic to separate functions or use with/case"
        (Map.ofList [
            ("symptom", "Credo nesting warning")
            ("surface_cause", "Multiple nested conditionals")
            ("system_behavior", "Deep nesting reduces readability")
            ("config_gap", "Nesting limit not enforced")
            ("design_flaw", "Incremental feature additions")
        ])

/// EX-030: Pipe chain starts with raw value
let EX030_PipeChainStart =
    createElixirPattern
        "EX-030"
        "Pipe Chain Starts With Raw Value"
        @"Credo\.Check\.Readability\.PipeIntoAnonymousFunctions"
        ElixirCredo
        Warning
        None
        None
        "Pipe chain should start with a function call"
        "Assign raw value to variable first, then pipe"
        (Map.ofList [
            ("symptom", "Credo pipe chain warning")
            ("surface_cause", "Raw value at start of pipe")
            ("system_behavior", "Pipes are for transformations")
            ("config_gap", "Style not enforced")
            ("design_flaw", "Pipe syntax allows raw values")
        ])

// ----------------------------------------------------------------------------
// EX-031 to EX-035: FACTORY/TEST PATTERNS
// Common test and factory errors
// ----------------------------------------------------------------------------

/// EX-031: Missing factory function
let EX031_MissingFactoryFunction =
    createElixirPattern
        "EX-031"
        "Missing Factory Function"
        @"undefined\s+function\s+(create_|insert_|build_)\w+"
        ElixirCredo
        Error
        (Some "SC-FAC-002")
        None
        "Factory function not defined for resource"
        "Add factory function to test/support/factories"
        (Map.ofList [
            ("symptom", "undefined function create_resource")
            ("surface_cause", "Factory not defined")
            ("system_behavior", "Each resource needs factory")
            ("config_gap", "Factory coverage incomplete")
            ("design_flaw", "No auto-generation of factories")
        ])

/// EX-032: ExMachina usage instead of Ash.Changeset
let EX032_ExMachinaUsage =
    createElixirPattern
        "EX-032"
        "ExMachina Usage Instead of Ash.Changeset"
        @"ExMachina\.(insert|build|create)"
        ElixirCredo
        Warning
        (Some "SC-FAC-001")
        None
        "Use Ash.Changeset.for_create instead of ExMachina"
        "Replace ExMachina with Ash.Changeset pattern"
        (Map.ofList [
            ("symptom", "ExMachina usage detected")
            ("surface_cause", "Using wrong factory library")
            ("system_behavior", "Ash resources use Changeset")
            ("config_gap", "Old factory pattern in use")
            ("design_flaw", "Multiple factory approaches")
        ])

/// EX-033: Test assertion on undefined variable
let EX033_AssertionUndefinedVar =
    createElixirPattern
        "EX-033"
        "Assertion on Undefined Variable"
        @"assert\s+\w+\s*==.*undefined\s+variable"
        ElixirCredo
        Error
        (Some "SC-TEST-002")
        (Some "AOR-TEST-002")
        "Test assertion references undefined variable"
        "Verify all variables in assertions are defined in test setup"
        (Map.ofList [
            ("symptom", "undefined variable in assertion")
            ("surface_cause", "Variable not defined before assertion")
            ("system_behavior", "Assertions need valid variables")
            ("config_gap", "Test setup incomplete")
            ("design_flaw", "Easy to reference wrong variable name")
        ])

/// EX-034: Missing migration declaration
let EX034_MissingMigrationDecl =
    createElixirPattern
        "EX-034"
        "Missing Migration Declaration"
        @"migration.*not\s+declared"
        ElixirCredo
        Error
        (Some "SC-MIG-001")
        None
        "Database test must declare required migrations"
        "Add @tag migration: true or use MigrationAware"
        (Map.ofList [
            ("symptom", "migration not declared for test")
            ("surface_cause", "Test uses DB without migration tag")
            ("system_behavior", "Tests need migration context")
            ("config_gap", "Missing migration declaration")
            ("design_flaw", "Implicit vs explicit migration needs")
        ])

/// EX-035: Sandbox mode not set
let EX035_SandboxModeNotSet =
    createElixirPattern
        "EX-035"
        "Sandbox Mode Not Set"
        @"Ecto\.Adapters\.SQL\.Sandbox\s+mode\s+not\s+set"
        ElixirCredo
        Error
        None
        None
        "Ecto sandbox mode not configured for test"
        "Add Ecto.Adapters.SQL.Sandbox.mode/2 in test setup"
        (Map.ofList [
            ("symptom", "Sandbox mode not set for process")
            ("surface_cause", "Missing sandbox configuration")
            ("system_behavior", "Tests need isolated DB transactions")
            ("config_gap", "Test setup incomplete")
            ("design_flaw", "Manual sandbox setup required")
        ])

// ----------------------------------------------------------------------------
// EX-036 to EX-040: SYNTAX/COMPILATION PATTERNS
// Common Elixir syntax errors from production logs
// ----------------------------------------------------------------------------

/// EX-036: Joined keywords (endupdate)
let EX036_JoinedKeywords =
    createElixirPattern
        "EX-036"
        "Joined Keywords"
        @"undefined\s+function\s+end\w+"
        ElixirCredo
        Error
        None
        None
        "Keywords joined without proper spacing (e.g., endupdate)"
        "Add proper line breaks between 'end' and next keywords"
        (Map.ofList [
            ("symptom", "undefined function endupdate/enddef/endif")
            ("surface_cause", "Keywords joined during text processing")
            ("system_behavior", "Elixir requires proper keyword separation")
            ("config_gap", "Script text processing error")
            ("design_flaw", "Insufficient whitespace handling")
        ])

/// EX-037: Default parameter backslash
let EX037_DefaultParamBackslash =
    createElixirPattern
        "EX-037"
        "Default Parameter Backslash"
        @"syntax\s+error.*default.*parameter"
        ElixirCredo
        Error
        None
        None
        "Default parameter uses single backslash instead of double"
        "Use \\\\\\\\ for default parameters: def foo(bar \\\\\\\\ :default)"
        (Map.ofList [
            ("symptom", "syntax error in default parameter")
            ("surface_cause", "Single backslash instead of double")
            ("system_behavior", "Elixir requires \\\\ for defaults")
            ("config_gap", "Incorrect escape sequence")
            ("design_flaw", "Confusing escape syntax")
        ])

/// EX-038: Missing do block
let EX038_MissingDoBlock =
    createElixirPattern
        "EX-038"
        "Missing do Block"
        @"unexpected\s+token.*expected.*do"
        ElixirCredo
        Error
        None
        None
        "Function or macro missing do block"
        "Add 'do' after function signature or use 'do:' for one-liners"
        (Map.ofList [
            ("symptom", "unexpected token, expected do")
            ("surface_cause", "Missing do keyword")
            ("system_behavior", "Functions require do block")
            ("config_gap", "Incomplete function definition")
            ("design_flaw", "Easy to forget do keyword")
        ])

/// EX-039: Unexpected end
let EX039_UnexpectedEnd =
    createElixirPattern
        "EX-039"
        "Unexpected end"
        @"unexpected\s+reserved\s+word.*end"
        ElixirCredo
        Error
        None
        None
        "Unexpected 'end' keyword - mismatched block structure"
        "Check block nesting and matching do/end pairs"
        (Map.ofList [
            ("symptom", "unexpected reserved word: end")
            ("surface_cause", "Mismatched block structure")
            ("system_behavior", "Each do needs matching end")
            ("config_gap", "Block nesting error")
            ("design_flaw", "Manual block tracking")
        ])

/// EX-040: Unterminated string
let EX040_UnterminatedString =
    createElixirPattern
        "EX-040"
        "Unterminated String"
        @"unterminated\s+(string|heredoc)"
        SyntaxError
        Error
        None
        None
        "String literal not properly terminated"
        "Add matching quote or heredoc delimiter"
        (Map.ofList [
            ("symptom", "unterminated string/heredoc")
            ("surface_cause", "Missing closing quote")
            ("system_behavior", "Strings must be terminated")
            ("config_gap", "String not closed")
            ("design_flaw", "Editor highlighting helps")
        ])

// ============================================================================
// TYPE/SPEC ERROR PATTERNS (EX-041 to EX-060)
// Sprint 46.1.3.0.0: Dialyzer and Typespec Error Patterns
// ============================================================================

/// EX-041: Dialyzer type mismatch
let EX041_DialyzerTypeMismatch =
    createElixirPattern
        "EX-041"
        "Dialyzer Type Mismatch"
        @"type\s+mismatch.*expected.*got"
        TypeSpec
        Warning
        (Some "SC-TYPE-001")
        (Some "AOR-TYPE-001")
        "Dialyzer detected type mismatch between expected and actual types"
        "Ensure function returns match typespec or update the @spec annotation"
        (Map.ofList [
            ("symptom", "Dialyzer warning: type mismatch")
            ("surface_cause", "Function return type doesn't match @spec")
            ("system_behavior", "Dialyzer performs static type analysis")
            ("config_gap", "@spec annotation doesn't match implementation")
            ("design_flaw", "Type contracts not verified during development")
        ])

/// EX-042: Invalid typespec syntax
let EX042_InvalidTypespecSyntax =
    createElixirPattern
        "EX-042"
        "Invalid Typespec Syntax"
        @"invalid\s+type\s+specification|@spec.*syntax\s+error"
        TypeSpec
        Error
        (Some "SC-TYPE-002")
        None
        "The @spec annotation has invalid syntax"
        "Fix the typespec syntax following Elixir typespec format"
        (Map.ofList [
            ("symptom", "Invalid type specification error")
            ("surface_cause", "Malformed @spec annotation")
            ("system_behavior", "Elixir parser rejects invalid typespecs")
            ("config_gap", "No typespec validation in editor")
            ("design_flaw", "Complex typespec syntax")
        ])

/// EX-043: Unknown type in spec
let EX043_UnknownTypeInSpec =
    createElixirPattern
        "EX-043"
        "Unknown Type in Spec"
        @"unknown\s+type.*@spec|type\s+\w+\s+is\s+not\s+defined"
        TypeSpec
        Error
        (Some "SC-TYPE-003")
        None
        "Referenced type in @spec is not defined"
        "Define the type with @type or use a built-in type"
        (Map.ofList [
            ("symptom", "Unknown type error in typespec")
            ("surface_cause", "Type alias not defined")
            ("system_behavior", "Elixir requires type definitions")
            ("config_gap", "Type not imported or defined")
            ("design_flaw", "No auto-import of common types")
        ])

/// EX-044: Spec arity mismatch
let EX044_SpecArityMismatch =
    createElixirPattern
        "EX-044"
        "Spec Arity Mismatch"
        @"@spec.*arity.*does\s+not\s+match|spec\s+for\s+\w+/\d+\s+but.*defined\s+with\s+\d+"
        TypeSpec
        Error
        (Some "SC-TYPE-004")
        None
        "Function arity in @spec doesn't match function definition"
        "Ensure @spec arity matches the function parameter count"
        (Map.ofList [
            ("symptom", "@spec arity doesn't match function")
            ("surface_cause", "Spec written for wrong arity")
            ("system_behavior", "Elixir validates spec against function")
            ("config_gap", "Spec not updated when function changed")
            ("design_flaw", "Spec and function not co-located")
        ])

/// EX-045: No local return (Dialyzer)
let EX045_NoLocalReturn =
    createElixirPattern
        "EX-045"
        "No Local Return (Dialyzer)"
        @"function.*has\s+no\s+local\s+return"
        TypeSpec
        Warning
        (Some "SC-TYPE-005")
        None
        "Dialyzer detected function always raises or loops"
        "Ensure function has at least one successful return path"
        (Map.ofList [
            ("symptom", "Function has no local return")
            ("surface_cause", "All code paths raise or loop infinitely")
            ("system_behavior", "Dialyzer tracks return reachability")
            ("config_gap", "Missing success path")
            ("design_flaw", "Function design doesn't allow normal return")
        ])

/// EX-046: Contract violation
let EX046_ContractViolation =
    createElixirPattern
        "EX-046"
        "Contract Violation"
        @"breaks?\s+the\s+contract|contract\s+violation"
        TypeSpec
        Warning
        (Some "SC-TYPE-006")
        None
        "Function implementation breaks its type contract"
        "Update implementation to satisfy the @spec contract"
        (Map.ofList [
            ("symptom", "Contract violation warning")
            ("surface_cause", "Implementation doesn't match contract")
            ("system_behavior", "Dialyzer validates contracts statically")
            ("config_gap", "Contract written but not honored")
            ("design_flaw", "Contracts not enforced at compile time")
        ])

/// EX-047: Invalid return type
let EX047_InvalidReturnType =
    createElixirPattern
        "EX-047"
        "Invalid Return Type"
        @"invalid\s+return\s+type|return\s+type.*does\s+not\s+match"
        TypeSpec
        Warning
        (Some "SC-TYPE-007")
        None
        "Function returns a type that doesn't match its @spec"
        "Update the return type in @spec or fix the function"
        (Map.ofList [
            ("symptom", "Return type doesn't match spec")
            ("surface_cause", "Function returns wrong type")
            ("system_behavior", "Dialyzer checks return types")
            ("config_gap", "Return type evolved without spec update")
            ("design_flaw", "No runtime type enforcement")
        ])

/// EX-048: Guard fail
let EX048_GuardFail =
    createElixirPattern
        "EX-048"
        "Guard Will Always Fail"
        @"guard.*will\s+always\s+fail|guard\s+test.*can\s+never\s+succeed"
        TypeSpec
        Warning
        (Some "SC-TYPE-008")
        None
        "Guard clause will never succeed based on types"
        "Fix the guard to be satisfiable or remove it"
        (Map.ofList [
            ("symptom", "Guard will always fail")
            ("surface_cause", "Type constraints make guard unsatisfiable")
            ("system_behavior", "Dialyzer analyzes guard reachability")
            ("config_gap", "Dead guard not detected in tests")
            ("design_flaw", "Guard doesn't match actual input types")
        ])

/// EX-049: Callback type mismatch
let EX049_CallbackTypeMismatch =
    createElixirPattern
        "EX-049"
        "Callback Type Mismatch"
        @"callback.*type\s+mismatch|@impl.*does\s+not\s+match\s+callback"
        TypeSpec
        Error
        (Some "SC-TYPE-009")
        None
        "Behaviour callback implementation doesn't match expected type"
        "Ensure callback implementation matches behaviour spec"
        (Map.ofList [
            ("symptom", "Callback type mismatch")
            ("surface_cause", "@impl doesn't match @callback spec")
            ("system_behavior", "Elixir validates behaviour implementations")
            ("config_gap", "Callback updated without implementation")
            ("design_flaw", "Behaviour evolution not tracked")
        ])

/// EX-050: Opaque type violation
let EX050_OpaqueTypeViolation =
    createElixirPattern
        "EX-050"
        "Opaque Type Violation"
        @"opaque\s+type.*violated|pattern\s+matching\s+on\s+opaque"
        TypeSpec
        Warning
        (Some "SC-TYPE-010")
        None
        "Code attempts to inspect or pattern match on opaque type"
        "Use the module's API functions instead of direct access"
        (Map.ofList [
            ("symptom", "Opaque type violation")
            ("surface_cause", "Pattern matching on @opaque type")
            ("system_behavior", "Dialyzer enforces opaque boundaries")
            ("config_gap", "Opaque type internals exposed")
            ("design_flaw", "Encapsulation broken")
        ])

// ============================================================================
// COMPILATION ERROR PATTERNS (EX-051 to EX-060)
// Sprint 46.1.3.0.0: Module/Dependency Errors
// ============================================================================

/// EX-051: Module not found
let EX051_ModuleNotFound =
    createElixirPattern
        "EX-051"
        "Module Not Found"
        @"module\s+\w+\s+(is\s+)?not\s+(available|loaded|found)"
        CompilationError
        Error
        (Some "SC-COMP-001")
        None
        "Referenced module doesn't exist or isn't compiled"
        "Ensure module exists and is compiled before use"
        (Map.ofList [
            ("symptom", "Module not found/available")
            ("surface_cause", "Module doesn't exist or not compiled")
            ("system_behavior", "Elixir requires modules to exist")
            ("config_gap", "Dependency not declared")
            ("design_flaw", "Module loading order issues")
        ])

/// EX-052: Undefined module attribute
let EX052_UndefinedModuleAttribute =
    createElixirPattern
        "EX-052"
        "Undefined Module Attribute"
        @"undefined\s+module\s+attribute\s+@\w+"
        CompilationError
        Error
        (Some "SC-COMP-002")
        None
        "Referenced module attribute is not defined"
        "Define the module attribute before using it"
        (Map.ofList [
            ("symptom", "Undefined module attribute @name")
            ("surface_cause", "Attribute used before definition")
            ("system_behavior", "Attributes must be defined first")
            ("config_gap", "Attribute definition missing")
            ("design_flaw", "No default values for attributes")
        ])

/// EX-053: Circular dependency
let EX053_CircularDependency =
    createElixirPattern
        "EX-053"
        "Circular Dependency"
        @"circular\s+dependency|dependency\s+cycle|deadlocked.*compile"
        CompilationError
        Error
        (Some "SC-COMP-003")
        (Some "AOR-ARCH-001")
        "Modules have circular compile-time dependency"
        "Break the cycle by extracting shared types to a third module"
        (Map.ofList [
            ("symptom", "Circular dependency detected")
            ("surface_cause", "Module A requires B and B requires A")
            ("system_behavior", "Elixir cannot compile cycles")
            ("config_gap", "Architecture allows tight coupling")
            ("design_flaw", "No dependency graph validation")
        ])

/// EX-054: Application not started
let EX054_ApplicationNotStarted =
    createElixirPattern
        "EX-054"
        "Application Not Started"
        @"application\s+\w+\s+is\s+not\s+started|could\s+not\s+start\s+application"
        CompilationError
        Error
        (Some "SC-COMP-004")
        None
        "Required application not started"
        "Add application to extra_applications in mix.exs"
        (Map.ofList [
            ("symptom", "Application not started")
            ("surface_cause", "Missing from extra_applications")
            ("system_behavior", "OTP requires explicit app start")
            ("config_gap", "Application dependency not declared")
            ("design_flaw", "Implicit application usage")
        ])

/// EX-055: Protocol not implemented
let EX055_ProtocolNotImplemented =
    createElixirPattern
        "EX-055"
        "Protocol Not Implemented"
        @"protocol\s+\w+\s+not\s+implemented\s+for|no\s+implementation\s+of\s+protocol"
        CompilationError
        Error
        (Some "SC-COMP-005")
        None
        "Protocol not implemented for the given type"
        "Implement the protocol for the type using defimpl"
        (Map.ofList [
            ("symptom", "Protocol not implemented for type")
            ("surface_cause", "Missing defimpl for type")
            ("system_behavior", "Protocols require explicit impl")
            ("config_gap", "Type added without protocol support")
            ("design_flaw", "No derive option for protocol")
        ])

/// EX-056: Behaviour not implemented
let EX056_BehaviourNotImplemented =
    createElixirPattern
        "EX-056"
        "Behaviour Not Implemented"
        @"required\s+callback\s+\w+/\d+\s+is\s+not\s+implemented|undefined\s+callback"
        CompilationError
        Error
        (Some "SC-COMP-006")
        None
        "Required behaviour callback not implemented"
        "Implement all required callbacks defined by @behaviour"
        (Map.ofList [
            ("symptom", "Required callback not implemented")
            ("surface_cause", "Missing callback function")
            ("system_behavior", "Behaviours require all callbacks")
            ("config_gap", "Behaviour added without all callbacks")
            ("design_flaw", "No scaffold generation for behaviours")
        ])

/// EX-057: Conflicting behaviours
let EX057_ConflictingBehaviours =
    createElixirPattern
        "EX-057"
        "Conflicting Behaviours"
        @"conflicting\s+behaviours|callback.*conflicts.*with"
        CompilationError
        Warning
        (Some "SC-COMP-007")
        None
        "Multiple behaviours define conflicting callbacks"
        "Resolve by implementing callbacks explicitly or using @impl"
        (Map.ofList [
            ("symptom", "Conflicting behaviour callbacks")
            ("surface_cause", "Two behaviours with same callback name")
            ("system_behavior", "Elixir warns on conflicts")
            ("config_gap", "Multiple behaviours without resolution")
            ("design_flaw", "Behaviour composition is complex")
        ])

/// EX-058: Struct key not found
let EX058_StructKeyNotFound =
    createElixirPattern
        "EX-058"
        "Struct Key Not Found"
        @"key\s+:\w+\s+not\s+found\s+in.*struct|unknown\s+key\s+:\w+\s+for\s+struct"
        CompilationError
        Error
        (Some "SC-COMP-008")
        None
        "Attempting to access non-existent struct key"
        "Add the key to defstruct or use the correct key name"
        (Map.ofList [
            ("symptom", "Key not found in struct")
            ("surface_cause", "Struct doesn't define this key")
            ("system_behavior", "Elixir validates struct keys")
            ("config_gap", "Key name mismatch")
            ("design_flaw", "Struct schema changed without update")
        ])

/// EX-059: Could not compile dependency
let EX059_DependencyCompileFailed =
    createElixirPattern
        "EX-059"
        "Dependency Compile Failed"
        @"could\s+not\s+compile\s+dependency|dependency.*failed\s+to\s+compile"
        CompilationError
        Error
        (Some "SC-COMP-009")
        None
        "A dependency failed to compile"
        "Check dependency compatibility and fix or pin to working version"
        (Map.ofList [
            ("symptom", "Dependency compilation failed")
            ("surface_cause", "Dependency code error or incompatibility")
            ("system_behavior", "Mix compiles all dependencies")
            ("config_gap", "Incompatible dependency version")
            ("design_flaw", "Dependency version constraints too loose")
        ])

/// EX-060: Redefining module
let EX060_RedefiningModule =
    createElixirPattern
        "EX-060"
        "Redefining Module"
        @"redefining\s+module\s+\w+|module\s+\w+\s+is\s+already\s+defined"
        CompilationError
        Warning
        (Some "SC-COMP-010")
        None
        "Module is defined in multiple files"
        "Remove duplicate module definition or rename one"
        (Map.ofList [
            ("symptom", "Redefining module warning")
            ("surface_cause", "Same module name in multiple files")
            ("system_behavior", "Elixir replaces previous definition")
            ("config_gap", "No unique module name enforcement")
            ("design_flaw", "Module namespace collision")
        ])

// ============================================================================
// MODULE/IMPORT ERROR PATTERNS (EX-061 to EX-070)
// Sprint 46.1.4.0.0: Import, Alias, and Use Errors
// ============================================================================

/// EX-061: Missing import causing undefined function
let EX061_MissingImport =
    createElixirPattern
        "EX-061"
        "Missing Import"
        @"undefined\s+function\s+\w+/\d+.*hint.*import"
        ModuleImport
        Error
        (Some "SC-IMPORT-001")
        (Some "AOR-IMPORT-001")
        "Function call failed because module is not imported"
        "Add 'import ModuleName' at the top of the module"
        (Map.ofList [
            ("symptom", "undefined function with import hint")
            ("surface_cause", "Module not imported")
            ("system_behavior", "Functions must be imported to use without prefix")
            ("config_gap", "Missing import statement")
            ("design_flaw", "No auto-import for common functions")
        ])

/// EX-062: Ambiguous function import
let EX062_AmbiguousImport =
    createElixirPattern
        "EX-062"
        "Ambiguous Function Import"
        @"function\s+\w+/\d+\s+imported\s+from\s+both|ambiguous\s+call"
        ModuleImport
        Error
        (Some "SC-IMPORT-002")
        None
        "Same function imported from multiple modules"
        "Use 'import Module, except: [func: arity]' to resolve conflict"
        (Map.ofList [
            ("symptom", "Function imported from both X and Y")
            ("surface_cause", "Multiple imports with same function")
            ("system_behavior", "Elixir cannot resolve ambiguity")
            ("config_gap", "Imports not scoped properly")
            ("design_flaw", "Overlapping module APIs")
        ])

/// EX-063: Unused import warning
let EX063_UnusedImport =
    createElixirPattern
        "EX-063"
        "Unused Import Warning"
        @"warning:.*unused\s+import|import.*is\s+unused"
        ModuleImport
        Warning
        (Some "SC-IMPORT-003")
        None
        "Imported module or function is never used"
        "Remove unused import or use the imported functions"
        (Map.ofList [
            ("symptom", "Unused import warning")
            ("surface_cause", "Import statement but no usage")
            ("system_behavior", "Elixir warns about dead code")
            ("config_gap", "No auto-cleanup of imports")
            ("design_flaw", "Imports added but code removed")
        ])

/// EX-064: Alias collision
let EX064_AliasCollision =
    createElixirPattern
        "EX-064"
        "Alias Collision"
        @"alias.*already\s+defined|alias\s+\w+\s+conflicts"
        ModuleImport
        Error
        (Some "SC-IMPORT-004")
        None
        "Alias name conflicts with existing binding"
        "Use 'alias Module, as: DifferentName' to resolve"
        (Map.ofList [
            ("symptom", "Alias already defined/conflicts")
            ("surface_cause", "Same alias used twice")
            ("system_behavior", "Elixir rejects duplicate bindings")
            ("config_gap", "Alias naming not unique")
            ("design_flaw", "Multiple modules with same short name")
        ])

/// EX-065: Invalid alias syntax
let EX065_InvalidAliasSyntax =
    createElixirPattern
        "EX-065"
        "Invalid Alias Syntax"
        @"invalid\s+alias|alias.*expected\s+a\s+module"
        ModuleImport
        Error
        (Some "SC-IMPORT-005")
        None
        "Alias syntax is malformed"
        "Use 'alias Module.Name' or 'alias Module.Name, as: Short'"
        (Map.ofList [
            ("symptom", "Invalid alias syntax error")
            ("surface_cause", "Malformed alias statement")
            ("system_behavior", "Parser rejects invalid alias")
            ("config_gap", "Incorrect alias usage")
            ("design_flaw", "Complex alias syntax")
        ])

/// EX-066: Use clause error
let EX066_UseClauseError =
    createElixirPattern
        "EX-066"
        "Use Clause Error"
        @"cannot\s+use\s+\w+|use.*is\s+not\s+a\s+behaviour|__using__.*undefined"
        ModuleImport
        Error
        (Some "SC-IMPORT-006")
        None
        "Use clause failed - module doesn't support use"
        "Ensure module defines __using__/1 macro or use correct module"
        (Map.ofList [
            ("symptom", "Cannot use module / __using__ undefined")
            ("surface_cause", "Module doesn't define __using__")
            ("system_behavior", "use requires __using__/1 macro")
            ("config_gap", "Wrong module used with use")
            ("design_flaw", "Not all modules support use")
        ])

/// EX-067: Missing require for macro
let EX067_MissingRequire =
    createElixirPattern
        "EX-067"
        "Missing Require for Macro"
        @"you\s+must\s+require\s+\w+|macro.*requires.*require"
        ModuleImport
        Error
        (Some "SC-IMPORT-007")
        (Some "AOR-MACRO-001")
        "Macro usage requires explicit require statement"
        "Add 'require ModuleName' before using macros"
        (Map.ofList [
            ("symptom", "Must require module for macro")
            ("surface_cause", "Macro used without require")
            ("system_behavior", "Macros need compile-time require")
            ("config_gap", "Missing require statement")
            ("design_flaw", "Macros have different import rules")
        ])

/// EX-068: Module attribute undefined
let EX068_ModuleAttributeUndefined =
    createElixirPattern
        "EX-068"
        "Module Attribute Access Error"
        @"cannot\s+access\s+@\w+|@\w+.*is\s+not\s+set"
        ModuleImport
        Error
        (Some "SC-IMPORT-008")
        None
        "Attempted to access module attribute that isn't defined"
        "Define @attribute before using it"
        (Map.ofList [
            ("symptom", "Cannot access @attribute / not set")
            ("surface_cause", "Attribute used before definition")
            ("system_behavior", "Attributes must be set first")
            ("config_gap", "Attribute definition order wrong")
            ("design_flaw", "No default attribute values")
        ])

/// EX-069: Invalid module nesting
let EX069_InvalidModuleNesting =
    createElixirPattern
        "EX-069"
        "Invalid Module Nesting"
        @"cannot\s+define\s+module.*inside|nested\s+module.*invalid"
        ModuleImport
        Error
        (Some "SC-IMPORT-009")
        None
        "Module definition inside invalid context"
        "Define nested modules using proper Elixir module syntax"
        (Map.ofList [
            ("symptom", "Cannot define module inside X")
            ("surface_cause", "Module in wrong context")
            ("system_behavior", "Modules have nesting rules")
            ("config_gap", "Module placement error")
            ("design_flaw", "Context-dependent module rules")
        ])

/// EX-070: Unquote outside quote
let EX070_UnquoteOutsideQuote =
    createElixirPattern
        "EX-070"
        "Unquote Outside Quote"
        @"unquote.*called.*outside.*quote|unquote.*not\s+inside\s+quote"
        ModuleImport
        Error
        (Some "SC-IMPORT-010")
        None
        "unquote/1 used outside of a quote block"
        "Wrap the code in quote do ... end"
        (Map.ofList [
            ("symptom", "unquote called outside quote")
            ("surface_cause", "Metaprogramming context error")
            ("system_behavior", "unquote only valid in quote")
            ("config_gap", "Missing quote block")
            ("design_flaw", "Metaprogramming is complex")
        ])

// ============================================================================
// DEPENDENCY/CONFIG ERROR PATTERNS (EX-071 to EX-080)
// Sprint 46.1.4.0.0: Mix, Config, and Database Errors
// ============================================================================

/// EX-071: Mix dependency version conflict
let EX071_DependencyVersionConflict =
    createElixirPattern
        "EX-071"
        "Dependency Version Conflict"
        @"dependency.*version\s+conflict|failed\s+to\s+converge|incompatible\s+requirements"
        DependencyConfig
        Error
        (Some "SC-DEP-001")
        (Some "AOR-DEP-001")
        "Two dependencies require incompatible versions of same package"
        "Use override: true or find compatible versions"
        (Map.ofList [
            ("symptom", "Dependency version conflict")
            ("surface_cause", "Incompatible version requirements")
            ("system_behavior", "Mix cannot satisfy all constraints")
            ("config_gap", "Version constraints too strict")
            ("design_flaw", "Transitive dependency conflicts")
        ])

/// EX-072: Missing dependency in mix.exs
let EX072_MissingDependency =
    createElixirPattern
        "EX-072"
        "Missing Dependency"
        @"could\s+not\s+find\s+dependency|dependency.*not\s+in\s+mix\.exs"
        DependencyConfig
        Error
        (Some "SC-DEP-002")
        None
        "Required dependency not declared in mix.exs"
        "Add the dependency to deps() in mix.exs"
        (Map.ofList [
            ("symptom", "Could not find dependency")
            ("surface_cause", "Dependency not in mix.exs")
            ("system_behavior", "Mix requires explicit deps")
            ("config_gap", "Dependency declaration missing")
            ("design_flaw", "No auto-detection of deps")
        ])

/// EX-073: Hex package not found
let EX073_HexPackageNotFound =
    createElixirPattern
        "EX-073"
        "Hex Package Not Found"
        @"hex\.pm.*not\s+found|package.*does\s+not\s+exist|no\s+matching\s+version"
        DependencyConfig
        Error
        (Some "SC-DEP-003")
        None
        "Package doesn't exist on Hex.pm or version not found"
        "Check package name spelling and available versions"
        (Map.ofList [
            ("symptom", "Package not found on hex.pm")
            ("surface_cause", "Wrong package name or version")
            ("system_behavior", "Hex cannot resolve package")
            ("config_gap", "Invalid dependency specification")
            ("design_flaw", "No package suggestion")
        ])

/// EX-074: Database encoding mismatch
let EX074_DatabaseEncodingMismatch =
    createElixirPattern
        "EX-074"
        "Database Encoding Mismatch"
        @"encoding.*UTF8.*incompatible.*SQL_ASCII|encoding.*mismatch"
        DependencyConfig
        Error
        (Some "SC-DB-001")
        (Some "AOR-DB-001")
        "Database encoding incompatible with Elixir requirements"
        "Recreate database with template0 and UTF8 encoding"
        (Map.ofList [
            ("symptom", "UTF8 incompatible with SQL_ASCII")
            ("surface_cause", "Template database wrong encoding")
            ("system_behavior", "PostgreSQL restricts encoding")
            ("config_gap", "Default template has wrong encoding")
            ("design_flaw", "System template mismatch")
        ])

/// EX-075: Migration failed
let EX075_MigrationFailed =
    createElixirPattern
        "EX-075"
        "Migration Failed"
        @"migration.*failed|ecto\.migrate.*error|cannot\s+execute\s+migration"
        DependencyConfig
        Error
        (Some "SC-DB-002")
        None
        "Database migration execution failed"
        "Check migration file syntax and database state"
        (Map.ofList [
            ("symptom", "Migration failed to execute")
            ("surface_cause", "Migration code error")
            ("system_behavior", "Ecto rolls back on failure")
            ("config_gap", "Migration not tested")
            ("design_flaw", "Migrations can fail silently")
        ])

/// EX-076: Schema mismatch
let EX076_SchemaMismatch =
    createElixirPattern
        "EX-076"
        "Schema Mismatch"
        @"schema.*does\s+not\s+match|column.*does\s+not\s+exist|relation.*does\s+not\s+exist"
        DependencyConfig
        Error
        (Some "SC-DB-003")
        None
        "Ecto schema doesn't match database structure"
        "Run migrations or update schema to match database"
        (Map.ofList [
            ("symptom", "Column/relation does not exist")
            ("surface_cause", "Schema and DB out of sync")
            ("system_behavior", "Ecto validates against DB")
            ("config_gap", "Migration not applied")
            ("design_flaw", "Schema drift detection")
        ])

/// EX-077: Ecto adapter error
let EX077_EctoAdapterError =
    createElixirPattern
        "EX-077"
        "Ecto Adapter Error"
        @"ecto.*adapter.*error|cannot\s+connect\s+to\s+database|connection\s+refused"
        DependencyConfig
        Error
        (Some "SC-DB-004")
        None
        "Cannot connect to database - adapter or connection error"
        "Check database is running and credentials are correct"
        (Map.ofList [
            ("symptom", "Adapter error / connection refused")
            ("surface_cause", "Database not running or wrong config")
            ("system_behavior", "Ecto cannot establish connection")
            ("config_gap", "Database config incorrect")
            ("design_flaw", "Connection errors opaque")
        ])

/// EX-078: Config missing key
let EX078_ConfigMissingKey =
    createElixirPattern
        "EX-078"
        "Config Missing Key"
        @"config.*key.*not\s+found|missing\s+configuration|Application\.get_env.*nil"
        DependencyConfig
        Error
        (Some "SC-CONFIG-001")
        None
        "Required configuration key is missing"
        "Add the key to config/config.exs or config/runtime.exs"
        (Map.ofList [
            ("symptom", "Config key not found / nil")
            ("surface_cause", "Configuration not set")
            ("system_behavior", "Application.get_env returns nil")
            ("config_gap", "Missing config entry")
            ("design_flaw", "No config validation at boot")
        ])

/// EX-079: Runtime config error
let EX079_RuntimeConfigError =
    createElixirPattern
        "EX-079"
        "Runtime Config Error"
        @"runtime\.exs.*error|config_env.*not\s+set|cannot\s+read\s+runtime\s+config"
        DependencyConfig
        Error
        (Some "SC-CONFIG-002")
        None
        "Error reading or parsing runtime.exs configuration"
        "Check runtime.exs syntax and environment variables"
        (Map.ofList [
            ("symptom", "Runtime config error")
            ("surface_cause", "runtime.exs syntax or env error")
            ("system_behavior", "Release cannot start")
            ("config_gap", "Runtime config not validated")
            ("design_flaw", "Runtime vs compile-time confusion")
        ])

/// EX-080: Environment variable missing
let EX080_EnvVarMissing =
    createElixirPattern
        "EX-080"
        "Environment Variable Missing"
        @"System\.get_env.*nil.*required|environment\s+variable.*not\s+set|must\s+be\s+set"
        DependencyConfig
        Error
        (Some "SC-CONFIG-003")
        (Some "AOR-ENV-001")
        "Required environment variable is not set"
        "Set the environment variable or provide default"
        (Map.ofList [
            ("symptom", "Env variable not set / required")
            ("surface_cause", "Missing environment variable")
            ("system_behavior", "System.get_env returns nil")
            ("config_gap", "Env not documented or set")
            ("design_flaw", "No env validation at startup")
        ])

// ============================================================================
// ELIXIR ADVANCED SYNTAX PATTERNS (EX-081 to EX-100)
// Sprint 46.1.5.0.0: Advanced syntax, macro, guard, and pattern matching errors
// ============================================================================

/// EX-081: Invalid macro expansion
let EX081_InvalidMacroExpansion =
    createElixirPattern
        "EX-081"
        "Invalid Macro Expansion"
        @"macro\s+.*\s+is\s+undefined|cannot\s+invoke\s+macro|macro.*expanded\s+to\s+invalid"
        SyntaxAdvanced
        Error
        (Some "SC-MACRO-001")
        (Some "AOR-MACRO-001")
        "Macro cannot be expanded or produces invalid code"
        "Check macro definition and required imports"
        (Map.ofList [
            ("symptom", "Macro expansion error")
            ("surface_cause", "Invalid macro or missing import")
            ("system_behavior", "Compiler cannot expand macro")
            ("config_gap", "Macro dependency not declared")
            ("design_flaw", "Complex macro without guards")
        ])

/// EX-082: Quote/unquote mismatch
let EX082_QuoteUnquoteMismatch =
    createElixirPattern
        "EX-082"
        "Quote/Unquote Mismatch"
        @"unquote.*outside\s+quote|invalid\s+quoted\s+expression|unquote_splicing.*invalid"
        SyntaxAdvanced
        Error
        (Some "SC-MACRO-002")
        (Some "AOR-MACRO-002")
        "unquote used outside quote or invalid quoting"
        "Ensure unquote is inside quote block"
        (Map.ofList [
            ("symptom", "Quote/unquote syntax error")
            ("surface_cause", "Unquote outside quote block")
            ("system_behavior", "AST manipulation fails")
            ("config_gap", "Metaprogramming misuse")
            ("design_flaw", "Macro hygiene violation")
        ])

/// EX-083: Invalid guard clause
let EX083_InvalidGuardClause =
    createElixirPattern
        "EX-083"
        "Invalid Guard Clause"
        @"invalid\s+guard|cannot\s+invoke.*in\s+guards?|guard.*not\s+allowed|invalid\s+expression\s+in\s+guard"
        SyntaxAdvanced
        Error
        (Some "SC-GUARD-001")
        (Some "AOR-GUARD-001")
        "Expression not allowed in guard clause"
        "Use only guard-safe functions (is_*, elem, etc.)"
        (Map.ofList [
            ("symptom", "Invalid guard expression")
            ("surface_cause", "Non-guard function in when clause")
            ("system_behavior", "Guard compilation fails")
            ("config_gap", "Custom guard not defined")
            ("design_flaw", "Logic in guards instead of body")
        ])

/// EX-084: Pattern matching failure
let EX084_PatternMatchFailure =
    createElixirPattern
        "EX-084"
        "Pattern Match Failure"
        @"no\s+match\s+of\s+right\s+hand\s+side|match\s+error|cannot\s+match.*to"
        SyntaxAdvanced
        Error
        (Some "SC-PATTERN-001")
        (Some "AOR-PATTERN-001")
        "Pattern does not match the given value"
        "Add catch-all clause or validate input"
        (Map.ofList [
            ("symptom", "Match error at runtime")
            ("surface_cause", "Pattern doesn't cover all cases")
            ("system_behavior", "MatchError exception")
            ("config_gap", "Missing edge case handling")
            ("design_flaw", "Non-exhaustive patterns")
        ])

/// EX-085: Binary/bitstring syntax error
let EX085_BinarySyntaxError =
    createElixirPattern
        "EX-085"
        "Binary/Bitstring Syntax Error"
        @"invalid\s+binary\s+pattern|binary\s+modifier.*invalid|size.*must\s+be|bitstring.*invalid"
        SyntaxAdvanced
        Error
        (Some "SC-BINARY-001")
        (Some "AOR-BINARY-001")
        "Invalid binary or bitstring pattern syntax"
        "Check binary modifiers and size specifications"
        (Map.ofList [
            ("symptom", "Binary pattern syntax error")
            ("surface_cause", "Invalid binary modifier")
            ("system_behavior", "Binary compilation fails")
            ("config_gap", "Size specification wrong")
            ("design_flaw", "Complex binary without tests")
        ])

/// EX-086: Invalid comprehension syntax
let EX086_InvalidComprehension =
    createElixirPattern
        "EX-086"
        "Invalid Comprehension Syntax"
        @"invalid\s+generator|comprehension.*invalid|<-\s+expected|into:.*invalid"
        SyntaxAdvanced
        Error
        (Some "SC-COMP-001")
        (Some "AOR-COMP-001")
        "List/for comprehension has invalid syntax"
        "Use <- for generators, filters after generators"
        (Map.ofList [
            ("symptom", "Comprehension syntax error")
            ("surface_cause", "Invalid generator or filter")
            ("system_behavior", "Comprehension fails to compile")
            ("config_gap", "Wrong comprehension structure")
            ("design_flaw", "Overcomplex comprehension")
        ])

/// EX-087: Function clause head mismatch
let EX087_FunctionClauseHead =
    createElixirPattern
        "EX-087"
        "Function Clause Head Mismatch"
        @"function.*clauses.*arity|head\s+mismatch|clauses\s+with\s+different\s+arities"
        SyntaxAdvanced
        Error
        (Some "SC-FUNC-001")
        (Some "AOR-FUNC-001")
        "Function clauses have different arities"
        "Ensure all clauses have same arity"
        (Map.ofList [
            ("symptom", "Function arity mismatch")
            ("surface_cause", "Clauses with different param counts")
            ("system_behavior", "Compiler rejects function")
            ("config_gap", "Copy-paste error")
            ("design_flaw", "Multiple functions with same name")
        ])

/// EX-088: Invalid anonymous function
let EX088_InvalidAnonymousFunction =
    createElixirPattern
        "EX-088"
        "Invalid Anonymous Function"
        @"invalid\s+fn|anonymous\s+function.*invalid|&\d+\s+outside|capture.*invalid"
        SyntaxAdvanced
        Error
        (Some "SC-ANON-001")
        (Some "AOR-ANON-001")
        "Anonymous function or capture syntax invalid"
        "Check fn/end syntax or & capture format"
        (Map.ofList [
            ("symptom", "Anonymous function error")
            ("surface_cause", "Invalid fn or & syntax")
            ("system_behavior", "Function creation fails")
            ("config_gap", "Capture arity mismatch")
            ("design_flaw", "Complex captures")
        ])

/// EX-089: Pin operator misuse
let EX089_PinOperatorMisuse =
    createElixirPattern
        "EX-089"
        "Pin Operator Misuse"
        @"cannot\s+pin|pin.*invalid|pinned\s+variable.*undefined|\^.*cannot"
        SyntaxAdvanced
        Error
        (Some "SC-PIN-001")
        (Some "AOR-PIN-001")
        "Pin operator ^ used incorrectly"
        "Pin only existing variables in patterns"
        (Map.ofList [
            ("symptom", "Pin operator error")
            ("surface_cause", "Pinning undefined or rebinding")
            ("system_behavior", "Pattern fails to compile")
            ("config_gap", "Variable scope confusion")
            ("design_flaw", "Overuse of pin operator")
        ])

/// EX-090: With clause error
let EX090_WithClauseError =
    createElixirPattern
        "EX-090"
        "With Clause Error"
        @"with.*clause.*invalid|else.*not\s+allowed|<-\s+in\s+with.*invalid"
        SyntaxAdvanced
        Error
        (Some "SC-WITH-001")
        (Some "AOR-WITH-001")
        "with expression has invalid clause or else"
        "Use <- for matching, else for non-match handling"
        (Map.ofList [
            ("symptom", "With expression error")
            ("surface_cause", "Invalid with clause syntax")
            ("system_behavior", "With compilation fails")
            ("config_gap", "Missing else clause")
            ("design_flaw", "Deeply nested with")
        ])

/// EX-091: Case clause overlap
let EX091_CaseClauseOverlap =
    createElixirPattern
        "EX-091"
        "Case Clause Overlap"
        @"clause.*never\s+match|unreachable\s+clause|shadowed.*clause|pattern.*always\s+matches"
        SyntaxAdvanced
        Warning
        (Some "SC-CASE-001")
        (Some "AOR-CASE-001")
        "Case clause is unreachable or always matches"
        "Reorder clauses from specific to general"
        (Map.ofList [
            ("symptom", "Unreachable case clause")
            ("surface_cause", "Earlier clause always matches")
            ("system_behavior", "Warning, code unreachable")
            ("config_gap", "Missing coverage analysis")
            ("design_flaw", "Wrong clause ordering")
        ])

/// EX-092: Receive timeout error
let EX092_ReceiveTimeoutError =
    createElixirPattern
        "EX-092"
        "Receive Timeout Error"
        @"receive.*after.*invalid|timeout.*must\s+be|infinite\s+timeout"
        SyntaxAdvanced
        Error
        (Some "SC-RECEIVE-001")
        (Some "AOR-RECEIVE-001")
        "Invalid receive timeout specification"
        "Use integer timeout or :infinity"
        (Map.ofList [
            ("symptom", "Receive timeout syntax error")
            ("surface_cause", "Invalid after clause")
            ("system_behavior", "Receive fails to compile")
            ("config_gap", "Timeout not validated")
            ("design_flaw", "No timeout handling")
        ])

/// EX-093: Try/rescue clause error
let EX093_TryRescueError =
    createElixirPattern
        "EX-093"
        "Try/Rescue Clause Error"
        @"rescue.*invalid|catch.*invalid\s+clause|try.*else.*invalid|invalid\s+exception\s+pattern"
        SyntaxAdvanced
        Error
        (Some "SC-TRY-001")
        (Some "AOR-TRY-001")
        "Invalid try/rescue/catch/after clause"
        "Use proper exception types in rescue"
        (Map.ofList [
            ("symptom", "Try/rescue syntax error")
            ("surface_cause", "Invalid rescue pattern")
            ("system_behavior", "Try block fails to compile")
            ("config_gap", "Exception type unknown")
            ("design_flaw", "Catch-all without logging")
        ])

/// EX-094: Raise argument error
let EX094_RaiseArgumentError =
    createElixirPattern
        "EX-094"
        "Raise Argument Error"
        @"raise\s+.*\s+invalid|exception.*not\s+defined|reraise.*invalid"
        SyntaxAdvanced
        Error
        (Some "SC-RAISE-001")
        (Some "AOR-RAISE-001")
        "Invalid raise/reraise argument"
        "Raise exception struct or message string"
        (Map.ofList [
            ("symptom", "Raise argument invalid")
            ("surface_cause", "Non-exception raised")
            ("system_behavior", "Raise fails")
            ("config_gap", "Custom exception missing")
            ("design_flaw", "Using raise for flow control")
        ])

/// EX-095: Struct update syntax error
let EX095_StructUpdateError =
    createElixirPattern
        "EX-095"
        "Struct Update Syntax Error"
        @"cannot\s+update.*struct|%.*\|.*invalid|struct.*does\s+not\s+have\s+key"
        SyntaxAdvanced
        Error
        (Some "SC-STRUCT-001")
        (Some "AOR-STRUCT-001")
        "Invalid struct update syntax or key"
        "Use %Struct{struct | key: value} for updates"
        (Map.ofList [
            ("symptom", "Struct update error")
            ("surface_cause", "Invalid key or syntax")
            ("system_behavior", "Struct update fails")
            ("config_gap", "Key not in struct definition")
            ("design_flaw", "Dynamic keys on struct")
        ])

/// EX-096: Sigil syntax error
let EX096_SigilSyntaxError =
    createElixirPattern
        "EX-096"
        "Sigil Syntax Error"
        @"invalid\s+sigil|sigil.*not\s+defined|~[a-zA-Z].*invalid|sigil\s+modifier.*unknown"
        SyntaxAdvanced
        Error
        (Some "SC-SIGIL-001")
        (Some "AOR-SIGIL-001")
        "Invalid sigil syntax or undefined sigil"
        "Use built-in sigils or define custom sigil macro"
        (Map.ofList [
            ("symptom", "Sigil syntax error")
            ("surface_cause", "Unknown sigil or bad syntax")
            ("system_behavior", "Sigil fails to compile")
            ("config_gap", "Custom sigil not imported")
            ("design_flaw", "Sigil without documentation")
        ])

/// EX-097: Access syntax error
let EX097_AccessSyntaxError =
    createElixirPattern
        "EX-097"
        "Access Syntax Error"
        @"cannot\s+access|Access.*not\s+implemented|get_in.*invalid|put_in.*invalid"
        SyntaxAdvanced
        Error
        (Some "SC-ACCESS-001")
        (Some "AOR-ACCESS-001")
        "Invalid Access behaviour usage"
        "Implement Access or use Map/Keyword functions"
        (Map.ofList [
            ("symptom", "Access syntax error")
            ("surface_cause", "Type doesn't implement Access")
            ("system_behavior", "Access operation fails")
            ("config_gap", "Missing Access implementation")
            ("design_flaw", "Assuming all types are accessible")
        ])

/// EX-098: Pipe operator error
let EX098_PipeOperatorError =
    createElixirPattern
        "EX-098"
        "Pipe Operator Error"
        @"pipe.*invalid|cannot\s+pipe\s+into|\|>\s+.*\s+invalid|first\s+argument.*pipe"
        SyntaxAdvanced
        Error
        (Some "SC-PIPE-001")
        (Some "AOR-PIPE-001")
        "Invalid pipe operator usage"
        "Ensure piped value is first argument"
        (Map.ofList [
            ("symptom", "Pipe operator error")
            ("surface_cause", "Value not first argument")
            ("system_behavior", "Pipe fails to compile")
            ("config_gap", "Function signature mismatch")
            ("design_flaw", "Long pipe chains")
        ])

/// EX-099: Module attribute error
let EX099_ModuleAttributeError =
    createElixirPattern
        "EX-099"
        "Module Attribute Error"
        @"module\s+attribute.*invalid|@\w+.*not\s+set|accumulating\s+attribute.*invalid"
        SyntaxAdvanced
        Error
        (Some "SC-ATTR-001")
        (Some "AOR-ATTR-001")
        "Invalid module attribute usage"
        "Define attribute before use, consider accumulate"
        (Map.ofList [
            ("symptom", "Module attribute error")
            ("surface_cause", "Attribute not defined or wrong type")
            ("system_behavior", "Attribute lookup fails")
            ("config_gap", "Attribute scope confusion")
            ("design_flaw", "Runtime attribute access")
        ])

/// EX-100: Keyword list syntax error
let EX100_KeywordListError =
    createElixirPattern
        "EX-100"
        "Keyword List Syntax Error"
        @"keyword\s+list.*invalid|non-atom\s+key|duplicate\s+key.*keyword|expected\s+keyword"
        SyntaxAdvanced
        Error
        (Some "SC-KWLIST-001")
        (Some "AOR-KWLIST-001")
        "Invalid keyword list syntax or keys"
        "Use atom keys and proper [{key: val}] syntax"
        (Map.ofList [
            ("symptom", "Keyword list error")
            ("surface_cause", "Non-atom key or syntax")
            ("system_behavior", "Keyword list invalid")
            ("config_gap", "Key type confusion")
            ("design_flaw", "Using keyword list as map")
        ])

// ============================================================================
// ELIXIR WARNING PATTERNS (WP-001 to WP-100)
// Sprint 46.1.6.0.0: Compilation, unused, deprecation, and style warnings
// ============================================================================

// ----------------------------------------------------------------------------
// COMPILATION WARNINGS (WP-001 to WP-025)
// ----------------------------------------------------------------------------

/// WP-001: Unused variable warning
let WP001_UnusedVariable =
    createElixirPattern
        "WP-001"
        "Unused Variable"
        @"warning:.*variable\s+[`""]?(\w+)[`""]?\s+is\s+unused"
        WarningCompilation
        Warning
        (Some "SC-WARN-001")
        (Some "AOR-WARN-001")
        "Variable declared but never used"
        "Prefix with underscore (_var) or remove"
        (Map.ofList [
            ("symptom", "Variable is unused warning")
            ("surface_cause", "Variable declared but not used")
            ("system_behavior", "Compiler warns about dead code")
            ("config_gap", "No automatic unused detection")
            ("design_flaw", "Leftover from refactoring")
        ])

/// WP-002: Unused function argument
let WP002_UnusedFunctionArg =
    createElixirPattern
        "WP-002"
        "Unused Function Argument"
        @"warning:.*argument\s+[`""]?(\w+)[`""]?\s+is\s+unused"
        WarningCompilation
        Warning
        (Some "SC-WARN-002")
        (Some "AOR-WARN-002")
        "Function argument is never used"
        "Prefix with underscore (_arg) or use it"
        (Map.ofList [
            ("symptom", "Argument unused in function")
            ("surface_cause", "Parameter not referenced")
            ("system_behavior", "Warning about unused arg")
            ("config_gap", "Interface requires arg")
            ("design_flaw", "Over-specified function signature")
        ])

/// WP-003: Unused private function
let WP003_UnusedPrivateFunction =
    createElixirPattern
        "WP-003"
        "Unused Private Function"
        @"warning:.*function\s+(\w+/\d+)\s+is\s+unused"
        WarningCompilation
        Warning
        (Some "SC-WARN-003")
        (Some "AOR-WARN-003")
        "Private function is never called"
        "Remove the function or use it"
        (Map.ofList [
            ("symptom", "Private function never called")
            ("surface_cause", "Dead code in module")
            ("system_behavior", "Function compiled but unused")
            ("config_gap", "No dead code elimination")
            ("design_flaw", "Leftover from refactoring")
        ])

/// WP-004: Unreachable code
let WP004_UnreachableCode =
    createElixirPattern
        "WP-004"
        "Unreachable Code"
        @"warning:.*unreachable\s+code|code\s+will\s+never\s+be\s+executed"
        WarningCompilation
        Warning
        (Some "SC-WARN-004")
        (Some "AOR-WARN-004")
        "Code after return/raise is unreachable"
        "Remove unreachable code or fix control flow"
        (Map.ofList [
            ("symptom", "Code never executes")
            ("surface_cause", "Return/raise before code")
            ("system_behavior", "Code compiled but skipped")
            ("config_gap", "No control flow analysis")
            ("design_flaw", "Logic error in flow")
        ])

/// WP-005: Missing @doc on public function
let WP005_MissingDocPublic =
    createElixirPattern
        "WP-005"
        "Missing @doc on Public Function"
        @"warning:.*public\s+function.*without\s+@doc|missing\s+documentation"
        WarningCompilation
        Warning
        (Some "SC-WARN-005")
        (Some "AOR-DOC-001")
        "Public function lacks documentation"
        "Add @doc with description"
        (Map.ofList [
            ("symptom", "Public function undocumented")
            ("surface_cause", "@doc not added")
            ("system_behavior", "ExDoc skips function")
            ("config_gap", "No doc enforcement")
            ("design_flaw", "Documentation debt")
        ])

/// WP-006: @doc on private function
let WP006_DocOnPrivate =
    createElixirPattern
        "WP-006"
        "@doc on Private Function"
        @"warning:.*@doc\s+.*private\s+function.*discarded|defp.*@doc.*ignored"
        WarningCompilation
        Warning
        (Some "SC-WARN-006")
        (Some "AOR-DOC-002")
        "@doc attribute ignored on private function"
        "Use # comments for private function docs"
        (Map.ofList [
            ("symptom", "@doc discarded for defp")
            ("surface_cause", "@doc on private function")
            ("system_behavior", "Documentation ignored")
            ("config_gap", "No doc scope validation")
            ("design_flaw", "Misunderstanding @doc scope")
        ])

/// WP-007: Redefining module
let WP007_RedefiningModule =
    createElixirPattern
        "WP-007"
        "Redefining Module"
        @"warning:.*redefining\s+module\s+(\S+)"
        WarningCompilation
        Warning
        (Some "SC-WARN-007")
        (Some "AOR-MOD-001")
        "Module being redefined (duplicate)"
        "Rename one module or consolidate"
        (Map.ofList [
            ("symptom", "Module redefinition warning")
            ("surface_cause", "Same module in multiple files")
            ("system_behavior", "Last definition wins")
            ("config_gap", "No namespace management")
            ("design_flaw", "Copy-paste without rename")
        ])

/// WP-008: Shadowing variable
let WP008_ShadowingVariable =
    createElixirPattern
        "WP-008"
        "Shadowing Variable"
        @"warning:.*variable\s+[`""]?(\w+)[`""]?\s+is\s+shadowed|shadows.*outer\s+variable"
        WarningCompilation
        Warning
        (Some "SC-WARN-008")
        (Some "AOR-VAR-003")
        "Variable shadows outer scope variable"
        "Rename inner variable to be unique"
        (Map.ofList [
            ("symptom", "Variable shadowing warning")
            ("surface_cause", "Same name in nested scope")
            ("system_behavior", "Inner hides outer")
            ("config_gap", "No shadow detection")
            ("design_flaw", "Confusing variable naming")
        ])

/// WP-009: Boolean comparison
let WP009_BooleanComparison =
    createElixirPattern
        "WP-009"
        "Boolean Comparison"
        @"warning:.*comparison\s+.*true|false.*always|comparing.*boolean.*literal"
        WarningCompilation
        Warning
        (Some "SC-WARN-009")
        (Some "AOR-BOOL-001")
        "Comparing to true/false is redundant"
        "Use value directly or negate with !"
        (Map.ofList [
            ("symptom", "Redundant boolean comparison")
            ("surface_cause", "Comparing to literal bool")
            ("system_behavior", "Works but verbose")
            ("config_gap", "No style enforcement")
            ("design_flaw", "Non-idiomatic code")
        ])

/// WP-010: String concatenation in interpolation
let WP010_ConcatInInterpolation =
    createElixirPattern
        "WP-010"
        "Concatenation in Interpolation"
        @"warning:.*concatenation.*inside\s+interpolation|<>\s+inside\s+#\{"
        WarningCompilation
        Warning
        (Some "SC-WARN-010")
        (Some "AOR-STR-001")
        "String concatenation inside interpolation"
        "Use multiple interpolations or concat outside"
        (Map.ofList [
            ("symptom", "Concat in interpolation warning")
            ("surface_cause", "<> used inside #{}")
            ("system_behavior", "Works but inefficient")
            ("config_gap", "No string optimization")
            ("design_flaw", "Performance anti-pattern")
        ])

/// WP-011: Guard expression has no effect
let WP011_GuardNoEffect =
    createElixirPattern
        "WP-011"
        "Guard Has No Effect"
        @"warning:.*guard.*no\s+effect|expression\s+in\s+guard.*unused"
        WarningCompilation
        Warning
        (Some "SC-WARN-011")
        (Some "AOR-GUARD-002")
        "Guard expression result is not used"
        "Remove effectless guard or use result"
        (Map.ofList [
            ("symptom", "Guard expression unused")
            ("surface_cause", "Guard returns unused value")
            ("system_behavior", "Guard evaluated but ignored")
            ("config_gap", "No guard effect analysis")
            ("design_flaw", "Misunderstanding guards")
        ])

/// WP-012: Clause never matches
let WP012_ClauseNeverMatches =
    createElixirPattern
        "WP-012"
        "Clause Never Matches"
        @"warning:.*clause.*never\s+match|pattern.*cannot\s+match"
        WarningCompilation
        Warning
        (Some "SC-WARN-012")
        (Some "AOR-MATCH-001")
        "Function/case clause can never match"
        "Fix pattern or remove clause"
        (Map.ofList [
            ("symptom", "Clause unreachable")
            ("surface_cause", "Pattern too restrictive")
            ("system_behavior", "Dead clause in function")
            ("config_gap", "No pattern coverage")
            ("design_flaw", "Copy-paste error")
        ])

/// WP-013: Atoms limit warning
let WP013_AtomsLimit =
    createElixirPattern
        "WP-013"
        "Atoms Limit Warning"
        @"warning:.*atom\s+table|too\s+many\s+atoms|atom\s+limit"
        WarningCompilation
        Warning
        (Some "SC-WARN-013")
        (Some "AOR-ATOM-001")
        "Approaching atom table limit"
        "Use strings for dynamic values"
        (Map.ofList [
            ("symptom", "Atom table growth warning")
            ("surface_cause", "Dynamic atom creation")
            ("system_behavior", "System may crash")
            ("config_gap", "No atom monitoring")
            ("design_flaw", "Using atoms for data")
        ])

/// WP-014: Large binary literal
let WP014_LargeBinaryLiteral =
    createElixirPattern
        "WP-014"
        "Large Binary Literal"
        @"warning:.*large\s+binary|binary.*too\s+large|embedded\s+binary"
        WarningCompilation
        Warning
        (Some "SC-WARN-014")
        (Some "AOR-BIN-001")
        "Large binary literal in code"
        "Load from file at runtime instead"
        (Map.ofList [
            ("symptom", "Large binary in source")
            ("surface_cause", "Binary embedded in code")
            ("system_behavior", "Slow compilation")
            ("config_gap", "No size limit check")
            ("design_flaw", "Data in code")
        ])

/// WP-015: Spawn without link/monitor
let WP015_SpawnWithoutLink =
    createElixirPattern
        "WP-015"
        "Spawn Without Link/Monitor"
        @"warning:.*spawn\s+without.*link|unlinked\s+process|orphan\s+process"
        WarningCompilation
        Warning
        (Some "SC-WARN-015")
        (Some "AOR-PROC-001")
        "Process spawned without supervision"
        "Use spawn_link or Task/GenServer"
        (Map.ofList [
            ("symptom", "Orphan process created")
            ("surface_cause", "spawn without link")
            ("system_behavior", "Process may crash silently")
            ("config_gap", "No supervision")
            ("design_flaw", "Raw spawn usage")
        ])

/// WP-016: Unsafe variable
let WP016_UnsafeVariable =
    createElixirPattern
        "WP-016"
        "Unsafe Variable"
        @"warning:.*unsafe\s+variable|variable.*may\s+not\s+be\s+bound"
        WarningCompilation
        Warning
        (Some "SC-WARN-016")
        (Some "AOR-VAR-004")
        "Variable may not be bound in all paths"
        "Ensure variable is bound in all branches"
        (Map.ofList [
            ("symptom", "Variable possibly unbound")
            ("surface_cause", "Conditional binding")
            ("system_behavior", "May fail at runtime")
            ("config_gap", "No flow analysis")
            ("design_flaw", "Incomplete pattern coverage")
        ])

/// WP-017: Long compile time
let WP017_LongCompileTime =
    createElixirPattern
        "WP-017"
        "Long Compile Time"
        @"warning:.*long\s+compile|compilation.*slow|compile.*time.*exceeded"
        WarningCompilation
        Warning
        (Some "SC-WARN-017")
        (Some "AOR-PERF-001")
        "Module takes unusually long to compile"
        "Split module or reduce macros"
        (Map.ofList [
            ("symptom", "Slow compilation")
            ("surface_cause", "Complex macros or large module")
            ("system_behavior", "Build time increases")
            ("config_gap", "No compile time budget")
            ("design_flaw", "Macro abuse")
        ])

/// WP-018: Deep nesting
let WP018_DeepNesting =
    createElixirPattern
        "WP-018"
        "Deep Nesting"
        @"warning:.*deep.*nesting|nesting.*level.*exceeded|too\s+many\s+nested"
        WarningCompilation
        Warning
        (Some "SC-WARN-018")
        (Some "AOR-STYLE-001")
        "Code has excessive nesting depth"
        "Extract to helper functions"
        (Map.ofList [
            ("symptom", "Deep nesting warning")
            ("surface_cause", "Many nested blocks")
            ("system_behavior", "Hard to read/maintain")
            ("config_gap", "No nesting limit")
            ("design_flaw", "Monolithic functions")
        ])

/// WP-019: Comparison always true/false
let WP019_ComparisonAlways =
    createElixirPattern
        "WP-019"
        "Comparison Always True/False"
        @"warning:.*comparison.*always.*true|comparison.*always.*false|result.*always"
        WarningCompilation
        Warning
        (Some "SC-WARN-019")
        (Some "AOR-LOGIC-001")
        "Comparison result is constant"
        "Check logic or remove dead branch"
        (Map.ofList [
            ("symptom", "Constant comparison result")
            ("surface_cause", "Logic error or dead code")
            ("system_behavior", "Branch never/always taken")
            ("config_gap", "No static analysis")
            ("design_flaw", "Logic error")
        ])

/// WP-020: Compile dependency cycle
let WP020_DependencyCycle =
    createElixirPattern
        "WP-020"
        "Compile Dependency Cycle"
        @"warning:.*dependency.*cycle|circular.*dependency|compile.*cycle"
        WarningCompilation
        Warning
        (Some "SC-WARN-020")
        (Some "AOR-DEP-001")
        "Compile-time dependency cycle detected"
        "Refactor to break cycle"
        (Map.ofList [
            ("symptom", "Dependency cycle warning")
            ("surface_cause", "Modules depend on each other")
            ("system_behavior", "Slow/unstable compilation")
            ("config_gap", "No cycle detection")
            ("design_flaw", "Tangled architecture")
        ])

/// WP-021: Missing return type
let WP021_MissingReturnType =
    createElixirPattern
        "WP-021"
        "Missing Return Type in Spec"
        @"warning:.*missing.*return\s+type|@spec.*no\s+return|spec.*incomplete"
        WarningCompilation
        Warning
        (Some "SC-WARN-021")
        (Some "AOR-SPEC-001")
        "@spec missing return type"
        "Add return type to @spec"
        (Map.ofList [
            ("symptom", "Incomplete @spec")
            ("surface_cause", "Return type omitted")
            ("system_behavior", "Dialyzer less effective")
            ("config_gap", "No spec completeness check")
            ("design_flaw", "Partial type specification")
        ])

/// WP-022: Overridden callback
let WP022_OverriddenCallback =
    createElixirPattern
        "WP-022"
        "Overridden Callback"
        @"warning:.*callback.*overridden|override.*behaviour|callback.*replaced"
        WarningCompilation
        Warning
        (Some "SC-WARN-022")
        (Some "AOR-CB-001")
        "Behaviour callback is overridden"
        "Use @impl true or rename"
        (Map.ofList [
            ("symptom", "Callback override warning")
            ("surface_cause", "Function overrides callback")
            ("system_behavior", "May break behaviour contract")
            ("config_gap", "No @impl enforcement")
            ("design_flaw", "Accidental override")
        ])

/// WP-023: Unused macro
let WP023_UnusedMacro =
    createElixirPattern
        "WP-023"
        "Unused Macro"
        @"warning:.*macro\s+(\w+/\d+)\s+is\s+unused"
        WarningCompilation
        Warning
        (Some "SC-WARN-023")
        (Some "AOR-MACRO-003")
        "Defined macro is never used"
        "Remove macro or use it"
        (Map.ofList [
            ("symptom", "Macro never invoked")
            ("surface_cause", "Dead macro code")
            ("system_behavior", "Macro compiled but unused")
            ("config_gap", "No macro usage tracking")
            ("design_flaw", "Leftover from development")
        ])

/// WP-024: Map update syntax deprecated
let WP024_MapUpdateDeprecated =
    createElixirPattern
        "WP-024"
        "Map Update Syntax Warning"
        @"warning:.*map.*update.*deprecated|%\{.*\|.*\}.*warning"
        WarningCompilation
        Warning
        (Some "SC-WARN-024")
        (Some "AOR-MAP-001")
        "Old map update syntax usage"
        "Use Map.put or modern syntax"
        (Map.ofList [
            ("symptom", "Deprecated map syntax")
            ("surface_cause", "Old syntax still used")
            ("system_behavior", "Works but warned")
            ("config_gap", "No syntax version check")
            ("design_flaw", "Code not updated")
        ])

/// WP-025: Function clause order
let WP025_ClauseOrder =
    createElixirPattern
        "WP-025"
        "Function Clause Order"
        @"warning:.*clause.*order|specific.*after.*general|clause.*shadowed"
        WarningCompilation
        Warning
        (Some "SC-WARN-025")
        (Some "AOR-CLAUSE-001")
        "Function clauses in wrong order"
        "Order from specific to general"
        (Map.ofList [
            ("symptom", "Clause order warning")
            ("surface_cause", "General before specific")
            ("system_behavior", "Later clauses unreachable")
            ("config_gap", "No clause order check")
            ("design_flaw", "Pattern matching confusion")
        ])

// ----------------------------------------------------------------------------
// UNUSED CODE WARNINGS (WP-026 to WP-050)
// ----------------------------------------------------------------------------

/// WP-026: Unused alias
let WP026_UnusedAlias =
    createElixirPattern
        "WP-026"
        "Unused Alias"
        @"warning:.*unused\s+alias\s+(\w+)|alias.*never\s+used"
        WarningUnused
        Warning
        (Some "SC-UNUSED-001")
        (Some "AOR-UNUSED-001")
        "Alias is declared but never used"
        "Remove unused alias"
        (Map.ofList [
            ("symptom", "Alias never referenced")
            ("surface_cause", "Dead import code")
            ("system_behavior", "Alias loaded but unused")
            ("config_gap", "No alias usage tracking")
            ("design_flaw", "Leftover from refactoring")
        ])

/// WP-027: Unused import
let WP027_UnusedImport =
    createElixirPattern
        "WP-027"
        "Unused Import"
        @"warning:.*unused\s+import|import.*never\s+used"
        WarningUnused
        Warning
        (Some "SC-UNUSED-002")
        (Some "AOR-UNUSED-002")
        "Import is declared but no functions used"
        "Remove unused import"
        (Map.ofList [
            ("symptom", "Import never referenced")
            ("surface_cause", "Dead import statement")
            ("system_behavior", "Functions imported but unused")
            ("config_gap", "No import usage tracking")
            ("design_flaw", "Over-importing")
        ])

/// WP-028: Unused require
let WP028_UnusedRequire =
    createElixirPattern
        "WP-028"
        "Unused Require"
        @"warning:.*unused\s+require|require.*never\s+used"
        WarningUnused
        Warning
        (Some "SC-UNUSED-003")
        (Some "AOR-UNUSED-003")
        "Require is declared but macros never used"
        "Remove unused require"
        (Map.ofList [
            ("symptom", "Require never referenced")
            ("surface_cause", "Dead require statement")
            ("system_behavior", "Macros loaded but unused")
            ("config_gap", "No require usage tracking")
            ("design_flaw", "Copy-paste requires")
        ])

/// WP-029: Unused module attribute
let WP029_UnusedModuleAttr =
    createElixirPattern
        "WP-029"
        "Unused Module Attribute"
        @"warning:.*module\s+attribute\s+@(\w+).*unused|@\w+.*never\s+used"
        WarningUnused
        Warning
        (Some "SC-UNUSED-004")
        (Some "AOR-UNUSED-004")
        "Module attribute defined but never used"
        "Remove or use the attribute"
        (Map.ofList [
            ("symptom", "Attribute never referenced")
            ("surface_cause", "Dead attribute definition")
            ("system_behavior", "Attribute compiled but unused")
            ("config_gap", "No attribute usage tracking")
            ("design_flaw", "Planned feature not implemented")
        ])

/// WP-030: Unused type
let WP030_UnusedType =
    createElixirPattern
        "WP-030"
        "Unused Type"
        @"warning:.*type\s+(\w+).*is\s+unused|@type.*never\s+used"
        WarningUnused
        Warning
        (Some "SC-UNUSED-005")
        (Some "AOR-UNUSED-005")
        "Type definition is never referenced"
        "Remove unused type or use it"
        (Map.ofList [
            ("symptom", "Type never referenced")
            ("surface_cause", "Dead type definition")
            ("system_behavior", "Type compiled but unused")
            ("config_gap", "No type usage tracking")
            ("design_flaw", "Over-specification")
        ])

/// WP-031: Unused struct key
let WP031_UnusedStructKey =
    createElixirPattern
        "WP-031"
        "Unused Struct Key"
        @"warning:.*struct\s+key\s+:(\w+).*unused|defstruct.*key.*never\s+used"
        WarningUnused
        Warning
        (Some "SC-UNUSED-006")
        (Some "AOR-UNUSED-006")
        "Struct key is never accessed"
        "Remove key or access it"
        (Map.ofList [
            ("symptom", "Struct key never accessed")
            ("surface_cause", "Dead struct field")
            ("system_behavior", "Key exists but unused")
            ("config_gap", "No struct usage analysis")
            ("design_flaw", "Over-specified struct")
        ])

/// WP-032: Unused callback
let WP032_UnusedCallback =
    createElixirPattern
        "WP-032"
        "Unused Callback"
        @"warning:.*callback\s+(\w+).*unused|@callback.*never\s+implemented"
        WarningUnused
        Warning
        (Some "SC-UNUSED-007")
        (Some "AOR-UNUSED-007")
        "Behaviour callback is never implemented"
        "Implement callback or remove from behaviour"
        (Map.ofList [
            ("symptom", "Callback not implemented")
            ("surface_cause", "Missing implementation")
            ("system_behavior", "Behaviour incomplete")
            ("config_gap", "No callback tracking")
            ("design_flaw", "Behaviour too large")
        ])

/// WP-033: Unused typep
let WP033_UnusedPrivateType =
    createElixirPattern
        "WP-033"
        "Unused Private Type"
        @"warning:.*typep\s+(\w+).*unused|private\s+type.*never\s+used"
        WarningUnused
        Warning
        (Some "SC-UNUSED-008")
        (Some "AOR-UNUSED-008")
        "Private type is never used"
        "Remove or use the private type"
        (Map.ofList [
            ("symptom", "Private type unused")
            ("surface_cause", "Dead type definition")
            ("system_behavior", "Type exists but unused")
            ("config_gap", "No private type tracking")
            ("design_flaw", "Leftover from refactoring")
        ])

/// WP-034: Unused behaviour
let WP034_UnusedBehaviour =
    createElixirPattern
        "WP-034"
        "Unused Behaviour"
        @"warning:.*behaviour\s+(\w+).*unused|@behaviour.*not\s+used"
        WarningUnused
        Warning
        (Some "SC-UNUSED-009")
        (Some "AOR-UNUSED-009")
        "Declared behaviour not implemented"
        "Implement or remove @behaviour"
        (Map.ofList [
            ("symptom", "Behaviour not used")
            ("surface_cause", "Missing implementations")
            ("system_behavior", "Behaviour declaration only")
            ("config_gap", "No behaviour enforcement")
            ("design_flaw", "Interface not realized")
        ])

/// WP-035: Unused exception
let WP035_UnusedException =
    createElixirPattern
        "WP-035"
        "Unused Exception"
        @"warning:.*exception.*unused|defexception.*never\s+raised"
        WarningUnused
        Warning
        (Some "SC-UNUSED-010")
        (Some "AOR-UNUSED-010")
        "Custom exception is never raised"
        "Raise or remove the exception"
        (Map.ofList [
            ("symptom", "Exception never raised")
            ("surface_cause", "Dead exception definition")
            ("system_behavior", "Exception exists but unused")
            ("config_gap", "No exception usage tracking")
            ("design_flaw", "Over-designed error handling")
        ])

/// WP-036: Unused protocol
let WP036_UnusedProtocol =
    createElixirPattern
        "WP-036"
        "Unused Protocol"
        @"warning:.*protocol.*unused|defprotocol.*never\s+implemented"
        WarningUnused
        Warning
        (Some "SC-UNUSED-011")
        (Some "AOR-UNUSED-011")
        "Protocol defined but never implemented"
        "Implement or remove protocol"
        (Map.ofList [
            ("symptom", "Protocol without implementations")
            ("surface_cause", "Dead protocol definition")
            ("system_behavior", "Protocol exists but unused")
            ("config_gap", "No protocol tracking")
            ("design_flaw", "Premature abstraction")
        ])

/// WP-037: Unused guard function
let WP037_UnusedGuardFunc =
    createElixirPattern
        "WP-037"
        "Unused Guard Function"
        @"warning:.*defguard.*unused|guard.*function.*never\s+used"
        WarningUnused
        Warning
        (Some "SC-UNUSED-012")
        (Some "AOR-UNUSED-012")
        "Custom guard function is never used"
        "Use or remove the guard function"
        (Map.ofList [
            ("symptom", "Guard function unused")
            ("surface_cause", "Dead guard definition")
            ("system_behavior", "Guard compiled but unused")
            ("config_gap", "No guard usage tracking")
            ("design_flaw", "Over-engineering")
        ])

/// WP-038: Unused config value
let WP038_UnusedConfigValue =
    createElixirPattern
        "WP-038"
        "Unused Config Value"
        @"warning:.*config.*unused|Application\.get_env.*never\s+called"
        WarningUnused
        Warning
        (Some "SC-UNUSED-013")
        (Some "AOR-UNUSED-013")
        "Configuration value is never accessed"
        "Remove config or access it"
        (Map.ofList [
            ("symptom", "Config value unused")
            ("surface_cause", "Dead configuration")
            ("system_behavior", "Config loaded but unused")
            ("config_gap", "No config usage tracking")
            ("design_flaw", "Config drift")
        ])

/// WP-039: Unused ETS table
let WP039_UnusedEtsTable =
    createElixirPattern
        "WP-039"
        "Unused ETS Table"
        @"warning:.*ETS.*table.*unused|:ets\.new.*never\s+used"
        WarningUnused
        Warning
        (Some "SC-UNUSED-014")
        (Some "AOR-UNUSED-014")
        "ETS table created but never used"
        "Use or remove the ETS table"
        (Map.ofList [
            ("symptom", "ETS table unused")
            ("surface_cause", "Dead table creation")
            ("system_behavior", "Table exists but unused")
            ("config_gap", "No ETS tracking")
            ("design_flaw", "Memory waste")
        ])

/// WP-040: Unused GenServer callback
let WP040_UnusedGenServerCb =
    createElixirPattern
        "WP-040"
        "Unused GenServer Callback"
        @"warning:.*handle_\w+.*unused|GenServer.*callback.*never\s+called"
        WarningUnused
        Warning
        (Some "SC-UNUSED-015")
        (Some "AOR-UNUSED-015")
        "GenServer callback never triggered"
        "Remove or trigger the callback"
        (Map.ofList [
            ("symptom", "Callback never called")
            ("surface_cause", "Dead callback code")
            ("system_behavior", "Callback exists but unused")
            ("config_gap", "No callback tracking")
            ("design_flaw", "Unused message handler")
        ])

/// WP-041: Unused test helper
let WP041_UnusedTestHelper =
    createElixirPattern
        "WP-041"
        "Unused Test Helper"
        @"warning:.*test.*helper.*unused|setup.*never\s+used"
        WarningUnused
        Warning
        (Some "SC-UNUSED-016")
        (Some "AOR-UNUSED-016")
        "Test helper function is never called"
        "Use or remove the test helper"
        (Map.ofList [
            ("symptom", "Test helper unused")
            ("surface_cause", "Dead test code")
            ("system_behavior", "Helper exists but unused")
            ("config_gap", "No test code tracking")
            ("design_flaw", "Test debt")
        ])

/// WP-042: Unused pattern variable
let WP042_UnusedPatternVar =
    createElixirPattern
        "WP-042"
        "Unused Pattern Variable"
        @"warning:.*pattern.*variable.*unused|match.*variable.*never\s+used"
        WarningUnused
        Warning
        (Some "SC-UNUSED-017")
        (Some "AOR-UNUSED-017")
        "Variable in pattern match is unused"
        "Prefix with _ or use the variable"
        (Map.ofList [
            ("symptom", "Pattern variable unused")
            ("surface_cause", "Over-destructuring")
            ("system_behavior", "Variable bound but unused")
            ("config_gap", "No pattern analysis")
            ("design_flaw", "Unnecessary binding")
        ])

/// WP-043: Unused plug
let WP043_UnusedPlug =
    createElixirPattern
        "WP-043"
        "Unused Plug"
        @"warning:.*plug.*unused|plug\s+\w+.*never\s+called"
        WarningUnused
        Warning
        (Some "SC-UNUSED-018")
        (Some "AOR-UNUSED-018")
        "Plug is defined but not in pipeline"
        "Add to pipeline or remove"
        (Map.ofList [
            ("symptom", "Plug not in pipeline")
            ("surface_cause", "Dead plug code")
            ("system_behavior", "Plug exists but unused")
            ("config_gap", "No plug tracking")
            ("design_flaw", "Orphan plug")
        ])

/// WP-044: Unused schema field
let WP044_UnusedSchemaField =
    createElixirPattern
        "WP-044"
        "Unused Schema Field"
        @"warning:.*schema.*field.*unused|field.*never\s+accessed"
        WarningUnused
        Warning
        (Some "SC-UNUSED-019")
        (Some "AOR-UNUSED-019")
        "Ecto schema field is never used"
        "Remove field or use it"
        (Map.ofList [
            ("symptom", "Schema field unused")
            ("surface_cause", "Dead database column")
            ("system_behavior", "Field loaded but unused")
            ("config_gap", "No schema analysis")
            ("design_flaw", "Schema drift")
        ])

/// WP-045: Unused changeset function
let WP045_UnusedChangesetFn =
    createElixirPattern
        "WP-045"
        "Unused Changeset Function"
        @"warning:.*changeset.*unused|validate_\w+.*never\s+called"
        WarningUnused
        Warning
        (Some "SC-UNUSED-020")
        (Some "AOR-UNUSED-020")
        "Changeset validation function unused"
        "Use or remove the validation"
        (Map.ofList [
            ("symptom", "Validation function unused")
            ("surface_cause", "Dead validation code")
            ("system_behavior", "Function exists but unused")
            ("config_gap", "No changeset tracking")
            ("design_flaw", "Validation drift")
        ])

/// WP-046: Unused context function
let WP046_UnusedContextFn =
    createElixirPattern
        "WP-046"
        "Unused Context Function"
        @"warning:.*context.*function.*unused|list_\w+.*never\s+called"
        WarningUnused
        Warning
        (Some "SC-UNUSED-021")
        (Some "AOR-UNUSED-021")
        "Phoenix context function is unused"
        "Use or remove the function"
        (Map.ofList [
            ("symptom", "Context function unused")
            ("surface_cause", "Dead context code")
            ("system_behavior", "Function exists but unused")
            ("config_gap", "No context tracking")
            ("design_flaw", "Generated code not used")
        ])

/// WP-047: Unused LiveView assign
let WP047_UnusedLiveViewAssign =
    createElixirPattern
        "WP-047"
        "Unused LiveView Assign"
        @"warning:.*assign.*unused|@\w+.*never\s+used.*template"
        WarningUnused
        Warning
        (Some "SC-UNUSED-022")
        (Some "AOR-UNUSED-022")
        "LiveView assign is never used in template"
        "Remove assign or use in template"
        (Map.ofList [
            ("symptom", "Assign never rendered")
            ("surface_cause", "Dead assign")
            ("system_behavior", "Assign exists but unused")
            ("config_gap", "No template tracking")
            ("design_flaw", "Stale assigns")
        ])

/// WP-048: Unused event handler
let WP048_UnusedEventHandler =
    createElixirPattern
        "WP-048"
        "Unused Event Handler"
        @"warning:.*handle_event.*unused|phx-\w+.*never\s+triggered"
        WarningUnused
        Warning
        (Some "SC-UNUSED-023")
        (Some "AOR-UNUSED-023")
        "LiveView event handler is never triggered"
        "Wire up event or remove handler"
        (Map.ofList [
            ("symptom", "Event handler orphaned")
            ("surface_cause", "Dead event code")
            ("system_behavior", "Handler exists but unused")
            ("config_gap", "No event tracking")
            ("design_flaw", "UI/code mismatch")
        ])

/// WP-049: Unused channel callback
let WP049_UnusedChannelCb =
    createElixirPattern
        "WP-049"
        "Unused Channel Callback"
        @"warning:.*channel.*callback.*unused|handle_in.*never\s+called"
        WarningUnused
        Warning
        (Some "SC-UNUSED-024")
        (Some "AOR-UNUSED-024")
        "Channel callback is never triggered"
        "Wire up message or remove handler"
        (Map.ofList [
            ("symptom", "Channel handler orphaned")
            ("surface_cause", "Dead channel code")
            ("system_behavior", "Handler exists but unused")
            ("config_gap", "No channel tracking")
            ("design_flaw", "Protocol drift")
        ])

/// WP-050: Unused telemetry handler
let WP050_UnusedTelemetryHandler =
    createElixirPattern
        "WP-050"
        "Unused Telemetry Handler"
        @"warning:.*telemetry.*handler.*unused|:telemetry\.attach.*never\s+triggered"
        WarningUnused
        Warning
        (Some "SC-UNUSED-025")
        (Some "AOR-UNUSED-025")
        "Telemetry handler never receives events"
        "Emit events or remove handler"
        (Map.ofList [
            ("symptom", "Handler never triggered")
            ("surface_cause", "Dead telemetry code")
            ("system_behavior", "Handler exists but unused")
            ("config_gap", "No telemetry tracking")
            ("design_flaw", "Observability gap")
        ])

// ============================================================================
// WP-051 to WP-075: DEPRECATION WARNINGS
// STAMP: SC-DEPR-001 to SC-DEPR-025
// ============================================================================

/// WP-051: Deprecated function call
let WP051_DeprecatedFunction =
    createElixirPattern
        "WP-051"
        "Deprecated Function"
        @"warning:.*function\s+(\w+\.\w+/\d+)\s+is\s+deprecated"
        WarningDeprecation
        Warning
        (Some "SC-DEPR-001")
        (Some "AOR-DEPR-001")
        "Calling a function marked as deprecated"
        "Use the recommended replacement function"
        (Map.ofList [
            ("symptom", "Deprecated function warning")
            ("surface_cause", "Using old API")
            ("system_behavior", "Function still works but will be removed")
            ("config_gap", "No deprecation tracking")
            ("design_flaw", "Not updating to new APIs")
        ])

/// WP-052: Deprecated module usage
let WP052_DeprecatedModule =
    createElixirPattern
        "WP-052"
        "Deprecated Module"
        @"warning:.*module\s+(\w+)\s+is\s+deprecated"
        WarningDeprecation
        Warning
        (Some "SC-DEPR-002")
        (Some "AOR-DEPR-002")
        "Using a module marked as deprecated"
        "Migrate to the replacement module"
        (Map.ofList [
            ("symptom", "Deprecated module warning")
            ("surface_cause", "Using old module")
            ("system_behavior", "Module works but will be removed")
            ("config_gap", "No module migration tracking")
            ("design_flaw", "Technical debt accumulation")
        ])

/// WP-053: Deprecated behaviour callback
let WP053_DeprecatedCallback =
    createElixirPattern
        "WP-053"
        "Deprecated Behaviour Callback"
        @"warning:.*callback\s+(\w+/\d+)\s+is\s+deprecated"
        WarningDeprecation
        Warning
        (Some "SC-DEPR-003")
        (Some "AOR-DEPR-003")
        "Implementing a deprecated behaviour callback"
        "Update to new callback signature"
        (Map.ofList [
            ("symptom", "Deprecated callback warning")
            ("surface_cause", "Old behaviour implementation")
            ("system_behavior", "Callback works but signature changing")
            ("config_gap", "No callback tracking")
            ("design_flaw", "Behaviour API evolution")
        ])

/// WP-054: Deprecated Ecto function
let WP054_DeprecatedEcto =
    createElixirPattern
        "WP-054"
        "Deprecated Ecto Function"
        @"warning:.*Ecto\.(\w+)\s+is\s+deprecated|Repo\.(\w+)/\d+\s+is\s+deprecated"
        WarningDeprecation
        Warning
        (Some "SC-DEPR-004")
        (Some "AOR-DEPR-004")
        "Using deprecated Ecto function"
        "Update to new Ecto API"
        (Map.ofList [
            ("symptom", "Deprecated Ecto warning")
            ("surface_cause", "Old Ecto API usage")
            ("system_behavior", "Query works but API changing")
            ("config_gap", "No Ecto version tracking")
            ("design_flaw", "Not following Ecto updates")
        ])

/// WP-055: Deprecated Phoenix function
let WP055_DeprecatedPhoenix =
    createElixirPattern
        "WP-055"
        "Deprecated Phoenix Function"
        @"warning:.*Phoenix\.(\w+)\s+is\s+deprecated|Phoenix\.\w+\.(\w+)/\d+\s+is\s+deprecated"
        WarningDeprecation
        Warning
        (Some "SC-DEPR-005")
        (Some "AOR-DEPR-005")
        "Using deprecated Phoenix function"
        "Update to new Phoenix API"
        (Map.ofList [
            ("symptom", "Deprecated Phoenix warning")
            ("surface_cause", "Old Phoenix API usage")
            ("system_behavior", "Function works but API changing")
            ("config_gap", "No Phoenix version tracking")
            ("design_flaw", "Not following Phoenix updates")
        ])

/// WP-056: Deprecated Plug function
let WP056_DeprecatedPlug =
    createElixirPattern
        "WP-056"
        "Deprecated Plug Function"
        @"warning:.*Plug\.(\w+)\s+is\s+deprecated"
        WarningDeprecation
        Warning
        (Some "SC-DEPR-006")
        (Some "AOR-DEPR-006")
        "Using deprecated Plug function"
        "Update to new Plug API"
        (Map.ofList [
            ("symptom", "Deprecated Plug warning")
            ("surface_cause", "Old Plug API usage")
            ("system_behavior", "Plug works but API changing")
            ("config_gap", "No Plug version tracking")
            ("design_flaw", "Not following Plug updates")
        ])

/// WP-057: Deprecated Logger function
let WP057_DeprecatedLogger =
    createElixirPattern
        "WP-057"
        "Deprecated Logger Function"
        @"warning:.*Logger\.(\w+)/\d+\s+is\s+deprecated"
        WarningDeprecation
        Warning
        (Some "SC-DEPR-007")
        (Some "AOR-DEPR-007")
        "Using deprecated Logger function"
        "Update to new Logger API"
        (Map.ofList [
            ("symptom", "Deprecated Logger warning")
            ("surface_cause", "Old Logger API usage")
            ("system_behavior", "Logging works but API changing")
            ("config_gap", "No Logger version tracking")
            ("design_flaw", "Not following Logger updates")
        ])

/// WP-058: Deprecated GenServer function
let WP058_DeprecatedGenServer =
    createElixirPattern
        "WP-058"
        "Deprecated GenServer Function"
        @"warning:.*GenServer\.(\w+)/\d+\s+is\s+deprecated"
        WarningDeprecation
        Warning
        (Some "SC-DEPR-008")
        (Some "AOR-DEPR-008")
        "Using deprecated GenServer function"
        "Update to new GenServer API"
        (Map.ofList [
            ("symptom", "Deprecated GenServer warning")
            ("surface_cause", "Old GenServer API usage")
            ("system_behavior", "GenServer works but API changing")
            ("config_gap", "No GenServer version tracking")
            ("design_flaw", "Not following OTP updates")
        ])

/// WP-059: Deprecated Agent function
let WP059_DeprecatedAgent =
    createElixirPattern
        "WP-059"
        "Deprecated Agent Function"
        @"warning:.*Agent\.(\w+)/\d+\s+is\s+deprecated"
        WarningDeprecation
        Warning
        (Some "SC-DEPR-009")
        (Some "AOR-DEPR-009")
        "Using deprecated Agent function"
        "Update to new Agent API or use GenServer"
        (Map.ofList [
            ("symptom", "Deprecated Agent warning")
            ("surface_cause", "Old Agent API usage")
            ("system_behavior", "Agent works but API changing")
            ("config_gap", "No Agent version tracking")
            ("design_flaw", "Consider GenServer for complex state")
        ])

/// WP-060: Deprecated Task function
let WP060_DeprecatedTask =
    createElixirPattern
        "WP-060"
        "Deprecated Task Function"
        @"warning:.*Task\.(\w+)/\d+\s+is\s+deprecated"
        WarningDeprecation
        Warning
        (Some "SC-DEPR-010")
        (Some "AOR-DEPR-010")
        "Using deprecated Task function"
        "Update to new Task API"
        (Map.ofList [
            ("symptom", "Deprecated Task warning")
            ("surface_cause", "Old Task API usage")
            ("system_behavior", "Task works but API changing")
            ("config_gap", "No Task version tracking")
            ("design_flaw", "Not following OTP updates")
        ])

/// WP-061: Deprecated String function
let WP061_DeprecatedString =
    createElixirPattern
        "WP-061"
        "Deprecated String Function"
        @"warning:.*String\.(\w+)/\d+\s+is\s+deprecated"
        WarningDeprecation
        Warning
        (Some "SC-DEPR-011")
        (Some "AOR-DEPR-011")
        "Using deprecated String function"
        "Update to new String API"
        (Map.ofList [
            ("symptom", "Deprecated String warning")
            ("surface_cause", "Old String API usage")
            ("system_behavior", "Function works but API changing")
            ("config_gap", "No String version tracking")
            ("design_flaw", "Not following Elixir updates")
        ])

/// WP-062: Deprecated Enum function
let WP062_DeprecatedEnum =
    createElixirPattern
        "WP-062"
        "Deprecated Enum Function"
        @"warning:.*Enum\.(\w+)/\d+\s+is\s+deprecated"
        WarningDeprecation
        Warning
        (Some "SC-DEPR-012")
        (Some "AOR-DEPR-012")
        "Using deprecated Enum function"
        "Update to new Enum API"
        (Map.ofList [
            ("symptom", "Deprecated Enum warning")
            ("surface_cause", "Old Enum API usage")
            ("system_behavior", "Function works but API changing")
            ("config_gap", "No Enum version tracking")
            ("design_flaw", "Not following Elixir updates")
        ])

/// WP-063: Deprecated Map function
let WP063_DeprecatedMap =
    createElixirPattern
        "WP-063"
        "Deprecated Map Function"
        @"warning:.*Map\.(\w+)/\d+\s+is\s+deprecated"
        WarningDeprecation
        Warning
        (Some "SC-DEPR-013")
        (Some "AOR-DEPR-013")
        "Using deprecated Map function"
        "Update to new Map API"
        (Map.ofList [
            ("symptom", "Deprecated Map warning")
            ("surface_cause", "Old Map API usage")
            ("system_behavior", "Function works but API changing")
            ("config_gap", "No Map version tracking")
            ("design_flaw", "Not following Elixir updates")
        ])

/// WP-064: Deprecated Keyword function
let WP064_DeprecatedKeyword =
    createElixirPattern
        "WP-064"
        "Deprecated Keyword Function"
        @"warning:.*Keyword\.(\w+)/\d+\s+is\s+deprecated"
        WarningDeprecation
        Warning
        (Some "SC-DEPR-014")
        (Some "AOR-DEPR-014")
        "Using deprecated Keyword function"
        "Update to new Keyword API"
        (Map.ofList [
            ("symptom", "Deprecated Keyword warning")
            ("surface_cause", "Old Keyword API usage")
            ("system_behavior", "Function works but API changing")
            ("config_gap", "No Keyword version tracking")
            ("design_flaw", "Not following Elixir updates")
        ])

/// WP-065: Deprecated List function
let WP065_DeprecatedList =
    createElixirPattern
        "WP-065"
        "Deprecated List Function"
        @"warning:.*List\.(\w+)/\d+\s+is\s+deprecated"
        WarningDeprecation
        Warning
        (Some "SC-DEPR-015")
        (Some "AOR-DEPR-015")
        "Using deprecated List function"
        "Update to new List API"
        (Map.ofList [
            ("symptom", "Deprecated List warning")
            ("surface_cause", "Old List API usage")
            ("system_behavior", "Function works but API changing")
            ("config_gap", "No List version tracking")
            ("design_flaw", "Not following Elixir updates")
        ])

/// WP-066: Deprecated Ash function
let WP066_DeprecatedAsh =
    createElixirPattern
        "WP-066"
        "Deprecated Ash Function"
        @"warning:.*Ash\.(\w+)/\d+\s+is\s+deprecated|Ash\.\w+\.(\w+)/\d+\s+is\s+deprecated"
        WarningDeprecation
        Warning
        (Some "SC-DEPR-016")
        (Some "AOR-DEPR-016")
        "Using deprecated Ash function"
        "Update to new Ash 3.x API"
        (Map.ofList [
            ("symptom", "Deprecated Ash warning")
            ("surface_cause", "Old Ash API usage")
            ("system_behavior", "Function works but API changing")
            ("config_gap", "No Ash version tracking")
            ("design_flaw", "Not following Ash 3.x migration")
        ])

/// WP-067: Deprecated macro
let WP067_DeprecatedMacro =
    createElixirPattern
        "WP-067"
        "Deprecated Macro"
        @"warning:.*macro\s+(\w+)\s+is\s+deprecated"
        WarningDeprecation
        Warning
        (Some "SC-DEPR-017")
        (Some "AOR-DEPR-017")
        "Using deprecated macro"
        "Update to replacement macro or function"
        (Map.ofList [
            ("symptom", "Deprecated macro warning")
            ("surface_cause", "Old macro usage")
            ("system_behavior", "Macro works but will be removed")
            ("config_gap", "No macro deprecation tracking")
            ("design_flaw", "Technical debt accumulation")
        ])

/// WP-068: Deprecated type spec
let WP068_DeprecatedTypeSpec =
    createElixirPattern
        "WP-068"
        "Deprecated Type Spec"
        @"warning:.*type\s+@type\s+(\w+)\s+is\s+deprecated|typep?\s+(\w+)\s+is\s+deprecated"
        WarningDeprecation
        Warning
        (Some "SC-DEPR-018")
        (Some "AOR-DEPR-018")
        "Using deprecated type specification"
        "Update to new type definition"
        (Map.ofList [
            ("symptom", "Deprecated type warning")
            ("surface_cause", "Old type specification")
            ("system_behavior", "Type works but definition changing")
            ("config_gap", "No type evolution tracking")
            ("design_flaw", "Type system evolution")
        ])

/// WP-069: Deprecated config key
let WP069_DeprecatedConfig =
    createElixirPattern
        "WP-069"
        "Deprecated Config Key"
        @"warning:.*config.*key\s+:(\w+)\s+is\s+deprecated"
        WarningDeprecation
        Warning
        (Some "SC-DEPR-019")
        (Some "AOR-DEPR-019")
        "Using deprecated configuration key"
        "Update config to use new key"
        (Map.ofList [
            ("symptom", "Deprecated config warning")
            ("surface_cause", "Old configuration key")
            ("system_behavior", "Config works but key changing")
            ("config_gap", "No config evolution tracking")
            ("design_flaw", "Configuration API evolution")
        ])

/// WP-070: Deprecated environment variable
let WP070_DeprecatedEnvVar =
    createElixirPattern
        "WP-070"
        "Deprecated Environment Variable"
        @"warning:.*environment.*variable\s+(\w+)\s+is\s+deprecated"
        WarningDeprecation
        Warning
        (Some "SC-DEPR-020")
        (Some "AOR-DEPR-020")
        "Using deprecated environment variable"
        "Update to new environment variable"
        (Map.ofList [
            ("symptom", "Deprecated env var warning")
            ("surface_cause", "Old environment variable")
            ("system_behavior", "Env works but name changing")
            ("config_gap", "No env var evolution tracking")
            ("design_flaw", "Deployment configuration evolution")
        ])

/// WP-071: Deprecated syntax
let WP071_DeprecatedSyntax =
    createElixirPattern
        "WP-071"
        "Deprecated Syntax"
        @"warning:.*syntax.*is\s+deprecated"
        WarningDeprecation
        Warning
        (Some "SC-DEPR-021")
        (Some "AOR-DEPR-021")
        "Using deprecated Elixir syntax"
        "Update to modern syntax"
        (Map.ofList [
            ("symptom", "Deprecated syntax warning")
            ("surface_cause", "Old Elixir syntax")
            ("system_behavior", "Code works but syntax changing")
            ("config_gap", "No syntax evolution tracking")
            ("design_flaw", "Language evolution")
        ])

/// WP-072: Deprecated sigil
let WP072_DeprecatedSigil =
    createElixirPattern
        "WP-072"
        "Deprecated Sigil"
        @"warning:.*sigil\s+~(\w)\s+is\s+deprecated"
        WarningDeprecation
        Warning
        (Some "SC-DEPR-022")
        (Some "AOR-DEPR-022")
        "Using deprecated sigil"
        "Update to replacement sigil"
        (Map.ofList [
            ("symptom", "Deprecated sigil warning")
            ("surface_cause", "Old sigil usage")
            ("system_behavior", "Sigil works but changing")
            ("config_gap", "No sigil evolution tracking")
            ("design_flaw", "Language evolution")
        ])

/// WP-073: Deprecated protocol implementation
let WP073_DeprecatedProtocol =
    createElixirPattern
        "WP-073"
        "Deprecated Protocol Implementation"
        @"warning:.*protocol\s+(\w+)\s+implementation.*deprecated"
        WarningDeprecation
        Warning
        (Some "SC-DEPR-023")
        (Some "AOR-DEPR-023")
        "Protocol implementation method deprecated"
        "Update protocol implementation"
        (Map.ofList [
            ("symptom", "Deprecated protocol warning")
            ("surface_cause", "Old protocol method")
            ("system_behavior", "Protocol works but interface changing")
            ("config_gap", "No protocol evolution tracking")
            ("design_flaw", "Protocol API evolution")
        ])

/// WP-074: Deprecated struct key
let WP074_DeprecatedStructKey =
    createElixirPattern
        "WP-074"
        "Deprecated Struct Key"
        @"warning:.*struct.*key\s+:(\w+)\s+is\s+deprecated"
        WarningDeprecation
        Warning
        (Some "SC-DEPR-024")
        (Some "AOR-DEPR-024")
        "Using deprecated struct key"
        "Update struct usage to new key"
        (Map.ofList [
            ("symptom", "Deprecated struct key warning")
            ("surface_cause", "Old struct field")
            ("system_behavior", "Struct works but field changing")
            ("config_gap", "No struct evolution tracking")
            ("design_flaw", "Data structure evolution")
        ])

/// WP-075: Deprecated atom
let WP075_DeprecatedAtom =
    createElixirPattern
        "WP-075"
        "Deprecated Atom Value"
        @"warning:.*atom\s+:(\w+)\s+is\s+deprecated"
        WarningDeprecation
        Warning
        (Some "SC-DEPR-025")
        (Some "AOR-DEPR-025")
        "Using deprecated atom value"
        "Update to replacement atom"
        (Map.ofList [
            ("symptom", "Deprecated atom warning")
            ("surface_cause", "Old atom value")
            ("system_behavior", "Atom works but name changing")
            ("config_gap", "No atom evolution tracking")
            ("design_flaw", "API naming evolution")
        ])

// ============================================================================
// WP-076 to WP-100: STYLE/BEST PRACTICE WARNINGS
// STAMP: SC-STYLE-001 to SC-STYLE-025
// ============================================================================

/// WP-076: Long function (Credo)
let WP076_LongFunction =
    createElixirPattern
        "WP-076"
        "Long Function"
        @"warning:.*function\s+body\s+is\s+too\s+long|credo.*Readability\.MaxLineCount"
        WarningStyle
        Warning
        (Some "SC-STYLE-001")
        (Some "AOR-STYLE-001")
        "Function body exceeds recommended length"
        "Break function into smaller functions"
        (Map.ofList [
            ("symptom", "Function too long warning")
            ("surface_cause", "Complex function")
            ("system_behavior", "Code works but hard to maintain")
            ("config_gap", "No function size limits")
            ("design_flaw", "Single responsibility violation")
        ])

/// WP-077: Complex function (Credo)
let WP077_ComplexFunction =
    createElixirPattern
        "WP-077"
        "Complex Function"
        @"credo.*Refactor\.CyclomaticComplexity|warning:.*cyclomatic.*complexity"
        WarningStyle
        Warning
        (Some "SC-STYLE-002")
        (Some "AOR-STYLE-002")
        "Function has high cyclomatic complexity"
        "Reduce conditionals and branching"
        (Map.ofList [
            ("symptom", "High complexity warning")
            ("surface_cause", "Too many branches")
            ("system_behavior", "Code works but hard to test")
            ("config_gap", "No complexity limits")
            ("design_flaw", "Over-complicated logic")
        ])

/// WP-078: Deep nesting (Credo)
let WP078_DeepNesting =
    createElixirPattern
        "WP-078"
        "Deep Nesting"
        @"credo.*Refactor\.Nesting|warning:.*nesting.*too\s+deep"
        WarningStyle
        Warning
        (Some "SC-STYLE-003")
        (Some "AOR-STYLE-003")
        "Code nesting is too deep"
        "Flatten with early returns or extract functions"
        (Map.ofList [
            ("symptom", "Deep nesting warning")
            ("surface_cause", "Too many nested blocks")
            ("system_behavior", "Code works but hard to read")
            ("config_gap", "No nesting limits")
            ("design_flaw", "Poor code structure")
        ])

/// WP-079: Missing moduledoc
let WP079_MissingModuledoc =
    createElixirPattern
        "WP-079"
        "Missing Moduledoc"
        @"credo.*Readability\.ModuleDoc|warning:.*missing.*@moduledoc"
        WarningStyle
        Warning
        (Some "SC-STYLE-004")
        (Some "AOR-STYLE-004")
        "Module is missing @moduledoc"
        "Add @moduledoc with WHAT/WHY/CONSTRAINTS"
        (Map.ofList [
            ("symptom", "Missing moduledoc warning")
            ("surface_cause", "No documentation")
            ("system_behavior", "Code works but undocumented")
            ("config_gap", "No doc enforcement")
            ("design_flaw", "Documentation debt")
        ])

/// WP-080: Missing doc
let WP080_MissingDoc =
    createElixirPattern
        "WP-080"
        "Missing Function Doc"
        @"credo.*Readability\.Specs|warning:.*missing.*@doc"
        WarningStyle
        Warning
        (Some "SC-STYLE-005")
        (Some "AOR-STYLE-005")
        "Public function is missing @doc"
        "Add @doc describing function purpose"
        (Map.ofList [
            ("symptom", "Missing doc warning")
            ("surface_cause", "Undocumented function")
            ("system_behavior", "Function works but undocumented")
            ("config_gap", "No doc enforcement")
            ("design_flaw", "Documentation debt")
        ])

/// WP-081: Missing typespec
let WP081_MissingSpec =
    createElixirPattern
        "WP-081"
        "Missing Typespec"
        @"credo.*Readability\.Specs|warning:.*missing.*@spec"
        WarningStyle
        Warning
        (Some "SC-STYLE-006")
        (Some "AOR-STYLE-006")
        "Public function is missing @spec"
        "Add @spec for type documentation"
        (Map.ofList [
            ("symptom", "Missing spec warning")
            ("surface_cause", "No type specification")
            ("system_behavior", "Function works but types unclear")
            ("config_gap", "No spec enforcement")
            ("design_flaw", "Type documentation debt")
        ])

/// WP-082: Large module
let WP082_LargeModule =
    createElixirPattern
        "WP-082"
        "Large Module"
        @"credo.*Refactor\.ModuleSize|warning:.*module.*too\s+large"
        WarningStyle
        Warning
        (Some "SC-STYLE-007")
        (Some "AOR-STYLE-007")
        "Module exceeds recommended size"
        "Split into smaller focused modules"
        (Map.ofList [
            ("symptom", "Large module warning")
            ("surface_cause", "Too much code in one module")
            ("system_behavior", "Code works but hard to maintain")
            ("config_gap", "No module size limits")
            ("design_flaw", "Poor module organization")
        ])

/// WP-083: Long line
let WP083_LongLine =
    createElixirPattern
        "WP-083"
        "Long Line"
        @"credo.*Readability\.MaxLineLength|warning:.*line.*too\s+long"
        WarningStyle
        Warning
        (Some "SC-STYLE-008")
        (Some "AOR-STYLE-008")
        "Line exceeds maximum length"
        "Break line into multiple lines"
        (Map.ofList [
            ("symptom", "Long line warning")
            ("surface_cause", "Line too wide")
            ("system_behavior", "Code works but hard to read")
            ("config_gap", "No line length enforcement")
            ("design_flaw", "Readability issue")
        ])

/// WP-084: Trailing whitespace
let WP084_TrailingWhitespace =
    createElixirPattern
        "WP-084"
        "Trailing Whitespace"
        @"credo.*Consistency\.TrailingWhiteSpace|warning:.*trailing\s+whitespace"
        WarningStyle
        Warning
        (Some "SC-STYLE-009")
        (Some "AOR-STYLE-009")
        "Line has trailing whitespace"
        "Remove trailing whitespace"
        (Map.ofList [
            ("symptom", "Trailing whitespace warning")
            ("surface_cause", "Extra whitespace")
            ("system_behavior", "Code works but unclean")
            ("config_gap", "No whitespace enforcement")
            ("design_flaw", "Code cleanliness")
        ])

/// WP-085: Inconsistent spacing
let WP085_InconsistentSpacing =
    createElixirPattern
        "WP-085"
        "Inconsistent Spacing"
        @"credo.*Consistency\.SpaceAroundOperators|warning:.*inconsistent.*spacing"
        WarningStyle
        Warning
        (Some "SC-STYLE-010")
        (Some "AOR-STYLE-010")
        "Inconsistent spacing around operators"
        "Use consistent spacing per style guide"
        (Map.ofList [
            ("symptom", "Inconsistent spacing warning")
            ("surface_cause", "Uneven spacing")
            ("system_behavior", "Code works but inconsistent")
            ("config_gap", "No spacing enforcement")
            ("design_flaw", "Style inconsistency")
        ])

/// WP-086: Unused pipe operator
let WP086_UnusedPipe =
    createElixirPattern
        "WP-086"
        "Unnecessary Pipe"
        @"credo.*Refactor\.PipeChainStart|warning:.*unnecessary.*pipe"
        WarningStyle
        Warning
        (Some "SC-STYLE-011")
        (Some "AOR-STYLE-011")
        "Pipe chain starts with single value"
        "Remove unnecessary pipe or add more transformations"
        (Map.ofList [
            ("symptom", "Unnecessary pipe warning")
            ("surface_cause", "Single-step pipe")
            ("system_behavior", "Code works but verbose")
            ("config_gap", "No pipe chain rules")
            ("design_flaw", "Over-use of pipe operator")
        ])

/// WP-087: Boolean comparison
let WP087_BooleanComparison =
    createElixirPattern
        "WP-087"
        "Boolean Comparison"
        @"credo.*Refactor\.CondStatements|warning:.*comparing.*to.*true|false"
        WarningStyle
        Warning
        (Some "SC-STYLE-012")
        (Some "AOR-STYLE-012")
        "Comparing boolean to true/false"
        "Use boolean value directly"
        (Map.ofList [
            ("symptom", "Boolean comparison warning")
            ("surface_cause", "Explicit bool comparison")
            ("system_behavior", "Code works but verbose")
            ("config_gap", "No bool comparison rules")
            ("design_flaw", "Verbose boolean logic")
        ])

/// WP-088: Negation in condition
let WP088_NegationCondition =
    createElixirPattern
        "WP-088"
        "Negation in Condition"
        @"credo.*Refactor\.NegatedConditionsWithElse|warning:.*negated.*condition"
        WarningStyle
        Warning
        (Some "SC-STYLE-013")
        (Some "AOR-STYLE-013")
        "Using negation in if/unless with else"
        "Swap branches and remove negation"
        (Map.ofList [
            ("symptom", "Negation condition warning")
            ("surface_cause", "Negated conditional")
            ("system_behavior", "Code works but confusing")
            ("config_gap", "No condition rules")
            ("design_flaw", "Negative logic confusion")
        ])

/// WP-089: Unless with else
let WP089_UnlessWithElse =
    createElixirPattern
        "WP-089"
        "Unless With Else"
        @"credo.*Refactor\.UnlessWithElse|warning:.*unless.*else"
        WarningStyle
        Warning
        (Some "SC-STYLE-014")
        (Some "AOR-STYLE-014")
        "Using unless with else clause"
        "Use if instead for clarity"
        (Map.ofList [
            ("symptom", "Unless with else warning")
            ("surface_cause", "Unless/else combination")
            ("system_behavior", "Code works but confusing")
            ("config_gap", "No unless rules")
            ("design_flaw", "Confusing conditional")
        ])

/// WP-090: Single pipe
let WP090_SinglePipe =
    createElixirPattern
        "WP-090"
        "Single Pipe Chain"
        @"credo.*Readability\.SinglePipe|warning:.*single.*pipe"
        WarningStyle
        Warning
        (Some "SC-STYLE-015")
        (Some "AOR-STYLE-015")
        "Pipe chain with only one step"
        "Use direct function call instead"
        (Map.ofList [
            ("symptom", "Single pipe warning")
            ("surface_cause", "One-step pipe")
            ("system_behavior", "Code works but verbose")
            ("config_gap", "No pipe length rules")
            ("design_flaw", "Over-use of pipe operator")
        ])

/// WP-091: String literal concatenation
let WP091_StringConcat =
    createElixirPattern
        "WP-091"
        "String Literal Concatenation"
        @"credo.*Readability\.StringSigils|warning:.*string.*concatenation"
        WarningStyle
        Warning
        (Some "SC-STYLE-016")
        (Some "AOR-STYLE-016")
        "Concatenating string literals"
        "Use string interpolation instead"
        (Map.ofList [
            ("symptom", "String concat warning")
            ("surface_cause", "Literal concatenation")
            ("system_behavior", "Code works but verbose")
            ("config_gap", "No string rules")
            ("design_flaw", "Inefficient string building")
        ])

/// WP-092: Redundant with clause
let WP092_RedundantWith =
    createElixirPattern
        "WP-092"
        "Redundant With Clause"
        @"credo.*Readability\.WithSingleClause|warning:.*redundant.*with"
        WarningStyle
        Warning
        (Some "SC-STYLE-017")
        (Some "AOR-STYLE-017")
        "With expression has only one clause"
        "Use case or pattern match directly"
        (Map.ofList [
            ("symptom", "Redundant with warning")
            ("surface_cause", "Single-clause with")
            ("system_behavior", "Code works but verbose")
            ("config_gap", "No with rules")
            ("design_flaw", "Over-use of with")
        ])

/// WP-093: Alias order
let WP093_AliasOrder =
    createElixirPattern
        "WP-093"
        "Alias Order"
        @"credo.*Consistency\.AliasOrder|warning:.*alias.*order"
        WarningStyle
        Warning
        (Some "SC-STYLE-018")
        (Some "AOR-STYLE-018")
        "Aliases are not in alphabetical order"
        "Sort aliases alphabetically"
        (Map.ofList [
            ("symptom", "Alias order warning")
            ("surface_cause", "Unsorted aliases")
            ("system_behavior", "Code works but inconsistent")
            ("config_gap", "No alias ordering")
            ("design_flaw", "Inconsistent imports")
        ])

/// WP-094: Import order
let WP094_ImportOrder =
    createElixirPattern
        "WP-094"
        "Import Order"
        @"credo.*Consistency\.ImportOrder|warning:.*import.*order"
        WarningStyle
        Warning
        (Some "SC-STYLE-019")
        (Some "AOR-STYLE-019")
        "Imports are not in proper order"
        "Sort imports per convention"
        (Map.ofList [
            ("symptom", "Import order warning")
            ("surface_cause", "Unsorted imports")
            ("system_behavior", "Code works but inconsistent")
            ("config_gap", "No import ordering")
            ("design_flaw", "Inconsistent imports")
        ])

/// WP-095: Multi-alias syntax
let WP095_MultiAlias =
    createElixirPattern
        "WP-095"
        "Multi-Alias Syntax"
        @"credo.*Readability\.MultiAlias|warning:.*multi.*alias"
        WarningStyle
        Warning
        (Some "SC-STYLE-020")
        (Some "AOR-STYLE-020")
        "Multiple aliases should use multi-alias syntax"
        "Use alias Foo.{Bar, Baz} syntax"
        (Map.ofList [
            ("symptom", "Multi-alias warning")
            ("surface_cause", "Separate alias statements")
            ("system_behavior", "Code works but verbose")
            ("config_gap", "No multi-alias rules")
            ("design_flaw", "Verbose imports")
        ])

/// WP-096: Parentheses on zero-arity function
let WP096_ParensZeroArity =
    createElixirPattern
        "WP-096"
        "Parentheses on Zero-Arity"
        @"credo.*Consistency\.ParameterPatternMatching|warning:.*parentheses.*zero.*arity"
        WarningStyle
        Warning
        (Some "SC-STYLE-021")
        (Some "AOR-STYLE-021")
        "Inconsistent parentheses on zero-arity functions"
        "Be consistent with parentheses usage"
        (Map.ofList [
            ("symptom", "Zero-arity parens warning")
            ("surface_cause", "Inconsistent parens")
            ("system_behavior", "Code works but inconsistent")
            ("config_gap", "No parens rules")
            ("design_flaw", "Style inconsistency")
        ])

/// WP-097: Prefer unquoted atoms
let WP097_QuotedAtom =
    createElixirPattern
        "WP-097"
        "Prefer Unquoted Atoms"
        @"credo.*Readability\.PreferUnquotedAtoms|warning:.*quoted.*atom"
        WarningStyle
        Warning
        (Some "SC-STYLE-022")
        (Some "AOR-STYLE-022")
        "Atom uses quotes unnecessarily"
        "Use unquoted atom if possible"
        (Map.ofList [
            ("symptom", "Quoted atom warning")
            ("surface_cause", "Unnecessary quotes")
            ("system_behavior", "Code works but verbose")
            ("config_gap", "No atom style rules")
            ("design_flaw", "Verbose atoms")
        ])

/// WP-098: Use keyword syntax
let WP098_KeywordSyntax =
    createElixirPattern
        "WP-098"
        "Prefer Keyword Syntax"
        @"credo.*Readability\.PreferKeywordSyntax|warning:.*keyword.*syntax"
        WarningStyle
        Warning
        (Some "SC-STYLE-023")
        (Some "AOR-STYLE-023")
        "Function call can use keyword syntax"
        "Use keyword: value syntax for clarity"
        (Map.ofList [
            ("symptom", "Keyword syntax warning")
            ("surface_cause", "Positional arguments")
            ("system_behavior", "Code works but less readable")
            ("config_gap", "No keyword syntax rules")
            ("design_flaw", "Less readable calls")
        ])

/// WP-099: Duplicate alias
let WP099_DuplicateAlias =
    createElixirPattern
        "WP-099"
        "Duplicate Alias"
        @"credo.*Consistency\.DuplicateAlias|warning:.*duplicate.*alias"
        WarningStyle
        Warning
        (Some "SC-STYLE-024")
        (Some "AOR-STYLE-024")
        "Module is aliased multiple times"
        "Remove duplicate alias"
        (Map.ofList [
            ("symptom", "Duplicate alias warning")
            ("surface_cause", "Repeated alias")
            ("system_behavior", "Code works but redundant")
            ("config_gap", "No duplicate detection")
            ("design_flaw", "Copy-paste error")
        ])

/// WP-100: Redundant blank lines
let WP100_RedundantBlankLines =
    createElixirPattern
        "WP-100"
        "Redundant Blank Lines"
        @"credo.*Readability\.RedundantBlankLines|warning:.*redundant.*blank.*lines"
        WarningStyle
        Warning
        (Some "SC-STYLE-025")
        (Some "AOR-STYLE-025")
        "Multiple blank lines in a row"
        "Use single blank line for separation"
        (Map.ofList [
            ("symptom", "Redundant blank lines warning")
            ("surface_cause", "Extra blank lines")
            ("system_behavior", "Code works but messy")
            ("config_gap", "No blank line rules")
            ("design_flaw", "Formatting inconsistency")
        ])

// ============================================================================
// ELIXIR PATTERN COLLECTIONS
// ============================================================================

/// All Elixir Ash Framework patterns (EX-001 to EX-010)
let allAshFrameworkPatterns = [
    EX001_MissingUpdateDefault
    EX002_RequireAtomicFalse
    EX003_ForceChangeAttribute
    EX004_MissingBaseResource
    EX005_MissingUuidPrimaryKey
    EX006_ActorNotPassed
    EX007_QueryTenantContext
    EX008_PaginationStruct
    EX009_CreateIfNotExists
    EX010_TableNamePrefix
]

/// All Elixir Ash Resource patterns (EX-011 to EX-015)
let allAshResourcePatterns = [
    EX011_MissingDomainRef
    EX012_InvalidAttributeType
    EX013_RelationshipNoDestination
    EX014_ActionNoAccept
    EX015_CalculationNoExpression
]

/// All PropCheck/StreamData patterns (EX-016 to EX-018)
let allPropCheckPatterns = [
    EX016_PropCheckStreamDataConflict
    EX017_RawUtf8Generator
    EX018_HeaderNameSpaces
]

/// All Elixir Variable patterns (EX-019 to EX-020)
let allElixirVariablePatterns = [
    EX019_UnderscorePrefixMismatch
    EX020_DoubleUnderscoreTypo
]

/// All Wallaby Testing patterns (EX-021 to EX-025)
let allWallabyPatterns = [
    EX021_BrowserAssertHasArity
    EX022_AmbiguousTextImport
    EX023_BrowserHasArity
    EX024_LoggerNotRequired
    EX025_WallabySessionNotStarted
]

/// All Credo Anti-patterns (EX-026 to EX-030)
let allCredoPatterns = [
    EX026_ApplyAntiPattern
    EX027_DuplicateCodeBlocks
    EX028_ComplexFunction
    EX029_NestingTooDeep
    EX030_PipeChainStart
]

/// All Factory/Test patterns (EX-031 to EX-035)
let allFactoryTestPatterns = [
    EX031_MissingFactoryFunction
    EX032_ExMachinaUsage
    EX033_AssertionUndefinedVar
    EX034_MissingMigrationDecl
    EX035_SandboxModeNotSet
]

/// All Syntax/Compilation patterns (EX-036 to EX-040)
let allSyntaxPatterns = [
    EX036_JoinedKeywords
    EX037_DefaultParamBackslash
    EX038_MissingDoBlock
    EX039_UnexpectedEnd
    EX040_UnterminatedString
]

/// All Type/Spec patterns (EX-041 to EX-050)
let allTypeSpecPatterns = [
    EX041_DialyzerTypeMismatch
    EX042_InvalidTypespecSyntax
    EX043_UnknownTypeInSpec
    EX044_SpecArityMismatch
    EX045_NoLocalReturn
    EX046_ContractViolation
    EX047_InvalidReturnType
    EX048_GuardFail
    EX049_CallbackTypeMismatch
    EX050_OpaqueTypeViolation
]

/// All Compilation Error patterns (EX-051 to EX-060)
let allCompilationErrorPatterns = [
    EX051_ModuleNotFound
    EX052_UndefinedModuleAttribute
    EX053_CircularDependency
    EX054_ApplicationNotStarted
    EX055_ProtocolNotImplemented
    EX056_BehaviourNotImplemented
    EX057_ConflictingBehaviours
    EX058_StructKeyNotFound
    EX059_DependencyCompileFailed
    EX060_RedefiningModule
]

/// All Module/Import patterns (EX-061 to EX-070)
let allModuleImportPatterns = [
    EX061_MissingImport
    EX062_AmbiguousImport
    EX063_UnusedImport
    EX064_AliasCollision
    EX065_InvalidAliasSyntax
    EX066_UseClauseError
    EX067_MissingRequire
    EX068_ModuleAttributeUndefined
    EX069_InvalidModuleNesting
    EX070_UnquoteOutsideQuote
]

/// All Dependency/Config patterns (EX-071 to EX-080)
let allDependencyConfigPatterns = [
    EX071_DependencyVersionConflict
    EX072_MissingDependency
    EX073_HexPackageNotFound
    EX074_DatabaseEncodingMismatch
    EX075_MigrationFailed
    EX076_SchemaMismatch
    EX077_EctoAdapterError
    EX078_ConfigMissingKey
    EX079_RuntimeConfigError
    EX080_EnvVarMissing
]

/// All Advanced Syntax patterns (EX-081 to EX-100)
let allAdvancedSyntaxPatterns = [
    EX081_InvalidMacroExpansion
    EX082_QuoteUnquoteMismatch
    EX083_InvalidGuardClause
    EX084_PatternMatchFailure
    EX085_BinarySyntaxError
    EX086_InvalidComprehension
    EX087_FunctionClauseHead
    EX088_InvalidAnonymousFunction
    EX089_PinOperatorMisuse
    EX090_WithClauseError
    EX091_CaseClauseOverlap
    EX092_ReceiveTimeoutError
    EX093_TryRescueError
    EX094_RaiseArgumentError
    EX095_StructUpdateError
    EX096_SigilSyntaxError
    EX097_AccessSyntaxError
    EX098_PipeOperatorError
    EX099_ModuleAttributeError
    EX100_KeywordListError
]

// ============================================================================
// WARNING PATTERN COLLECTIONS (WP-001 to WP-100)
// ============================================================================

/// All Compilation Warning patterns (WP-001 to WP-025)
let allCompilationWarningPatterns = [
    WP001_UnusedVariable
    WP002_UnusedFunctionArg
    WP003_UnusedPrivateFunction
    WP004_UnreachableCode
    WP005_MissingDocPublic
    WP006_DocOnPrivate
    WP007_RedefiningModule
    WP008_ShadowingVariable
    WP009_BooleanComparison
    WP010_ConcatInInterpolation
    WP011_GuardNoEffect
    WP012_ClauseNeverMatches
    WP013_AtomsLimit
    WP014_LargeBinaryLiteral
    WP015_SpawnWithoutLink
    WP016_UnsafeVariable
    WP017_LongCompileTime
    WP018_DeepNesting
    WP019_ComparisonAlways
    WP020_DependencyCycle
    WP021_MissingReturnType
    WP022_OverriddenCallback
    WP023_UnusedMacro
    WP024_MapUpdateDeprecated
    WP025_ClauseOrder
]

/// All Unused Code Warning patterns (WP-026 to WP-050)
let allUnusedWarningPatterns = [
    WP026_UnusedAlias
    WP027_UnusedImport
    WP028_UnusedRequire
    WP029_UnusedModuleAttr
    WP030_UnusedType
    WP031_UnusedStructKey
    WP032_UnusedCallback
    WP033_UnusedPrivateType
    WP034_UnusedBehaviour
    WP035_UnusedException
    WP036_UnusedProtocol
    WP037_UnusedGuardFunc
    WP038_UnusedConfigValue
    WP039_UnusedEtsTable
    WP040_UnusedGenServerCb
    WP041_UnusedTestHelper
    WP042_UnusedPatternVar
    WP043_UnusedPlug
    WP044_UnusedSchemaField
    WP045_UnusedChangesetFn
    WP046_UnusedContextFn
    WP047_UnusedLiveViewAssign
    WP048_UnusedEventHandler
    WP049_UnusedChannelCb
    WP050_UnusedTelemetryHandler
]

/// All Deprecation Warning patterns (WP-051 to WP-075)
let allDeprecationWarningPatterns = [
    WP051_DeprecatedFunction
    WP052_DeprecatedModule
    WP053_DeprecatedCallback
    WP054_DeprecatedEcto
    WP055_DeprecatedPhoenix
    WP056_DeprecatedPlug
    WP057_DeprecatedLogger
    WP058_DeprecatedGenServer
    WP059_DeprecatedAgent
    WP060_DeprecatedTask
    WP061_DeprecatedString
    WP062_DeprecatedEnum
    WP063_DeprecatedMap
    WP064_DeprecatedKeyword
    WP065_DeprecatedList
    WP066_DeprecatedAsh
    WP067_DeprecatedMacro
    WP068_DeprecatedTypeSpec
    WP069_DeprecatedConfig
    WP070_DeprecatedEnvVar
    WP071_DeprecatedSyntax
    WP072_DeprecatedSigil
    WP073_DeprecatedProtocol
    WP074_DeprecatedStructKey
    WP075_DeprecatedAtom
]

/// All Style Warning patterns (WP-076 to WP-100)
let allStyleWarningPatterns = [
    WP076_LongFunction
    WP077_ComplexFunction
    WP078_DeepNesting
    WP079_MissingModuledoc
    WP080_MissingDoc
    WP081_MissingSpec
    WP082_LargeModule
    WP083_LongLine
    WP084_TrailingWhitespace
    WP085_InconsistentSpacing
    WP086_UnusedPipe
    WP087_BooleanComparison
    WP088_NegationCondition
    WP089_UnlessWithElse
    WP090_SinglePipe
    WP091_StringConcat
    WP092_RedundantWith
    WP093_AliasOrder
    WP094_ImportOrder
    WP095_MultiAlias
    WP096_ParensZeroArity
    WP097_QuotedAtom
    WP098_KeywordSyntax
    WP099_DuplicateAlias
    WP100_RedundantBlankLines
]

/// All Elixir Warning patterns combined (WP-001 to WP-100)
let allElixirWarningPatterns =
    allCompilationWarningPatterns
    @ allUnusedWarningPatterns
    @ allDeprecationWarningPatterns
    @ allStyleWarningPatterns

/// All Elixir patterns combined (EX-001 to EX-100, WP-001 to WP-100)
let allElixirPatterns =
    allAshFrameworkPatterns
    @ allAshResourcePatterns
    @ allPropCheckPatterns
    @ allElixirVariablePatterns
    @ allWallabyPatterns
    @ allCredoPatterns
    @ allFactoryTestPatterns
    @ allSyntaxPatterns
    @ allTypeSpecPatterns
    @ allCompilationErrorPatterns
    @ allModuleImportPatterns
    @ allDependencyConfigPatterns
    @ allAdvancedSyntaxPatterns
    @ allElixirWarningPatterns

// ============================================================================
// ELIXIR PATTERN MATCHING ENGINE
// ============================================================================

/// Elixir match result
type ElixirPatternMatch = {
    Pattern: ElixirErrorPattern
    FilePath: string
    Line: int
    Column: int
    Message: string
    RawText: string
    Groups: Map<string, string>
}

/// Match a single line against all Elixir patterns
let matchElixirLine (line: string) : ElixirPatternMatch list =
    allElixirPatterns
    |> List.choose (fun pattern ->
        let m = pattern.Pattern.Match(line)
        if m.Success then
            let groups =
                [ for g in m.Groups -> g.Name, g.Value ]
                |> List.filter (fun (name, _) -> not (String.IsNullOrEmpty name) && name <> "0")
                |> Map.ofList
            Some {
                Pattern = pattern
                FilePath = ""
                Line = 0
                Column = 0
                Message = m.Value
                RawText = line
                Groups = groups
            }
        else
            None)

/// Match Elixir compilation output (multiple lines)
let matchElixirOutput (output: string) : ElixirPatternMatch list =
    output.Split([|'\n'; '\r'|], StringSplitOptions.RemoveEmptyEntries)
    |> Array.toList
    |> List.collect matchElixirLine

/// Parse Elixir file location from error message
let parseElixirLocation (line: string) : (string * int * int) option =
    // Elixir format: lib/path/file.ex:123:45: error message
    let pattern = Regex(@"([^:]+\.exs?):(\d+):?(\d+)?:")
    let m = pattern.Match(line)
    if m.Success then
        let col = if m.Groups.[3].Success then int m.Groups.[3].Value else 0
        Some (m.Groups.[1].Value, int m.Groups.[2].Value, col)
    else
        None

/// Enhanced match with location parsing for Elixir
let matchElixirWithLocation (line: string) : ElixirPatternMatch list =
    let location = parseElixirLocation line
    matchElixirLine line
    |> List.map (fun pm ->
        match location with
        | Some (path, ln, col) ->
            { pm with FilePath = path; Line = ln; Column = col }
        | None -> pm)

/// Analyze mix compile output
let analyzeElixirBuildOutput (output: string) =
    let matches = matchElixirOutput output
    let errors = matches |> List.filter (fun m ->
        m.Pattern.Severity = Error || m.Pattern.Severity = Critical)
    let warnings = matches |> List.filter (fun m -> m.Pattern.Severity = Warning)

    {|
        TotalMatches = List.length matches
        ErrorCount = List.length errors
        WarningCount = List.length warnings
        // Core Framework Errors
        AshFrameworkErrors = matches |> List.filter (fun m -> m.Pattern.Category = AshFramework)
        AshResourceErrors = matches |> List.filter (fun m -> m.Pattern.Category = AshResource)
        PropCheckErrors = matches |> List.filter (fun m -> m.Pattern.Category = PropCheck)
        VariableErrors = matches |> List.filter (fun m -> m.Pattern.Category = ElixirVariable)
        // Code Quality Errors
        CredoErrors = matches |> List.filter (fun m -> m.Pattern.Category = ElixirCredo)
        FactoryTestErrors = matches |> List.filter (fun m -> m.Pattern.Category = FactoryTest)
        SyntaxErrors = matches |> List.filter (fun m -> m.Pattern.Category = SyntaxError)
        // Type/Spec Errors (Sprint 46.1.3.0.0)
        TypeSpecErrors = matches |> List.filter (fun m -> m.Pattern.Category = TypeSpec)
        CompilationErrors = matches |> List.filter (fun m -> m.Pattern.Category = CompilationError)
        // Module/Dependency Errors (Sprint 46.1.4.0.0)
        ModuleImportErrors = matches |> List.filter (fun m -> m.Pattern.Category = ModuleImport)
        DependencyConfigErrors = matches |> List.filter (fun m -> m.Pattern.Category = DependencyConfig)
        // Advanced Syntax Errors (Sprint 46.1.5.0.0)
        AdvancedSyntaxErrors = matches |> List.filter (fun m -> m.Pattern.Category = SyntaxAdvanced)
        // Warning Categories (Sprint 46.1.6.0.0)
        CompilationWarnings = matches |> List.filter (fun m -> m.Pattern.Category = WarningCompilation)
        UnusedCodeWarnings = matches |> List.filter (fun m -> m.Pattern.Category = WarningUnused)
        DeprecationWarnings = matches |> List.filter (fun m -> m.Pattern.Category = WarningDeprecation)
        StyleWarnings = matches |> List.filter (fun m -> m.Pattern.Category = WarningStyle)
        // STAMP and AOR
        StampViolations = matches |> List.filter (fun m -> m.Pattern.StampConstraint.IsSome)
        AorViolations = matches |> List.filter (fun m -> m.Pattern.AorRule.IsSome)
        TpsAnalysis = matches |> List.map (fun m -> m.Pattern.Id, m.Pattern.TpsAnalysis)
    |}

/// Get Elixir patterns by category
let getElixirPatternsByCategory (category: ElixirPatternCategory) =
    allElixirPatterns |> List.filter (fun p -> p.Category = category)

/// Get Elixir patterns with STAMP constraints
let getElixirStampPatterns () =
    allElixirPatterns |> List.filter (fun p -> p.StampConstraint.IsSome)

/// Get Elixir patterns with AOR rules
let getElixirAorPatterns () =
    allElixirPatterns |> List.filter (fun p -> p.AorRule.IsSome)

// ============================================================================
// UNIFIED PATTERN ANALYSIS
// Combines F# and Elixir pattern matching
// ============================================================================

/// Combined build analysis result
type UnifiedBuildAnalysis = {
    FSharpMatches: PatternMatch list
    ElixirMatches: ElixirPatternMatch list
    TotalErrors: int
    TotalWarnings: int
    StampViolationCount: int
}

/// Analyze mixed build output (both F# and Elixir)
let analyzeUnifiedOutput (output: string) : UnifiedBuildAnalysis =
    let fsMatches = matchOutput output
    let exMatches = matchElixirOutput output

    let fsErrors = fsMatches |> List.filter (fun m ->
        m.Pattern.Severity = Error || m.Pattern.Severity = Critical)
    let fsWarnings = fsMatches |> List.filter (fun m -> m.Pattern.Severity = Warning)

    let exErrors = exMatches |> List.filter (fun m ->
        m.Pattern.Severity = Error || m.Pattern.Severity = Critical)
    let exWarnings = exMatches |> List.filter (fun m -> m.Pattern.Severity = Warning)

    let fsStamp = fsMatches |> List.filter (fun m -> m.Pattern.StampConstraint.IsSome)
    let exStamp = exMatches |> List.filter (fun m -> m.Pattern.StampConstraint.IsSome)

    {
        FSharpMatches = fsMatches
        ElixirMatches = exMatches
        TotalErrors = List.length fsErrors + List.length exErrors
        TotalWarnings = List.length fsWarnings + List.length exWarnings
        StampViolationCount = List.length fsStamp + List.length exStamp
    }
