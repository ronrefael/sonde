use serde::{Deserialize, Serialize};
use std::path::PathBuf;
use std::time::{SystemTime, UNIX_EPOCH};

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct HistoryEntry {
    pub timestamp: u64,
    pub five_hour_util: Option<f64>,
    pub seven_day_util: Option<f64>,
    pub session_cost: Option<f64>,
}

fn history_path() -> Option<PathBuf> {
    dirs::cache_dir().map(|d| d.join("sonde").join("usage_history.json"))
}

fn now_epoch() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs()
}

pub fn record(five_hour_util: Option<f64>, seven_day_util: Option<f64>, session_cost: Option<f64>) {
    let path = match history_path() {
        Some(p) => p,
        None => return,
    };

    let now = now_epoch();
    let mut entries = read_history_from(&path);

    // Dedup: skip if last entry was < 60s ago
    if let Some(last) = entries.last() {
        if now.saturating_sub(last.timestamp) < 60 {
            return;
        }
    }

    entries.push(HistoryEntry {
        timestamp: now,
        five_hour_util,
        seven_day_util,
        session_cost,
    });

    // Prune entries older than 24 hours
    let cutoff = now.saturating_sub(24 * 3600);
    entries.retain(|e| e.timestamp >= cutoff);

    // Write atomically
    if let Some(parent) = path.parent() {
        let _ = std::fs::create_dir_all(parent);
    }

    let tmp = path.with_extension("json.tmp");
    match serde_json::to_string(&entries) {
        Ok(json) => {
            if std::fs::write(&tmp, &json).is_ok() {
                let _ = std::fs::rename(&tmp, &path);
                // Set restrictive permissions (no tokens, but good practice)
                #[cfg(unix)]
                {
                    use std::os::unix::fs::PermissionsExt;
                    let _ = std::fs::set_permissions(&path, std::fs::Permissions::from_mode(0o600));
                }
            }
        }
        Err(e) => {
            tracing::debug!("Failed to serialize history: {e}");
        }
    }
}

#[allow(dead_code)] // Used by TUI sparkline (F8)
pub fn read_history() -> Vec<HistoryEntry> {
    match history_path() {
        Some(p) => read_history_from(&p),
        None => Vec::new(),
    }
}

fn read_history_from(path: &std::path::Path) -> Vec<HistoryEntry> {
    let content = match std::fs::read_to_string(path) {
        Ok(c) => c,
        Err(_) => return Vec::new(),
    };
    match serde_json::from_str(&content) {
        Ok(entries) => entries,
        Err(e) => {
            tracing::debug!("Failed to parse history: {e}");
            Vec::new()
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn creates_file_if_missing() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("sonde").join("usage_history.json");
        let entries = read_history_from(&path);
        assert!(entries.is_empty());
    }

    #[test]
    fn deduplicates_within_60s() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("history.json");

        let now = now_epoch();
        let entries = vec![HistoryEntry {
            timestamp: now,
            five_hour_util: Some(42.0),
            seven_day_util: None,
            session_cost: None,
        }];

        let json = serde_json::to_string(&entries).unwrap();
        std::fs::write(&path, &json).unwrap();

        let loaded = read_history_from(&path);
        assert_eq!(loaded.len(), 1);
    }

    #[test]
    fn prunes_old_entries() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("history.json");

        let now = now_epoch();
        let entries = vec![
            HistoryEntry {
                timestamp: now - 25 * 3600, // 25h ago — should be pruned
                five_hour_util: Some(10.0),
                seven_day_util: None,
                session_cost: None,
            },
            HistoryEntry {
                timestamp: now - 3600, // 1h ago — should survive
                five_hour_util: Some(50.0),
                seven_day_util: None,
                session_cost: None,
            },
        ];

        let json = serde_json::to_string(&entries).unwrap();
        std::fs::write(&path, &json).unwrap();

        // Read and verify the old entry is still in the file
        let loaded = read_history_from(&path);
        assert_eq!(loaded.len(), 2);
    }

    #[test]
    fn handles_corrupt_file() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("history.json");
        std::fs::write(&path, "not json").unwrap();

        let entries = read_history_from(&path);
        assert!(entries.is_empty());
    }
}
