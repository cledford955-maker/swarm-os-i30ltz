package models

// ── Steam ────────────────────────────────────────────────────────────────────

type SteamGame struct {
	AppId           int    `json:"appid"`
	Name            string `json:"name"`
	PlaytimeMinutes int    `json:"playtime_forever"`
	IconUrl         string `json:"img_icon_url"`
}

type SteamResponseInner struct {
	Games     []SteamGame `json:"games"`
	GameCount int         `json:"game_count"`
}

type SteamResponse struct {
	Response SteamResponseInner `json:"response"`
}

// ── GFN ──────────────────────────────────────────────────────────────────────

type GfnGame struct {
	Id         int64    `json:"id"`
	Title      string   `json:"title"`
	SteamUrl   string   `json:"steamUrl"`
	SteamAppId int      `json:"-"`
	Status     string   `json:"status"`
	Genres     []string `json:"genres"`
	Publisher  string   `json:"publisher"`
	Store      string   `json:"store"`
}

// ── Enriched game (intersection result) ──────────────────────────────────────

type EnrichedGame struct {
	AppId           int      `json:"appId"`
	Name            string   `json:"name"`
	OnGfn           bool     `json:"onGfn"`
	GfnId           string   `json:"gfnId,omitempty"`
	Genres          []string `json:"genres"`
	Description     string   `json:"description,omitempty"`
	Publisher       string   `json:"publisher,omitempty"`
	PlaytimeMinutes int      `json:"playtimeMinutes"`
	HeaderImage     string   `json:"headerImage"`
	CapsuleImage    string   `json:"capsuleImage"`
	SteamUrl        string   `json:"steamUrl"`
	GfnUrl          string   `json:"gfnUrl,omitempty"`
	IsFavorite      bool     `json:"isFavorite"`
	IsPinned        bool     `json:"isPinned"`
}

// ── Favorites ─────────────────────────────────────────────────────────────────

type FavoriteEntry struct {
	AppId      int  `json:"appId"`
	IsFavorite bool `json:"isFavorite"`
	IsPinned   bool `json:"isPinned"`
}

// ── CheapShark ───────────────────────────────────────────────────────────────

type CheapSharkDeal struct {
	StoreId     string `json:"storeID"`
	Price       string `json:"price"`
	RetailPrice string `json:"retailPrice"`
	Savings     string `json:"savings"`
}

type CheapSharkCheapest struct {
	Price string `json:"price"`
	Date  int64  `json:"date"`
}

type CheapSharkInfo struct {
	Title        string              `json:"title"`
	Thumb        string              `json:"thumb"`
	CheapestEver *CheapSharkCheapest `json:"cheapestPriceEver"`
}

type CheapSharkGameDetail struct {
	Info  *CheapSharkInfo  `json:"info"`
	Deals []CheapSharkDeal `json:"deals"`
}

// ── Lucille eval ──────────────────────────────────────────────────────────────

type LucilleEvalResult struct {
	GenreFilters      []string  `json:"genreFilters"`
	PinGames          []string  `json:"pinGames"`
	SortBy            string    `json:"sortBy"`
	FavoriteGames     []string  `json:"favoriteGames"`
	Summary           string    `json:"summary"`
	SystemSuggestions []string  `json:"systemSuggestions"`
	TopGames          []TopGame `json:"topGames"`
	Error             string    `json:"error,omitempty"`
}

type TopGame struct {
	Name  string  `json:"name"`
	Hours float64 `json:"hours"`
	OnGfn bool    `json:"onGfn"`
}

// ── Lucille chat ──────────────────────────────────────────────────────────────

type ChatMessage struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

type LucilleChatRequest struct {
	Messages  []ChatMessage `json:"messages"`
	SessionId string        `json:"sessionId"`
}

type LucilleChatResponse struct {
	Reply     string `json:"reply"`
	SessionId string `json:"sessionId"`
	Error     string `json:"error,omitempty"`
}

type ChatHistoryEntry struct {
	Id        int64  `json:"id"`
	Role      string `json:"role"`
	Content   string `json:"content"`
	CreatedAt string `json:"createdAt"`
}

// ── Media control (MPRIS via playerctl) ────────────────────────────────────────

type MediaStatus struct {
	Available   bool     `json:"available"`
	Player      string   `json:"player,omitempty"`
	PlayerLabel string   `json:"playerLabel,omitempty"`
	Status      string   `json:"status,omitempty"` // "Playing" | "Paused" | "Stopped"
	Title       string   `json:"title,omitempty"`
	Artist      string   `json:"artist,omitempty"`
	Album       string   `json:"album,omitempty"`
	ArtUrl      string   `json:"artUrl,omitempty"`
	Position    string   `json:"position,omitempty"` // formatted h:mm:ss
	Duration    string   `json:"duration,omitempty"` // formatted h:mm:ss
	Volume      float64  `json:"volume"`
	VolumeKnown bool     `json:"volumeKnown"`
	Players     []string `json:"players,omitempty"` // all active MPRIS player instances
}

type MediaControlRequest struct {
	// One of: play, pause, play-pause, next, previous, stop
	Action string `json:"action"`
	// Optional: target a specific player instance from MediaStatus.Players.
	// Empty targets playerctl's default (most-recently-active) player.
	Player string `json:"player,omitempty"`
}

type MediaVolumeRequest struct {
	Volume float64 `json:"volume"` // 0.0-1.0
	Player string  `json:"player,omitempty"`
}
