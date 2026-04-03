---
description: Key Management System — key lifecycle, certificates, encryption, KMS state verification
allowed-tools: mcp__sentinel-zenoh__sentinel, mcp__sentinel-zenoh__zenoh_query, mcp__sentinel-zenoh__checkpoint_op, Read, Grep, Glob
argument-hint: [status|verify|rotate|audit|backup]
---

# Key Management System (SC-SEC-044 to SC-SEC-047)

Cryptographic key lifecycle management: generation, rotation, backup, and integrity verification.

## Usage
```
/kms status         # KMS state and key inventory
/kms verify         # Verify key integrity and chain of custody
/kms rotate         # Check rotation schedule and compliance
/kms audit          # Audit trail of key operations
/kms backup         # Verify KMS backup in checkpoint
```

## Cryptographic Inventory
| Algorithm | Purpose | Key Size | STAMP |
|-----------|---------|----------|-------|
| Ed25519 | Block signatures | 256-bit | SC-REG-003 |
| SHA3-256 | Block hashing | 256-bit | Ω₈ |
| BLAKE3 | Fast hashing | 256-bit | SC-SEC-047 |
| HMAC-SHA512 | Federation MAC | 512-bit | SC-SEC-047 |
| RS(255,223) | Error correction | 32 symbols | SC-REG-009 |

## KMS State Location
```
data/kms/
├── keys/           # Active key material
├── certificates/   # X.509 certificates
├── revoked/        # Revoked key archive
└── audit.log       # Key operation audit trail
```

## Verification Steps
1. Check Sentinel health: `sentinel(action: "health")`
2. Query KMS status: `zenoh_query(action: "get", key: "indrajaal/kms/status")`
3. Verify checkpoint includes KMS: `checkpoint_op(action: "verify")`
4. Check key file permissions (600/owner-only)
5. Verify no expired certificates
6. Audit rotation compliance (SC-SEC-047)
7. Validate Ed25519 key pairs (public matches private)
8. Check HMAC-SHA512 federation keys active

## Key Lifecycle
```
Generate → Store → Activate → Use → Rotate → Archive → Destroy
    │                                    │
    └── Backup (checkpoint Phase 1) ─────┘
```

## Mathematical Foundation

**Key Entropy** (generation quality):

$$H(K) = -\sum_{i=0}^{2^n - 1} p_i \log_2 p_i = n \text{ bits (ideal)}$$

For Ed25519: $H(K) = 256$ bits. For HMAC-SHA512: $H(K) = 512$ bits.

**Quantum Resistance Margin** (SC-SIL6-010):

$$S_{quantum} = \frac{H(K)}{128} \geq 2.0$$

Ed25519 provides $256/128 = 2.0$× Grover margin. SHA3-256 provides collision resistance $2^{128}$.

**Key Rotation Period** (compliance):

$$T_{rotate} \leq T_{max} = 90 \text{ days}, \quad P_{compromise} = 1 - e^{-\lambda T_{rotate}}$$

Shorter rotation → lower compromise probability.

**Reed-Solomon Detection Probability**:

$$P_{detect} = 1 - \frac{1}{q^{d_{min}-1}} = 1 - \frac{1}{256^{32}} \approx 1$$

Virtually certain detection for any error pattern within correction capacity.

**Chain of Custody** (audit completeness):

$$\text{Auditable}(K) \iff \forall op \in \text{lifecycle}(K) : \exists \text{log}(op)$$

## STAMP Constraints
| ID | Constraint |
|----|------------|
| SC-SEC-044 | Sobelow security check |
| SC-SEC-047 | Encryption mandatory |
| SC-SIL6-010 | Quantum-resistant cryptography |
| SC-SIL6-015 | Immutable audit trail |
| SC-REG-003 | Ed25519 signed blocks |
| SC-REG-009 | Reed-Solomon RS(255,223) |
| SC-UCR-001 | KMS in Phase 1 checkpoint |
