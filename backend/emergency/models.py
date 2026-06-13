from datetime import datetime, timezone
from enum import Enum
from typing import Annotated

import phonenumbers
from pydantic import BaseModel, BeforeValidator, Field, field_validator


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


def normalize_phone(value: str) -> str:
    try:
        parsed = phonenumbers.parse(value, None)
    except phonenumbers.NumberParseException as exc:
        raise ValueError("Phone number must include a valid country code.") from exc
    if not phonenumbers.is_valid_number(parsed):
        raise ValueError("Phone number is invalid.")
    return phonenumbers.format_number(
        parsed,
        phonenumbers.PhoneNumberFormat.E164,
    )


E164Phone = Annotated[str, BeforeValidator(normalize_phone)]


class ContactSource(str, Enum):
    manual = "manual"
    device_contact = "device_contact"


class EmergencyTrigger(str, Enum):
    manual_sos = "manual_sos"
    probable_fall = "probable_fall"


class EmergencyOutcome(str, Enum):
    detected = "detected"
    cancelled = "cancelled"
    call_attempted = "callAttempted"
    call_failed = "callFailed"


class EmergencyContactInput(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    phoneNumber: E164Phone
    relationship: str = Field(default="", max_length=80)
    source: ContactSource
    verified: bool = True

    @field_validator("name", "relationship")
    @classmethod
    def trim_text(cls, value: str) -> str:
        return value.strip()


class EmergencyContactResponse(EmergencyContactInput):
    updatedAt: datetime


class UserProfileResponse(BaseModel):
    userId: str
    onboardingComplete: bool
    monitoringEnabled: bool
    createdAt: datetime
    updatedAt: datetime


class SensorSummary(BaseModel):
    peakAcceleration: float | None = Field(default=None, ge=0, le=200)
    peakRotation: float | None = Field(default=None, ge=0, le=100)
    inactivitySeconds: float | None = Field(default=None, ge=0, le=60)


class LocationSummary(BaseModel):
    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, le=180)
    accuracyMeters: float = Field(ge=0, le=100000)


class EmergencyEventInput(BaseModel):
    eventId: str = Field(min_length=16, max_length=64)
    trigger: EmergencyTrigger
    outcome: EmergencyOutcome
    occurredAt: datetime
    sensorSummary: SensorSummary | None = None
    location: LocationSummary | None = None

    @field_validator("occurredAt")
    @classmethod
    def require_timezone(cls, value: datetime) -> datetime:
        if value.tzinfo is None:
            raise ValueError("occurredAt must include a timezone.")
        return value.astimezone(timezone.utc)


class EmergencyEventResponse(EmergencyEventInput):
    createdAt: datetime


class EmergencyEventPage(BaseModel):
    items: list[EmergencyEventResponse]
    page: int
    limit: int
    total: int
