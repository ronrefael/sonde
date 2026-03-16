use serde::{Deserialize, Serialize};
use std::path::{Path, PathBuf};
use std::time::{SystemTime, UNIX_EPOCH};

#[derive(Debug, Serialize, Deserialize)]
pub struct CacheEnvelope<T> {
    pub data: T,
    pub created_at: u64,
    pub expires_at: u64,
    /// When the 5-hour window resets (epoch seconds). Cache is invalid after this.
    pub five_hour_resets_at: Option<u64>,
}

fn now_epoch() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs()
}

/// Get the cache directory path.
pub fn cache_dir() -> Option<PathBuf> {
    dirs::cache_dir().map(|d| d.join("sonde"))
}

/// Get a cache file path by name.
pub fn cache_path(name: &str) -> Option<PathBuf> {
    cache_dir().map(|d| d.join(format!("{name}.json")))
}

/// Write data to cache with a TTL in seconds.
pub fn write_cache<T: Serialize>(
    path: &Path,
    data: &T,
    ttl_secs: u64,
    five_hour_resets_at: Option<u64>,
) -> bool {
    let now = now_epoch();
    let data_value = match serde_json::to_value(data) {
        Ok(v) => v,
        Err(e) => {
            tracing::warn!("Failed to serialize data for cache: {e}");
            return false;
        }
    };

    let envelope = CacheEnvelope {
        data: data_value,
        created_at: now,
        expires_at: now + ttl_secs,
        five_hour_resets_at,
    };

    // Ensure parent directory exists
    if let Some(parent) = path.parent() {
        if let Err(e) = std::fs::create_dir_all(parent) {
            tracing::warn!("Failed to create cache dir {}: {e}", parent.display());
            return false;
        }
    }

    let json = match serde_json::to_string(&envelope) {
        Ok(j) => j,
        Err(e) => {
            tracing::warn!("Failed to serialize cache: {e}");
            return false;
        }
    };

    match std::fs::write(path, json) {
        Ok(_) => true,
        Err(e) => {
            tracing::warn!("Failed to write cache {}: {e}", path.display());
            false
        }
    }
}

/// Read data from cache. Returns None if expired or missing.
/// If allow_stale is true, returns data even if TTL has expired
/// (but still invalidates on window reset).
pub fn read_cache<T: for<'de> Deserialize<'de>>(path: &Path, allow_stale: bool) -> Option<T> {
    let content = match std::fs::read_to_string(path) {
        Ok(c) => c,
        Err(_) => return None,
    };

    let envelope: CacheEnvelope<serde_json::Value> = match serde_json::from_str(&content) {
        Ok(e) => e,
        Err(e) => {
            tracing::debug!("Failed to parse cache {}: {e}", path.display());
            return None;
        }
    };

    let now = now_epoch();

    // Window reset: prefer stale data over nothing
    if let Some(resets_at) = envelope.five_hour_resets_at {
        if now >= resets_at && !allow_stale {
            tracing::debug!("Cache invalidated by window reset");
            return None;
        }
    }

    // Check TTL unless stale is allowed
    if !allow_stale && now >= envelope.expires_at {
        tracing::debug!("Cache expired");
        return None;
    }

    match serde_json::from_value(envelope.data) {
        Ok(d) => Some(d),
        Err(e) => {
            tracing::debug!("Failed to deserialize cached data: {e}");
            None
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn write_and_read_cache() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("test.json");

        let data = serde_json::json!({"utilization": 42.0});
        assert!(write_cache(&path, &data, 60, None));

        let read: Option<serde_json::Value> = read_cache(&path, false);
        assert!(read.is_some());
        assert_eq!(read.unwrap()["utilization"], 42.0);
    }

    #[test]
    fn expired_cache_returns_none() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("test.json");

        let data = serde_json::json!({"value": 1});
        // TTL of 0 = already expired
        assert!(write_cache(&path, &data, 0, None));

        // Strict read should fail
        let read: Option<serde_json::Value> = read_cache(&path, false);
        assert!(read.is_none());

        // Stale read should succeed
        let stale: Option<serde_json::Value> = read_cache(&path, true);
        assert!(stale.is_some());
    }
}
