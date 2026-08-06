from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.anomalies import router as anomalies_router
from app.api.assistant import router as assistant_router
from app.api.connections import router as connections_router
from app.api.dashboard import router as dashboard_router
from app.api.extended_finance import router as extended_finance_router
from app.api.household_members import pending_invites_router, router as household_members_router
from app.api.households import router as households_router
from app.api.invites import router as invites_router
from app.api.me import router as me_router
from app.settings import settings

app = FastAPI(title="Family Finance API")
app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=settings.cors_allowed_origin_regex,
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)
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


@app.get("/health")
def health():
    return {"status": "ok"}
