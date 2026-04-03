
# Dockerfile.mojo - Mojo MAX Compute Substrate (SIL-6 Biomorphic)
# Version: 1.0.0
# Stub: Provides health endpoint on :11436 until real MAX SDK available
FROM docker.io/library/alpine:3.21

RUN apk add --no-cache curl socat

WORKDIR /app

# Health endpoint stub — responds 200 on /health
RUN printf '#!/bin/sh\nwhile true; do\n  echo -e "HTTP/1.1 200 OK\\r\\nContent-Type: application/json\\r\\nConnection: close\\r\\n\\r\\n{\\"status\\":\\"healthy\\",\\"service\\":\\"mojo-max-stub\\",\\"version\\":\\"1.0.0-stub\\"}" | socat - TCP-LISTEN:11436,reuseaddr,fork &\n  wait\ndone\n' > /app/serve.sh && chmod +x /app/serve.sh

EXPOSE 11436

HEALTHCHECK --interval=10s --timeout=5s --retries=3 \
    CMD curl -sf http://localhost:11436/health || exit 1

ENTRYPOINT ["/bin/sh", "/app/serve.sh"]
