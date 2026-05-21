from pydantic import BaseModel
from typing import List

class PrivacySettings(BaseModel):
    block_trackers: bool = True
    require_tx_confirmation: bool = True
    share_analytics: bool = False

class ConnectedDApp(BaseModel):
    dapp_id: str
    name: str
    permissions: List[str] # наприклад: ["read_address", "sign_tx"]

class UserProfile(BaseModel):
    public_key: str # Ed25519 публічний ключ (hex)
    privacy: PrivacySettings = PrivacySettings()
    dapps: List[ConnectedDApp] = []