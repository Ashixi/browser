pub mod crypto;
pub mod deserialization;
pub mod erasure;
pub mod storage; // Наш новий модуль!

use serde::{Deserialize, Serialize};
use std::fs;

#[derive(Debug, Serialize, Deserialize, PartialEq)]
struct BrowserHistory {
    urls: Vec<String>,
    last_cleared: u64,
}

fn main() {
    let file_path = "history.enc";
    let recovered_file_path = "history_recovered.enc";
    let secret_key: [u8; 32] = [42; 32]; // Ключ для AES-256

    let history = BrowserHistory {
        urls: vec![
            "github.com".to_string(),
            "rust-lang.org".to_string(),
            "dou.ua".to_string(),
        ],
        last_cleared: 1672531200,
    };
    println!("1. Початкові дані:\n   {:#?}\n", history);

    storage::save_to_encrypted_file(file_path, &history, &secret_key)
        .expect("Помилка збереження у файл");
    println!("2. Дані серіалізовано, зашифровано та збережено у файл '{}'.", file_path);

    let encrypted_bytes = fs::read(file_path).expect("Помилка читання файлу");
    println!("   Розмір зашифрованого файлу: {} байт\n", encrypted_bytes.len());

    let data_shards = 4;
    let parity_shards = 2;
    let original_size = encrypted_bytes.len();
    
    let mut chunks = erasure::split_data("browser_data", &encrypted_bytes, data_shards, parity_shards)
        .expect("Помилка розбиття на частини");
    println!(
        "3. Дані розбито на {} частин ({} даних + {} парності)\n",
        chunks.len(), data_shards, parity_shards
    );

    let lost_chunk = chunks.remove(1);
    println!("4. Симуляція втрати даних!");
    println!("   Видалено частину з індексом: {}", lost_chunk.chunk_index);
    println!("   Залишилось частин для відновлення: {}\n", chunks.len());

    // 6. Запускаємо код відновлення, щоб зібрати зашифровані байти назад
    let reassembled_bytes = deserialization::decode_and_reassemble(
        chunks, data_shards, parity_shards, original_size
    ).expect("Помилка відновлення даних Ріда-Соломона");
    println!("5. Алгоритм Ріда-Соломона успішно відновив втрачений пакет.");
    println!("   Розмір відновлених даних: {} байт\n", reassembled_bytes.len());

    // Переконуємось, що відновлені байти ідентичні до тих, що були у початковому файлі
    assert_eq!(encrypted_bytes, reassembled_bytes, "Відновлені дані пошкоджені!");

    // 7. Записуємо відновлені зашифровані байти у новий файл
    fs::write(recovered_file_path, &reassembled_bytes)
        .expect("Помилка запису відновленого файлу");
    println!("6. Відновлені зашифровані байти збережено у '{}'.\n", recovered_file_path);

    // 8. Використовуємо модуль storage для читання нового файлу: розшифровуємо і десеріалізуємо назад
    let recovered_history: BrowserHistory = storage::load_from_encrypted_file(recovered_file_path, &secret_key)
        .expect("Помилка розшифрування та десеріалізації");

    println!("7. Розшифрована структура з відновленого файлу:\n   {:#?}\n", recovered_history);
    
    // Фінальна перевірка
    assert_eq!(history, recovered_history);
    println!("Успіх!");
}