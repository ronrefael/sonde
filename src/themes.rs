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

// -- Dracula --
static DRACULA_MODULES: &[(&str, (Color, Color))] = &[
    (
        "sonde.model",
        (Color::Rgb(40, 42, 54), Color::Rgb(189, 147, 249)),
    ), // purple
    (
        "sonde.context_bar",
        (Color::Rgb(40, 42, 54), Color::Rgb(80, 250, 123)),
    ), // green
    (
        "sonde.context_window",
        (Color::Rgb(40, 42, 54), Color::Rgb(80, 250, 123)),
    ),
    (
        "sonde.usage_limits",
        (Color::Rgb(40, 42, 54), Color::Rgb(241, 250, 140)),
    ), // yellow
    (
        "sonde.promo_badge",
        (Color::Rgb(40, 42, 54), Color::Rgb(255, 184, 108)),
    ), // orange
    (
        "sonde.pacing",
        (Color::Rgb(40, 42, 54), Color::Rgb(255, 121, 198)),
    ), // pink
    (
        "sonde.session_clock",
        (Color::Rgb(248, 248, 242), Color::Rgb(68, 71, 90)),
    ), // comment
    (
        "sonde.git_branch",
        (Color::Rgb(40, 42, 54), Color::Rgb(139, 233, 253)),
    ), // cyan
    (
        "sonde.active_sessions",
        (Color::Rgb(248, 248, 242), Color::Rgb(68, 71, 90)),
    ),
    (
        "sonde.model_suggestion",
        (Color::Rgb(40, 42, 54), Color::Rgb(241, 250, 140)),
    ),
];

static DRACULA: Palette = Palette {
    base: Color::Rgb(40, 42, 54),
    text: Color::Rgb(248, 248, 242),
    surface: Color::Rgb(68, 71, 90),
    modules: DRACULA_MODULES,
};

// -- Tokyo Night --
static TOKYO_NIGHT_MODULES: &[(&str, (Color, Color))] = &[
    (
        "sonde.model",
        (Color::Rgb(26, 27, 38), Color::Rgb(187, 154, 247)),
    ), // purple
    (
        "sonde.context_bar",
        (Color::Rgb(26, 27, 38), Color::Rgb(115, 218, 202)),
    ), // teal
    (
        "sonde.context_window",
        (Color::Rgb(26, 27, 38), Color::Rgb(115, 218, 202)),
    ),
    (
        "sonde.usage_limits",
        (Color::Rgb(26, 27, 38), Color::Rgb(158, 206, 106)),
    ), // green
    (
        "sonde.promo_badge",
        (Color::Rgb(26, 27, 38), Color::Rgb(255, 158, 100)),
    ), // orange
    (
        "sonde.pacing",
        (Color::Rgb(26, 27, 38), Color::Rgb(224, 175, 104)),
    ), // yellow
    (
        "sonde.session_clock",
        (Color::Rgb(169, 177, 214), Color::Rgb(52, 59, 88)),
    ), // dark3
    (
        "sonde.git_branch",
        (Color::Rgb(26, 27, 38), Color::Rgb(115, 218, 202)),
    ), // teal
    (
        "sonde.active_sessions",
        (Color::Rgb(169, 177, 214), Color::Rgb(52, 59, 88)),
    ),
    (
        "sonde.model_suggestion",
        (Color::Rgb(26, 27, 38), Color::Rgb(224, 175, 104)),
    ),
];

static TOKYO_NIGHT: Palette = Palette {
    base: Color::Rgb(26, 27, 38),
    text: Color::Rgb(169, 177, 214),
    surface: Color::Rgb(52, 59, 88),
    modules: TOKYO_NIGHT_MODULES,
};

// -- Nord --
static NORD_MODULES: &[(&str, (Color, Color))] = &[
    (
        "sonde.model",
        (Color::Rgb(46, 52, 64), Color::Rgb(180, 142, 173)),
    ), // purple
    (
        "sonde.context_bar",
        (Color::Rgb(46, 52, 64), Color::Rgb(136, 192, 208)),
    ), // frost cyan
    (
        "sonde.context_window",
        (Color::Rgb(46, 52, 64), Color::Rgb(136, 192, 208)),
    ),
    (
        "sonde.usage_limits",
        (Color::Rgb(46, 52, 64), Color::Rgb(163, 190, 140)),
    ), // green
    (
        "sonde.promo_badge",
        (Color::Rgb(46, 52, 64), Color::Rgb(208, 135, 112)),
    ), // orange
    (
        "sonde.pacing",
        (Color::Rgb(46, 52, 64), Color::Rgb(235, 203, 139)),
    ), // yellow
    (
        "sonde.session_clock",
        (Color::Rgb(216, 222, 233), Color::Rgb(67, 76, 94)),
    ), // polar3
    (
        "sonde.git_branch",
        (Color::Rgb(46, 52, 64), Color::Rgb(143, 188, 187)),
    ), // frost teal
    (
        "sonde.active_sessions",
        (Color::Rgb(216, 222, 233), Color::Rgb(67, 76, 94)),
    ),
    (
        "sonde.model_suggestion",
        (Color::Rgb(46, 52, 64), Color::Rgb(235, 203, 139)),
    ),
];

static NORD: Palette = Palette {
    base: Color::Rgb(46, 52, 64),
    text: Color::Rgb(216, 222, 233),
    surface: Color::Rgb(67, 76, 94),
    modules: NORD_MODULES,
};

// -- Gruvbox --
static GRUVBOX_MODULES: &[(&str, (Color, Color))] = &[
    (
        "sonde.model",
        (Color::Rgb(40, 40, 40), Color::Rgb(211, 134, 155)),
    ), // purple
    (
        "sonde.context_bar",
        (Color::Rgb(40, 40, 40), Color::Rgb(142, 192, 124)),
    ), // green
    (
        "sonde.context_window",
        (Color::Rgb(40, 40, 40), Color::Rgb(142, 192, 124)),
    ),
    (
        "sonde.usage_limits",
        (Color::Rgb(40, 40, 40), Color::Rgb(184, 187, 38)),
    ), // yellow-green
    (
        "sonde.promo_badge",
        (Color::Rgb(40, 40, 40), Color::Rgb(254, 128, 25)),
    ), // orange
    (
        "sonde.pacing",
        (Color::Rgb(40, 40, 40), Color::Rgb(250, 189, 47)),
    ), // yellow
    (
        "sonde.session_clock",
        (Color::Rgb(235, 219, 178), Color::Rgb(80, 73, 69)),
    ), // bg2
    (
        "sonde.git_branch",
        (Color::Rgb(40, 40, 40), Color::Rgb(142, 192, 124)),
    ), // green
    (
        "sonde.active_sessions",
        (Color::Rgb(235, 219, 178), Color::Rgb(80, 73, 69)),
    ),
    (
        "sonde.model_suggestion",
        (Color::Rgb(40, 40, 40), Color::Rgb(250, 189, 47)),
    ),
];

static GRUVBOX: Palette = Palette {
    base: Color::Rgb(40, 40, 40),
    text: Color::Rgb(235, 219, 178),
    surface: Color::Rgb(80, 73, 69),
    modules: GRUVBOX_MODULES,
};

// -- Solarized Dark --
static SOLARIZED_DARK_MODULES: &[(&str, (Color, Color))] = &[
    (
        "sonde.model",
        (Color::Rgb(0, 43, 54), Color::Rgb(108, 113, 196)),
    ), // violet
    (
        "sonde.context_bar",
        (Color::Rgb(0, 43, 54), Color::Rgb(42, 161, 152)),
    ), // cyan
    (
        "sonde.context_window",
        (Color::Rgb(0, 43, 54), Color::Rgb(42, 161, 152)),
    ),
    (
        "sonde.usage_limits",
        (Color::Rgb(0, 43, 54), Color::Rgb(133, 153, 0)),
    ), // green
    (
        "sonde.promo_badge",
        (Color::Rgb(0, 43, 54), Color::Rgb(203, 75, 22)),
    ), // orange
    (
        "sonde.pacing",
        (Color::Rgb(0, 43, 54), Color::Rgb(181, 137, 0)),
    ), // yellow
    (
        "sonde.session_clock",
        (Color::Rgb(147, 161, 161), Color::Rgb(7, 54, 66)),
    ), // base02
    (
        "sonde.git_branch",
        (Color::Rgb(0, 43, 54), Color::Rgb(42, 161, 152)),
    ), // cyan
    (
        "sonde.active_sessions",
        (Color::Rgb(147, 161, 161), Color::Rgb(7, 54, 66)),
    ),
    (
        "sonde.model_suggestion",
        (Color::Rgb(0, 43, 54), Color::Rgb(181, 137, 0)),
    ),
];

static SOLARIZED_DARK: Palette = Palette {
    base: Color::Rgb(0, 43, 54),
    text: Color::Rgb(147, 161, 161),
    surface: Color::Rgb(7, 54, 66),
    modules: SOLARIZED_DARK_MODULES,
};

pub const ALL_THEME_NAMES: &[&str] = &[
    "catppuccin-mocha",
    "dracula",
    "tokyo-night",
    "nord",
    "gruvbox",
    "solarized-dark",
];

pub fn get_palette(name: &str) -> &'static Palette {
    match name {
        "dracula" => &DRACULA,
        "tokyo-night" => &TOKYO_NIGHT,
        "nord" => &NORD,
        "gruvbox" => &GRUVBOX,
        "solarized-dark" => &SOLARIZED_DARK,
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
    fn get_dracula() {
        let p = get_palette("dracula");
        assert!(matches!(p.base, Color::Rgb(40, 42, 54)));
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
        let p = get_palette("dracula");
        let (fg, bg) = powerline_colors(p, "sonde.nonexistent");
        assert_eq!(fg, p.text);
        assert_eq!(bg, p.surface);
    }
}
