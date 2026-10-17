// SWARM Overlay — Lucille-controlled gaming overlay.
//
// Modes, chosen by the first CLI arg (or SWARM_OVERLAY_MODE):
//   dashboard  — full-page HUD: now-playing (GamingAgent /api/media/*),
//                Lucille chat (/api/lucille/chat), and a walkthrough/web
//                launcher. The embedded HTML is baked into this binary via
//                include_str!, not served over HTTP — confirmed 2026-09-20
//                that GamingAgent's originGate rejects a real HTTP Origin
//                that isn't on its allowlist, while a bare/no Origin (what a
//                baked-in page's fetch() calls send) passes through as a
//                trusted native client. Do not switch this to loading the
//                HTML over a local HTTP server without also updating
//                GamingAgent's allowed-origins list.
//   browser    — widget: a single resizable/movable window pointed at a URL
//                (second CLI arg, or SWARM_OVERLAY_URL), for walkthroughs
//                and general web browsing over the game.
//   video      — same as browser, but smaller and pre-positioned at the
//                screen's right edge by default (still resizable/movable
//                afterward) — for a walkthrough video playing alongside the
//                game rather than a full browsing session.
//
// Dashboard and browser/video windows are created with with_transparent so
// holding Super fades the page to near-invisible via a CSS class toggled
// through evaluate_script, letting the game show through underneath —
// released, it returns to normal. This only affects the page's own visual
// opacity, not input routing (clicks still go to this window while faded).
//
// Window placement/always-on-top/undecorated behavior otherwise is handled
// by labwc's windowRules (see 40-iso-profile/.../labwc/rc.xml), matched by
// title, the same way the Lucille Slint panel already floats — not by
// anything in here.

use std::env;
use std::process::Command;

use tao::dpi::LogicalSize;
use tao::event::{Event, WindowEvent};
use tao::event_loop::{ControlFlow, EventLoop};
use tao::window::WindowBuilder;
use wry::WebViewBuilder;

const DASHBOARD_HTML: &str = include_str!("../assets/dashboard.html");
const DEFAULT_BROWSER_URL: &str = "https://www.google.com";

enum Mode {
    Dashboard,
    Browser(String),
    Video(String),
}

fn resolve_mode() -> Mode {
    let mut args = env::args().skip(1);
    let mode_arg = args.next().or_else(|| env::var("SWARM_OVERLAY_MODE").ok());

    match mode_arg.as_deref() {
        Some("browser") => {
            let url = args
                .next()
                .or_else(|| env::var("SWARM_OVERLAY_URL").ok())
                .unwrap_or_else(|| DEFAULT_BROWSER_URL.to_string());
            Mode::Browser(url)
        }
        Some("video") => {
            let url = args
                .next()
                .or_else(|| env::var("SWARM_OVERLAY_URL").ok())
                .unwrap_or_else(|| DEFAULT_BROWSER_URL.to_string());
            Mode::Video(url)
        }
        _ => Mode::Dashboard,
    }
}

/// Candidate binary names for an app IPC action, tried in order — covers
/// distro packaging differences (e.g. Chrome ships as google-chrome-stable
/// on Arch, google-chrome elsewhere; Opera GX has no official Arch package,
/// AUR-only, so opera-gx is tried but not guaranteed present).
fn launch_app(name: &str) {
    let candidates: &[&str] = match name {
        "chrome" => &["google-chrome-stable", "google-chrome", "chromium"],
        "opera-gx" => &["opera-gx", "opera"],
        other => {
            eprintln!("[swarm-overlay] unknown app for open_app action: {other}");
            return;
        }
    };
    for bin in candidates {
        match Command::new(bin).spawn() {
            Ok(_) => {
                eprintln!("[swarm-overlay] launched {bin} for open_app:{name}");
                return;
            }
            Err(e) => eprintln!("[swarm-overlay] {bin} not available ({e}), trying next"),
        }
    }
    eprintln!("[swarm-overlay] no candidate binary found for open_app:{name}");
}

/// Spawns a new swarm-overlay browser-mode window pointed at url. Re-execs
/// this same binary rather than opening the URL in-process, so the new
/// window is independently movable/resizable/closable from the caller.
fn open_browser_widget(url: &str) {
    let exe = env::current_exe().unwrap_or_else(|_| "swarm-overlay".into());
    match Command::new(exe).arg("browser").arg(url).spawn() {
        Ok(_) => eprintln!("[swarm-overlay] opened browser widget: {url}"),
        Err(e) => eprintln!("[swarm-overlay] failed to open browser widget: {e}"),
    }
}

/// Handles a message the dashboard's JS sent via window.ipc.postMessage.
/// Protocol (plain "verb:payload" strings, kept simple over a real IPC
/// schema since the message set is small and unlikely to grow much):
///   open_browser:<url>   — spawn a browser-widget window at url
///   open_app:<name>      — launch an installed app (chrome | opera-gx)
/// Pure parse of an IPC message into (verb, payload) — split out from
/// handle_ipc_message so the parsing itself is unit-testable without
/// spawning real processes (see the tests module at the bottom of this file).
fn parse_ipc_message(message: &str) -> Option<(&str, &str)> {
    if let Some(rest) = message.strip_prefix("open_browser:") {
        Some(("open_browser", rest))
    } else if let Some(rest) = message.strip_prefix("open_app:") {
        Some(("open_app", rest))
    } else {
        None
    }
}

fn handle_ipc_message(message: String) {
    match parse_ipc_message(&message) {
        Some(("open_browser", url)) => open_browser_widget(url),
        Some(("open_app", name)) => launch_app(name),
        _ => eprintln!("[swarm-overlay] unrecognized IPC message: {message}"),
    }
}

/// JS injected into every window: toggles a `peek` class on <body> so the
/// page fades to reveal the game underneath. Kept generic (works whether or
/// not the page defines `.peek` — dashboard.html does; browser/video mode
/// pages are arbitrary sites that won't, so peek there simply has no visual
/// effect beyond the transparent window background wry itself provides).
const PEEK_ON_JS: &str = "document.body && document.body.classList.add('swarm-overlay-peek')";
const PEEK_OFF_JS: &str = "document.body && document.body.classList.remove('swarm-overlay-peek')";

fn main() -> wry::Result<()> {
    let mode = resolve_mode();

    let (title, size, position): (&str, LogicalSize<f64>, Option<(f64, f64)>) = match &mode {
        Mode::Dashboard => ("SWARM Overlay — Dashboard", LogicalSize::new(360.0, 640.0), None),
        Mode::Browser(_) => ("SWARM Overlay — Browser", LogicalSize::new(480.0, 720.0), None),
        Mode::Video(_) => ("SWARM Overlay — Video", LogicalSize::new(420.0, 300.0), None),
    };

    let event_loop = EventLoop::new();

    // Video mode defaults to the right edge of the primary monitor; still a
    // normal movable/resizable window afterward, this is just the initial
    // placement so it doesn't land center-screen over the game by default.
    let position = position.or_else(|| {
        if matches!(mode, Mode::Video(_)) {
            event_loop.primary_monitor().map(|m| {
                let scale = m.scale_factor();
                let logical_width = m.size().to_logical::<f64>(scale).width;
                let logical_height = m.size().to_logical::<f64>(scale).height;
                (logical_width - size.width - 24.0, (logical_height - size.height) / 2.0)
            })
        } else {
            None
        }
    });

    let mut window_builder = WindowBuilder::new()
        .with_title(title)
        .with_resizable(true)
        .with_transparent(true)
        .with_inner_size(size)
        .with_min_inner_size(LogicalSize::new(280.0, 220.0));
    if let Some((x, y)) = position {
        window_builder = window_builder.with_position(tao::dpi::LogicalPosition::new(x, y));
    }
    let window = window_builder
        .build(&event_loop)
        .expect("failed to create overlay window");

    let is_dashboard = matches!(mode, Mode::Dashboard);
    let webview_builder = WebViewBuilder::new(&window).with_transparent(true);
    let webview_builder = if is_dashboard {
        webview_builder.with_ipc_handler(|msg| handle_ipc_message(msg))
    } else {
        webview_builder
    };

    let _webview = match mode {
        Mode::Dashboard => webview_builder.with_html(DASHBOARD_HTML)?.build()?,
        Mode::Browser(url) | Mode::Video(url) => webview_builder.with_url(&url)?.build()?,
    };

    let mut super_held = false;

    event_loop.run(move |event, _, control_flow| {
        *control_flow = ControlFlow::Wait;
        match event {
            Event::WindowEvent {
                event: WindowEvent::CloseRequested,
                ..
            } => *control_flow = ControlFlow::Exit,
            Event::WindowEvent {
                event: WindowEvent::ModifiersChanged(modifiers),
                ..
            } => {
                let now_held = modifiers.super_key();
                if now_held != super_held {
                    super_held = now_held;
                    let js = if super_held { PEEK_ON_JS } else { PEEK_OFF_JS };
                    let _ = _webview.evaluate_script(js);
                }
            }
            _ => {}
        }
    });
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_open_browser() {
        assert_eq!(
            parse_ipc_message("open_browser:https://example.com"),
            Some(("open_browser", "https://example.com"))
        );
    }

    #[test]
    fn parses_open_app() {
        assert_eq!(parse_ipc_message("open_app:chrome"), Some(("open_app", "chrome")));
        assert_eq!(parse_ipc_message("open_app:opera-gx"), Some(("open_app", "opera-gx")));
    }

    #[test]
    fn rejects_unknown_verbs() {
        assert_eq!(parse_ipc_message("nonsense"), None);
        assert_eq!(parse_ipc_message("open_browser"), None); // missing ':' separator
        assert_eq!(parse_ipc_message(""), None);
    }

    #[test]
    fn empty_payload_still_parses() {
        // Empty url/app name parses fine here — validity is the caller's
        // problem (open_browser_widget/launch_app), not the parser's.
        assert_eq!(parse_ipc_message("open_browser:"), Some(("open_browser", "")));
    }
}
