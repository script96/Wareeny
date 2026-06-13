import asyncio
from dataclasses import dataclass

import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jwt import PyJWKClient

from .config import settings

bearer_scheme = HTTPBearer(auto_error=False)
_jwks_client = PyJWKClient(settings.clerk_jwks_url) if settings.clerk_jwks_url else None


@dataclass(frozen=True)
class AuthenticatedUser:
    user_id: str


def _unauthorized(message: str) -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail={"code": "unauthorized", "message": message},
        headers={"WWW-Authenticate": "Bearer"},
    )


def _decode_token(token: str) -> dict:
    if _jwks_client is None or not settings.clerk_issuer:
        raise _unauthorized("Clerk authentication is not configured.")
    signing_key = _jwks_client.get_signing_key_from_jwt(token)
    payload = jwt.decode(
        token,
        signing_key.key,
        algorithms=["RS256"],
        issuer=settings.clerk_issuer,
        options={"require": ["exp", "iat", "iss", "sub"]},
    )
    authorized_party = payload.get("azp")
    if (
        settings.clerk_authorized_parties
        and authorized_party not in settings.clerk_authorized_parties
    ):
        raise _unauthorized("The token authorized party is not allowed.")
    return payload


async def require_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
) -> AuthenticatedUser:
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise _unauthorized("A bearer token is required.")
    try:
        payload = await asyncio.to_thread(_decode_token, credentials.credentials)
    except HTTPException:
        raise
    except jwt.PyJWTError as exc:
        raise _unauthorized("The session token is invalid or expired.") from exc
    except Exception as exc:
        raise _unauthorized("The session token could not be verified.") from exc

    user_id = payload.get("sub")
    if not isinstance(user_id, str) or not user_id:
        raise _unauthorized("The session token has no user identifier.")
    return AuthenticatedUser(user_id=user_id)
