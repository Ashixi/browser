use crate::erasure::FileChunk;
use reed_solomon_erasure::galois_8::ReedSolomon;
/// Логіка валідації, зворотного збирання та відновлення втрачених пакетів.
pub fn decode_and_reassemble(
    mut received_chunks: Vec<FileChunk>,
    data_shards_count: usize,
    parity_shards_count: usize,
    original_file_size: usize,
) -> Result<Vec<u8>, &'static str> {

    // 1. Сортуємо масив шматків за порядковим номером
    received_chunks.sort_by_key(|chunk| chunk.chunk_index);

    let total_shards = data_shards_count + parity_shards_count;

    // 2. Масив для передачі в reed-solomon-erasure 
    // (Some - валідний шматок, None - втрачений або пошкоджений)
    let mut shards_for_reconstruction: Vec<Option<Vec<u8>>> = vec![None; total_shards];

    // 3. Валідація цілісності кожної частини через хеш-суму
    for chunk in received_chunks.into_iter() {
        if chunk.chunk_index >= total_shards {
            continue; // Ігноруємо шматки з некоректним індексом
        }

        let expected_hash = FileChunk::calculate_hash(&chunk.data);

        // Якщо хеш збігається, кладемо шматок на потрібну позицію
        if chunk.chunk_hash == expected_hash {
            shards_for_reconstruction[chunk.chunk_index] = Some(chunk.data);
        } else {
            eprintln!("Попередження: хеш не збігається, пошкоджено шматок #{}", chunk.chunk_index);
            // Шматок пошкоджено. Залишаємо позицію як None, алгоритм RS спробує його відновити
        }
    }

    // 4. Зворотний процес алгоритму Ріда-Соломона
    let rs = ReedSolomon::new(data_shards_count, parity_shards_count)
        .map_err(|_| "Помилка: неможливо ініціалізувати алгоритм Ріда-Соломона")?;

    // Реконструюємо втрачені пакети (якщо їхня кількість не перевищує parity_shards)
    rs.reconstruct(&mut shards_for_reconstruction)
        .map_err(|_| "Помилка: занадто багато втрачених або пошкоджених шматків для відновлення")?;

    // 5. Зшивання даних назад у початковий файл
    let mut decoded_file = Vec::with_capacity(original_file_size);
    for i in 0..data_shards_count {
        if let Some(valid_data_shard) = &shards_for_reconstruction[i] {
            decoded_file.extend_from_slice(valid_data_shard);
        }
    }

    // Оскільки алгоритм Ріда-Соломона вимагає однакового розміру шматків,
    // при розбитті файл міг бути доповнений нулями. Відкидаємо зайвий padding.
    decoded_file.truncate(original_file_size);

    Ok(decoded_file)
}