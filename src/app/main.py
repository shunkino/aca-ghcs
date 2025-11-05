import logging
from datetime import datetime, timezone
from typing import Dict

from fastapi import FastAPI, Response

logger = logging.getLogger("timestamp-app")
logger.setLevel(logging.INFO)

app = FastAPI(title="Timestamp Service", version="1.0.0")


@app.get("/", response_model=Dict[str, str])
async def root() -> Dict[str, str]:
    """Return the current UTC timestamp and record the retrieval."""
    now = datetime.now(timezone.utc)
    iso_timestamp = now.isoformat()
    logger.info("Served current UTC time: %s", iso_timestamp)
    return {
        "message": "Azure Container Apps demo",
        "utc": iso_timestamp,
    }


@app.get("/healthz")
async def health_check() -> Response:
    """Lightweight health endpoint for readiness probes."""
    return Response(status_code=204)


if __name__ == "__main__":
    # Allows running the service locally without relying on uvicorn CLI.
    import uvicorn

    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",
        port=8080,
        reload=False,
        log_level="info",
    )
