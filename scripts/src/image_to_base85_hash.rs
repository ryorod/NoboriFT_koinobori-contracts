use std::fs::{self, File};
use std::io::Read;
use std::path::Path;
use walkdir::WalkDir;
use base85;
use sha2::{Sha256, Digest};
use hex::encode as hex_encode;
use serde_json::json;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    // 出力先ディレクトリ
    let out_dir = "out";
    fs::create_dir_all(out_dir)?;

    // Base85エンコード結果とハッシュ結果の保存用配列
    let mut base85_results = Vec::new();
    let mut hash_results = Vec::new();

    // resourcesディレクトリの全てのAVIFファイルを処理
    for entry in WalkDir::new("resources")
        .into_iter()
        .filter_map(|e| e.ok())
        .filter(|e| e.path().extension().map(|s| s == "avif").unwrap_or(false))
    {
        let mut file = File::open(entry.path())?;
        let mut contents = Vec::new();
        file.read_to_end(&mut contents)?;

        // Base85エンコーディング
        let base85_encoded = base85::encode(&contents);
        base85_results.push(base85_encoded.clone());

        // SHA256ハッシュ化
        let mut hasher = Sha256::new();
        hasher.update(base85_encoded.as_bytes());
        let hash_bytes = hasher.finalize();
        let hash_hex = hex_encode(hash_bytes);
        hash_results.push(hash_hex);
    }

    // Base85結果をJSONとして出力
    let base85_json = json!({ "images": base85_results });
    let base85_out_path = Path::new(out_dir).join("image_base85.json");
    fs::write(base85_out_path, serde_json::to_string_pretty(&base85_json)?)?;

    // ハッシュ結果をJSONとして出力
    let hash_json = json!({ "hashes": hash_results });
    let hash_out_path = Path::new(out_dir).join("image_hash.json");
    fs::write(hash_out_path, serde_json::to_string_pretty(&hash_json)?)?;

    Ok(())
}
