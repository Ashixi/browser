import pytest
import pytest_asyncio
import httpx

BASE_URL = "http://localhost:8000"

@pytest.fixture(scope="session")
def anyio_backend():
    """Вказуємо anyio використовувати asyncio як бекенд."""
    return "asyncio"

@pytest_asyncio.fixture(scope="function")
async def api_client():
    """Фікстура для асинхронного HTTP-клієнта."""
    async with httpx.AsyncClient(base_url=BASE_URL, timeout=5.0) as client:
        yield client

@pytest.fixture
def mock_identity_data():
    """Тестові дані для ідентифікації (імітація фронтенду)."""
    return {
        "public_key": "ed25519_mock_public_key_77777777777777777777",
        "profile_metadata": {
            "username": "alice_crypto",
            "bio": "Decentralized content creator"
        }
    }
