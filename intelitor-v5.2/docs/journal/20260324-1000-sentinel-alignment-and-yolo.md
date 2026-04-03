# Journal Entry: Sentinel Messaging Alignment & YOLO Configuration

**Date:** March 24, 2026
**Version:** v21.3.1-SIL6 (Hardened)
**Author:** Gemini (Cybernetic Architect)
**Status:** ALIGNED & DOCUMENTED
**Objective:** Document the alignment of Sentinel messaging with the Fractal Telemetry Matrix and define how to enable the Vision Holon (YOLO).

---

## 1. Sentinel Messaging Alignment
To ensure full compliance with the system's 8x8 Fractal Matrix observability patterns, the Sentinel's Zenoh publisher (`Indrajaal.Observability.ZenohSafetyPublisher`) has been updated.

**Changes Made:**
The payloads for `publish_sentinel_threat/4` and `publish_sentinel_quarantine/2` now explicitly include structural fractal routing metadata:
- `fractal_layer: "l4_tactical"`
- `domain: "safety"`
- `component: "sentinel"`

**Why:** This allows downstream aggregators (like SigNoz and the `FractalTelemetryMatrix` engine) to route and filter immune system events correctly without needing to infer the origin from the Zenoh topic string alone. It ensures absolute semantic clarity in the audit logs.

## 2. Enabling YOLO (Vision Holon) in Settings
The "Vision Holon" provides L1 Reflex real-time object detection (e.g., weapons, smoke) via YOLO models executed on local accelerators. To maximize CI/CD and default developer speed, this feature is disabled by default.

### Configuration
I have explicitly added the configuration schema to `config/runtime.exs`:

```elixir
# ═══════════════════════════════════════════════════════════════════════════════
# VISION HOLON (YOLO) - L1 Reflex Node
# ═══════════════════════════════════════════════════════════════════════════════
config :indrajaal, Indrajaal.Bio.Holon.Vision,
  enabled: System.get_env("ENABLE_YOLO", "false") == "true",
  model_path: System.get_env("YOLO_MODEL_PATH", "models/yolov8-weapons.onnx"),
  confidence_threshold: 0.85,
  accelerator: System.get_env("YOLO_ACCELERATOR", "cpu")
```

### How to Enable
To activate the YOLO processing module at runtime, operators must inject the following environment variables during the `sa-up` or `mix phx.server` boot phase:

```bash
export ENABLE_YOLO=true
export YOLO_MODEL_PATH="models/yolov8-weapons.onnx" # Or path to scaled_yolov4
export YOLO_ACCELERATOR="cuda" # Options: cuda, cpu, tensorrt
```

**Note:** Ensure the appropriate backend dependencies (e.g., `EXLA`, `Torchx`) are available on the host machine or container if using hardware acceleration (`cuda`/`tensorrt`).

---
**Signature:** `0x7E...F4A` (Cybernetic Architect)
"The visual cortex is configurable. The immune system speaks clearly."
