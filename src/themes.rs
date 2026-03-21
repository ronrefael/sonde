use nu_ansi_term::Color;

#[derive(Debug, Clone, Copy)]
pub struct Palette {
    pub base: Color,
    pub text: Color,
    pub surface: Color,
    pub modules: &'static [(&'static str, (Color, Color))],
}

// -- Catppuccin Mocha (default) --
static CATPPUCCIN_MOCHA_MODULES: &[(&str, (Color, Color))] = &[
    (
        "sonde.model",
        (Color::Rgb(30, 30, 46), Color::Rgb(203, 166, 247)),
    ), // mauve
    (
        "sonde.context_bar",
        (Color::Rgb(30, 30, 46), Color::Rgb(116, 199, 236)),
    ), // sapphire
    (
        "sonde.context_window",
        (Color::Rgb(30, 30, 46), Color::Rgb(116, 199, 236)),
    ),
    (
        "sonde.usage_limits",
        (Color::Rgb(30, 30, 46), Color::Rgb(166, 227, 161)),
    ), // green
    (
        "sonde.promo_badge",
        (Color::Rgb(30, 30, 46), Color::Rgb(250, 179, 135)),
    ), // peach
    (
        "sonde.pacing",
        (Color::Rgb(30, 30, 46), Color::Rgb(249, 226, 175)),
    ), // yellow
    (
        "sonde.session_clock",
        (Color::Rgb(205, 214, 244), Color::Rgb(69, 71, 90)),
    ), // surface1
    (
        "sonde.git_branch",
        (Color::Rgb(30, 30, 46), Color::Rgb(148, 226, 213)),
    ), // teal
    (
        "sonde.active_sessions",
        (Color::Rgb(205, 214, 244), Color::Rgb(69, 71, 90)),
    ),
    (
        "sonde.model_suggestion",
        (Color::Rgb(30, 30, 46), Color::Rgb(249, 226, 175)),
    ),
];

static CATPPUCCIN_MOCHA: Palette = Palette {
    base: Color::Rgb(30, 30, 46),
    text: Color::Rgb(205, 214, 244),
    surface: Color::Rgb(69, 71, 90),
    modules: CATPPUCCIN_MOCHA_MODULES,
};

// -- Terminal -- phosphor green CRT + amber accents
static TERMINAL_MODULES: &[(&str, (Color, Color))] = &[
    (
        "sonde.model",
        (Color::Rgb(5, 5, 10), Color::Rgb(255, 217, 77)),
    ), // amber
    (
        "sonde.context_bar",
        (Color::Rgb(5, 5, 10), Color::Rgb(51, 255, 51)),
    ), // phosphor green
    (
        "sonde.context_window",
        (Color::Rgb(5, 5, 10), Color::Rgb(77, 230, 230)),
    ), // cyan
    (
        "sonde.usage_limits",
        (Color::Rgb(5, 5, 10), Color::Rgb(38, 153, 38)),
    ), // phosphor dim
    (
        "sonde.promo_badge",
        (Color::Rgb(5, 5, 10), Color::Rgb(191, 153, 51)),
    ), // amber dim
    (
        "sonde.pacing",
        (Color::Rgb(5, 5, 10), Color::Rgb(102, 204, 51)),
    ), // lime green
    (
        "sonde.session_clock",
        (Color::Rgb(51, 255, 51), Color::Rgb(10, 15, 10)),
    ), // dark surface + phosphor text
    (
        "sonde.git_branch",
        (Color::Rgb(5, 5, 10), Color::Rgb(31, 115, 31)),
    ), // phosphor faint
    (
        "sonde.active_sessions",
        (Color::Rgb(51, 255, 51), Color::Rgb(15, 20, 15)),
    ), // deeper dark
    (
        "sonde.model_suggestion",
        (Color::Rgb(5, 5, 10), Color::Rgb(255, 38, 38)),
    ), // CRT red
];

static TERMINAL: Palette = Palette {
    base: Color::Rgb(5, 5, 10),
    text: Color::Rgb(51, 255, 51),
    surface: Color::Rgb(10, 15, 10),
    modules: TERMINAL_MODULES,
};

// -- Cyberpunk -- neon cyan + electric accents on deep navy
static CYBERPUNK_MODULES: &[(&str, (Color, Color))] = &[
    (
        "sonde.model",
        (Color::Rgb(11, 12, 16), Color::Rgb(24, 224, 255)),
    ), // neon cyan accent
    (
        "sonde.context_bar",
        (Color::Rgb(11, 12, 16), Color::Rgb(140, 64, 217)),
    ), // electric purple
    (
        "sonde.context_window",
        (Color::Rgb(11, 12, 16), Color::Rgb(51, 115, 230)),
    ), // deep blue
    (
        "sonde.usage_limits",
        (Color::Rgb(11, 12, 16), Color::Rgb(0, 255, 136)),
    ), // neon green
    (
        "sonde.promo_badge",
        (Color::Rgb(11, 12, 16), Color::Rgb(255, 0, 170)),
    ), // hot magenta
    (
        "sonde.pacing",
        (Color::Rgb(11, 12, 16), Color::Rgb(230, 255, 0)),
    ), // electric yellow
    (
        "sonde.session_clock",
        (Color::Rgb(224, 224, 224), Color::Rgb(20, 23, 38)),
    ), // card surface
    (
        "sonde.git_branch",
        (Color::Rgb(11, 12, 16), Color::Rgb(0, 166, 140)),
    ), // teal
    (
        "sonde.active_sessions",
        (Color::Rgb(143, 164, 184), Color::Rgb(11, 12, 16)),
    ), // deep base
    (
        "sonde.model_suggestion",
        (Color::Rgb(11, 12, 16), Color::Rgb(255, 120, 0)),
    ), // neon orange
];

static CYBERPUNK: Palette = Palette {
    base: Color::Rgb(11, 12, 16),
    text: Color::Rgb(224, 224, 224),
    surface: Color::Rgb(20, 23, 38),
    modules: CYBERPUNK_MODULES,
};

// -- Synthwave -- hot pink + retro purple on midnight
static SYNTHWAVE_MODULES: &[(&str, (Color, Color))] = &[
    (
        "sonde.model",
        (Color::Rgb(26, 16, 37), Color::Rgb(255, 41, 117)),
    ), // hot pink accent
    (
        "sonde.context_bar",
        (Color::Rgb(26, 16, 37), Color::Rgb(196, 160, 232)),
    ), // lavender
    (
        "sonde.context_window",
        (Color::Rgb(26, 16, 37), Color::Rgb(140, 80, 200)),
    ), // deep violet
    (
        "sonde.usage_limits",
        (Color::Rgb(26, 16, 37), Color::Rgb(0, 255, 255)),
    ), // neon cyan
    (
        "sonde.promo_badge",
        (Color::Rgb(26, 16, 37), Color::Rgb(255, 150, 50)),
    ), // sunset orange
    (
        "sonde.pacing",
        (Color::Rgb(26, 16, 37), Color::Rgb(255, 230, 77)),
    ), // retro yellow
    (
        "sonde.session_clock",
        (Color::Rgb(240, 230, 255), Color::Rgb(45, 27, 78)),
    ), // card surface
    (
        "sonde.git_branch",
        (Color::Rgb(26, 16, 37), Color::Rgb(77, 130, 255)),
    ), // electric blue
    (
        "sonde.active_sessions",
        (Color::Rgb(196, 160, 232), Color::Rgb(26, 16, 37)),
    ), // deep base
    (
        "sonde.model_suggestion",
        (Color::Rgb(26, 16, 37), Color::Rgb(255, 100, 100)),
    ), // coral red
];

static SYNTHWAVE: Palette = Palette {
    base: Color::Rgb(26, 16, 37),
    text: Color::Rgb(240, 230, 255),
    surface: Color::Rgb(45, 27, 78),
    modules: SYNTHWAVE_MODULES,
};

// -- Solarflare -- fiery orange + solar tones on deep red-black
static SOLARFLARE_MODULES: &[(&str, (Color, Color))] = &[
    (
        "sonde.model",
        (Color::Rgb(13, 2, 8), Color::Rgb(255, 107, 43)),
    ), // fiery orange accent
    (
        "sonde.context_bar",
        (Color::Rgb(13, 2, 8), Color::Rgb(255, 200, 50)),
    ), // solar yellow
    (
        "sonde.context_window",
        (Color::Rgb(13, 2, 8), Color::Rgb(200, 60, 40)),
    ), // ember red
    (
        "sonde.usage_limits",
        (Color::Rgb(13, 2, 8), Color::Rgb(220, 170, 80)),
    ), // molten gold
    (
        "sonde.promo_badge",
        (Color::Rgb(13, 2, 8), Color::Rgb(230, 60, 120)),
    ), // flare pink
    (
        "sonde.pacing",
        (Color::Rgb(13, 2, 8), Color::Rgb(200, 140, 60)),
    ), // copper
    (
        "sonde.session_clock",
        (Color::Rgb(255, 224, 200), Color::Rgb(26, 10, 18)),
    ), // card surface
    (
        "sonde.git_branch",
        (Color::Rgb(13, 2, 8), Color::Rgb(100, 140, 220)),
    ), // corona blue
    (
        "sonde.active_sessions",
        (Color::Rgb(192, 128, 80), Color::Rgb(13, 2, 8)),
    ), // deep base
    (
        "sonde.model_suggestion",
        (Color::Rgb(13, 2, 8), Color::Rgb(255, 240, 200)),
    ), // white-hot
];

static SOLARFLARE: Palette = Palette {
    base: Color::Rgb(13, 2, 8),
    text: Color::Rgb(255, 224, 200),
    surface: Color::Rgb(26, 10, 18),
    modules: SOLARFLARE_MODULES,
};

// -- Sonde Dark (Catppuccin Mocha-inspired) --
static SONDE_DARK_MODULES: &[(&str, (Color, Color))] = &[
    (
        "sonde.project",
        (Color::Rgb(205, 214, 244), Color::Rgb(35, 25, 55)),
    ), // deep purple - dark and striking
    (
        "sonde.git_branch",
        (Color::Rgb(205, 214, 244), Color::Rgb(69, 71, 90)),
    ), // surface1 - light text
    (
        "sonde.model",
        (Color::Rgb(30, 30, 46), Color::Rgb(203, 166, 247)),
    ), // mauve
    (
        "sonde.usage_5h",
        (Color::Rgb(30, 30, 46), Color::Rgb(148, 226, 213)),
    ), // teal
    (
        "sonde.usage_7d",
        (Color::Rgb(30, 30, 46), Color::Rgb(137, 220, 235)),
    ), // sky
    (
        "sonde.pacing",
        (Color::Rgb(30, 30, 46), Color::Rgb(166, 227, 161)),
    ), // green (default/comfortable)
    (
        "sonde.context_bar",
        (Color::Rgb(30, 30, 46), Color::Rgb(116, 199, 236)),
    ), // sapphire
    (
        "sonde.promo_badge",
        (Color::Rgb(30, 30, 46), Color::Rgb(250, 179, 135)),
    ), // peach
    (
        "sonde.usage_limits",
        (Color::Rgb(30, 30, 46), Color::Rgb(148, 226, 213)),
    ), // teal (backward compat)
    (
        "sonde.session_clock",
        (Color::Rgb(205, 214, 244), Color::Rgb(69, 71, 90)),
    ), // surface1
    (
        "sonde.active_sessions",
        (Color::Rgb(205, 214, 244), Color::Rgb(69, 71, 90)),
    ), // surface1
    (
        "sonde.context_window",
        (Color::Rgb(30, 30, 46), Color::Rgb(116, 199, 236)),
    ), // sapphire
    (
        "sonde.model_suggestion",
        (Color::Rgb(30, 30, 46), Color::Rgb(249, 226, 175)),
    ), // yellow
];

static SONDE_DARK: Palette = Palette {
    base: Color::Rgb(30, 30, 46),
    text: Color::Rgb(205, 214, 244),
    surface: Color::Rgb(69, 71, 90),
    modules: SONDE_DARK_MODULES,
};

// -- Sonde Light (Catppuccin Latte-inspired) --
static SONDE_LIGHT_MODULES: &[(&str, (Color, Color))] = &[
    (
        "sonde.project",
        (Color::Rgb(76, 79, 105), Color::Rgb(220, 224, 232)),
    ), // surface0 - dark text
    (
        "sonde.git_branch",
        (Color::Rgb(76, 79, 105), Color::Rgb(188, 192, 204)),
    ), // surface1 - dark text
    (
        "sonde.model",
        (Color::Rgb(239, 241, 245), Color::Rgb(136, 57, 239)),
    ), // mauve
    (
        "sonde.usage_5h",
        (Color::Rgb(239, 241, 245), Color::Rgb(23, 146, 153)),
    ), // teal
    (
        "sonde.usage_7d",
        (Color::Rgb(239, 241, 245), Color::Rgb(4, 165, 229)),
    ), // sky
    (
        "sonde.pacing",
        (Color::Rgb(239, 241, 245), Color::Rgb(64, 160, 43)),
    ), // green
    (
        "sonde.context_bar",
        (Color::Rgb(239, 241, 245), Color::Rgb(32, 159, 181)),
    ), // sapphire
    (
        "sonde.promo_badge",
        (Color::Rgb(239, 241, 245), Color::Rgb(254, 100, 11)),
    ), // peach
    (
        "sonde.usage_limits",
        (Color::Rgb(239, 241, 245), Color::Rgb(23, 146, 153)),
    ), // teal
    (
        "sonde.session_clock",
        (Color::Rgb(76, 79, 105), Color::Rgb(188, 192, 204)),
    ), // surface1
    (
        "sonde.active_sessions",
        (Color::Rgb(76, 79, 105), Color::Rgb(188, 192, 204)),
    ), // surface1
    (
        "sonde.context_window",
        (Color::Rgb(239, 241, 245), Color::Rgb(32, 159, 181)),
    ), // sapphire
    (
        "sonde.model_suggestion",
        (Color::Rgb(239, 241, 245), Color::Rgb(223, 142, 29)),
    ), // yellow
];

static SONDE_LIGHT: Palette = Palette {
    base: Color::Rgb(239, 241, 245),
    text: Color::Rgb(76, 79, 105),
    surface: Color::Rgb(188, 192, 204),
    modules: SONDE_LIGHT_MODULES,
};

pub fn is_light_terminal() -> bool {
    if let Ok(val) = std::env::var("COLORFGBG") {
        if let Some(bg_str) = val.rsplit(';').next() {
            if let Ok(bg) = bg_str.parse::<u8>() {
                return bg > 6;
            }
        }
    }
    false
}

pub fn sonde_model_color(model_name: &str, is_light: bool) -> Color {
    let lower = model_name.to_lowercase();
    if lower.contains("opus") {
        if is_light {
            Color::Rgb(136, 57, 239)
        } else {
            Color::Rgb(203, 166, 247)
        }
    } else if lower.contains("haiku") {
        if is_light {
            Color::Rgb(156, 160, 176)
        } else {
            Color::Rgb(24, 24, 37)
        }
    } else {
        // Sonnet (default)
        if is_light {
            Color::Rgb(180, 135, 35)
        } else {
            Color::Rgb(235, 190, 100)
        }
    }
}

pub fn sonde_pace_color(tier_name: &str, is_light: bool) -> Color {
    match tier_name {
        "Comfortable" => {
            if is_light {
                Color::Rgb(64, 160, 43)
            } else {
                Color::Rgb(166, 227, 161)
            }
        }
        "On Track" => {
            if is_light {
                Color::Rgb(114, 135, 253)
            } else {
                Color::Rgb(180, 190, 254)
            }
        }
        "Elevated" => {
            if is_light {
                Color::Rgb(223, 142, 29)
            } else {
                Color::Rgb(249, 226, 175)
            }
        }
        "Hot" => {
            if is_light {
                Color::Rgb(230, 69, 83)
            } else {
                Color::Rgb(235, 160, 172)
            }
        }
        "Runaway" | "Critical" => {
            if is_light {
                Color::Rgb(210, 15, 57)
            } else {
                Color::Rgb(150, 60, 85)
            }
        }
        _ => {
            if is_light {
                Color::Rgb(64, 160, 43)
            } else {
                Color::Rgb(166, 227, 161)
            }
        }
    }
}

pub const ALL_THEME_NAMES: &[&str] = &[
    "catppuccin-mocha",
    "terminal",
    "cyberpunk",
    "synthwave",
    "solarflare",
    "sonde",
];

pub fn get_palette(name: &str) -> &'static Palette {
    match name {
        "terminal" => &TERMINAL,
        "cyberpunk" => &CYBERPUNK,
        "synthwave" => &SYNTHWAVE,
        "solarflare" => &SOLARFLARE,
        "sonde" => {
            if is_light_terminal() {
                &SONDE_LIGHT
            } else {
                &SONDE_DARK
            }
        }
        _ => &CATPPUCCIN_MOCHA, // default fallback
    }
}

pub fn powerline_colors(palette: &Palette, module_name: &str) -> (Color, Color) {
    for &(name, colors) in palette.modules {
        if name == module_name {
            return colors;
        }
    }
    // Default: light text on surface
    (palette.text, palette.surface)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn get_catppuccin_mocha_default() {
        let p = get_palette("catppuccin-mocha");
        assert!(matches!(p.base, Color::Rgb(30, 30, 46)));
    }

    #[test]
    fn get_terminal() {
        let p = get_palette("terminal");
        assert!(matches!(p.base, Color::Rgb(5, 5, 10)));
    }

    #[test]
    fn nonexistent_falls_back_to_catppuccin() {
        let p = get_palette("nonexistent");
        assert!(matches!(p.base, Color::Rgb(30, 30, 46)));
    }

    #[test]
    fn all_palettes_all_modules_have_valid_colors() {
        let core_modules = [
            "sonde.model",
            "sonde.context_bar",
            "sonde.usage_limits",
            "sonde.pacing",
            "sonde.session_clock",
        ];
        for theme_name in ALL_THEME_NAMES {
            let palette = get_palette(theme_name);
            for module in &core_modules {
                let (fg, bg) = powerline_colors(palette, module);
                // Verify they're RGB colors (not default)
                assert!(
                    matches!(fg, Color::Rgb(_, _, _)),
                    "theme={theme_name} module={module} has non-RGB fg"
                );
                assert!(
                    matches!(bg, Color::Rgb(_, _, _)),
                    "theme={theme_name} module={module} has non-RGB bg"
                );
            }
        }
    }

    #[test]
    fn unknown_module_returns_surface_default() {
        let p = get_palette("terminal");
        let (fg, bg) = powerline_colors(p, "sonde.nonexistent");
        assert_eq!(fg, p.text);
        assert_eq!(bg, p.surface);
    }
}
