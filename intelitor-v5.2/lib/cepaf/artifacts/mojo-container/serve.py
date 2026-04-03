"""
MAX Engine Inference Server with Zenoh Neural Bridge.

Serves GGUF models via MAX Engine and bridges inference requests
through Zenoh pub/sub for the Indrajaal biomorphic mesh.

STAMP Constraints:
- SC-MOJO-001: Zenoh connection to router
- SC-MOJO-002: Inference latency monitoring
- SC-MOJO-006: Health beacon publication
- SC-NEURAL-BRIDGE-001: Request correlation via request_id
- SC-NEURAL-BRIDGE-002: Circuit breaker on consecutive failures
- SC-NEURAL-BRIDGE-003: Backpressure via queue depth limit

Run: python3 serve.py
"""

import asyncio
import json
import logging
import os
import time
import uuid
from contextlib import asynccontextmanager

import uvicorn
from fastapi import FastAPI

# Zenoh imported conditionally (graceful degradation if not available)
try:
    import zenoh

    ZENOH_AVAILABLE = True
except ImportError:
    ZENOH_AVAILABLE = False

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("indrajaal-mojo")

# Configuration from environment
ZENOH_ROUTER = os.getenv("ZENOH_ROUTER_ENDPOINT", "tcp/zenoh-router-1:7447")
ZENOH_MODE = os.getenv("ZENOH_MODE", "client")
MODEL_PATH = os.getenv("MAX_MODEL_PATH", "/models/llama-3-8b.gguf")
SERVE_PORT = int(os.getenv("MAX_SERVE_PORT", "11436"))
MAX_QUEUE_DEPTH = int(os.getenv("MAX_QUEUE_DEPTH", "100"))

# Key expressions (SC-NEURAL-BRIDGE-001)
KEY_REQUEST = "indrajaal/inference/request/"
KEY_RESPONSE = "indrajaal/inference/response/"
KEY_HEALTH = "indrajaal/inference/health"
KEY_METRICS = "indrajaal/inference/metrics"

# State
_engine = None
_zenoh_session = None
_subscriber = None
_request_count = 0
_total_latency_ms = 0.0
_consecutive_failures = 0
_circuit_open = False
_queue_depth = 0


class InferenceEngine:
    """Wrapper around MAX Engine for model loading and inference."""

    def __init__(self, model_path: str):
        self.model_path = model_path
        self.model = None
        self.loaded = False
        self.model_version = "unknown"

    def load(self):
        """Load GGUF model via MAX Engine."""
        try:
            # MAX Engine SDK import — available inside container
            from max import engine as max_engine

            eng = max_engine.InferenceSession()
            self.model = eng.load(self.model_path)
            self.loaded = True
            self.model_version = os.path.basename(self.model_path)
            logger.info(f"Model loaded: {self.model_version}")
        except ImportError:
            logger.warning("MAX Engine SDK not available — running in stub mode")
            self.loaded = False
        except Exception as e:
            logger.error(f"Model load failed: {e}")
            self.loaded = False

    def infer(self, input_text: str, params: dict | None = None) -> dict:
        """Run inference on loaded model."""
        if not self.loaded:
            return {"error": "model_not_loaded", "output": "[stub] " + input_text[:50]}

        start = time.monotonic()
        try:
            # MAX Engine inference call
            result = self.model.execute(input_text, **(params or {}))
            latency = (time.monotonic() - start) * 1000
            return {
                "output": str(result),
                "latency_ms": round(latency, 2),
                "model_version": self.model_version,
            }
        except Exception as e:
            latency = (time.monotonic() - start) * 1000
            return {"error": str(e), "latency_ms": round(latency, 2)}


def _publish_health():
    """Publish health beacon to Zenoh (SC-MOJO-006)."""
    global _zenoh_session, _engine, _request_count, _total_latency_ms, _queue_depth

    if not _zenoh_session:
        return

    avg_latency = (_total_latency_ms / _request_count) if _request_count > 0 else 0.0

    health = {
        "status": "healthy" if (_engine and _engine.loaded and not _circuit_open) else "degraded",
        "models_loaded": [_engine.model_version] if (_engine and _engine.loaded) else [],
        "queue_depth": _queue_depth,
        "circuit_breaker": "open" if _circuit_open else "closed",
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%S.000000Z", time.gmtime()),
    }
    try:
        _zenoh_session.put(KEY_HEALTH, json.dumps(health).encode())
    except Exception as e:
        logger.warning(f"Health publish failed: {e}")

    metrics = {
        "throughput_rps": _request_count / max(1, time.monotonic() - _start_time),
        "avg_latency_ms": round(avg_latency, 2),
        "queue_depth": _queue_depth,
        "total_requests": _request_count,
    }
    try:
        _zenoh_session.put(KEY_METRICS, json.dumps(metrics).encode())
    except Exception:
        pass


async def _health_beacon_loop():
    """Periodic health beacon (every 10s)."""
    while True:
        _publish_health()
        await asyncio.sleep(10)


def _handle_inference_request(sample):
    """Zenoh subscriber callback for inference requests (SC-NEURAL-BRIDGE-001)."""
    global _request_count, _total_latency_ms, _consecutive_failures
    global _circuit_open, _queue_depth

    # Circuit breaker check (SC-NEURAL-BRIDGE-002)
    if _circuit_open:
        logger.warning("Circuit breaker OPEN — rejecting request")
        return

    # Backpressure check (SC-NEURAL-BRIDGE-003)
    if _queue_depth >= MAX_QUEUE_DEPTH:
        logger.warning(f"Queue full ({_queue_depth}/{MAX_QUEUE_DEPTH}) — rejecting")
        return

    _queue_depth += 1
    try:
        payload = json.loads(sample.payload.to_bytes())
        request_id = payload.get("request_id", str(uuid.uuid4()))
        model = payload.get("model", "default")
        input_text = payload.get("input", "")
        params = payload.get("params", {})

        logger.info(f"Inference request {request_id}: model={model}, input_len={len(input_text)}")

        result = _engine.infer(input_text, params)
        result["request_id"] = request_id

        _request_count += 1
        latency = result.get("latency_ms", 0)
        _total_latency_ms += latency

        if "error" in result and result["error"] != "model_not_loaded":
            _consecutive_failures += 1
            if _consecutive_failures >= 5:
                _circuit_open = True
                logger.error("Circuit breaker TRIPPED after 5 consecutive failures")
        else:
            _consecutive_failures = 0

        # Publish response (SC-NEURAL-BRIDGE-001)
        response_key = f"{KEY_RESPONSE}{request_id}"
        if _zenoh_session:
            _zenoh_session.put(response_key, json.dumps(result).encode())

    except Exception as e:
        logger.error(f"Request handler error: {e}")
        _consecutive_failures += 1
    finally:
        _queue_depth -= 1


_start_time = time.monotonic()


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan — init engine + Zenoh."""
    global _engine, _zenoh_session, _subscriber, _start_time

    _start_time = time.monotonic()

    # Load model
    _engine = InferenceEngine(MODEL_PATH)
    _engine.load()

    # Connect to Zenoh (SC-MOJO-001)
    if ZENOH_AVAILABLE:
        try:
            config = zenoh.Config()
            config.insert_json5("mode", f'"{ZENOH_MODE}"')
            config.insert_json5("connect/endpoints", f'["{ZENOH_ROUTER}"]')
            _zenoh_session = zenoh.open(config)

            # Subscribe to inference requests
            _subscriber = _zenoh_session.declare_subscriber(
                f"{KEY_REQUEST}*", _handle_inference_request
            )
            logger.info(f"Zenoh connected to {ZENOH_ROUTER}, subscribed to {KEY_REQUEST}*")
        except Exception as e:
            logger.error(f"Zenoh connection failed: {e} — running without mesh bridge")
    else:
        logger.warning("Zenoh not available — running in HTTP-only mode")

    # Start health beacon
    beacon_task = asyncio.create_task(_health_beacon_loop())

    yield

    # Cleanup
    beacon_task.cancel()
    if _subscriber:
        _subscriber.undeclare()
    if _zenoh_session:
        _zenoh_session.close()


app = FastAPI(title="indrajaal-mojo", version="1.0.0", lifespan=lifespan)


@app.get("/health")
async def health():
    """Health endpoint for container orchestration (SC-MOJO-004)."""
    return {
        "status": "healthy" if (_engine and _engine.loaded and not _circuit_open) else "degraded",
        "models_loaded": [_engine.model_version] if (_engine and _engine.loaded) else [],
        "zenoh_connected": _zenoh_session is not None,
        "circuit_breaker": "open" if _circuit_open else "closed",
        "queue_depth": _queue_depth,
        "uptime_s": round(time.monotonic() - _start_time, 1),
    }


@app.post("/v1/inference")
async def inference(request: dict):
    """HTTP inference endpoint (fallback when Zenoh is unavailable)."""
    if _circuit_open:
        return {"error": "circuit_breaker_open"}

    input_text = request.get("input", "")
    params = request.get("params", {})
    result = _engine.infer(input_text, params)
    result["request_id"] = request.get("request_id", str(uuid.uuid4()))
    return result


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=SERVE_PORT, log_level="info")
