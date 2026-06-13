import logging
from typing import Any

from fastapi import HTTPException, status
from pymongo import ASCENDING, DESCENDING, AsyncMongoClient
from pymongo.asynchronous.database import AsyncDatabase

from .config import settings

_client: AsyncMongoClient[dict[str, Any]] | None = None
_database: AsyncDatabase[dict[str, Any]] | None = None
logger = logging.getLogger(__name__)


async def connect_database() -> None:
    global _client, _database
    if not settings.mongodb_uri:
        return
    client = AsyncMongoClient(
        settings.mongodb_uri,
        serverSelectionTimeoutMS=5000,
        connectTimeoutMS=5000,
    )
    database = client[settings.mongodb_database]
    try:
        await client.admin.command("ping")
        await database.user_profiles.create_index(
            [("ownerId", ASCENDING)], unique=True
        )
        await database.emergency_contacts.create_index(
            [("ownerId", ASCENDING)], unique=True
        )
        await database.emergency_events.create_index(
            [("eventId", ASCENDING)], unique=True
        )
        await database.emergency_events.create_index(
            [("ownerId", ASCENDING), ("occurredAt", DESCENDING)]
        )
    except Exception:
        logger.exception("MongoDB initialization failed")
        await client.close()
        return
    _client = client
    _database = database


async def close_database() -> None:
    global _client, _database
    if _client is not None:
        await _client.close()
    _client = None
    _database = None


def get_database() -> AsyncDatabase[dict[str, Any]]:
    if _database is None:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail={
                "code": "database_unavailable",
                "message": "Emergency data storage is unavailable.",
            },
        )
    return _database


async def database_is_available() -> bool:
    if _client is None:
        return False
    try:
        await _client.admin.command("ping")
    except Exception:
        return False
    return True
