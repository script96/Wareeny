from datetime import datetime, timezone

import pytest
from pydantic import ValidationError

from emergency.models import EmergencyContactInput, EmergencyEventInput


def test_contact_normalizes_phone_to_e164():
    contact = EmergencyContactInput(
        name="Mona",
        phoneNumber="+20 100 123 4567",
        relationship="Sister",
        source="manual",
    )

    assert contact.phoneNumber == "+201001234567"


def test_contact_rejects_invalid_phone():
    with pytest.raises(ValidationError):
        EmergencyContactInput(
            name="Mona",
            phoneNumber="123",
            source="manual",
        )


def test_event_requires_timezone():
    with pytest.raises(ValidationError):
        EmergencyEventInput(
            eventId="1234567890abcdef",
            trigger="manual_sos",
            outcome="cancelled",
            occurredAt=datetime(2026, 1, 1),
        )


def test_event_accepts_utc_timestamp():
    event = EmergencyEventInput(
        eventId="1234567890abcdef",
        trigger="probable_fall",
        outcome="callAttempted",
        occurredAt=datetime(2026, 1, 1, tzinfo=timezone.utc),
    )

    assert event.occurredAt.tzinfo == timezone.utc
