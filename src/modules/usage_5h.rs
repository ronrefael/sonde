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
            tracing::warn!("usage_5h: no usage data available");
            return None;
        }
    };

    let fh = match data.five_hour {
        Some(ref w) => w,
        None => {
            tracing::warn!("usage_5h: no five_hour window in usage data");
            return None;
        }
    };

    let pct = match fh.utilization {
        Some(p) => p,
        None => {
            tracing::warn!("usage_5h: no utilization value in five_hour window");
            return None;
        }
    };

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

    let total_hours = diff.num_hours();
    let mins = diff.num_minutes() % 60;

    if total_hours >= 24 {
        let days = total_hours / 24;
        let hours = total_hours % 24;
        format!("{days}d {hours}h{mins:02}m")
    } else if total_hours > 0 {
        format!("{total_hours}h{mins:02}m")
    } else {
        format!("{mins}m")
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn format_reset_countdown() {
        let future = "2099-01-01T00:00:00+00:00";
        let result = format_reset_time(future);
        assert!(result.contains('h') || result.contains('m'));
    }

    #[test]
    fn format_reset_past() {
        let past = "2020-01-01T00:00:00+00:00";
        assert_eq!(format_reset_time(past), "now");
    }

    #[test]
    fn format_reset_invalid() {
        let bad = "not-a-date";
        assert_eq!(format_reset_time(bad), "not-a-date");
    }
}
