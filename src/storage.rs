use serde::{de::DeserializeOwned, Serialize};
use std::fs;
use std::path::Path;

// Імпортуємо ваші функції з модуля crypto
use crate::crypto::{decrypt_data, encrypt_data};

/// Зберігає структуру даних у зашифрований файл (.enc) у форматі JSON
pub fn save_to_encrypted_file<T: Serialize, P: AsRef<Path>>(
    file_path: P,
    data: &T,
    key_bytes: &[u8; 32],
) -> Result<(), String> {
    // 1. Серіалізація структури у JSON-байти
    let json_bytes = serde_json::to_vec(data)
        .map_err(|e| format!("Помилка серіалізації JSON: {}", e))?;

    // 2. Шифрування байтів (використовує вашу реалізацію aes-gcm)
    let encrypted_data = encrypt_data(&json_bytes, key_bytes)?;

    // 3. Запис зашифрованих байтів на диск
    fs::write(file_path, encrypted_data)
        .map_err(|e| format!("Помилка запису файлу: {}", e))?;

    Ok(())
}

/// Зчитує зашифрований файл, дешифрує його та десеріалізує з JSON у структуру даних
pub fn load_from_encrypted_file<T: DeserializeOwned, P: AsRef<Path>>(
    file_path: P,
    key_bytes: &[u8; 32],
) -> Result<T, String> {
    // 1. Зчитування зашифрованих байтів з диска
    let encrypted_data = fs::read(file_path)
        .map_err(|e| format!("Помилка читання файлу: {}", e))?;

    // 2. Дешифрування
    let decrypted_bytes = decrypt_data(&encrypted_data, key_bytes)?;

    // 3. Десеріалізація з JSON назад у структуру
    let data: T = serde_json::from_slice(&decrypted_bytes)
        .map_err(|e| format!("Помилка десеріалізації JSON: {}", e))?;

    Ok(data)
}