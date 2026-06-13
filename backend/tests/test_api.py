from copy import deepcopy

from fastapi.testclient import TestClient

from emergency.auth import AuthenticatedUser, require_user
from emergency.database import get_database
from main import app


class FakeCollection:
    def __init__(self):
        self.documents = []

    async def update_one(self, query, update, upsert=False):
        document = await self.find_one(query)
        if document is None and upsert:
            document = {**query, **deepcopy(update.get("$setOnInsert", {}))}
            self.documents.append(document)
        if document is not None:
            document.update(deepcopy(update.get("$set", {})))

    async def replace_one(self, query, replacement, upsert=False):
        existing = await self.find_one(query)
        if existing is not None:
            self.documents.remove(existing)
        if existing is not None or upsert:
            self.documents.append(deepcopy(replacement))

    async def find_one(self, query):
        for document in self.documents:
            if all(document.get(key) == value for key, value in query.items()):
                return document
        return None

    async def delete_one(self, query):
        document = await self.find_one(query)
        if document is not None:
            self.documents.remove(document)


class FakeDatabase:
    def __init__(self):
        self.user_profiles = FakeCollection()
        self.emergency_contacts = FakeCollection()
        self.emergency_events = FakeCollection()


def test_missing_bearer_token_is_rejected():
    app.dependency_overrides[get_database] = lambda: FakeDatabase()
    try:
        with TestClient(app) as client:
            response = client.get("/api/v1/me")
        assert response.status_code == 401
    finally:
        app.dependency_overrides.clear()


def test_contacts_are_isolated_by_verified_user():
    database = FakeDatabase()
    current_user = {"id": "user_a"}

    async def fake_user():
        return AuthenticatedUser(user_id=current_user["id"])

    app.dependency_overrides[get_database] = lambda: database
    app.dependency_overrides[require_user] = fake_user
    try:
        with TestClient(app) as client:
            saved = client.put(
                "/api/v1/me/emergency-contact",
                json={
                    "name": "Mona",
                    "phoneNumber": "+201001234567",
                    "relationship": "Sister",
                    "source": "manual",
                    "verified": True,
                },
            )
            assert saved.status_code == 200

            current_user["id"] = "user_b"
            other_user = client.get("/api/v1/me/emergency-contact")
            assert other_user.status_code == 404
    finally:
        app.dependency_overrides.clear()


def test_retrying_event_uuid_is_idempotent():
    database = FakeDatabase()

    async def fake_user():
        return AuthenticatedUser(user_id="user_a")

    app.dependency_overrides[get_database] = lambda: database
    app.dependency_overrides[require_user] = fake_user
    payload = {
        "eventId": "8af63b58-75c5-45fe-98ee-84b639aac990",
        "trigger": "manual_sos",
        "outcome": "callAttempted",
        "occurredAt": "2026-06-12T10:00:00Z",
    }
    try:
        with TestClient(app) as client:
            first = client.post("/api/v1/me/emergency-events", json=payload)
            second = client.post("/api/v1/me/emergency-events", json=payload)

        assert first.status_code == 200
        assert second.status_code == 200
        assert len(database.emergency_events.documents) == 1
    finally:
        app.dependency_overrides.clear()
