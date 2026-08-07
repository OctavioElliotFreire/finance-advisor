import logging
import time

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from sqlalchemy import text

from app.api.alerts import router as alerts_router
from app.api.anomalies import router as anomalies_router
from app.api.assistant import router as assistant_router
from app.api.audit import router as audit_router
from app.api.connections import router as connections_router
from app.api.dashboard import router as dashboard_router
from app.api.export import router as export_router
from app.api.extended_finance import router as extended_finance_router
from app.api.household_members import pending_invites_router, router as household_members_router
from app.api.households import router as households_router
from app.api.invites import router as invites_router
from app.api.me import router as me_router
from app.database.session import engine
from app.settings import settings

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s %(message)s")
logger = logging.getLogger("app.request")

app = FastAPI(title="Family Finance API")
app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=settings.cors_allowed_origin_regex,
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.middleware("http")
async def log_requests(request: Request, call_next):
    start = time.monotonic()
    response = await call_next(request)
    duration_ms = round((time.monotonic() - start) * 1000, 1)
    logger.info(
        "%s %s -> %s (%sms)",
        request.method,
        request.url.path,
        response.status_code,
        duration_ms,
    )
    return response


app.include_router(me_router)
app.include_router(households_router)
app.include_router(household_members_router)
app.include_router(pending_invites_router)
app.include_router(invites_router)
app.include_router(connections_router)
app.include_router(dashboard_router)
app.include_router(extended_finance_router)
app.include_router(anomalies_router)
app.include_router(assistant_router)
app.include_router(audit_router)
app.include_router(export_router)
app.include_router(alerts_router)


@app.get("/health")
def health():
    try:
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
    except Exception as exc:  # noqa: BLE001 - reported to caller, not swallowed
        logger.error("health check: database unreachable: %s", exc)
        return JSONResponse(
            status_code=503,
            content={"status": "error", "database": "unreachable"},
        )
    return {"status": "ok", "database": "ok"}
