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
	Id          string   `json:"id"`
	Title       string   `json:"title"`
	SteamUrl    string   `json:"steamUrl"`
	SteamAppId  int      `json:"steamAppId"`
	Status      string   `json:"status"`
	Genres      []string `json:"genres"`
	Description string   `json:"description"`
	Publisher   string   `json:"publisher"`
	ReleaseYear int      `json:"releaseYear"`
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
