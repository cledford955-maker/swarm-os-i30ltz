use futures_util::StreamExt;
use reqwest::Client;
use serde::{Deserialize, Serialize};

const BASE: &str = "http://localhost:8401";

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct ChatMsg {
    pub role: String,
    pub content: String,
}

#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct EnrichedGame {
    #[serde(rename = "appId")]      pub app_id: i32,
    pub name: String,
    #[serde(rename = "onGfn")]      pub on_gfn: bool,
    pub genres: Vec<String>,
    #[serde(rename = "playtimeMinutes")] pub playtime_minutes: i32,
    #[serde(rename = "headerImage")] pub header_image: String,
    #[serde(rename = "isFavorite")] pub is_favorite: bool,
    #[serde(rename = "isPinned")]   pub is_pinned: bool,
}

#[derive(Debug, Deserialize)]
pub struct LucilleEvalResult {
    #[serde(rename = "genreFilters")]      pub genre_filters: Vec<String>,
    #[serde(rename = "pinGames")]          pub pin_games: Vec<String>,
    #[serde(rename = "sortBy")]            pub sort_by: String,
    #[serde(rename = "favoriteGames")]     pub favorite_games: Vec<String>,
    pub summary: String,
    #[serde(rename = "systemSuggestions")] pub system_suggestions: Vec<String>,
    #[serde(default)]                      pub error: Option<String>,
}

#[derive(Clone)]
pub struct GamingClient {
    client: Client,
}

impl GamingClient {
    pub fn new() -> Self {
        Self { client: Client::new() }
    }

    pub async fn get_intersection(&self) -> reqwest::Result<Vec<EnrichedGame>> {
        self.client.get(format!("{BASE}/api/games/intersection"))
            .send().await?
            .json::<Vec<EnrichedGame>>().await
    }

    pub async fn get_genres(&self) -> reqwest::Result<Vec<String>> {
        self.client.get(format!("{BASE}/api/games/genres"))
            .send().await?
            .json::<Vec<String>>().await
    }

    pub async fn lucille_eval(&self) -> reqwest::Result<LucilleEvalResult> {
        self.client.get(format!("{BASE}/api/lucille/eval"))
            .send().await?
            .json::<LucilleEvalResult>().await
    }

    pub async fn set_favorite(&self, app_id: i32, is_favorite: bool, is_pinned: bool) -> reqwest::Result<()> {
        #[derive(Serialize)]
        struct Body {
            #[serde(rename = "appId")]      app_id: i32,
            #[serde(rename = "isFavorite")] is_favorite: bool,
            #[serde(rename = "isPinned")]   is_pinned: bool,
        }
        self.client.post(format!("{BASE}/api/games/favorite"))
            .json(&Body { app_id, is_favorite, is_pinned })
            .send().await?;
        Ok(())
    }

    /// Returns formatted "Store X: $Price" strings for the deal modal.
    pub async fn get_prices(&self, app_id: i32) -> reqwest::Result<Vec<String>> {
        #[derive(Deserialize)]
        struct Deal {
            #[serde(rename = "storeID")] store_id: String,
            price: String,
        }
        #[derive(Deserialize)]
        struct Detail {
            deals: Option<Vec<Deal>>,
        }
        let detail: Detail = self.client.get(format!("{BASE}/api/games/prices/{app_id}"))
            .send().await?
            .json().await?;
        Ok(detail.deals.unwrap_or_default().iter()
            .map(|d| format!("Store {}: ${}", d.store_id, d.price))
            .collect())
    }

    // NOTE: GET /api/lucille/history exists server-side but has no caller yet —
    // the chat session is purely in-memory (resets each app launch), and there's
    // no session picker UI to resume a prior one. Add a client method here when
    // that UI exists rather than carrying dead code in the meantime.

    /// Streams a chat reply token-by-token via SSE. The server sends an
    /// `event: session` frame first (see lucille_service.go) carrying the
    /// session id — required so a caller with no prior session can persist it
    /// for the next turn and keep multi-turn context continuous.
    pub async fn chat_stream<F, S>(
        &self,
        messages: Vec<ChatMsg>,
        session_id: Option<String>,
        mut on_token: F,
        mut on_session: S,
    ) -> reqwest::Result<()>
    where
        F: FnMut(String) + Send,
        S: FnMut(String) + Send,
    {
        #[derive(Serialize)]
        struct Body {
            messages: Vec<ChatMsg>,
            #[serde(rename = "sessionId")]
            session_id: String,
        }

        let resp = self.client.post(format!("{BASE}/api/lucille/chat/stream"))
            .json(&Body { messages, session_id: session_id.unwrap_or_default() })
            .send().await?;

        let mut stream = resp.bytes_stream();
        let mut buf = String::new();
        let mut current_event = String::from("message");

        while let Some(chunk) = stream.next().await {
            let chunk = chunk?;
            buf.push_str(&String::from_utf8_lossy(&chunk));

            while let Some(pos) = buf.find('\n') {
                let line = buf[..pos].trim_end_matches('\r').to_string();
                buf.drain(..=pos);

                if line.is_empty() {
                    current_event = String::from("message");
                    continue;
                }
                if let Some(rest) = line.strip_prefix("event: ") {
                    current_event = rest.to_string();
                } else if let Some(rest) = line.strip_prefix("data: ") {
                    if current_event == "session" {
                        on_session(rest.to_string());
                    } else if rest != "[DONE]" {
                        on_token(rest.to_string());
                    }
                }
            }
        }
        Ok(())
    }
}
