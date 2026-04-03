namespace Cepaf.Observability.Fractal

open System
open System.Text.RegularExpressions
open System.Security.Cryptography

/// PII Masking Module - Implements SC-LOG-003 (PII masking at decorator)
/// Ensures sensitive data is masked before log emission per GDPR/CCPA requirements
/// STAMP Compliance: SC-LOG-003 (mandatory), SC-SEC-001 (encryption), SC-SEC-002 (hashing)
module PIIMasking =

    // ============================================================
    // TYPES
    // ============================================================

    /// Categories of sensitive data for targeted masking
    [<RequireQualifiedAccess>]
    type SensitiveCategory =
        /// Personally Identifiable Information
        | PII
        /// Payment Card Industry data
        | PCI
        /// Protected Health Information (HIPAA)
        | PHI
        /// Authentication credentials
        | Credentials
        /// API keys and tokens
        | APISecrets
        /// Custom category for domain-specific data
        | Custom of string

    /// Masking strategy to apply
    [<RequireQualifiedAccess>]
    type MaskingStrategy =
        /// Replace with asterisks (e.g., "****")
        | Asterisks
        /// Replace with redacted placeholder (e.g., "[REDACTED]")
        | Redacted
        /// Partial mask preserving start/end (e.g., "john****@example.com")
        | Partial of prefixLen: int * suffixLen: int
        /// One-way hash (irreversible, for correlation)
        | Hash
        /// Tokenize (reversible with key)
        | Tokenize
        /// Remove entirely
        | Remove
        /// Email-specific: mask local part, preserve domain (e.g., "joh***@example.com")
        | Email of prefixLen: int

    /// PII detection pattern
    type PIIPattern = {
        /// Pattern name for identification
        Name: string

        /// Category of sensitive data
        Category: SensitiveCategory

        /// Regex pattern to match
        Pattern: Regex

        /// Masking strategy to apply
        Strategy: MaskingStrategy

        /// Priority (higher = matched first)
        Priority: int

        /// Whether pattern is enabled
        Enabled: bool
    }

    /// Masking result with metadata
    type MaskingResult = {
        /// Original value (for internal use only, not logged)
        Original: string

        /// Masked value
        Masked: string

        /// Category that matched
        Category: SensitiveCategory option

        /// Pattern that matched
        PatternName: string option

        /// Whether any masking was applied
        WasMasked: bool

        /// Hash of original for correlation (optional)
        CorrelationHash: string option
    }

    /// Configuration for PII masking
    type PIIMaskingConfig = {
        /// Whether masking is enabled globally
        Enabled: bool

        /// Whether to include correlation hashes
        IncludeCorrelationHash: bool

        /// Salt for hashing (should be from secure config)
        HashSalt: string

        /// Categories to mask (empty = all)
        EnabledCategories: SensitiveCategory list

        /// Keys to always mask regardless of content
        SensitiveKeys: Set<string>

        /// Keys to never mask (whitelist)
        ExemptKeys: Set<string>
    }

    // ============================================================
    // DEFAULT PATTERNS (SC-LOG-003)
    // ============================================================

    /// Email address pattern
    let private emailPattern = {
        Name = "email"
        Category = SensitiveCategory.PII
        Pattern = Regex(@"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}", RegexOptions.Compiled)
        Strategy = MaskingStrategy.Email(3)  // "joh***@example.com" - preserves domain
        Priority = 100
        Enabled = true
    }

    /// Phone number patterns (multiple formats)
    let private phonePattern = {
        Name = "phone"
        Category = SensitiveCategory.PII
        Pattern = Regex(@"(\+?\d{1,3}[-.\s]?)?\(?\d{2,4}\)?[-.\s]?\d{3,4}[-.\s]?\d{3,4}", RegexOptions.Compiled)
        Strategy = MaskingStrategy.Partial(0, 4)  // "****1234"
        Priority = 90
        Enabled = true
    }

    /// Credit card number pattern (Luhn-validatable)
    let private creditCardPattern = {
        Name = "credit_card"
        Category = SensitiveCategory.PCI
        Pattern = Regex(@"\b(?:\d[ -]*?){13,19}\b", RegexOptions.Compiled)
        Strategy = MaskingStrategy.Partial(0, 4)  // "************1234"
        Priority = 200  // High priority for PCI
        Enabled = true
    }

    /// Social Security Number pattern (US)
    let private ssnPattern = {
        Name = "ssn"
        Category = SensitiveCategory.PII
        Pattern = Regex(@"\b\d{3}[-\s]?\d{2}[-\s]?\d{4}\b", RegexOptions.Compiled)
        Strategy = MaskingStrategy.Redacted
        Priority = 180
        Enabled = true
    }

    /// API key/token patterns
    let private apiKeyPattern = {
        Name = "api_key"
        Category = SensitiveCategory.APISecrets
        Pattern = Regex(@"(?:api[_-]?key|token|secret|bearer)\s*[:=]\s*['""]?([a-zA-Z0-9_\-]{16,})['""]?", RegexOptions.Compiled ||| RegexOptions.IgnoreCase)
        Strategy = MaskingStrategy.Partial(4, 4)
        Priority = 250  // Highest priority for secrets
        Enabled = true
    }

    /// Password in URL or config
    let private passwordPattern = {
        Name = "password"
        Category = SensitiveCategory.Credentials
        Pattern = Regex(@"(?:password|passwd|pwd)\s*[:=]\s*['""]?([^'""&\s]+)['""]?", RegexOptions.Compiled ||| RegexOptions.IgnoreCase)
        Strategy = MaskingStrategy.Redacted
        Priority = 240
        Enabled = true
    }

    /// JWT token pattern
    let private jwtPattern = {
        Name = "jwt"
        Category = SensitiveCategory.APISecrets
        Pattern = Regex(@"eyJ[a-zA-Z0-9_-]*\.eyJ[a-zA-Z0-9_-]*\.[a-zA-Z0-9_-]*", RegexOptions.Compiled)
        Strategy = MaskingStrategy.Partial(11, 10)  // Preserve JWT header structure hint
        Priority = 230
        Enabled = true
    }

    /// IP address pattern
    let private ipAddressPattern = {
        Name = "ip_address"
        Category = SensitiveCategory.PII
        Pattern = Regex(@"\b(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b", RegexOptions.Compiled)
        Strategy = MaskingStrategy.Partial(0, 3)  // "***.***.***123"
        Priority = 60
        Enabled = true
    }

    /// Default patterns ordered by priority
    let private defaultPatterns =
        [
            apiKeyPattern
            passwordPattern
            jwtPattern
            creditCardPattern
            ssnPattern
            emailPattern
            phonePattern
            ipAddressPattern
        ]
        |> List.sortByDescending (fun p -> p.Priority)

    // ============================================================
    // DEFAULT CONFIGURATION
    // ============================================================

    /// Default masking configuration
    let defaultConfig : PIIMaskingConfig = {
        Enabled = true
        IncludeCorrelationHash = true
        HashSalt = "fractal-log-salt-change-in-prod"  // Should be overridden from secure config
        EnabledCategories = []  // Empty = all categories
        SensitiveKeys = Set.ofList [
            "password"; "passwd"; "pwd"; "secret"; "token"; "api_key"; "apikey";
            "authorization"; "auth"; "bearer"; "credential"; "private_key"
        ]
        ExemptKeys = Set.ofList [
            "timestamp"; "level"; "module"; "function"; "line"; "node_id"
        ]
    }

    // ============================================================
    // MASKING IMPLEMENTATION
    // ============================================================

    /// Compute SHA-256 hash for correlation
    let private computeHash (salt: string) (value: string) : string =
        use sha256 = SHA256.Create()
        let bytes = System.Text.Encoding.UTF8.GetBytes(salt + value)
        let hash = sha256.ComputeHash(bytes)
        BitConverter.ToString(hash).Replace("-", "").ToLowerInvariant().[..15]  // First 16 chars

    /// Apply asterisk masking
    let private applyAsterisks (value: string) : string =
        String.replicate value.Length "*"

    /// Apply partial masking
    let private applyPartial (prefixLen: int) (suffixLen: int) (value: string) : string =
        let len = value.Length
        if len <= prefixLen + suffixLen then
            applyAsterisks value
        else
            let prefix = if prefixLen > 0 then value.[..prefixLen-1] else ""
            let suffix = if suffixLen > 0 then value.[len-suffixLen..] else ""
            let maskLen = len - prefixLen - suffixLen
            prefix + String.replicate maskLen "*" + suffix

    /// Apply email-specific masking: preserve domain, mask local part with minimum 3 asterisks
    let private applyEmailMasking (prefixLen: int) (value: string) : string =
        match value.IndexOf('@') with
        | -1 -> applyAsterisks value  // Not a valid email, mask all
        | atIndex ->
            let localPart = value.[..atIndex-1]
            let domain = value.[atIndex..]  // Includes @
            // Always mask at least 3 characters for visibility
            let minMaskLen = 3
            if localPart.Length <= 1 then
                // Very short local part (1 char) - mask entirely with minimum asterisks
                String.replicate minMaskLen "*" + domain
            elif localPart.Length <= prefixLen then
                // Short local part - show first char, mask rest with minimum asterisks
                string localPart.[0] + String.replicate minMaskLen "*" + domain
            else
                let prefix = localPart.[..prefixLen-1]
                let actualMaskLen = localPart.Length - prefixLen
                let maskLen = max actualMaskLen minMaskLen
                prefix + String.replicate maskLen "*" + domain

    /// Apply masking strategy to a value
    let private applyStrategy (config: PIIMaskingConfig) (strategy: MaskingStrategy) (value: string) : string =
        match strategy with
        | MaskingStrategy.Asterisks ->
            applyAsterisks value

        | MaskingStrategy.Redacted ->
            "[REDACTED]"

        | MaskingStrategy.Partial(prefixLen, suffixLen) ->
            applyPartial prefixLen suffixLen value

        | MaskingStrategy.Hash ->
            sprintf "[HASH:%s]" (computeHash config.HashSalt value)

        | MaskingStrategy.Tokenize ->
            // In production, this would use a proper tokenization service
            sprintf "[TOKEN:%s]" (computeHash config.HashSalt value)

        | MaskingStrategy.Remove ->
            ""

        | MaskingStrategy.Email(prefixLen) ->
            applyEmailMasking prefixLen value

    /// Check if a category is enabled
    let private isCategoryEnabled (config: PIIMaskingConfig) (category: SensitiveCategory) : bool =
        config.EnabledCategories.IsEmpty ||
        config.EnabledCategories |> List.contains category

    /// Mask a string value using patterns
    let maskValue (config: PIIMaskingConfig) (patterns: PIIPattern list) (value: string) : MaskingResult =
        if not config.Enabled || String.IsNullOrWhiteSpace(value) then
            { Original = value; Masked = value; Category = None; PatternName = None; WasMasked = false; CorrelationHash = None }
        else
            // Find first matching enabled pattern
            let matchedPattern =
                patterns
                |> List.filter (fun p -> p.Enabled && isCategoryEnabled config p.Category)
                |> List.sortByDescending (fun p -> p.Priority)
                |> List.tryFind (fun p -> p.Pattern.IsMatch(value))

            match matchedPattern with
            | Some pattern ->
                let masked = pattern.Pattern.Replace(value, fun m ->
                    // If pattern has a capturing group, mask only the captured value
                    // and preserve the prefix/suffix
                    if m.Groups.Count > 1 && m.Groups.[1].Success then
                        let wholeMatch = m.Value
                        let captured = m.Groups.[1].Value
                        let captureStart = m.Groups.[1].Index - m.Index
                        let prefix = wholeMatch.[..captureStart - 1]
                        let suffix =
                            let captureEnd = captureStart + captured.Length
                            if captureEnd < wholeMatch.Length then wholeMatch.[captureEnd..]
                            else ""
                        let maskedCapture = applyStrategy config pattern.Strategy captured
                        prefix + maskedCapture + suffix
                    else
                        applyStrategy config pattern.Strategy m.Value
                )
                let correlationHash =
                    if config.IncludeCorrelationHash then
                        Some (computeHash config.HashSalt value)
                    else
                        None
                {
                    Original = value
                    Masked = masked
                    Category = Some pattern.Category
                    PatternName = Some pattern.Name
                    WasMasked = true
                    CorrelationHash = correlationHash
                }
            | None ->
                { Original = value; Masked = value; Category = None; PatternName = None; WasMasked = false; CorrelationHash = None }

    /// Mask a value using default patterns
    let maskWithDefaults (config: PIIMaskingConfig) (value: string) : MaskingResult =
        maskValue config defaultPatterns value

    /// Check if a key should always be masked (sensitive key names)
    let isSensitiveKey (config: PIIMaskingConfig) (key: string) : bool =
        let lowerKey = key.ToLowerInvariant()
        config.SensitiveKeys
        |> Set.exists (fun sensitiveKey -> lowerKey.Contains(sensitiveKey))

    /// Check if a key is exempt from masking
    let isExemptKey (config: PIIMaskingConfig) (key: string) : bool =
        let lowerKey = key.ToLowerInvariant()
        config.ExemptKeys |> Set.contains lowerKey

    // ============================================================
    // LOG ENTRY MASKING (SC-LOG-003 Implementation)
    // ============================================================

    /// Mask all sensitive data in a key-value pair
    let maskKeyValue (config: PIIMaskingConfig) (key: string) (value: obj) : obj =
        if not config.Enabled then
            value
        elif isExemptKey config key then
            value
        elif isSensitiveKey config key then
            box "[REDACTED]"
        else
            match value with
            | :? string as s ->
                let result = maskWithDefaults config s
                box result.Masked
            | _ ->
                value

    /// Mask a FractalLogEntry payload
    let maskPayload (config: PIIMaskingConfig) (payload: FractalPayload) : FractalPayload =
        if not config.Enabled then
            payload
        else
            match payload with
            | FractalPayload.Empty -> FractalPayload.Empty

            | FractalPayload.Text text ->
                let result = maskWithDefaults config text
                FractalPayload.Text result.Masked

            | FractalPayload.Json json ->
                // Simple JSON string masking (production would use proper JSON parser)
                let result = maskWithDefaults config json
                FractalPayload.Json result.Masked

            | FractalPayload.Binary bytes ->
                // Don't mask binary data
                FractalPayload.Binary bytes

            | FractalPayload.Structured fields ->
                let maskedFields =
                    fields
                    |> List.map (fun (k, v) ->
                        let maskedValue = maskKeyValue config k v
                        (k, maskedValue)
                    )
                FractalPayload.Structured maskedFields

    /// Mask a FractalLogEntry baggage
    let maskBaggage (config: PIIMaskingConfig) (baggage: Map<string, string>) : Map<string, string> =
        if not config.Enabled then
            baggage
        else
            baggage
            |> Map.map (fun key value ->
                if isExemptKey config key then
                    value
                elif isSensitiveKey config key then
                    "[REDACTED]"
                else
                    let result = maskWithDefaults config value
                    result.Masked
            )

    /// Mask an entire FractalLogEntry (main SC-LOG-003 entry point)
    let maskLogEntry (config: PIIMaskingConfig) (entry: FractalLogEntry) : FractalLogEntry =
        if not config.Enabled then
            entry
        else
            { entry with
                Payload = maskPayload config entry.Payload
                Baggage = maskBaggage config entry.Baggage
            }

    // ============================================================
    // BATCH MASKING
    // ============================================================

    /// Mask multiple entries (for batch processing)
    let maskBatch (config: PIIMaskingConfig) (entries: FractalLogEntry list) : FractalLogEntry list =
        entries |> List.map (maskLogEntry config)

    // ============================================================
    // VALIDATION AND TESTING
    // ============================================================

    /// Validate that masking is working correctly
    let validateMasking () : SafetyConstraintResult =
        // Test email masking separately
        let emailResult = maskWithDefaults defaultConfig "user@example.com"
        let emailMasked = emailResult.WasMasked &&
                          emailResult.Masked.Contains("***") &&
                          emailResult.Masked.Contains("@example.com") &&
                          not (emailResult.Masked.Contains("user@"))

        // Test SSN masking separately
        let ssnResult = maskWithDefaults defaultConfig "SSN: 123-45-6789"
        let ssnMasked = ssnResult.WasMasked && ssnResult.Masked.Contains("[REDACTED]")

        if emailMasked && ssnMasked then
            {
                ConstraintId = SafetyConstraints.scLog003
                Description = "PII masking at decorator"
                Passed = true
                Details = sprintf "Masking verified: %d patterns active" defaultPatterns.Length
            }
        else
            {
                ConstraintId = SafetyConstraints.scLog003
                Description = "PII masking at decorator"
                Passed = false
                Details = sprintf "Masking failed: email=%s, ssn=%s" emailResult.Masked ssnResult.Masked
            }

    /// Get masking statistics
    let getMaskingStats () =
        {|
            PatternCount = defaultPatterns.Length
            EnabledPatterns = defaultPatterns |> List.filter (fun p -> p.Enabled) |> List.length
            Categories = defaultPatterns |> List.map (fun p -> p.Category) |> List.distinct
        |}

