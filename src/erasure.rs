use reed_solomon_erasure::galois_8::ReedSolomon;

const DATA_SHARDS: usize = 3;
const PARITY_SHARDS: usize = 1;
const TOTAL_SHARDS: usize = DATA_SHARDS + PARITY_SHARDS; // Разом 4 частини

pub fn split_data(data: &[u8]) -> Result<(Vec<Vec<u8>>, usize), String> {
    let rs = ReedSolomon::new(DATA_SHARDS, PARITY_SHARDS)
        .map_err(|e| e.to_string())?;
        
    // Вираховуємо розмір одного фрагмента
    let shard_size = (data.len() + DATA_SHARDS - 1) / DATA_SHARDS;
    let mut shards = vec![vec![0u8; shard_size]; TOTAL_SHARDS];

    // Заповнюємо перші 3 частини реальними даними
    for i in 0..DATA_SHARDS {
        let start = i * shard_size;
        let end = std::cmp::min(start + shard_size, data.len());
        let slice_len = end - start;

        if slice_len > 0 {
            shards[i][..slice_len].copy_from_slice(&data[start..end]);
        }
    }
    
    // Генеруємо 4-ту частину (parity) для відновлення
    rs.encode(&mut shards).map_err(|e| e.to_string())?;
    
    Ok((shards, data.len()))
}

pub fn restore_data(mut shards: Vec<Option<Vec<u8>>>, original_len: usize) -> Result<Vec<u8>, String> {
    let rs = ReedSolomon::new(DATA_SHARDS, PARITY_SHARDS)
        .map_err(|e| e.to_string())?;
        
    // Математично відновлюємо втрачені частини (ті, що None)
    rs.reconstruct(&mut shards).map_err(|e| e.to_string())?;

    let mut result = Vec::with_capacity(original_len);
    for i in 0..DATA_SHARDS {
        if let Some(shard) = &shards[i] {
            result.extend_from_slice(shard);
        }
    }
    
    // Відрізаємо зайві нулі, які додалися при вирівнюванні розміру фрагментів
    result.truncate(original_len);
    Ok(result)
}