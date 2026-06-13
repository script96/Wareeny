import os
from dataclasses import dataclass


@dataclass(frozen=True)
class EmergencySettings:
    mongodb_uri: str
    mongodb_database: str
    clerk_issuer: str
    clerk_jwks_url: str
    clerk_authorized_parties: tuple[str, ...]

    @classmethod
    def from_environment(cls) -> "EmergencySettings":
        issuer = os.getenv("CLERK_ISSUER", "").rstrip("/")
        jwks_url = os.getenv(
            "CLERK_JWKS_URL",
            f"{issuer}/.well-known/jwks.json" if issuer else "",
        )
        parties = tuple(
            value.strip()
            for value in os.getenv("CLERK_AUTHORIZED_PARTIES", "").split(",")
            if value.strip()
        )
        return cls(
            mongodb_uri=os.getenv("MONGODB_URI", ""),
            mongodb_database=os.getenv("MONGODB_DATABASE", "wareeny"),
            clerk_issuer=issuer,
            clerk_jwks_url=jwks_url,
            clerk_authorized_parties=parties,
        )


settings = EmergencySettings.from_environment()
