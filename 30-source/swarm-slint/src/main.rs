mod api;
mod forge_controller;
mod gaming_controller;
mod monitor_controller;

use std::time::Duration;

use slint::ComponentHandle;
use tokio::time;

slint::include_modules!();

#[tokio::main]
async fn main() {
    // Startup diagnostic captured by journalctl -u swarm-ui.service.
    println!(
        "[swarm-slint] starting — WAYLAND_DISPLAY={} DISPLAY={}",
        std::env::var("WAYLAND_DISPLAY").unwrap_or_else(|_| "(unset)".into()),
        std::env::var("DISPLAY").unwrap_or_else(|_| "(unset)".into()),
    );

    let app = AppWindow::new().expect("failed to create AppWindow");

    // Stamp version from env (build script can inject SWARM_VERSION)
    let version = option_env!("SWARM_VERSION").unwrap_or("dev");
    app.set_version_text(format!("v{version}").into());

    // ── Gaming dashboard (GamingAgent :8401) ─────────────────────────────────
    let gaming = gaming_controller::GamingController::new();
    gaming.init(&app);

    // ── Forge — the real general/coding Lucille, LucyServer :5000 /lucy, SSE.
    // Added 2026-09-19, replacing the old standalone "Chat" tab (removed —
    // it was GamingAgent-backed, same as Gaming, so this panel had no
    // non-gaming chat at all). ───────────────────────────────────────────────
    let forge = forge_controller::ForgeController::new();
    forge.init(&app);

    // ── System monitor (LucyServer :5000) ────────────────────────────────────
    let monitor = monitor_controller::MonitorController::new();
    monitor.init(&app);

    // ── Clock update (every second) ──────────────────────────────────────────
    {
        let handle = app.as_weak();
        tokio::spawn(async move {
            let mut ticker = time::interval(Duration::from_secs(1));
            loop {
                ticker.tick().await;
                let now = chrono::Local::now();
                let clock = now.format("%H:%M:%S").to_string();
                let handle = handle.clone();
                let _ = slint::invoke_from_event_loop(move || {
                    if let Some(app) = handle.upgrade() {
                        app.set_clock_text(clock.into());
                    }
                });
            }
        });
    }

    app.run().expect("UI event loop failed");
}
