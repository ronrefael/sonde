use crate::ansi;
use crate::config::SondeConfig;
use crate::usage_api;

use crate::context::Context;

pub fn render(_ctx: &Context, cfg: &SondeConfig) -> Option<String> {
    let ucfg = cfg.usage_limits.as_ref();

    // Check if disabled
    if let Some(c) = ucfg {
        if c.enabled == Some(false) {
            return None;
        }
    }

    let ttl = ucfg.and_then(|c| c.ttl);
    let data = match usage_api::fetch_usage(ttl) {
        Some(d) => d,
        None => {
            tracing::debug!("usage_limits: no usage data available");
            return None;
        }
    };

    let mut parts = Vec::new();

    if let Some(ref fh) = data.five_hour {
        if let Some(pct) = fh.utilization {
            let reset = fh
                .resets_at
                .as_ref()
                .map(|r| format_reset_time(r))
                .unwrap_or_default();
            let fmt = ucfg
                .and_then(|c| c.five_hour_format.as_deref())
                .unwrap_or("5h {pct}% ({reset})");
            let text = fmt
                .replace("{pct}", &format!("{pct:.0}"))
                .replace("{reset}", &reset);
            parts.push((text, pct));
        }
    }

    if let Some(ref sd) = data.seven_day {
        if let Some(pct) = sd.utilization {
            let reset = sd
                .resets_at
                .as_ref()
                .map(|r| format_reset_time(r))
                .unwrap_or_default();
            let fmt = ucfg
                .and_then(|c| c.seven_day_format.as_deref())
                .unwrap_or("7d {pct}% ({reset})");
            let text = fmt
                .replace("{pct}", &format!("{pct:.0}"))
                .replace("{reset}", &reset);
            parts.push((text, pct));
        }
    }

    if parts.is_empty() {
        return None;
    }

    let separator = ucfg.and_then(|c| c.separator.as_deref()).unwrap_or(" ");

    let styled_parts: Vec<String> = parts
        .iter()
        .map(|(text, pct)| {
            let style = ucfg.and_then(|c| {
                ansi::threshold_style(
                    *pct,
                    c.warn_threshold,
                    c.warn_style.as_deref(),
                    c.critical_threshold,
                    c.critical_style.as_deref(),
                    c.style.as_deref(),
                )
            });
            ansi::styled(text, style)
        })
        .collect();

    Some(styled_parts.join(separator))
}

/// Format a reset timestamp as a human-readable countdown.
fn format_reset_time(rfc3339: &str) -> String {
    let reset_dt = match chrono::DateTime::parse_from_rfc3339(rfc3339) {
        Ok(dt) => dt,
        Err(_) => return rfc3339.to_string(),
    };

    let now = chrono::Utc::now();
    let diff = reset_dt.signed_duration_since(now);

    if diff.num_seconds() <= 0 {
        return "now".to_string();
    }

    let hours = diff.num_hours();
    let mins = diff.num_minutes() % 60;

    if hours > 0 {
        format!("{hours}h{mins:02}m")
    } else {
        format!("{mins}m")
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn format_reset_countdown() {
        // A far-future time should give a countdown
        let future = "2099-01-01T00:00:00+00:00";
        let result = format_reset_time(future);
        assert!(result.contains('h') || result.contains('m'));
    }

    #[test]
    fn format_reset_past() {
        let past = "2020-01-01T00:00:00+00:00";
        assert_eq!(format_reset_time(past), "now");
    }
}
