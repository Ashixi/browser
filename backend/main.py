from fastapi import FastAPI, Header, HTTPException, Depends, status
from typing import Optional, List
import re

from backend.shemas import UserProfile, ConnectedDApp, PrivacySettings

app = FastAPI(
    title="User Profile Management API",
    description="Mock API for user profile and connected dApps with session-key authorization.",
    version="0.1.0",
)

mock_profile = UserProfile(
    public_key="a1b2c3d4e5f60123456789abcdefabcdef1234567890abcdefabcdef12345678",
    privacy=PrivacySettings(
        block_trackers=True,
        require_tx_confirmation=True,
        share_analytics=False,
    ),
    dapps=[
        ConnectedDApp(
            dapp_id="dapp-1",
            name="Sample Swap",
            permissions=["read_address", "sign_tx"],
        )
    ],
)


def extract_session_key(
    authorization: Optional[str] = Header(None, alias="Authorization"),
    x_user_key: Optional[str] = Header(None, alias="X-User-Key"),
) -> str:
    session_key = None
    if x_user_key:
        session_key = x_user_key.strip()
    elif authorization:
        if authorization.lower().startswith("bearer "):
            session_key = authorization[7:].strip()
        else:
            session_key = authorization.strip()

    if not session_key:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Mock authorization required: provide X-User-Key or Authorization header.",
        )

    if not re.fullmatch(r"[0-9a-fA-F]{32,}", session_key):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Mock authorization key must be a hex session/public key.",
        )

    return session_key


def authorize_user(session_key: str = Depends(extract_session_key)) -> UserProfile:
    if session_key != mock_profile.public_key:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Mock session not recognized for the current profile.",
        )
    return mock_profile


@app.get("/health")
def health_check() -> dict:
    return {"status": "ok"}


@app.get("/profile", response_model=UserProfile)
def get_user_profile(profile: UserProfile = Depends(authorize_user)) -> UserProfile:
    return profile


@app.put("/profile", response_model=UserProfile)
def update_user_profile(
    updated_profile: UserProfile,
    profile: UserProfile = Depends(authorize_user),
) -> UserProfile:
    profile.public_key = updated_profile.public_key
    profile.privacy = updated_profile.privacy
    profile.dapps = updated_profile.dapps
    return profile


@app.patch("/profile/privacy", response_model=PrivacySettings)
def update_privacy_settings(
    privacy: PrivacySettings,
    profile: UserProfile = Depends(authorize_user),
) -> PrivacySettings:
    profile.privacy = privacy
    return profile.privacy


@app.get("/profile/dapps", response_model=List[ConnectedDApp])
def list_connected_dapps(profile: UserProfile = Depends(authorize_user)) -> List[ConnectedDApp]:
    return profile.dapps


@app.post("/profile/dapps", response_model=ConnectedDApp, status_code=status.HTTP_201_CREATED)
def add_connected_dapp(
    dapp: ConnectedDApp,
    profile: UserProfile = Depends(authorize_user),
) -> ConnectedDApp:
    existing = next((item for item in profile.dapps if item.dapp_id == dapp.dapp_id), None)
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"dApp with id '{dapp.dapp_id}' is already connected.",
        )
    profile.dapps.append(dapp)
    return dapp


@app.delete("/profile/dapps/{dapp_id}", status_code=status.HTTP_204_NO_CONTENT)
def remove_connected_dapp(
    dapp_id: str,
    profile: UserProfile = Depends(authorize_user),
) -> None:
    profile.dapps = [item for item in profile.dapps if item.dapp_id != dapp_id]
    return None
