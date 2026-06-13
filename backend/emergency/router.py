from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from pymongo.asynchronous.database import AsyncDatabase

from .auth import AuthenticatedUser, require_user
from .database import get_database
from .models import (
    EmergencyContactInput,
    EmergencyContactResponse,
    EmergencyEventInput,
    EmergencyEventPage,
    EmergencyEventResponse,
    UserProfileResponse,
    utc_now,
)

router = APIRouter(prefix="/api/v1", tags=["emergency"])


def _public_document(document: dict[str, Any]) -> dict[str, Any]:
    return {key: value for key, value in document.items() if key != "_id"}


@router.post("/users/bootstrap", response_model=UserProfileResponse)
async def bootstrap_user(
    user: AuthenticatedUser = Depends(require_user),
    database: AsyncDatabase = Depends(get_database),
):
    now = utc_now()
    await database.user_profiles.update_one(
        {"ownerId": user.user_id},
        {
            "$set": {"updatedAt": now},
            "$setOnInsert": {
                "ownerId": user.user_id,
                "onboardingComplete": False,
                "monitoringEnabled": False,
                "createdAt": now,
            },
        },
        upsert=True,
    )
    document = await database.user_profiles.find_one({"ownerId": user.user_id})
    return _profile_response(document)


@router.get("/me", response_model=UserProfileResponse)
async def get_profile(
    user: AuthenticatedUser = Depends(require_user),
    database: AsyncDatabase = Depends(get_database),
):
    document = await database.user_profiles.find_one({"ownerId": user.user_id})
    if document is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"code": "profile_not_found", "message": "Profile not found."},
        )
    return _profile_response(document)


@router.put(
    "/me/emergency-contact",
    response_model=EmergencyContactResponse,
)
async def put_emergency_contact(
    contact: EmergencyContactInput,
    user: AuthenticatedUser = Depends(require_user),
    database: AsyncDatabase = Depends(get_database),
):
    now = utc_now()
    document = {
        "ownerId": user.user_id,
        **contact.model_dump(),
        "updatedAt": now,
    }
    await database.emergency_contacts.replace_one(
        {"ownerId": user.user_id},
        document,
        upsert=True,
    )
    await database.user_profiles.update_one(
        {"ownerId": user.user_id},
        {
            "$set": {"onboardingComplete": True, "updatedAt": now},
            "$setOnInsert": {
                "ownerId": user.user_id,
                "monitoringEnabled": False,
                "createdAt": now,
            },
        },
        upsert=True,
    )
    return EmergencyContactResponse(**_public_document(document))


@router.get(
    "/me/emergency-contact",
    response_model=EmergencyContactResponse,
)
async def get_emergency_contact(
    user: AuthenticatedUser = Depends(require_user),
    database: AsyncDatabase = Depends(get_database),
):
    document = await database.emergency_contacts.find_one(
        {"ownerId": user.user_id}
    )
    if document is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"code": "contact_not_found", "message": "Contact not found."},
        )
    return EmergencyContactResponse(**_public_document(document))


@router.delete(
    "/me/emergency-contact",
    status_code=status.HTTP_204_NO_CONTENT,
)
async def delete_emergency_contact(
    user: AuthenticatedUser = Depends(require_user),
    database: AsyncDatabase = Depends(get_database),
):
    await database.emergency_contacts.delete_one({"ownerId": user.user_id})
    await database.user_profiles.update_one(
        {"ownerId": user.user_id},
        {"$set": {"onboardingComplete": False, "updatedAt": utc_now()}},
    )
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.post(
    "/me/emergency-events",
    response_model=EmergencyEventResponse,
)
async def create_emergency_event(
    event: EmergencyEventInput,
    user: AuthenticatedUser = Depends(require_user),
    database: AsyncDatabase = Depends(get_database),
):
    now = utc_now()
    document = {
        "ownerId": user.user_id,
        **event.model_dump(),
        "createdAt": now,
    }
    await database.emergency_events.update_one(
        {"eventId": event.eventId, "ownerId": user.user_id},
        {"$setOnInsert": document},
        upsert=True,
    )
    stored = await database.emergency_events.find_one(
        {"eventId": event.eventId, "ownerId": user.user_id}
    )
    return EmergencyEventResponse(**_public_document(stored))


@router.get("/me/emergency-events", response_model=EmergencyEventPage)
async def list_emergency_events(
    page: int = Query(default=1, ge=1),
    limit: int = Query(default=20, ge=1, le=100),
    user: AuthenticatedUser = Depends(require_user),
    database: AsyncDatabase = Depends(get_database),
):
    query = {"ownerId": user.user_id}
    cursor = (
        database.emergency_events.find(query)
        .sort("occurredAt", -1)
        .skip((page - 1) * limit)
        .limit(limit)
    )
    items = [
        EmergencyEventResponse(**_public_document(document))
        async for document in cursor
    ]
    total = await database.emergency_events.count_documents(query)
    return EmergencyEventPage(
        items=items,
        page=page,
        limit=limit,
        total=total,
    )


def _profile_response(document: dict[str, Any]) -> UserProfileResponse:
    return UserProfileResponse(
        userId=document["ownerId"],
        onboardingComplete=document.get("onboardingComplete", False),
        monitoringEnabled=document.get("monitoringEnabled", False),
        createdAt=document["createdAt"],
        updatedAt=document["updatedAt"],
    )
