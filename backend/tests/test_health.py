from fastapi.testclient import TestClient

from app import main
from app.main import app


def test_health_reports_ok_when_database_reachable():
    client = TestClient(app)

    response = client.get("/health")

    assert response.status_code == 200
    assert response.json() == {"status": "ok", "database": "ok"}


def test_health_reports_503_when_database_unreachable(monkeypatch):
    class _BrokenEngine:
        def connect(self):
            raise ConnectionError("simulated database outage")

    monkeypatch.setattr(main, "engine", _BrokenEngine())
    client = TestClient(app)

    response = client.get("/health")

    assert response.status_code == 503
    assert response.json() == {"status": "error", "database": "unreachable"}
