use std::sync::{Arc, Mutex};

use slint::{ComponentHandle, ModelRc, VecModel};

use crate::api::lucy::{ChatMsg, LucyClient};
use crate::{AppWindow, ForgeBubble, ForgeState};

struct ForgeBubbleData {
    role: String,
    content: String,
}

/// Backs the Forge tab — LucyServer's general orchestrator (`/lucy`), not
/// GamingAgent. Modeled on the old gaming-chat ChatController (deleted
/// 2026-09-19, recoverable from git history), same streaming-bubble pattern.
#[derive(Clone)]
pub struct ForgeController {
    client: LucyClient,
    history: Arc<Mutex<Vec<ForgeBubbleData>>>,
}

impl ForgeController {
    pub fn new() -> Self {
        Self {
            client: LucyClient::new(),
            history: Arc::new(Mutex::new(Vec::new())),
        }
    }

    pub fn init(&self, app: &AppWindow) {
        let state = app.global::<ForgeState>();

        let handle = app.as_weak();
        let client = self.client.clone();
        let history = self.history.clone();

        state.on_send_message(move |text| {
            let text = text.to_string();

            // Push the user bubble + an empty assistant placeholder, update UI immediately.
            {
                let mut h = history.lock().unwrap();
                h.push(ForgeBubbleData { role: "user".into(), content: text.clone() });
                h.push(ForgeBubbleData { role: "assistant".into(), content: String::new() });
            }
            if let Some(app) = handle.upgrade() {
                app.global::<ForgeState>().set_is_streaming(true);
                push_bubbles(&app, &history.lock().unwrap());
            }

            let handle = handle.clone();
            let client = client.clone();
            let history = history.clone();

            tokio::spawn(async move {
                // No server-side session id on /lucy — resend the whole
                // history each turn (stateless completion API, not a chat
                // session like GamingAgent's).
                let messages: Vec<ChatMsg> = history
                    .lock()
                    .unwrap()
                    .iter()
                    .filter(|b| !b.content.is_empty())
                    .map(|b| ChatMsg { role: b.role.clone(), content: b.content.clone() })
                    .collect();

                let handle_tok = handle.clone();
                let history_tok = history.clone();

                let result = client
                    .chat_stream(messages, move |token| {
                        {
                            let mut h = history_tok.lock().unwrap();
                            if let Some(last) = h.last_mut() {
                                last.content.push_str(&token);
                            }
                        }
                        let handle = handle_tok.clone();
                        let history = history_tok.clone();
                        let _ = slint::invoke_from_event_loop(move || {
                            if let Some(app) = handle.upgrade() {
                                push_bubbles(&app, &history.lock().unwrap());
                            }
                        });
                    })
                    .await;

                let _ = slint::invoke_from_event_loop(move || {
                    if let Some(app) = handle.upgrade() {
                        app.global::<ForgeState>().set_is_streaming(false);
                    }
                });

                if let Err(e) = result {
                    eprintln!("[Forge chat] stream error: {e}");
                }
            });
        });
    }
}

fn push_bubbles(app: &AppWindow, history: &[ForgeBubbleData]) {
    let bubbles: Vec<ForgeBubble> = history
        .iter()
        .map(|b| ForgeBubble { role: b.role.clone().into(), content: b.content.clone().into() })
        .collect();
    app.global::<ForgeState>().set_messages(ModelRc::new(VecModel::from(bubbles)));
}
