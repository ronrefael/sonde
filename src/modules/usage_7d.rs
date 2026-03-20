use crate::ansi;
use crate::config::SondeConfig;
use crate::context::Context;
use crate::usage_api;

pub fn render(_ctx: &Context, cfg: &SondeConfig) -> Option<String> {
    let ucfg = cfg.usage_limits.as_ref();

    if let Some(c) = ucfg {
        if c.enabled == Some(false) {
            return None;
        }
    }

    let ttl = ucfg.and_then(|c| c.ttl);
    let data = match usage_api::fetch_usage(ttl) {
        Some(d) => d,
        None => {
            tracing::warn!("usage_7d: no usage data available");
            return None;
        }
    };

    let sd = match data.seven_day {
        Some(ref w) => w,
        None => {
            tracing::warn!("usage_7d: no seven_day window in usage data");
            return None;
        }
    };

    let pct = match sd.utilization {
        Some(p) => p,
        None => {
            tracing::warn!("usage_7d: no utilization value in seven_day window");
            return None;
        }
    };

    let reset = sd
        .resets_at
        .as_ref()
        .map(|r| format_reset_time_7d(r))
        .unwrap_or_default();

    let fmt = ucfg
        .and_then(|c| c.seven_day_format.as_deref())
        .unwrap_or("7d {pct}% ({reset})");

    let text = fmt
        .replace("{pct}", &format!("{pct:.0}"))
        .replace("{reset}", &reset);

    let style = ucfg.and_then(|c| {
        ansi::threshold_style(
            pct,
            c.warn_threshold,
            c.warn_style.as_deref(),
            c.critical_threshold,
            c.critical_style.as_deref(),
            c.style.as_deref(),
        )
    });

    Some(ansi::styled(&text, style))
}

fn format_reset_time_7d(rfc3339: &str) -> String {
    let reset_dt = match chrono::DateTime::parse_from_rfc3339(rfc3339) {
        Ok(dt) => dt,
        Err(_) => return rfc3339.to_string(),
    };

    let now = chrono::Utc::now();
    let diff = reset_dt.signed_duration_since(now);

    if diff.num_seconds() <= 0 {
        return "now".to_string();
    }

    let total_hours = diff.num_hours();
    let days = total_hours / 24;
    let hours = total_hours % 24;
    let mins = diff.num_minutes() % 60;

    if days > 0 {
        format!("{days}d {hours}h{mins:02}m")
    } else if hours > 0 {
        format!("{hours}h{mins:02}m")
    } else {
        format!("{mins}m")
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn format_7d_shows_days() {
        // A far-future time should show days
        let future = "2099-01-01T00:00:00+00:00";
        let result = format_reset_time_7d(future);
        assert!(result.contains('d'), "Expected days in: {result}");
    }

    #[test]
    fn format_7d_past() {
        let past = "2020-01-01T00:00:00+00:00";
        assert_eq!(format_reset_time_7d(past), "now");
    }

    #[test]
    fn format_7d_invalid() {
        let bad = "not-a-date";
        assert_eq!(format_reset_time_7d(bad), "not-a-date");
    }

    #[test]
    fn format_7d_no_days_when_under_24h() {
        // Use chrono to build a time ~5 hours from now
        let future = chrono::Utc::now() + chrono::Duration::hours(5) + chrono::Duration::minutes(30);
        let rfc = future.to_rfc3339();
        let result = format_reset_time_7d(&rfc);
        assert!(!result.contains('d'), "Should not contain days: {result}");
        assert!(result.contains("5h"), "Expected 5h in: {result}");
    }
}
