use std::sync::{Arc, Mutex};

use slint::{ComponentHandle, Model, ModelRc, VecModel};

use crate::api::gaming::{EnrichedGame, GamingClient};
use crate::{AppWindow, GameCard, GameRow, GamingState, GenreChipData};

const CARDS_PER_ROW: usize = 6;

#[derive(Clone)]
pub struct GamingController {
    client: GamingClient,
    all_games: Arc<Mutex<Vec<EnrichedGame>>>,
    selected_genres: Arc<Mutex<Vec<String>>>,
    sort_by: Arc<Mutex<String>>,
}

impl GamingController {
    pub fn new() -> Self {
        Self {
            client: GamingClient::new(),
            all_games: Arc::new(Mutex::new(Vec::new())),
            selected_genres: Arc::new(Mutex::new(Vec::new())),
            sort_by: Arc::new(Mutex::new("playtime".to_string())),
        }
    }

    pub fn init(&self, app: &AppWindow) {
        self.refresh(app);
        self.wire_callbacks(app);
    }

    fn wire_callbacks(&self, app: &AppWindow) {
        let state = app.global::<GamingState>();

        // ── sub-tab switch: re-filter existing data, no network call ─────────
        {
            let handle = app.as_weak();
            let all_games = self.all_games.clone();
            let selected_genres = self.selected_genres.clone();
            let sort_by = self.sort_by.clone();
            state.on_sub_tab_changed(move |_tab| {
                if let Some(app) = handle.upgrade() {
                    let games = all_games.lock().unwrap().clone();
                    let genres = selected_genres.lock().unwrap().clone();
                    let sort = sort_by.lock().unwrap().clone();
                    rebuild_display(&app, &games, &genres, &sort);
                }
            });
        }

        // ── genre chip toggle ─────────────────────────────────────────────────
        {
            let handle = app.as_weak();
            let all_games = self.all_games.clone();
            let selected_genres = self.selected_genres.clone();
            let sort_by = self.sort_by.clone();
            state.on_genre_toggled(move |genre| {
                let genre = genre.to_string();
                {
                    let mut sel = selected_genres.lock().unwrap();
                    if let Some(pos) = sel.iter().position(|g| g == &genre) {
                        sel.remove(pos);
                    } else {
                        sel.push(genre);
                    }
                }
                if let Some(app) = handle.upgrade() {
                    let games = all_games.lock().unwrap().clone();
                    let sel = selected_genres.lock().unwrap().clone();
                    let sort = sort_by.lock().unwrap().clone();
                    update_genre_chips(&app, &sel);
                    rebuild_display(&app, &games, &sel, &sort);
                }
            });
        }

        // ── favorite toggle: optimistic update + fire-and-forget API call ────
        {
            let handle = app.as_weak();
            let all_games = self.all_games.clone();
            let selected_genres = self.selected_genres.clone();
            let sort_by = self.sort_by.clone();
            let client = self.client.clone();
            state.on_favorite_toggled(move |app_id| {
                let new_state = {
                    let mut games = all_games.lock().unwrap();
                    if let Some(g) = games.iter_mut().find(|g| g.app_id == app_id) {
                        g.is_favorite = !g.is_favorite;
                        Some(g.is_favorite)
                    } else {
                        None
                    }
                };
                if let (Some(app), Some(is_fav)) = (handle.upgrade(), new_state) {
                    let games = all_games.lock().unwrap().clone();
                    let sel = selected_genres.lock().unwrap().clone();
                    let sort = sort_by.lock().unwrap().clone();
                    rebuild_display(&app, &games, &sel, &sort);

                    let client = client.clone();
                    tokio::spawn(async move {
                        let _ = client.set_favorite(app_id, is_fav, false).await;
                    });
                }
            });
        }

        // ── Lucille eval ───────────────────────────────────────────────────────
        {
            let handle = app.as_weak();
            let client = self.client.clone();
            let all_games = self.all_games.clone();
            let selected_genres = self.selected_genres.clone();
            let sort_by = self.sort_by.clone();
            state.on_lucille_eval_requested(move || {
                if let Some(app) = handle.upgrade() {
                    app.global::<GamingState>().set_lucille_loading(true);
                }
                let handle = handle.clone();
                let client = client.clone();
                let all_games = all_games.clone();
                let selected_genres = selected_genres.clone();
                let sort_by = sort_by.clone();
                tokio::spawn(async move {
                    let result = client.lucille_eval().await;
                    let _ = slint::invoke_from_event_loop(move || {
                        if let Some(app) = handle.upgrade() {
                            let state = app.global::<GamingState>();
                            state.set_lucille_loading(false);
                            match result {
                                Ok(r) => {
                                    // The Go/.NET backend can return a 200 with an
                                    // embedded error message (e.g. Nemotron call
                                    // failed) rather than an HTTP error — surface it.
                                    let summary = match &r.error {
                                        Some(e) if !e.is_empty() => format!("{} ({e})", r.summary),
                                        _ => r.summary.clone(),
                                    };
                                    state.set_lucille_summary(summary.into());
                                    state.set_lucille_active(true);

                                    let mut badges: Vec<slint::SharedString> = r
                                        .genre_filters
                                        .iter()
                                        .map(|g| format!("Genre: {g}").into())
                                        .collect();
                                    badges.extend(
                                        r.pin_games.iter().map(|p| format!("Pinned: {p}").into()),
                                    );
                                    badges.extend(
                                        r.favorite_games
                                            .iter()
                                            .map(|f| format!("Favorited: {f}").into()),
                                    );
                                    if !r.sort_by.is_empty() {
                                        badges.push(format!("Sorted by: {}", r.sort_by).into());
                                    }
                                    state.set_action_badges(ModelRc::new(VecModel::from(badges)));

                                    let suggestions: Vec<slint::SharedString> = r
                                        .system_suggestions
                                        .iter()
                                        .map(|s| s.clone().into())
                                        .collect();
                                    state.set_system_suggestions(ModelRc::new(VecModel::from(suggestions)));

                                    // set_sort_order is a real Lucille tool — apply it.
                                    if !r.sort_by.is_empty() {
                                        *sort_by.lock().unwrap() = r.sort_by.clone();
                                    }
                                    let games = all_games.lock().unwrap().clone();
                                    let sel = selected_genres.lock().unwrap().clone();
                                    let sort = sort_by.lock().unwrap().clone();
                                    rebuild_display(&app, &games, &sel, &sort);
                                }
                                Err(e) => {
                                    state.set_lucille_summary(format!("Lucille error: {e}").into());
                                }
                            }
                        }
                    });
                });
            });
        }

        // ── Lucille reset ─────────────────────────────────────────────────────
        {
            let handle = app.as_weak();
            let all_games = self.all_games.clone();
            let selected_genres = self.selected_genres.clone();
            let sort_by = self.sort_by.clone();
            state.on_lucille_reset_requested(move || {
                *sort_by.lock().unwrap() = "playtime".to_string();
                if let Some(app) = handle.upgrade() {
                    let state = app.global::<GamingState>();
                    state.set_lucille_active(false);
                    state.set_lucille_summary("".into());
                    state.set_action_badges(ModelRc::new(VecModel::from(
                        Vec::<slint::SharedString>::new(),
                    )));
                    state.set_system_suggestions(ModelRc::new(VecModel::from(
                        Vec::<slint::SharedString>::new(),
                    )));
                    let games = all_games.lock().unwrap().clone();
                    let sel = selected_genres.lock().unwrap().clone();
                    rebuild_display(&app, &games, &sel, "playtime");
                }
            });
        }

        // ── card click → open deal modal, fetch prices ───────────────────────
        {
            let handle = app.as_weak();
            let all_games = self.all_games.clone();
            let client = self.client.clone();
            state.on_card_clicked(move |app_id| {
                let name = all_games
                    .lock()
                    .unwrap()
                    .iter()
                    .find(|g| g.app_id == app_id)
                    .map(|g| g.name.clone())
                    .unwrap_or_default();

                if let Some(app) = handle.upgrade() {
                    let state = app.global::<GamingState>();
                    state.set_show_deal_modal(true);
                    state.set_deal_game_name(name.into());
                    state.set_deal_loading(true);
                    state.set_deal_prices(ModelRc::new(VecModel::from(
                        Vec::<slint::SharedString>::new(),
                    )));
                }

                let handle = handle.clone();
                let client = client.clone();
                tokio::spawn(async move {
                    let prices = client.get_prices(app_id).await.unwrap_or_default();
                    let _ = slint::invoke_from_event_loop(move || {
                        if let Some(app) = handle.upgrade() {
                            let state = app.global::<GamingState>();
                            state.set_deal_loading(false);
                            let items: Vec<slint::SharedString> =
                                prices.iter().map(|p| p.clone().into()).collect();
                            state.set_deal_prices(ModelRc::new(VecModel::from(items)));
                        }
                    });
                });
            });
        }

        // ── close deal modal ──────────────────────────────────────────────────
        {
            let handle = app.as_weak();
            state.on_close_deal_modal(move || {
                if let Some(app) = handle.upgrade() {
                    app.global::<GamingState>().set_show_deal_modal(false);
                }
            });
        }

        // ── manual refresh ────────────────────────────────────────────────────
        {
            let controller = self.clone();
            let handle = app.as_weak();
            state.on_refresh_requested(move || {
                if let Some(app) = handle.upgrade() {
                    controller.refresh(&app);
                }
            });
        }
    }

    fn refresh(&self, app: &AppWindow) {
        let handle = app.as_weak();
        let client = self.client.clone();
        let all_games = self.all_games.clone();
        let selected_genres = self.selected_genres.clone();
        let sort_by = self.sort_by.clone();

        tokio::spawn(async move {
            let games = client.get_intersection().await.unwrap_or_default();
            let genres = client.get_genres().await.unwrap_or_default();
            *all_games.lock().unwrap() = games.clone();

            let _ = slint::invoke_from_event_loop(move || {
                if let Some(app) = handle.upgrade() {
                    let state = app.global::<GamingState>();

                    let gfn_count = games.iter().filter(|g| g.on_gfn).count();
                    let fav_count = games.iter().filter(|g| g.is_favorite).count();
                    state.set_stat_gfn_count(gfn_count.to_string().into());
                    state.set_stat_library_count(games.len().to_string().into());
                    state.set_stat_favorites_count(fav_count.to_string().into());
                    // On-sale count needs bulk CheapShark pricing — follow-up task.
                    state.set_stat_onsale_count("0".into());

                    let chips: Vec<GenreChipData> = genres
                        .iter()
                        .map(|g| GenreChipData { name: g.clone().into(), active: false })
                        .collect();
                    state.set_genre_list(ModelRc::new(VecModel::from(chips)));

                    let sel = selected_genres.lock().unwrap().clone();
                    let sort = sort_by.lock().unwrap().clone();
                    rebuild_display(&app, &games, &sel, &sort);
                }
            });
        });
    }
}

fn update_genre_chips(app: &AppWindow, selected: &[String]) {
    let state = app.global::<GamingState>();
    let current = state.get_genre_list();
    let updated: Vec<GenreChipData> = current
        .iter()
        .map(|c| GenreChipData {
            active: selected.iter().any(|s| s == c.name.as_str()),
            ..c
        })
        .collect();
    state.set_genre_list(ModelRc::new(VecModel::from(updated)));
}

fn rebuild_display(app: &AppWindow, games: &[EnrichedGame], selected_genres: &[String], sort_by: &str) {
    let state = app.global::<GamingState>();
    let sub_tab = state.get_sub_tab();

    let mut filtered: Vec<&EnrichedGame> = games
        .iter()
        .filter(|g| match sub_tab {
            0 => g.on_gfn && genre_match(g, selected_genres),
            1 => true,
            2 => g.is_favorite,
            _ => true,
        })
        .collect();
    sort_games(&mut filtered, sort_by);

    let cards: Vec<GameCard> = filtered.into_iter().map(to_card).collect();
    state.set_display_rows(ModelRc::new(VecModel::from(chunk_rows(cards))));

    let mut pinned: Vec<&EnrichedGame> = games.iter().filter(|g| g.is_pinned).collect();
    sort_games(&mut pinned, sort_by);
    let pinned_cards: Vec<GameCard> = pinned.into_iter().map(to_card).collect();
    state.set_pinned_rows(ModelRc::new(VecModel::from(chunk_rows(pinned_cards))));

    // On-sale rail needs bulk CheapShark pricing — left empty until that's wired.
    state.set_onsale_rows(ModelRc::new(VecModel::from(Vec::<GameRow>::new())));
}

fn genre_match(game: &EnrichedGame, selected: &[String]) -> bool {
    selected.is_empty() || game.genres.iter().any(|g| selected.contains(g))
}

/// Lucille's set_sort_order tool emits "playtime" | "name" | "gfn" (see the
/// Nemotron system prompt in GamingAgent-go/services/lucille_service.go).
fn sort_games(games: &mut [&EnrichedGame], sort_by: &str) {
    match sort_by {
        "name" => games.sort_by_key(|a| a.name.to_lowercase()),
        "gfn" => games.sort_by_key(|a| std::cmp::Reverse(a.on_gfn)),
        _ => games.sort_by_key(|a| std::cmp::Reverse(a.playtime_minutes)),
    }
}

fn to_card(g: &EnrichedGame) -> GameCard {
    GameCard {
        app_id: g.app_id,
        name: g.name.clone().into(),
        on_gfn: g.on_gfn,
        genres: g.genres.join(", ").into(),
        playtime_label: if g.playtime_minutes > 0 {
            format!("{}h played", g.playtime_minutes / 60)
        } else {
            "Not played".to_string()
        }
        .into(),
        is_favorite: g.is_favorite,
        is_pinned: g.is_pinned,
        on_sale: false,
    }
}

fn chunk_rows(cards: Vec<GameCard>) -> Vec<GameRow> {
    cards
        .chunks(CARDS_PER_ROW)
        .map(|chunk| GameRow { cards: ModelRc::new(VecModel::from(chunk.to_vec())) })
        .collect()
}
