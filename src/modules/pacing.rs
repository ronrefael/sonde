use nu_ansi_term::Color;

use crate::ansi;
use crate::config::SondeConfig;
use crate::context::Context;
use crate::history;
use crate::promo;
use crate::usage_api;

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum PaceTier {
    Comfortable,
    OnTrack,
    Elevated,
    Hot,
    Critical,
    Runaway,
}

impl PaceTier {
    pub fn icon(&self) -> &'static str {
        if crate::ansi::has_nerd_fonts() {
            match self {
                PaceTier::Comfortable => "\u{f058}",
                PaceTier::OnTrack => "\u{f00c}",
                PaceTier::Elevated => "\u{f071}",
                PaceTier::Hot => "\u{f06d}",
                PaceTier::Critical => "\u{f06a}",
                PaceTier::Runaway => "\u{f05e}",
            }
        } else {
            match self {
                PaceTier::Comfortable => "\u{25cf}", // ●
                PaceTier::OnTrack => "\u{2713}",     // ✓
                PaceTier::Elevated => "\u{25b2}",    // ▲
                PaceTier::Hot => "\u{25b2}",         // ▲
                PaceTier::Critical => "\u{25c6}",    // ◆
                PaceTier::Runaway => "\u{2715}",     // ✕
            }
        }
    }

    pub fn label(&self) -> &'static str {
        match self {
            PaceTier::Comfortable => "Comfortable",
            PaceTier::OnTrack => "On Track",
            PaceTier::Elevated => "Elevated",
            PaceTier::Hot => "Hot",
            PaceTier::Critical => "Critical",
            PaceTier::Runaway => "Runaway",
        }
    }

    pub fn style(&self) -> &'static str {
        match self {
            PaceTier::Comfortable => "green",
            PaceTier::OnTrack => "blue",
            PaceTier::Elevated => "yellow",
            PaceTier::Hot => "fg:#e0af68",
            PaceTier::Critical => "red",
            PaceTier::Runaway => "bold red",
        }
    }

    /// Powerline background color for this tier.
    pub fn powerline_bg(&self) -> Color {
        match self {
            PaceTier::Comfortable => Color::Rgb(166, 227, 161), // green
            PaceTier::OnTrack => Color::Rgb(137, 180, 250),     // blue
            PaceTier::Elevated => Color::Rgb(249, 226, 175),    // yellow
            PaceTier::Hot => Color::Rgb(250, 179, 135),         // peach
            PaceTier::Critical => Color::Rgb(243, 139, 168),    // red
            PaceTier::Runaway => Color::Rgb(243, 139, 168),     // red
        }
    }
}

pub fn calculate_tier(utilization: f64, promo_active: bool) -> PaceTier {
    // Runaway is absolute, not relative
    if utilization > 90.0 {
        return PaceTier::Runaway;
    }

    let effective = if promo_active {
        utilization / 2.0
    } else {
        utilization
    };

    if effective < 30.0 {
        PaceTier::Comfortable
    } else if effective < 60.0 {
        PaceTier::OnTrack
    } else if effective < 80.0 {
        PaceTier::Elevated
    } else if effective < 100.0 {
        PaceTier::Hot
    } else {
        PaceTier::Critical
    }
}

pub fn current_pacing(cfg: &SondeConfig) -> Option<(PaceTier, f64)> {
    let ttl = cfg.usage_limits.as_ref().and_then(|c| c.ttl);
    let data = usage_api::fetch_usage(ttl)?;
    let utilization = data.five_hour.as_ref().and_then(|w| w.utilization)?;

    let promo_aware = cfg
        .pacing
        .as_ref()
        .map(|c| c.promo_aware.unwrap_or(true))
        .unwrap_or(true);
    let promo_active = if promo_aware {
        let api_url = cfg.promo_badge.as_ref().and_then(|c| c.api_url.as_deref());
        let promo_ttl = cfg.promo_badge.as_ref().and_then(|c| c.poll_interval);
        promo::fetch_promo(api_url, promo_ttl)
            .and_then(|s| s.is_offpeak)
            .unwrap_or(false)
    } else {
        false
    };

    let tier = calculate_tier(utilization, promo_active);
    let remaining = (100.0 - utilization).max(0.0);
    Some((tier, remaining))
}

/// EWMA time constant in seconds. Controls how fast older samples decay.
/// tau=300s gives a half-life of ~3.5 minutes: recent data dominates,
/// but short pauses between requests don't cause wild swings.
const EWMA_TAU: f64 = 300.0;

/// Minimum number of differential rate samples to form a prediction.
/// 3 samples = at least 3 consecutive history entries = ~3 minutes of data.
const MIN_SAMPLES: usize = 3;

/// Maximum coefficient of variation (stddev / mean) before we suppress
/// the prediction. CV >= 2.0 means the rate scatter is too wide to
/// extrapolate reliably.
const MAX_CV: f64 = 2.0;

/// Only consider history entries from the last N seconds for the rate
/// calculation. 900s = 15 minutes. This window is short enough to exclude
/// long idle stretches but long enough to smooth over individual request gaps.
const RATE_WINDOW_SECS: u64 = 900;

/// Minimum utilization (%) before we attempt a prediction. Below this,
/// the percentage is dominated by measurement noise and the user is
/// unlikely to care about hitting the limit.
const MIN_UTILIZATION: f64 = 15.0;

/// Checks if the user has been in a heavy usage pattern (peak 5h util >= 80% on 3+ of last 5 days).
/// If so, returns a lower threshold to show predictions earlier as a proactive warning.
fn heavy_week_threshold(entries: &[history::HistoryEntry]) -> f64 {
    let now_epoch = chrono::Utc::now().timestamp() as u64;
    let five_days_ago = now_epoch.saturating_sub(5 * 86400);

    // Group entries by day and find peak utilization per day
    let mut daily_peaks: std::collections::HashMap<u64, f64> = std::collections::HashMap::new();
    for e in entries {
        if e.timestamp < five_days_ago {
            continue;
        }
        if let Some(util) = e.five_hour_util {
            let day = e.timestamp / 86400;
            let peak = daily_peaks.entry(day).or_insert(0.0);
            if util > *peak {
                *peak = util;
            }
        }
    }

    let heavy_days = daily_peaks.values().filter(|&&p| p >= 80.0).count();
    if heavy_days >= 3 {
        10.0
    } else {
        MIN_UTILIZATION
    }
}

/// Predicts time until utilization hits 100% using recent differential rates
/// from persisted history, EWMA smoothing, and confidence gating.
///
/// Returns formatted string like "~1h 23m" or None if confidence is too low
/// or the user is not projected to hit the limit.
pub fn predict_time_to_limit(utilization: f64, resets_at: Option<&str>) -> Option<String> {
    let entries = history::read_history();
    let threshold = heavy_week_threshold(&entries);
    predict_time_to_limit_with_history_threshold(
        utilization,
        resets_at,
        &entries,
        chrono::Utc::now(),
        threshold,
    )
}

/// Inner implementation that accepts history, clock, and threshold for testability.
#[allow(dead_code)]
pub fn predict_time_to_limit_with_history(
    utilization: f64,
    resets_at: Option<&str>,
    history: &[history::HistoryEntry],
    now: chrono::DateTime<chrono::Utc>,
) -> Option<String> {
    predict_time_to_limit_with_history_threshold(
        utilization,
        resets_at,
        history,
        now,
        MIN_UTILIZATION,
    )
}

fn predict_time_to_limit_with_history_threshold(
    utilization: f64,
    resets_at: Option<&str>,
    history: &[history::HistoryEntry],
    now: chrono::DateTime<chrono::Utc>,
    threshold: f64,
) -> Option<String> {
    // --- Gate 1: minimum utilization (may be lowered during heavy weeks) ---
    if utilization <= threshold {
        return None;
    }

    // --- Gate 2: parse resets_at to determine remaining window time ---
    let resets_at = resets_at?;
    let reset_dt = chrono::DateTime::parse_from_rfc3339(resets_at)
        .ok()?
        .with_timezone(&chrono::Utc);
    let remaining_secs = (reset_dt - now).num_seconds() as f64;
    if remaining_secs <= 0.0 {
        return None;
    }

    // Already at/past limit
    let remaining_util = 100.0 - utilization;
    if remaining_util <= 0.0 {
        return Some("now".to_string());
    }

    // --- Compute window boundaries ---
    let window_secs: f64 = 5.0 * 3600.0;
    let _window_start_epoch =
        (reset_dt - chrono::Duration::seconds(window_secs as i64)).timestamp() as u64;
    let now_epoch = now.timestamp() as u64;
    let rate_cutoff = now_epoch.saturating_sub(RATE_WINDOW_SECS);

    // --- Filter history to recent rate window only ---
    // We intentionally do NOT filter by window_start_epoch so that the user's
    // rate carries across 5h window resets. A user working through a reset
    // should see continuous prediction rather than a 3-5 minute blank gap.
    let relevant: Vec<&history::HistoryEntry> = history
        .iter()
        .filter(|e| e.timestamp >= rate_cutoff)
        .filter(|e| e.five_hour_util.is_some())
        .collect();

    // --- Gate 3: enough samples ---
    // We need at least MIN_SAMPLES + 1 entries to compute MIN_SAMPLES differentials.
    // However, the current live reading is an implicit extra sample at (now, utilization),
    // so we need MIN_SAMPLES entries from history.
    if relevant.len() < MIN_SAMPLES {
        // Fall back to the naive average-rate estimator if we don't have history yet.
        // This handles cold start gracefully.
        return predict_fallback_average(utilization, remaining_secs, window_secs);
    }

    // --- Compute differential rates ---
    // Build the sample series: history entries + current live reading.
    let mut samples: Vec<(f64, f64)> = relevant
        .iter()
        .map(|e| (e.timestamp as f64, e.five_hour_util.unwrap()))
        .collect();
    samples.push((now_epoch as f64, utilization));
    samples.sort_by(|a, b| a.0.partial_cmp(&b.0).unwrap());

    // Session idle timeout: if there's a 30+ minute gap with near-zero
    // utilization change, only use samples after the gap (new session).
    let idle_timeout_secs: f64 = 30.0 * 60.0;
    let mut session_start_idx = 0;
    for i in 1..samples.len() {
        let dt = samples[i].0 - samples[i - 1].0;
        let du = (samples[i].1 - samples[i - 1].1).abs();
        if dt >= idle_timeout_secs && du < 5.0 {
            session_start_idx = i;
        }
    }
    if session_start_idx > 0 {
        samples = samples[session_start_idx..].to_vec();
    }

    // Compute pairwise differential rates (%/s)
    // Skip window reset spikes (utilization drops > 30% between samples)
    let mut diff_rates: Vec<(f64, f64)> = Vec::with_capacity(samples.len() - 1); // (dt, rate)
    for i in 1..samples.len() {
        let dt = samples[i].0 - samples[i - 1].0;
        if dt < 1.0 {
            continue; // skip duplicate timestamps
        }
        let du = samples[i].1 - samples[i - 1].1;
        // A sharp drop (> 30%) indicates a window reset — skip this rate
        if du < -30.0 {
            continue;
        }
        let rate = du / dt;
        diff_rates.push((dt, rate));
    }

    if diff_rates.len() < MIN_SAMPLES {
        return predict_fallback_average(utilization, remaining_secs, window_secs);
    }

    // --- Gate 3b: recent idle detection ---
    // If the last MIN_SAMPLES differential rates are all effectively zero,
    // the user has stopped using the API. Suppress the prediction even if
    // the EWMA still carries residual signal from an earlier burst.
    // "Effectively zero" means less than 0.001 %/s (= 3.6 %/hour, negligible).
    let recent_tail = &diff_rates[diff_rates.len().saturating_sub(MIN_SAMPLES)..];
    let all_idle = recent_tail.iter().all(|&(_, r)| r.abs() < 0.001);
    if all_idle {
        return None;
    }

    // --- EWMA smoothing ---
    // Weight each differential rate by recency using exponential decay.
    // alpha_i = 1 - exp(-dt_i / tau) where dt_i is the time gap of that segment.
    let mut ewma_rate = diff_rates[0].1;
    for &(dt, rate) in diff_rates.iter().skip(1) {
        let alpha = 1.0 - (-dt / EWMA_TAU).exp();
        ewma_rate = alpha * rate + (1.0 - alpha) * ewma_rate;
    }

    // --- Gate 4: rate must be positive ---
    // If EWMA rate <= 0, utilization is flat or decreasing (idle / window sliding).
    if ewma_rate <= 0.0 {
        return None;
    }

    // --- Confidence: coefficient of variation ---
    let rates_only: Vec<f64> = diff_rates.iter().map(|r| r.1).collect();
    let n = rates_only.len() as f64;
    let mean = rates_only.iter().sum::<f64>() / n;

    if mean <= 0.0 {
        return None;
    }

    let variance = rates_only.iter().map(|r| (r - mean).powi(2)).sum::<f64>() / n;
    let cv = variance.sqrt() / mean;

    // --- Gate 5: confidence threshold ---
    if cv >= MAX_CV {
        // Rate is too erratic. Fall back to average if utilization is high enough
        // to warrant some signal, but label it differently.
        if utilization > 70.0 {
            return predict_fallback_average(utilization, remaining_secs, window_secs);
        }
        return None;
    }

    // --- Projection ---
    let secs_to_limit = remaining_util / ewma_rate;

    // Won't reach limit before window resets
    if secs_to_limit > remaining_secs {
        return None;
    }

    // Sanity: negative projection shouldn't happen given gates above, but be safe
    if secs_to_limit <= 0.0 {
        return Some("now".to_string());
    }

    Some(format_time(secs_to_limit))
}

/// Naive fallback: average rate over elapsed window. Used during cold start
/// (no history samples yet) or when confidence is low but utilization is high.
fn predict_fallback_average(
    utilization: f64,
    remaining_secs: f64,
    window_secs: f64,
) -> Option<String> {
    let elapsed_secs = window_secs - remaining_secs;
    if elapsed_secs <= 60.0 {
        return None; // need at least 1 minute of data
    }

    let rate = utilization / elapsed_secs;
    if rate <= 0.0 {
        return None;
    }

    let remaining_util = 100.0 - utilization;
    if remaining_util <= 0.0 {
        return Some("now".to_string());
    }

    let secs_to_limit = remaining_util / rate;
    if secs_to_limit > remaining_secs {
        return None;
    }

    Some(format!("{} avg", format_time(secs_to_limit)))
}

/// Format seconds into a human-readable "~Xh Ym" or "~Ym" string.
fn format_time(secs: f64) -> String {
    let hours = (secs / 3600.0) as u64;
    let mins = ((secs % 3600.0) / 60.0) as u64;

    if hours > 0 {
        format!("~{hours}h {mins:02}m")
    } else {
        format!("~{mins}m")
    }
}

pub fn render(_ctx: &Context, cfg: &SondeConfig) -> Option<String> {
    let pcfg = cfg.pacing.as_ref();

    if let Some(c) = pcfg {
        if c.enabled == Some(false) {
            return None;
        }
    }

    let (tier, _remaining) = current_pacing(cfg)?;

    let show_prediction = pcfg.and_then(|c| c.show_prediction).unwrap_or(true);

    let mut text = format!("{} {}", tier.icon(), tier.label());

    if show_prediction {
        let ttl = cfg.usage_limits.as_ref().and_then(|c| c.ttl);
        if let Some(data) = usage_api::fetch_usage(ttl) {
            let util = data.five_hour.as_ref().and_then(|w| w.utilization);
            let resets = data.five_hour.as_ref().and_then(|w| w.resets_at.as_deref());
            if let (Some(u), Some(r)) = (util, resets) {
                if let Some(prediction) = predict_time_to_limit(u, Some(r)) {
                    text.push_str(&format!(" ({prediction})"));
                }
            }
        }
    }

    Some(ansi::styled(&text, Some(tier.style())))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::history::HistoryEntry;

    // --- Tier tests (unchanged) ---

    #[test]
    fn tier_comfortable() {
        assert_eq!(calculate_tier(20.0, false), PaceTier::Comfortable);
    }

    #[test]
    fn tier_on_track() {
        assert_eq!(calculate_tier(45.0, false), PaceTier::OnTrack);
    }

    #[test]
    fn tier_elevated() {
        assert_eq!(calculate_tier(70.0, false), PaceTier::Elevated);
    }

    #[test]
    fn tier_hot() {
        assert_eq!(calculate_tier(85.0, false), PaceTier::Hot);
    }

    #[test]
    fn tier_runaway() {
        assert_eq!(calculate_tier(95.0, false), PaceTier::Runaway);
    }

    #[test]
    fn promo_halves_effective() {
        assert_eq!(calculate_tier(70.0, true), PaceTier::OnTrack);
        assert_eq!(calculate_tier(70.0, false), PaceTier::Elevated);
    }

    #[test]
    fn runaway_ignores_promo() {
        assert_eq!(calculate_tier(95.0, true), PaceTier::Runaway);
    }

    // --- Prediction tests ---

    /// Helper: build a history of steadily increasing utilization samples.
    fn steady_history(
        now_epoch: u64,
        count: usize,
        interval_secs: u64,
        start_util: f64,
        rate_per_sec: f64,
    ) -> Vec<HistoryEntry> {
        (0..count)
            .map(|i| {
                let t = now_epoch - (count as u64 - 1 - i as u64) * interval_secs;
                let u = start_util + rate_per_sec * (i as f64 * interval_secs as f64);
                HistoryEntry {
                    timestamp: t,
                    five_hour_util: Some(u),
                    seven_day_util: None,
                    session_cost: None,
                }
            })
            .collect()
    }

    #[test]
    fn predict_low_util_returns_none() {
        let now = chrono::Utc::now();
        let reset = (now + chrono::Duration::hours(3)).to_rfc3339();
        let result = predict_time_to_limit_with_history(5.0, Some(&reset), &[], now);
        assert_eq!(result, None);
    }

    #[test]
    fn predict_no_reset_returns_none() {
        let now = chrono::Utc::now();
        let result = predict_time_to_limit_with_history(50.0, None, &[], now);
        assert_eq!(result, None);
    }

    #[test]
    fn predict_steady_rate_returns_estimate() {
        // Simulate: 10 samples over 10 minutes, utilization climbing from 30% to 70%
        // at a steady rate of 4% per minute = 0.0667%/s.
        // Current utilization: 70%. Remaining: 30%.
        // At 0.0667%/s, time to limit = 30 / 0.0667 = 450s = 7.5 minutes.
        let now = chrono::Utc::now();
        let now_epoch = now.timestamp() as u64;
        let reset = (now + chrono::Duration::hours(2)).to_rfc3339();

        let history = steady_history(now_epoch, 10, 60, 30.0, 0.0667);

        let result = predict_time_to_limit_with_history(70.0, Some(&reset), &history, now);
        assert!(result.is_some(), "Expected prediction for steady rate");
        let text = result.unwrap();
        assert!(text.starts_with('~'), "Expected tilde prefix, got: {text}");
        // Should be roughly "~7m" (450s / 60 = 7.5, truncated to 7)
        assert!(text.contains('m'), "Expected minutes in: {text}");
    }

    #[test]
    fn predict_idle_returns_none() {
        // All history samples have the same utilization (flat = idle).
        // Rate should be ~0, prediction should be None.
        let now = chrono::Utc::now();
        let now_epoch = now.timestamp() as u64;
        let reset = (now + chrono::Duration::hours(2)).to_rfc3339();

        let history = steady_history(now_epoch, 10, 60, 30.0, 0.0); // rate = 0

        let result = predict_time_to_limit_with_history(30.0, Some(&reset), &history, now);
        assert!(result.is_none(), "Idle user should not get a prediction");
    }

    #[test]
    fn predict_burst_then_idle_is_suppressed() {
        // First 3 samples: burst from 20% to 50% (10%/min).
        // Next 7 samples: flat at 50% (idle).
        // The differential rates are [high, high, 0, 0, 0, 0, 0, 0, 0].
        // CV should be very high, suppressing the prediction.
        let now = chrono::Utc::now();
        let now_epoch = now.timestamp() as u64;

        let mut history: Vec<HistoryEntry> = Vec::new();
        // Burst: 3 entries, 60s apart, climbing 10%/min
        for i in 0..3 {
            history.push(HistoryEntry {
                timestamp: now_epoch - 600 + i * 60,
                five_hour_util: Some(20.0 + 10.0 * i as f64),
                seven_day_util: None,
                session_cost: None,
            });
        }
        // Idle: 7 entries, 60s apart, flat at 50%
        for i in 3..10 {
            history.push(HistoryEntry {
                timestamp: now_epoch - 600 + i * 60,
                five_hour_util: Some(50.0),
                seven_day_util: None,
                session_cost: None,
            });
        }

        let reset = (now + chrono::Duration::hours(2)).to_rfc3339();
        let result = predict_time_to_limit_with_history(50.0, Some(&reset), &history, now);
        // Should be None: EWMA rate is low (dominated by recent idle),
        // and/or CV is too high from the burst-then-idle pattern.
        // Either way, the prediction is not shown.
        assert!(
            result.is_none(),
            "Burst-then-idle should suppress prediction"
        );
    }

    #[test]
    fn predict_wont_reach_limit_returns_none() {
        // Slow steady rate: 0.001%/s over 10 minutes.
        // Current util: 20%. At 0.001%/s, time to 100% = 80000s = 22h.
        // Remaining window: 2h = 7200s. Won't reach. Should return None.
        let now = chrono::Utc::now();
        let now_epoch = now.timestamp() as u64;
        let reset = (now + chrono::Duration::hours(2)).to_rfc3339();

        let history = steady_history(now_epoch, 10, 60, 19.4, 0.001);

        let result = predict_time_to_limit_with_history(20.0, Some(&reset), &history, now);
        assert!(result.is_none(), "Slow rate should not project limit");
    }

    #[test]
    fn predict_at_limit_returns_now() {
        let now = chrono::Utc::now();
        let reset = (now + chrono::Duration::hours(2)).to_rfc3339();
        let result = predict_time_to_limit_with_history(100.0, Some(&reset), &[], now);
        assert_eq!(result, Some("now".to_string()));
    }

    #[test]
    fn predict_cold_start_uses_fallback() {
        // No history entries, but utilization > MIN_UTILIZATION.
        // Should fall back to the average rate estimator.
        // 70% used with 2h remaining → elapsed = 3h.
        // Average rate = 70/10800 = 0.00648%/s.
        // Time to limit = 30/0.00648 = 4629s ≈ 1h17m. Should return something.
        let now = chrono::Utc::now();
        let reset = (now + chrono::Duration::hours(2)).to_rfc3339();
        let result = predict_time_to_limit_with_history(70.0, Some(&reset), &[], now);
        assert!(result.is_some(), "Cold start should use fallback");
        let text = result.unwrap();
        assert!(
            text.contains("avg"),
            "Fallback should be labeled 'avg': {text}"
        );
    }

    #[test]
    fn predict_ignores_samples_from_previous_window() {
        // All history samples are from before the current 5h window started.
        // Should fall back to average rate.
        let now = chrono::Utc::now();
        let now_epoch = now.timestamp() as u64;
        let reset = (now + chrono::Duration::hours(2)).to_rfc3339();

        // Window started 3h ago. These samples are from 6h ago — before window.
        let history: Vec<HistoryEntry> = (0..10)
            .map(|i| HistoryEntry {
                timestamp: now_epoch - 6 * 3600 + i * 60,
                five_hour_util: Some(30.0 + i as f64),
                seven_day_util: None,
                session_cost: None,
            })
            .collect();

        let result = predict_time_to_limit_with_history(70.0, Some(&reset), &history, now);
        // Should fall back to average since no in-window history
        if let Some(text) = &result {
            assert!(
                text.contains("avg"),
                "Old-window data should trigger fallback: {text}"
            );
        }
    }

    #[test]
    fn format_time_hours_and_minutes() {
        assert_eq!(format_time(3900.0), "~1h 05m");
        assert_eq!(format_time(7200.0), "~2h 00m");
    }

    #[test]
    fn format_time_minutes_only() {
        assert_eq!(format_time(300.0), "~5m");
        assert_eq!(format_time(59.0), "~0m");
    }
}
