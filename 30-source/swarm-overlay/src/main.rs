// SWARM Overlay — Lucille-controlled gaming overlay.
//
// Two modes, chosen by the first CLI arg (or SWARM_OVERLAY_MODE):
//   dashboard  — full-page HUD: now-playing (GamingAgent /api/media/*),
//                Lucille chat (/api/lucille/chat). The embedded HTML is
//                baked into this binary via include_str!, not served over
//                HTTP — confirmed 2026-09-20 that GamingAgent's originGate
//                rejects a real HTTP Origin that isn't on its allowlist,
//                while a bare/no Origin (what a baked-in page's fetch()
//                calls send) passes through as a trusted native client. Do
//                not switch this to loading the HTML over a local HTTP
//                server without also updating GamingAgent's allowed-origins
//                list, or Lucille chat/media control will silently 403.
//   browser    — widget: a single resizable/movable window pointed at a URL
//                (second CLI arg, or SWARM_OVERLAY_URL), for walkthroughs
//                and general web browsing over the game.
//
// Window placement/always-on-top/undecorated behavior is handled by labwc's
// windowRules (see 40-iso-profile/.../labwc/rc.xml), matched by title, the
// same way the Lucille Slint panel already floats — not by anything in here.

use std::env;

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
        _ => Mode::Dashboard,
    }
}

fn main() -> wry::Result<()> {
    let mode = resolve_mode();

    let (title, size) = match &mode {
        Mode::Dashboard => ("SWARM Overlay — Dashboard", LogicalSize::new(360.0, 640.0)),
        Mode::Browser(_) => ("SWARM Overlay — Browser", LogicalSize::new(480.0, 720.0)),
    };

    let event_loop = EventLoop::new();
    let window = WindowBuilder::new()
        .with_title(title)
        .with_resizable(true)
        .with_inner_size(size)
        .with_min_inner_size(LogicalSize::new(280.0, 320.0))
        .build(&event_loop)
        .expect("failed to create overlay window");

    let webview_builder = WebViewBuilder::new(&window);
    let _webview = match mode {
        Mode::Dashboard => webview_builder.with_html(DASHBOARD_HTML)?.build()?,
        Mode::Browser(url) => webview_builder.with_url(&url)?.build()?,
    };

    event_loop.run(move |event, _, control_flow| {
        *control_flow = ControlFlow::Wait;
        if let Event::WindowEvent {
            event: WindowEvent::CloseRequested,
            ..
        } = event
        {
            *control_flow = ControlFlow::Exit;
        }
    });
}
