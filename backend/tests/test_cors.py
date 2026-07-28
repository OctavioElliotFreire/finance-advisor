from fastapi.testclient import TestClient

from app.main import app


def test_allows_localhost_origin_on_a_normal_request():
    client = TestClient(app)

    response = client.get("/health", headers={"Origin": "http://localhost:5000"})

    assert response.status_code == 200
    assert response.headers["access-control-allow-origin"] == "http://localhost:5000"


def test_allows_localhost_origin_preflight_for_patch():
    client = TestClient(app)

    response = client.options(
        "/v1/households/00000000-0000-0000-0000-000000000000/anomalies/00000000-0000-0000-0000-000000000000",
        headers={
            "Origin": "http://localhost:5000",
            "Access-Control-Request-Method": "PATCH",
        },
    )

    assert response.status_code == 200
    assert response.headers["access-control-allow-origin"] == "http://localhost:5000"


def test_rejects_non_localhost_origin():
    client = TestClient(app)

    response = client.get(
        "/health", headers={"Origin": "https://evil.example.com"}
    )

    assert response.status_code == 200
    assert "access-control-allow-origin" not in response.headers
