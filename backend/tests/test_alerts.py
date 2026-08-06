import time
import uuid

import jwt
import pytest
from fastapi.testclient import TestClient

from app.database.session import SessionLocal
from app.main import app
from app.models.app_user import AppUser
from app.models.audit_event import AuditEvent
from app.models.household import Household, HouseholdMember
from app.models.pluggy_connection import PluggyConnection, SyncJob
from app.settings import settings


@pytest.fixture(autouse=True)
def hs256_secret(monkeypatch):
    monkeypatch.setattr(settings, "supabase_url", "")
    monkeypatch.setattr(settings, "supabase_jwt_secret", "test-secret")
    monkeypatch.setattr(settings, "supabase_jwt_audience", "authenticated")
    monkeypatch.setattr(settings, "supabase_jwt_issuer", "")


@pytest.fixture
def client():
    return TestClient(app)


@pytest.fixture
def make_user():
    created_provider_ids = []

    def _make(email):
        provider_user_id = str(uuid.uuid4())
        created_provider_ids.append(provider_user_id)
        token = jwt.encode(
            {
                "sub": provider_user_id,
                "email": email,
                "aud": "authenticated",
                "exp": int(time.time()) + 3600,
            },
            "test-secret",
            algorithm="HS256",
        )
        return {"Authorization": f"Bearer {token}"}

    yield _make

    db = SessionLocal()
    app_user_ids = [
        row.id
        for row in db.query(AppUser)
        .filter(AppUser.auth_provider_user_id.in_(created_provider_ids))
        .all()
    ]
    if app_user_ids:
        household_ids = [
            row.household_id
            for row in db.query(HouseholdMember)
            .filter(HouseholdMember.app_user_id.in_(app_user_ids))
            .all()
        ]
        db.query(AuditEvent).filter(
            AuditEvent.actor_app_user_id.in_(app_user_ids)
        ).delete(synchronize_session=False)
        if household_ids:
            db.query(SyncJob).filter(SyncJob.household_id.in_(household_ids)).delete(
                synchronize_session=False
            )
            db.query(PluggyConnection).filter(
                PluggyConnection.household_id.in_(household_ids)
            ).delete(synchronize_session=False)
        db.query(HouseholdMember).filter(
            HouseholdMember.app_user_id.in_(app_user_ids)
        ).delete(synchronize_session=False)
        if household_ids:
            db.query(Household).filter(Household.id.in_(household_ids)).delete(
                synchronize_session=False
            )
        db.query(AppUser).filter(AppUser.id.in_(app_user_ids)).delete(
            synchronize_session=False
        )
    db.commit()
    db.close()


def test_alerts_lists_failed_sync_jobs(client, make_user):
    headers = make_user("alerts-owner@example.com")
    household = client.post(
        "/v1/households", json={"name": "Alerts Family"}, headers=headers
    ).json()

    db = SessionLocal()
    connection = PluggyConnection(
        household_id=household["id"], pluggy_item_id="item-alerts", status="LOGIN_ERROR"
    )
    db.add(connection)
    db.flush()
    db.add(
        SyncJob(
            household_id=household["id"], pluggy_connection_id=connection.id, status="failed"
        )
    )
    db.add(
        SyncJob(
            household_id=household["id"], pluggy_connection_id=connection.id, status="completed"
        )
    )
    db.commit()
    db.close()

    response = client.get(f"/v1/households/{household['id']}/alerts", headers=headers)

    assert response.status_code == 200
    body = response.json()
    assert len(body["failed_sync_jobs"]) == 1
    assert body["failed_sync_jobs"][0]["pluggy_item_id"] == "item-alerts"
    assert body["failure_events"] == []


def test_alerts_lists_failure_events(client, make_user):
    headers = make_user("alerts-events-owner@example.com")
    household = client.post(
        "/v1/households", json={"name": "Alerts Events Family"}, headers=headers
    ).json()

    db = SessionLocal()
    db.add(
        AuditEvent(
            household_id=household["id"],
            actor_app_user_id=db.query(AppUser)
            .filter(AppUser.email == "alerts-events-owner@example.com")
            .one()
            .id,
            action="assistant.call_failed",
            metadata_json={"error": "boom"},
        )
    )
    db.commit()
    db.close()

    response = client.get(f"/v1/households/{household['id']}/alerts", headers=headers)

    assert response.status_code == 200
    body = response.json()
    assert len(body["failure_events"]) == 1
    assert body["failure_events"][0]["action"] == "assistant.call_failed"
    assert body["failure_events"][0]["metadata_json"] == {"error": "boom"}


def test_non_owner_cannot_list_alerts(client, make_user):
    headers_owner = make_user("alerts-nonowner-owner@example.com")
    headers_member = make_user("alerts-nonowner-member@example.com")
    client.get("/v1/me", headers=headers_member)

    household = client.post(
        "/v1/households", json={"name": "Alerts Non Owner Family"}, headers=headers_owner
    ).json()
    client.post(
        f"/v1/households/{household['id']}/members",
        json={"email": "alerts-nonowner-member@example.com", "role": "member"},
        headers=headers_owner,
    )

    response = client.get(
        f"/v1/households/{household['id']}/alerts", headers=headers_member
    )

    assert response.status_code == 403


def test_alerts_require_authentication(client):
    fake_id = uuid.uuid4()
    assert client.get(f"/v1/households/{fake_id}/alerts").status_code in (401, 403)
