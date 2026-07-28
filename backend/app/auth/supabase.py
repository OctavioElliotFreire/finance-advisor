from functools import lru_cache

import jwt
from fastapi import HTTPException, status
from jwt import PyJWKClient

from app.settings import settings


@lru_cache
def _jwk_client() -> PyJWKClient:
    jwks_url = f"{settings.supabase_url.rstrip('/')}/auth/v1/.well-known/jwks.json"
    return PyJWKClient(jwks_url)


def verify_supabase_token(token: str) -> dict:
    """Verify a Supabase access token and return its claims.

    Newer Supabase projects sign with an asymmetric key published at a JWKS
    endpoint; older projects sign with a shared HS256 secret. Try JWKS first
    and fall back to the shared secret when one is configured.
    """
    options = {"require": ["exp", "sub"]}
    kwargs = {}
    if settings.supabase_jwt_audience:
        kwargs["audience"] = settings.supabase_jwt_audience
    if settings.supabase_jwt_issuer:
        kwargs["issuer"] = settings.supabase_jwt_issuer

    errors = []

    if settings.supabase_url:
        try:
            signing_key = _jwk_client().get_signing_key_from_jwt(token)
            return jwt.decode(
                token,
                signing_key.key,
                algorithms=["ES256", "RS256"],
                options=options,
                **kwargs,
            )
        except Exception as exc:  # noqa: BLE001 - fall through to HS256 attempt
            errors.append(exc)

    if settings.supabase_jwt_secret:
        try:
            return jwt.decode(
                token,
                settings.supabase_jwt_secret,
                algorithms=["HS256"],
                options=options,
                **kwargs,
            )
        except Exception as exc:  # noqa: BLE001
            errors.append(exc)

    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail=f"Invalid or expired token: {errors[-1]}" if errors else "Auth not configured",
        headers={"WWW-Authenticate": "Bearer"},
    )
