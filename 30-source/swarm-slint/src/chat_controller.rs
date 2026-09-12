use std::sync::{Arc, Mutex};

use slint::{ComponentHandle, ModelRc, VecModel};

use crate::api::gaming::{ChatMsg, GamingClient};
use crate::{AppWindow, ChatBubble, ChatState};

struct ChatBubbleData {
    role: String,
    content: String,
}

#[derive(Clone)]
pub struct ChatController {
    client: GamingClient,
    session_id: Arc<Mutex<Option<String>>>,
    history: Arc<Mutex<Vec<ChatBubbleData>>>,
}

impl ChatController {
    pub fn new() -> Self {
        Self {
            client: GamingClient::new(),
            session_id: Arc::new(Mutex::new(None)),
            history: Arc::new(Mutex::new(Vec::new())),
        }
    }

    pub fn init(&self, app: &AppWindow) {
        let state = app.global::<ChatState>();

        let handle = app.as_weak();
        let client = self.client.clone();
        let session_id = self.session_id.clone();
        let history = self.history.clone();

        state.on_send_message(move |text| {
            let text = text.to_string();

            // Push the user bubble + an empty assistant placeholder, update UI immediately.
            {
                let mut h = history.lock().unwrap();
                h.push(ChatBubbleData { role: "user".into(), content: text.clone() });
                h.push(ChatBubbleData { role: "assistant".into(), content: String::new() });
            }
            if let Some(app) = handle.upgrade() {
                app.global::<ChatState>().set_is_streaming(true);
                push_bubbles(&app, &history.lock().unwrap());
            }

            let handle = handle.clone();
            let client = client.clone();
            let session_id = session_id.clone();
            let history = history.clone();

            tokio::spawn(async move {
                let current_session = session_id.lock().unwrap().clone();
                let messages = vec![ChatMsg { role: "user".to_string(), content: text }];

                let handle_tok = handle.clone();
                let history_tok = history.clone();
                let session_id_sess = session_id.clone();

                let result = client
                    .chat_stream(
                        messages,
                        current_session,
                        move |token| {
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
                        },
                        move |new_session_id| {
                            *session_id_sess.lock().unwrap() = Some(new_session_id);
                        },
                    )
                    .await;

                let _ = slint::invoke_from_event_loop(move || {
                    if let Some(app) = handle.upgrade() {
                        app.global::<ChatState>().set_is_streaming(false);
                    }
                });

                if let Err(e) = result {
                    eprintln!("[Lucille chat] stream error: {e}");
                }
            });
        });
    }
}

fn push_bubbles(app: &AppWindow, history: &[ChatBubbleData]) {
    let bubbles: Vec<ChatBubble> = history
        .iter()
        .map(|b| ChatBubble { role: b.role.clone().into(), content: b.content.clone().into() })
        .collect();
    app.global::<ChatState>().set_messages(ModelRc::new(VecModel::from(bubbles)));
}
