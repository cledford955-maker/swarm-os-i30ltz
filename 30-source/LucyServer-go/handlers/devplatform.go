package handlers

import (
	"encoding/json"
	"io"
	"net/http"
	"os"

	"swarm-os/lucy-server/services"

	"github.com/go-chi/chi/v5"
)

// ── helpers ───────────────────────────────────────────────────────────────────

func decodeJSON(r *http.Request, dst any) error {
	defer r.Body.Close()
	return json.NewDecoder(r.Body).Decode(dst)
}

// ── Extension dev ─────────────────────────────────────────────────────────────

func ExtLinkLocal(w http.ResponseWriter, r *http.Request) {
	var body struct {
		SourcePath string `json:"source_path"`
	}
	if err := decodeJSON(r, &body); err != nil || body.SourcePath == "" {
		http.Error(w, `{"error":"source_path required"}`, http.StatusBadRequest)
		return
	}
	link, err := services.ExtLinkLocal(body.SourcePath)
	if err != nil {
		http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusBadRequest)
		return
	}
	writeJSON(w, map[string]any{"success": true, "extension": link})
}

func ExtListLocal(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, map[string]any{"extensions": services.ExtListLocal()})
}

func ExtUnlink(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "extensionId")
	if ok := services.ExtUnlink(id); !ok {
		http.Error(w, `{"error":"not found"}`, http.StatusNotFound)
		return
	}
	writeJSON(w, map[string]any{"success": true})
}

func ExtResolveDeps(w http.ResponseWriter, r *http.Request) {
	var body struct {
		Dependencies map[string]string `json:"dependencies"`
	}
	if err := decodeJSON(r, &body); err != nil {
		body.Dependencies = map[string]string{}
	}
	writeJSON(w, services.ExtResolveDeps(body.Dependencies))
}

func ExtCheckUpdates(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, map[string]any{"available_updates": services.ExtCheckUpdates()})
}

// ── Releases ──────────────────────────────────────────────────────────────────

func ReleasePublish(w http.ResponseWriter, r *http.Request) {
	var rel services.AppRelease
	if err := decodeJSON(r, &rel); err != nil {
		http.Error(w, `{"error":"invalid body"}`, http.StatusBadRequest)
		return
	}
	writeJSON(w, map[string]any{"release": services.ReleasePublish(rel)})
}

func ReleaseGet(w http.ResponseWriter, r *http.Request) {
	appID := chi.URLParam(r, "appId")
	channel := r.URL.Query().Get("channel")
	writeJSON(w, map[string]any{"releases": services.ReleaseGet(appID, channel)})
}

func ReleasePromote(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	var body struct {
		TargetChannel string `json:"target_channel"`
	}
	_ = decodeJSON(r, &body)
	if body.TargetChannel == "" {
		body.TargetChannel = "stable"
	}
	if ok := services.ReleasePromote(id, body.TargetChannel); !ok {
		http.Error(w, `{"error":"release not found"}`, http.StatusNotFound)
		return
	}
	writeJSON(w, map[string]any{"success": true})
}

// ── Git ───────────────────────────────────────────────────────────────────────

func GitListRepos(w http.ResponseWriter, r *http.Request) {
	repos, _ := services.GitListRepos()
	writeJSON(w, map[string]any{"repositories": repos})
}

func GitCreateRepo(w http.ResponseWriter, r *http.Request) {
	var body struct {
		Name string `json:"name"`
	}
	if err := decodeJSON(r, &body); err != nil || body.Name == "" {
		http.Error(w, `{"error":"name required"}`, http.StatusBadRequest)
		return
	}
	repo, err := services.GitCreateRepo(body.Name)
	if err != nil {
		http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusInternalServerError)
		return
	}
	writeJSON(w, map[string]any{"repository": repo})
}

// ── CI ────────────────────────────────────────────────────────────────────────

func CiTriggerPipeline(w http.ResponseWriter, r *http.Request) {
	var body struct {
		RepoName  string `json:"repo_name"`
		CommitSha string `json:"commit_sha"`
	}
	_ = decodeJSON(r, &body)
	p := services.CiTriggerPipeline(body.RepoName, body.CommitSha)
	writeJSON(w, map[string]any{"pipeline": p})
}

func CiGetPipeline(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	p := services.CiGetPipeline(id)
	if p == nil {
		http.Error(w, `{"error":"pipeline not found"}`, http.StatusNotFound)
		return
	}
	writeJSON(w, map[string]any{"pipeline": p})
}

// ── Artifacts ─────────────────────────────────────────────────────────────────

func ArtifactList(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, map[string]any{"artifacts": services.ArtifactList()})
}

func ArtifactDownload(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	art := services.ArtifactGet(id)
	if art == nil {
		http.Error(w, `{"error":"artifact not found"}`, http.StatusNotFound)
		return
	}
	f, err := os.Open(art.StoredPath)
	if err != nil {
		writeJSON(w, map[string]any{
			"artifact": art,
			"note":     "file not on disk (in-memory record only)",
		})
		return
	}
	defer f.Close()
	ct := art.ContentType
	if ct == "" {
		ct = "application/octet-stream"
	}
	w.Header().Set("Content-Type", ct)
	w.Header().Set("X-Artifact-Sha256", art.Sha256)
	w.Header().Set("Content-Disposition", `attachment; filename="`+art.Name+`"`)
	io.Copy(w, f)
}

// ── OAuth ─────────────────────────────────────────────────────────────────────

func OAuthLogin(w http.ResponseWriter, r *http.Request) {
	provider := chi.URLParam(r, "provider")
	url := services.OAuthLoginURL(provider)
	http.Redirect(w, r, url, http.StatusFound)
}

func OAuthCallback(w http.ResponseWriter, r *http.Request) {
	provider := chi.URLParam(r, "provider")
	code := r.URL.Query().Get("code")
	ok := services.OAuthHandleCallback(provider, code)
	writeJSON(w, map[string]any{"success": ok, "provider": provider})
}

// ── Analytics ─────────────────────────────────────────────────────────────────

func AnalyticsDashboard(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, services.AnalyticsDashboard())
}

// ── AI Coder ──────────────────────────────────────────────────────────────────

func AiCoderTask(w http.ResponseWriter, r *http.Request) {
	var body struct {
		Title          string `json:"title"`
		Prompt         string `json:"prompt"`
		ActiveFilePath string `json:"active_file_path"`
		Language       string `json:"language"`
		Role           string `json:"role"`
	}
	if err := decodeJSON(r, &body); err != nil || body.Prompt == "" {
		http.Error(w, `{"error":"prompt required"}`, http.StatusBadRequest)
		return
	}
	if body.Language == "" {
		body.Language = "dart"
	}
	if body.Role == "" {
		body.Role = "FullStackEngineer"
	}
	task, err := services.AiCoderDispatch(body.Title, body.Prompt, body.ActiveFilePath, body.Language, body.Role)
	if err != nil {
		writeJSON(w, map[string]any{"task": task, "error": err.Error()})
		return
	}
	writeJSON(w, task)
}

func AiCoderSuggestFixes(w http.ResponseWriter, r *http.Request) {
	var body struct {
		FilePath       string `json:"file_path"`
		FileContent    string `json:"file_content"`
		CompilerOutput string `json:"compiler_output"`
	}
	_ = decodeJSON(r, &body)
	fixes := services.AiCoderSuggestFixes(body.FilePath, body.FileContent, body.CompilerOutput)
	writeJSON(w, map[string]any{"suggested_fixes": fixes})
}

func AiCoderHistory(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, map[string]any{"tasks": services.AiCoderHistory()})
}

// ── Cloud Workspaces ──────────────────────────────────────────────────────────

func WorkspaceList(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, map[string]any{"workspaces": services.WorkspaceList()})
}

func WorkspaceCreate(w http.ResponseWriter, r *http.Request) {
	var body struct {
		Name       string `json:"name"`
		RemoteHost string `json:"remote_host"`
		SSHPort    int    `json:"ssh_port"`
		Username   string `json:"username"`
		RemotePath string `json:"remote_path"`
	}
	if err := decodeJSON(r, &body); err != nil || body.Name == "" {
		http.Error(w, `{"error":"name required"}`, http.StatusBadRequest)
		return
	}
	if body.SSHPort == 0 {
		body.SSHPort = 22
	}
	writeJSON(w, map[string]any{"workspace": services.WorkspaceCreate(body.Name, body.RemoteHost, body.SSHPort, body.Username, body.RemotePath)})
}

func WorkspaceSync(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	if ok := services.WorkspaceSync(id); !ok {
		http.Error(w, `{"error":"workspace not found"}`, http.StatusNotFound)
		return
	}
	writeJSON(w, map[string]any{"success": true, "message": "Workspace synced successfully"})
}

// ── Marketplace ───────────────────────────────────────────────────────────────

func MarketplaceTemplates(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, map[string]any{"templates": services.MarketplaceTemplates()})
}

func MarketplaceSubmitTemplate(w http.ResponseWriter, r *http.Request) {
	var t services.CommunityTemplate
	if err := decodeJSON(r, &t); err != nil || t.Title == "" {
		http.Error(w, `{"error":"title required"}`, http.StatusBadRequest)
		return
	}
	writeJSON(w, map[string]any{"template": services.MarketplaceSubmitTemplate(t)})
}

func MarketplaceGetReviews(w http.ResponseWriter, r *http.Request) {
	extID := chi.URLParam(r, "extensionId")
	writeJSON(w, map[string]any{"reviews": services.MarketplaceGetReviews(extID)})
}

func MarketplacePostReview(w http.ResponseWriter, r *http.Request) {
	var body struct {
		ExtensionID string  `json:"extension_id"`
		Username    string  `json:"username"`
		Rating      float64 `json:"rating"`
		Comment     string  `json:"comment"`
	}
	if err := decodeJSON(r, &body); err != nil || body.ExtensionID == "" {
		http.Error(w, `{"error":"extension_id required"}`, http.StatusBadRequest)
		return
	}
	writeJSON(w, map[string]any{"review": services.MarketplacePostReview(body.ExtensionID, body.Username, body.Rating, body.Comment)})
}

func MarketplacePurchase(w http.ResponseWriter, r *http.Request) {
	var body struct {
		ItemID   string  `json:"item_id"`
		ItemName string  `json:"item_name"`
		BuyerID  string  `json:"buyer_id"`
		PriceUSD float64 `json:"price_usd"`
	}
	if err := decodeJSON(r, &body); err != nil || body.ItemID == "" {
		http.Error(w, `{"error":"item_id required"}`, http.StatusBadRequest)
		return
	}
	writeJSON(w, services.MarketplacePurchase(body.ItemID, body.ItemName, body.BuyerID, body.PriceUSD))
}

func MarketplaceAnalytics(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, services.MarketplaceGetAnalytics())
}
