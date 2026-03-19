use crate::ansi;
use crate::themes;

pub fn run() {
    let mock_segments = [
        ("sonde.model", "Opus"),
        ("sonde.cost", "$1.23"),
        ("sonde.context_bar", "[━━━━╌╌╌╌╌╌] 42%"),
        ("sonde.usage_limits", "5h 42%"),
        ("sonde.pacing", "Elevated 38%"),
    ];

    for theme_name in themes::ALL_THEME_NAMES {
        let palette = themes::get_palette(theme_name);

        println!("\x1b[1m{theme_name}\x1b[0m");

        let segments: Vec<ansi::PowerlineSegment> = mock_segments
            .iter()
            .map(|&(module, text)| {
                let (fg, bg) = themes::powerline_colors(palette, module);
                ansi::PowerlineSegment {
                    text: text.to_string(),
                    fg,
                    bg,
                }
            })
            .collect();

        println!("  {}", ansi::render_powerline(&segments));
        println!();
    }
}

#[cfg(test)]
mod tests {
    use crate::themes;

    #[test]
    fn mock_segments_produce_output_for_each_theme() {
        for theme_name in themes::ALL_THEME_NAMES {
            let palette = themes::get_palette(theme_name);
            let (fg, bg) = themes::powerline_colors(palette, "sonde.model");
            let segments = vec![crate::ansi::PowerlineSegment {
                text: "Test".to_string(),
                fg,
                bg,
            }];
            let output = crate::ansi::render_powerline(&segments);
            assert!(
                !output.is_empty(),
                "theme {theme_name} produced empty output"
            );
        }
    }
}
