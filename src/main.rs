use axum::{
    routing::post,
    extract::State,
    Json, Router,
};
use ed25519_dalek::{SigningKey, Signer};
use serde::{Deserialize, Serialize};
use std::fs::File;
use std::io::Read;
use std::path::PathBuf;
use std::sync::Arc;

// Структура для вхідного JSON від Python-бекенду
#[derive(Deserialize)]
struct SignRequest {
    data: String,
}

// Структура для відповіді
#[derive(Serialize)]
struct SignResponse {
    signature_hex: String,
    public_key_hex: String,
}

// Спільний стан додатка, який зберігає зчитаний ключ
struct AppState {
    signing_key: SigningKey,
}

#[tokio::main]
async fn main() {
    println!("🚀 Ініціалізація локального сервісу безпеки...");

    // Визначаємо шлях до ключа (використовуємо файл з минулого завдання)
    let mut path = std::env::current_dir().unwrap_or_else(|_| PathBuf::from("."));
    path.push(".user_id.key"); // якщо перейменував на .enc, зміни розширення тут

    // Безпечно зчитуємо ключ при старті
    use rand::rngs::OsRng;

    let signing_key = if path.exists() {
        println!("🔒 Завантаження існуючого ключа...");

        load_key_from_file(&path).unwrap()
    } else {
        println!("🔑 Ключ не знайдено. Генеруємо новий...");

        let mut csprng = OsRng;
        let signing_key = SigningKey::generate(&mut csprng);

        std::fs::write(&path, signing_key.to_bytes())
            .expect("Не вдалося зберегти новий ключ");

        signing_key
    };

    // Загортаємо в Arc для безпечного шарингу між потоками Axum
    let shared_state = Arc::new(AppState { signing_key });

    // Описуємо роути
    let app = Router::new()
        .route("/sign", post(sign_handler))
        .with_state(shared_state);

    // Запускаємо тільки на localhost (127.0.0.1), щоб ніхто ззовні мережі не достукався
    let listener = tokio::net::TcpListener::bind("127.0.0.1:3000").await.unwrap();
    println!("📡 Мікросервіс підпису запущено на http://127.0.0.1:3000");

    axum::serve(listener, app).await.unwrap();
}

/// Допоміжна функція для вичитки байтів ключа
fn load_key_from_file(path: &PathBuf) -> Result<SigningKey, String> {
    let mut file = File::open(path).map_err(|e| e.to_string())?;
    let mut key_bytes = [0u8; 32];
    file.read_exact(&mut key_bytes).map_err(|e| e.to_string())?;
    Ok(SigningKey::from_bytes(&key_bytes))
}

/// Хендлер, який приймає текст від Python, підписує його та повертає Hex
async fn sign_handler(
    State(state): State<Arc<AppState>>,
    Json(payload): Json<SignRequest>,
) -> Json<SignResponse> {
    // Перетворюємо вхідний рядок у байти
    let message_bytes = payload.data.as_bytes();

    // Підписуємо приватним ключем Ed25519
    let signature = state.signing_key.sign(message_bytes);

    // Кодуємо підпис та публічний ключ в Hex-формат (зручно для JSON)
    let signature_hex = hex::encode(signature.to_bytes());
    let public_key_hex = hex::encode(state.signing_key.verifying_key().to_bytes());

    Json(SignResponse {
        signature_hex,
        public_key_hex,
    })
}