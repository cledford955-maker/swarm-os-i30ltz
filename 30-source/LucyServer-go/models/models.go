package models

// Field names verified against LucyServer/Services/ISystemIntegrationService.cs —
// ASP.NET's default Web JSON policy (camelCase) applies, no [JsonPropertyName] overrides.

type CommandResult struct {
	ExitCode       int    `json:"exitCode"`
	StandardOutput string `json:"standardOutput"`
	StandardError  string `json:"standardError"`
}

type ProcessInfo struct {
	Pid           int     `json:"pid"`
	Name          string  `json:"name"`
	MemoryUsageMb float64 `json:"memoryUsageMb"`
}

type SystemStats struct {
	CpuUsagePercentage float64 `json:"cpuUsagePercentage"`
	TotalMemoryMb      float64 `json:"totalMemoryMb"`
	UsedMemoryMb       float64 `json:"usedMemoryMb"`
	FreeMemoryMb       float64 `json:"freeMemoryMb"`
}

// FileSystemModels — field names match LucyServer/Models/FileSystemModels.cs
// (ASP.NET default camelCase serialization, no [JsonPropertyName] overrides).

type FileItemInfo struct {
	Name        string `json:"name"`
	Path        string `json:"path"`
	IsDirectory bool   `json:"isDirectory"`
	Size        int64  `json:"size"`
}

type FsAnalyzeRequest struct {
	Path string `json:"path"`
}

type FileReadRequest struct {
	Filename string `json:"filename"`
}

type FileSaveRequest struct {
	Filename string `json:"filename"`
	Content  string `json:"content"`
}

// Chat models — field names match LucyServer/Models/ChatModels.cs + ChatMessage.cs + LucyRequest.cs.
// The file stored on disk uses Go's standard camelCase tags; the GET /api/chats response
// uses explicit snake_case to match the .NET original's anonymous-object field names.

type ChatMessage struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

type ChatInfo struct {
	Title   string        `json:"title"`
	History []ChatMessage `json:"history"`
	Pinned  bool          `json:"pinned"`
	Privacy string        `json:"privacy"`
}

type ChatData struct {
	ActiveChatId string               `json:"activeChatId"`
	Chats        map[string]*ChatInfo `json:"chats"`
}

type ChatNewRequest struct {
	Title   string `json:"title"`
	Privacy string `json:"privacy"`
}

type ChatIdRequest struct {
	ChatId string `json:"chatId"`
}

type ChatRenameRequest struct {
	ChatId string `json:"chatId"`
	Title  string `json:"title"`
}

type LucyRequest struct {
	ModelId   string        `json:"modelId"`
	Messages  []ChatMessage `json:"messages"`
	AutoRoute bool          `json:"autoRoute"`
}

// TTS / Ollama / RAG / News models — field names match LucyServer .NET originals.

type GenerateVoiceRequest struct {
	Text      string `json:"text"`
	VoiceName string `json:"voiceName"`
}

type GfnOptimizeRequest struct {
	Game string `json:"game"`
}

type RagIngestRequest struct {
	Text   string `json:"text"`
	Source string `json:"source"`
}

type RagFileRequest struct {
	FilePath string `json:"filePath"`
}

type RagDocument struct {
	Text      string    `json:"text"`
	Embedding []float32 `json:"embedding"`
	Source    string    `json:"source,omitempty"`
}

type NewsItem struct {
	Source   string `json:"source"`
	Title    string `json:"title"`
	Link     string `json:"link"`
	PubDate  string `json:"pubDate"`
	Snippet  string `json:"snippet"`
	Category string `json:"category"`
}

type DealItem struct {
	Title       string `json:"title"`
	SalePrice   string `json:"salePrice"`
	NormalPrice string `json:"normalPrice"`
	Savings     string `json:"savings"`
	StoreId     string `json:"storeId"`
	DealId      string `json:"dealId"`
}
