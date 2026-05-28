use reed_solomon_erasure::galois_8::ReedSolomon;
use sha2::{Sha256, Digest};

#[derive(Debug, Clone)]
pub struct FileChunk {
    pub file_id: String,
    pub chunk_index: usize,
    pub chunk_hash: Vec<u8>,
    pub original_len: usize,
    pub data: Vec<u8>,
}

impl FileChunk {
    // Допоміжний метод для швидкого підрахунку SHA-256
    pub fn calculate_hash(data: &[u8]) -> Vec<u8> {
        let mut hasher = Sha256::new();
        hasher.update(data);
        let result = hasher.finalize();

        // Використовуємо стандартний синтаксис зрізу Rust [..]. 
        // Це примусово перетворює масив у &[u8], у якого ТОЧНО є .to_vec()
        result[..].to_vec()
    }
}

pub fn split_data(file_id: &str, data: &[u8], data_shards: usize, parity_shards: usize) -> Result<Vec<FileChunk>, String> {
    let rs = ReedSolomon::new(data_shards, parity_shards).map_err(|e| e.to_string())?;
    let total_shards = data_shards + parity_shards;

    let shard_size = (data.len() + data_shards - 1) / data_shards;
    let mut shards = vec![vec![0u8; shard_size]; total_shards];

    for i in 0..data_shards {
        let start = i * shard_size;
        let end = std::cmp::min(start + shard_size, data.len());
        let slice_len = end - start;
        if slice_len > 0 {
            shards[i][..slice_len].copy_from_slice(&data[start..end]);
        }
    }

    rs.encode(&mut shards).map_err(|e| e.to_string())?;

    let original_len = data.len();

    // FIX: Convert the shards explicitly to recover standard vector behaviors
    let owned_shards: Vec<Vec<u8>> = shards;

    let network_chunks = owned_shards
        .into_iter()
        .enumerate()
        .map(|(index, shard_data)| {
            let hash = FileChunk::calculate_hash(&shard_data);
            FileChunk {
                file_id: file_id.to_string(),
                chunk_index: index,
                chunk_hash: hash,
                original_len,
                data: shard_data,
            }
        })
        .collect();

    Ok(network_chunks)
}