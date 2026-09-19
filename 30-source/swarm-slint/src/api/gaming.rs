use reqwest::Client;
use serde::{Deserialize, Serialize};

const BASE: &str = "http://localhost:8401";

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

    // NOTE: GET /api/lucille/history and POST /api/lucille/chat/stream exist
    // server-side but have no caller here anymore — the standalone gaming-chat
    // tab that used them was replaced by Forge (LucyServer's general /lucy)
    // 2026-09-19. Re-add a client method here if a gaming-context chat UI
    // comes back, rather than carrying the dead code in the meantime.
}
