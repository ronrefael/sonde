use std::io::BufRead;
use std::path::PathBuf;
use std::time::SystemTime;

const MAX_CONTEXT_TOKENS: u64 = 200_000;
const ACTIVE_MINUTES: u64 = 60;
const MAX_PROJECTS: usize = 10;

#[derive(Debug, Clone)]
pub struct ScannedSession {
    pub id: String,
    pub project_name: String,
    #[allow(dead_code)]
    pub project_path: String,
    pub used_tokens: u64,
    pub free_tokens: u64,
    pub percentage: u8,
    pub last_modified: SystemTime,
}

struct SessionFile {
    path: PathBuf,
    mod_time: SystemTime,
    project: String,
}

pub fn scan_sessions() -> Vec<ScannedSession> {
    let home = match dirs::home_dir() {
        Some(h) => h,
        None => return Vec::new(),
    };

    let claude_dir = home.join(".claude").join("projects");
    let project_dirs = match std::fs::read_dir(&claude_dir) {
        Ok(d) => d,
        Err(_) => return Vec::new(),
    };

    let cutoff = SystemTime::now()
        .checked_sub(std::time::Duration::from_secs(ACTIVE_MINUTES * 60))
        .unwrap_or(SystemTime::UNIX_EPOCH);

    let mut all_sessions: Vec<SessionFile> = Vec::new();

    for entry in project_dirs.flatten() {
        let ft = match entry.file_type() {
            Ok(ft) => ft,
            Err(_) => continue,
        };
        if !ft.is_dir() {
            continue;
        }

        let project_name = entry.file_name().to_string_lossy().to_string();
        let project_path = entry.path();

        let files = match std::fs::read_dir(&project_path) {
            Ok(f) => f,
            Err(_) => continue,
        };

        for file_entry in files.flatten() {
            let name = file_entry.file_name();
            let name_str = name.to_string_lossy();

            if !name_str.ends_with(".jsonl") || name_str.starts_with("agent-") {
                continue;
            }

            let metadata = match file_entry.metadata() {
                Ok(m) => m,
                Err(_) => continue,
            };

            let mod_time = metadata.modified().unwrap_or(SystemTime::UNIX_EPOCH);
            if mod_time < cutoff {
                continue;
            }

            all_sessions.push(SessionFile {
                path: file_entry.path(),
                mod_time,
                project: project_name.clone(),
            });
        }
    }

    // Sort by modification time (newest first)
    all_sessions.sort_by(|a, b| b.mod_time.cmp(&a.mod_time));

    // Keep only the most recent session per project
    let mut seen = std::collections::HashSet::new();
    all_sessions.retain(|sf| seen.insert(sf.project.clone()));

    // Limit to MAX_PROJECTS
    all_sessions.truncate(MAX_PROJECTS);

    // Parse each session
    let mut sessions = Vec::new();
    for sf in &all_sessions {
        if let Some(session) = parse_session(&sf.path, &sf.project, sf.mod_time) {
            sessions.push(session);
        }
    }

    sessions
}

fn parse_session(
    path: &PathBuf,
    project_dir: &str,
    mod_time: SystemTime,
) -> Option<ScannedSession> {
    let file = match std::fs::File::open(path) {
        Ok(f) => f,
        Err(_) => return None,
    };

    // Use a 10MB buffer like the Go reference implementation
    let reader = std::io::BufReader::with_capacity(10 * 1024 * 1024, file);

    let mut last_usage: Option<(u64, u64, u64)> = None; // (input, cache_read, cache_creation)
    let mut cwd: Option<String> = None;

    for line in reader.lines() {
        let line = match line {
            Ok(l) => l,
            Err(_) => continue,
        };

        let val: serde_json::Value = match serde_json::from_str(&line) {
            Ok(v) => v,
            Err(_) => continue,
        };

        // Capture cwd from the first message that has it
        if cwd.is_none() {
            if let Some(c) = val.get("cwd").and_then(|v| v.as_str()) {
                if !c.is_empty() {
                    cwd = Some(c.to_string());
                }
            }
        }

        // Look for assistant messages with usage data
        if val.get("type").and_then(|v| v.as_str()) == Some("assistant") {
            if let Some(usage) = val.get("message").and_then(|m| m.get("usage")) {
                let input = usage
                    .get("input_tokens")
                    .and_then(|v| v.as_u64())
                    .unwrap_or(0);
                let cache_read = usage
                    .get("cache_read_input_tokens")
                    .and_then(|v| v.as_u64())
                    .unwrap_or(0);
                let cache_creation = usage
                    .get("cache_creation_input_tokens")
                    .and_then(|v| v.as_u64())
                    .unwrap_or(0);
                last_usage = Some((input, cache_read, cache_creation));
            }
        }
    }

    let (input, cache_read, cache_creation) = last_usage?;

    let total_used = input + cache_read + cache_creation;
    let percentage = ((total_used * 100) / MAX_CONTEXT_TOKENS).min(100) as u8;
    let free_tokens = MAX_CONTEXT_TOKENS.saturating_sub(total_used);

    // Use basename of cwd if available, otherwise fall back to directory name
    let project_name = cwd
        .as_deref()
        .and_then(|c| std::path::Path::new(c).file_name())
        .map(|n| n.to_string_lossy().to_string())
        .unwrap_or_else(|| project_dir.to_string());

    let id = path
        .file_name()
        .map(|n| n.to_string_lossy().to_string())
        .unwrap_or_default();

    Some(ScannedSession {
        id,
        project_name,
        project_path: project_dir.to_string(),
        used_tokens: total_used,
        free_tokens,
        percentage,
        last_modified: mod_time,
    })
}
