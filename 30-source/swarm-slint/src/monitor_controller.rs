use std::time::Duration;

use slint::{ComponentHandle, ModelRc, VecModel};
use tokio::time;

use crate::api::lucy::LucyClient;
use crate::{AppWindow, MonitorState, ProcessRow};

pub struct MonitorController {
    client: LucyClient,
}

impl MonitorController {
    pub fn new() -> Self {
        Self { client: LucyClient::new() }
    }

    pub fn init(&self, app: &AppWindow) {
        // ── Kill button ────────────────────────────────────────────────────────
        {
            let client = self.client.clone();
            app.global::<MonitorState>().on_kill_process(move |pid| {
                let client = client.clone();
                tokio::spawn(async move {
                    let _ = client.kill_process(pid).await;
                });
            });
        }

        // ── Poll stats + processes every 2s ─────────────────────────────────────
        let handle = app.as_weak();
        let client = self.client.clone();
        tokio::spawn(async move {
            let mut ticker = time::interval(Duration::from_secs(2));
            loop {
                ticker.tick().await;

                let stats = client.get_system_stats().await.ok();
                let processes = client.get_processes().await.unwrap_or_default();
                let engine = client.lucille_status().await.ok();

                let handle = handle.clone();
                let _ = slint::invoke_from_event_loop(move || {
                    let Some(app) = handle.upgrade() else { return };
                    let state = app.global::<MonitorState>();

                    if let Some(s) = stats {
                        state.set_cpu_label(format!("CPU  {:.0}%", s.cpu_usage_percentage).into());
                        state.set_ram_label(
                            format!("RAM  {:.0}/{:.0} MB", s.used_memory_mb, s.total_memory_mb).into(),
                        );
                    }

                    match &engine {
                        Some(e) if e.is_running() => {
                            let label = if e.active_processes > 0 {
                                format!("ENGINE  {} active", e.active_processes)
                            } else {
                                "ENGINE  idle".to_string()
                            };
                            state.set_engine_label(label.into());
                            state.set_engine_online(true);
                        }
                        _ => {
                            state.set_engine_label("ENGINE  offline".into());
                            state.set_engine_online(false);
                        }
                    }

                    let rows: Vec<ProcessRow> = processes
                        .iter()
                        .map(|p| ProcessRow {
                            pid: p.pid,
                            name: p.name.clone().into(),
                            memory_label: format!("{:.0} MB", p.memory_usage_mb).into(),
                        })
                        .collect();
                    state.set_processes(ModelRc::new(VecModel::from(rows)));
                });
            }
        });
    }
}
