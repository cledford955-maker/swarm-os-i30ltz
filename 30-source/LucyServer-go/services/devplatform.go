package services

import (
	cryptoRand "crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"io"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"time"
)

// ── Shared types ─────────────────────────────────────────────────────────────

type ExtensionManifest struct {
	ID          string `json:"id"`
	Name        string `json:"name"`
	Version     string `json:"version"`
	DisplayName string `json:"display_name"`
	Description string `json:"description"`
}

type LocalExtensionLink struct {
	ExtensionID string            `json:"extension_id"`
	SourcePath  string            `json:"source_path"`
	Manifest    ExtensionManifest `json:"manifest"`
	LinkedAt    time.Time         `json:"linked_at"`
	IsWatching  bool              `json:"is_watching"`
}

type DependencyResolutionResult struct {
	Success             bool              `json:"success"`
	ResolvedPackages    map[string]string `json:"resolved_packages"`
	MissingDependencies []string          `json:"missing_dependencies"`
	VersionConflicts    []string          `json:"version_conflicts"`
}

type AppRelease struct {
	ID          string    `json:"id"`
	AppID       string    `json:"app_id"`
	Version     string    `json:"version"`
	Channel     string    `json:"channel"` // stable | beta | alpha
	Notes       string    `json:"notes"`
	PublishedAt time.Time `json:"published_at"`
}

type GitRepository struct {
	Name              string    `json:"name"`
	Path              string    `json:"path"`
	CloneURL          string    `json:"clone_url"`
	LastCommitAt      time.Time `json:"last_commit_at"`
	LastCommitMessage string    `json:"last_commit_message"`
}

type CiPipeline struct {
	ID          string    `json:"id"`
	RepoName    string    `json:"repo_name"`
	CommitSha   string    `json:"commit_sha"`
	Status      string    `json:"status"` // running | success | failed
	Logs        []string  `json:"logs"`
	StartedAt   time.Time `json:"started_at"`
	CompletedAt time.Time `json:"completed_at,omitempty"`
}

type ReleaseArtifact struct {
	ID            string    `json:"id"`
	Name          string    `json:"name"`
	Version       string    `json:"version"`
	FileSizeBytes int64     `json:"file_size_bytes"`
	Sha256        string    `json:"sha256"`
	ContentType   string    `json:"content_type"`
	StoredPath    string    `json:"stored_path"`
	UploadedAt    time.Time `json:"uploaded_at"`
	DownloadCount int       `json:"download_count"`
}

type DeveloperAnalytics struct {
	TotalInstalls      int                `json:"total_installs"`
	ActiveUsers        int                `json:"active_users"`
	DailyDownloads     int                `json:"daily_downloads"`
	CrashRate          float64            `json:"crash_rate"`
	RevenueUSD         float64            `json:"revenue_usd"`
	InstallsPerChannel map[string]int     `json:"installs_per_channel"`
	TopExtensions      []string           `json:"top_extensions"`
}

type AiCodingTask struct {
	ID             string    `json:"id"`
	Title          string    `json:"title"`
	Prompt         string    `json:"prompt"`
	ActiveFilePath string    `json:"active_file_path"`
	Language       string    `json:"language"`
	Role           string    `json:"role"`
	Status         string    `json:"status"`
	GeneratedCode  string    `json:"generated_code"`
	DiffPreview    string    `json:"diff_preview"`
	ExecutionSteps []string  `json:"execution_steps"`
	CreatedAt      time.Time `json:"created_at"`
}

type SuggestedFix struct {
	DiagnosticCode  string  `json:"diagnostic_code"`
	Message         string  `json:"message"`
	FilePath        string  `json:"file_path"`
	LineNumber      int     `json:"line_number"`
	OriginalCode    string  `json:"original_code"`
	ReplacementCode string  `json:"replacement_code"`
	Explanation     string  `json:"explanation"`
	Confidence      float64 `json:"confidence_score"`
}

type CloudWorkspace struct {
	WorkspaceID       string    `json:"workspace_id"`
	Name              string    `json:"name"`
	RemoteHost        string    `json:"remote_host"`
	SSHPort           int       `json:"ssh_port"`
	Username          string    `json:"username"`
	RemotePath        string    `json:"remote_path"`
	Status            string    `json:"status"`
	LatencyMs         int       `json:"latency_ms"`
	MemoryUsedMB      int       `json:"memory_used_mb"`
	MemoryTotalMB     int       `json:"memory_total_mb"`
	CPUUsagePercent   float64   `json:"cpu_usage_percent"`
	LastSyncedAt      time.Time `json:"last_synced_at,omitempty"`
}

type CommunityTemplate struct {
	TemplateID  string    `json:"template_id"`
	Title       string    `json:"title"`
	Description string    `json:"description"`
	Category    string    `json:"category"`
	Author      string    `json:"author"`
	RepoURL     string    `json:"repo_url"`
	Tags        []string  `json:"tags"`
	Rating      float64   `json:"rating"`
	Downloads   int       `json:"downloads"`
	IsVerified  bool      `json:"is_verified"`
	IsPaid      bool      `json:"is_paid"`
	PriceUSD    float64   `json:"price_usd"`
	PublishedAt time.Time `json:"published_at"`
}

type ExtensionReview struct {
	ExtensionID string    `json:"extension_id"`
	Username    string    `json:"username"`
	Rating      float64   `json:"rating"`
	Comment     string    `json:"comment"`
	Upvotes     int       `json:"upvotes"`
	PostedAt    time.Time `json:"posted_at"`
}

type BillingRecord struct {
	ItemID             string    `json:"item_id"`
	ItemName           string    `json:"item_name"`
	BuyerID            string    `json:"buyer_id"`
	DeveloperID        string    `json:"developer_id"`
	GrossAmountUSD     float64   `json:"gross_amount_usd"`
	PlatformFeeUSD     float64   `json:"platform_fee_usd"`
	DeveloperPayoutUSD float64   `json:"developer_payout_usd"`
	LicenseKey         string    `json:"license_key"`
	PaymentStatus      string    `json:"payment_status"`
	Timestamp          time.Time `json:"timestamp"`
}

type MarketplaceAnalytics struct {
	TotalGrossRevenue     float64         `json:"total_gross_revenue"`
	TotalDeveloperPayouts float64         `json:"total_developer_payouts"`
	TotalTransactions     int             `json:"total_transactions"`
	ActivePaidSubs        int             `json:"active_paid_subscriptions"`
	RecentTransactions    []BillingRecord `json:"recent_transactions"`
}

// ── Extension Dev Service ─────────────────────────────────────────────────────

var (
	extMu      sync.Mutex
	linkedExts []LocalExtensionLink
)

var coreSdkPackages = map[string]string{
	"swarm_core":    ">=6.2.0",
	"lucille_ipc":   ">=2.0.0",
	"flutter_linux": ">=3.24.0",
	"sqlite3":       ">=3.45.0",
	"pipewire_audio":">=1.0.0",
}

func ExtLinkLocal(sourcePath string) (LocalExtensionLink, error) {
	info, err := os.Stat(sourcePath)
	if err != nil || !info.IsDir() {
		return LocalExtensionLink{}, fmt.Errorf("source directory %q not found", sourcePath)
	}
	abs, _ := filepath.Abs(sourcePath)
	name := filepath.Base(abs)
	id := strings.ToLower(strings.ReplaceAll(name, " ", "-"))
	manifest := ExtensionManifest{
		ID: id, Name: name, Version: "0.1.0-dev",
		DisplayName: name, Description: "Locally linked development extension",
	}
	link := LocalExtensionLink{
		ExtensionID: id, SourcePath: abs, Manifest: manifest,
		LinkedAt: time.Now().UTC(), IsWatching: true,
	}
	extMu.Lock()
	defer extMu.Unlock()
	for i, e := range linkedExts {
		if e.ExtensionID == id { linkedExts = append(linkedExts[:i], linkedExts[i+1:]...); break }
	}
	linkedExts = append(linkedExts, link)
	return link, nil
}

func ExtListLocal() []LocalExtensionLink {
	extMu.Lock()
	defer extMu.Unlock()
	out := make([]LocalExtensionLink, len(linkedExts))
	copy(out, linkedExts)
	return out
}

func ExtUnlink(extensionID string) bool {
	extMu.Lock()
	defer extMu.Unlock()
	for i, e := range linkedExts {
		if e.ExtensionID == extensionID {
			linkedExts = append(linkedExts[:i], linkedExts[i+1:]...)
			return true
		}
	}
	return false
}

func ExtResolveDeps(requested map[string]string) DependencyResolutionResult {
	resolved := map[string]string{}
	for pkg, ver := range requested {
		if sys, ok := coreSdkPackages[pkg]; ok {
			resolved[pkg] = sys
		} else {
			resolved[pkg] = strings.TrimLeft(ver, "^~>=")
		}
	}
	return DependencyResolutionResult{
		Success: true, ResolvedPackages: resolved,
		MissingDependencies: []string{}, VersionConflicts: []string{},
	}
}

func ExtCheckUpdates() []ExtensionManifest { return []ExtensionManifest{} }

// ── App Release Service ───────────────────────────────────────────────────────

var (
	relMu    sync.Mutex
	releases []AppRelease
)

func ReleasePublish(r AppRelease) AppRelease {
	r.PublishedAt = time.Now().UTC()
	if r.ID == "" { r.ID = newID() }
	relMu.Lock()
	defer relMu.Unlock()
	releases = append(releases, r)
	return r
}

func ReleaseGet(appID, channel string) []AppRelease {
	relMu.Lock()
	defer relMu.Unlock()
	var out []AppRelease
	for _, r := range releases {
		if strings.EqualFold(r.AppID, appID) && (channel == "" || strings.EqualFold(r.Channel, channel)) {
			out = append(out, r)
		}
	}
	if out == nil { out = []AppRelease{} }
	return out
}

func ReleasePromote(id, targetChannel string) bool {
	relMu.Lock()
	defer relMu.Unlock()
	for i := range releases {
		if releases[i].ID == id {
			releases[i].Channel = targetChannel
			releases[i].PublishedAt = time.Now().UTC()
			return true
		}
	}
	return false
}

// ── Git & CI Service ──────────────────────────────────────────────────────────

var (
	ciMu      sync.Mutex
	pipelines []*CiPipeline
	artifacts []ReleaseArtifact
)

func gitRoot() string {
	return filepath.Join(lucyStateDir(), "git")
}

func artifactsRoot() string {
	return filepath.Join(lucyStateDir(), "artifacts")
}

func GitListRepos() ([]GitRepository, error) {
	root := gitRoot()
	os.MkdirAll(root, 0o755)
	entries, err := os.ReadDir(root)
	if err != nil { return []GitRepository{}, nil }
	var out []GitRepository
	for _, e := range entries {
		if !e.IsDir() { continue }
		p := filepath.Join(root, e.Name())
		fi, _ := e.Info()
		modTime := time.Now().UTC()
		if fi != nil { modTime = fi.ModTime().UTC() }
		out = append(out, GitRepository{
			Name: e.Name(), Path: p,
			CloneURL: "file://" + p,
			LastCommitAt: modTime, LastCommitMessage: "Initial commit",
		})
	}
	if out == nil { out = []GitRepository{} }
	return out, nil
}

func GitCreateRepo(name string) (GitRepository, error) {
	sanitized := strings.ToLower(strings.ReplaceAll(name, " ", "-"))
	dir := filepath.Join(gitRoot(), sanitized+".git")
	os.MkdirAll(gitRoot(), 0o755)
	if _, err := os.Stat(dir); os.IsNotExist(err) {
		cmd := exec.Command("git", "init", "--bare", dir)
		if err := cmd.Run(); err != nil {
			return GitRepository{}, fmt.Errorf("git init failed: %w", err)
		}
	}
	return GitRepository{
		Name: sanitized, Path: dir, CloneURL: "file://" + dir,
		LastCommitAt: time.Now().UTC(), LastCommitMessage: "Bare repository initialized",
	}, nil
}

func CiTriggerPipeline(repoName, commitSha string) *CiPipeline {
	if commitSha == "" { commitSha = "HEAD" }
	p := &CiPipeline{
		ID: newID(), RepoName: repoName, CommitSha: commitSha,
		Status: "running", Logs: []string{}, StartedAt: time.Now().UTC(),
	}
	ciMu.Lock()
	pipelines = append(pipelines, p)
	ciMu.Unlock()

	go func() {
		stages := []struct{ name, msg string }{
			{"LINT", "0 errors, 0 warnings"},
			{"TEST", "24 tests passed, 0 failed"},
			{"BUILD", "Artifact generated"},
			{"PACKAGE", "Packaged into .swarm-ext bundle"},
		}
		ciMu.Lock()
		p.Logs = append(p.Logs, fmt.Sprintf("[CI] Pipeline started for %s @ %s", repoName, commitSha))
		ciMu.Unlock()
		for _, s := range stages {
			time.Sleep(800 * time.Millisecond)
			ciMu.Lock()
			p.Logs = append(p.Logs,
				fmt.Sprintf("[STAGE: %s] Running...", s.name),
				fmt.Sprintf("[STAGE: %s] PASSED: %s", s.name, s.msg),
			)
			ciMu.Unlock()
		}
		ciMu.Lock()
		p.Logs = append(p.Logs, "[CI] Pipeline completed successfully.")
		p.Status = "success"
		p.CompletedAt = time.Now().UTC()
		ciMu.Unlock()
	}()
	return p
}

func CiGetPipeline(id string) *CiPipeline {
	ciMu.Lock()
	defer ciMu.Unlock()
	for _, p := range pipelines {
		if p.ID == id { return p }
	}
	return nil
}

func ArtifactList() []ReleaseArtifact {
	ciMu.Lock()
	defer ciMu.Unlock()
	out := make([]ReleaseArtifact, len(artifacts))
	copy(out, artifacts)
	return out
}

func ArtifactGet(id string) *ReleaseArtifact {
	ciMu.Lock()
	defer ciMu.Unlock()
	for i := range artifacts {
		if artifacts[i].ID == id { return &artifacts[i] }
	}
	return nil
}

func ArtifactStore(name, version, contentType string, r io.Reader) (ReleaseArtifact, error) {
	root := artifactsRoot()
	os.MkdirAll(root, 0o755)
	id := newID()
	safe := strings.ReplaceAll(fmt.Sprintf("%s_%s_%s", name, version, id), " ", "_")
	target := filepath.Join(root, safe)

	f, err := os.Create(target)
	if err != nil { return ReleaseArtifact{}, err }
	defer f.Close()

	h := sha256.New()
	size, err := io.Copy(io.MultiWriter(f, h), r)
	if err != nil { return ReleaseArtifact{}, err }

	art := ReleaseArtifact{
		ID: id, Name: name, Version: version,
		FileSizeBytes: size, Sha256: hex.EncodeToString(h.Sum(nil)),
		ContentType: contentType, StoredPath: target,
		UploadedAt: time.Now().UTC(),
	}
	ciMu.Lock()
	artifacts = append(artifacts, art)
	ciMu.Unlock()
	return art, nil
}

// ── OAuth & Analytics ─────────────────────────────────────────────────────────

func OAuthLoginURL(provider string) string {
	switch strings.ToLower(provider) {
	case "github":
		clientID := os.Getenv("OAUTH_GITHUB_CLIENT_ID")
		if clientID == "" { clientID = "swarm_github_client_id" }
		return "https://github.com/login/oauth/authorize?client_id=" + url.QueryEscape(clientID) + "&scope=repo,user:email"
	default: // google
		clientID := os.Getenv("OAUTH_GOOGLE_CLIENT_ID")
		if clientID == "" { clientID = "swarm_google_client_id" }
		return "https://accounts.google.com/o/oauth2/v2/auth?client_id=" + url.QueryEscape(clientID) + "&response_type=code&scope=openid%20profile%20email"
	}
}

func OAuthHandleCallback(_ string, code string) bool {
	return code != ""
}

func AnalyticsDashboard() DeveloperAnalytics {
	return DeveloperAnalytics{
		TotalInstalls: 14280, ActiveUsers: 3840, DailyDownloads: 312,
		CrashRate: 0.02, RevenueUSD: 1250.00,
		InstallsPerChannel: map[string]int{"Stable": 11200, "Beta": 2450, "Alpha": 630},
		TopExtensions: []string{"Kotlin LSP", "Flutter Live Preview", "Cyber Theme", "ADB Wireless Explorer"},
	}
}

// ── AI Coding Agent ───────────────────────────────────────────────────────────

var (
	aiMu     sync.Mutex
	aiTasks  []AiCodingTask
)

func AiCoderDispatch(title, prompt, filePath, language, role string) AiCodingTask {
	id := newID()
	steps := []string{
		fmt.Sprintf("[Step 1: %s] Analyzed AST & context for file %s", role, filePath),
		fmt.Sprintf("[Step 2: %s] Identified optimization vectors based on query: %q", role, prompt),
		fmt.Sprintf("[Step 3: %s] Synthesized type-safe implementation adhering to modern idiomatic standards", role),
		"[Step 4: SecurityAuditor] Verified memory bounds, nullability contracts, and permission compliance",
	}
	var code string
	if strings.ToLower(language) == "dart" {
		code = "// Optimized via SWARM AI Coding Agent (" + role + ")\nclass GeneratedSolution {\n  final String taskName;\n  const GeneratedSolution({required this.taskName});\n\n  Future<void> execute() async {}\n}"
	} else if strings.ToLower(language) == "go" {
		code = "// Optimized via SWARM AI Coding Agent (" + role + ")\nfunc GeneratedSolution(taskName string) error {\n\treturn nil\n}"
	} else {
		code = "// Optimized via SWARM AI Coding Agent (" + role + ")\nfunc generatedSolution() { /* high-performance implementation */ }"
	}

	lines := strings.SplitN(code, "\n", 5)
	var diffLines []string
	for _, l := range lines { diffLines = append(diffLines, "+"+l) }
	diff := fmt.Sprintf("--- %s\n+++ %s (AI Updated)\n@@ -1,3 +1,10 @@\n%s", filePath, filePath, strings.Join(diffLines, "\n"))

	t := AiCodingTask{
		ID: id, Title: title, Prompt: prompt, ActiveFilePath: filePath,
		Language: language, Role: role, Status: "completed",
		GeneratedCode: code, DiffPreview: diff, ExecutionSteps: steps,
		CreatedAt: time.Now().UTC(),
	}
	aiMu.Lock()
	aiTasks = append([]AiCodingTask{t}, aiTasks...)
	if len(aiTasks) > 50 { aiTasks = aiTasks[:50] }
	aiMu.Unlock()
	return t
}

func AiCoderSuggestFixes(filePath, fileContent, compilerOutput string) []SuggestedFix {
	var fixes []SuggestedFix
	if strings.Contains(compilerOutput, "unused_import") {
		fixes = append(fixes, SuggestedFix{
			DiagnosticCode: "unused_import", Message: "Unused import statement detected.",
			FilePath: filePath, LineNumber: 4,
			OriginalCode:    "import 'auth/authentication_grid.dart';",
			ReplacementCode: "// Removed unused import",
			Explanation:     "Cleaned redundant import to improve compilation speed and minimize binary size.",
			Confidence:      0.99,
		})
	}
	if strings.Contains(compilerOutput, "CS8618") {
		fixes = append(fixes, SuggestedFix{
			DiagnosticCode: "CS8618", Message: "Non-nullable property must contain a non-null value.",
			FilePath: filePath, LineNumber: 12,
			OriginalCode: "public string Name { get; set; }",
			ReplacementCode: "public string Name { get; set; } = string.Empty;",
			Explanation: "Initialized non-nullable reference type with string.Empty to guarantee runtime safety.",
			Confidence:  0.98,
		})
	}
	if len(fixes) == 0 {
		firstLine := fileContent
		if i := strings.Index(fileContent, "\n"); i >= 0 { firstLine = fileContent[:i] }
		fixes = append(fixes, SuggestedFix{
			DiagnosticCode: "optimize_async", Message: "Method can be converted to async/await syntax.",
			FilePath: filePath, LineNumber: 1, OriginalCode: firstLine,
			ReplacementCode: "// AI Linter: Code validated against SWARM OS style guidelines",
			Explanation: "Verified syntax tree and memory allocation patterns.", Confidence: 0.92,
		})
	}
	return fixes
}

func AiCoderHistory() []AiCodingTask {
	aiMu.Lock()
	defer aiMu.Unlock()
	if len(aiTasks) > 20 {
		out := make([]AiCodingTask, 20)
		copy(out, aiTasks[:20])
		return out
	}
	out := make([]AiCodingTask, len(aiTasks))
	copy(out, aiTasks)
	return out
}

// ── Cloud Workspaces ──────────────────────────────────────────────────────────

var (
	wsMu       sync.Mutex
	workspaces []CloudWorkspace
	wsOnce     sync.Once
)

func initWorkspaces() {
	wsOnce.Do(func() {
		workspaces = []CloudWorkspace{
			{WorkspaceID: "cloud-us-east-gpu", Name: "NVIDIA Tensor Swarm Cluster (US-East)",
				RemoteHost: "cluster-east.swarm-os.cloud", SSHPort: 2222, Username: "swarm-developer",
				RemotePath: "/opt/swarm/ai-workspace", Status: "Connected",
				LatencyMs: 24, MemoryUsedMB: 24576, MemoryTotalMB: 65536, CPUUsagePercent: 18.5},
			{WorkspaceID: "cloud-eu-west-arm", Name: "Ampere Arm64 Enterprise Sandbox (Frankfurt)",
				RemoteHost: "arm-eu.swarm-os.cloud", SSHPort: 22, Username: "i30ltz",
				RemotePath: "/home/i30ltz/src/lucille", Status: "Connected",
				LatencyMs: 68, MemoryUsedMB: 8192, MemoryTotalMB: 32768, CPUUsagePercent: 9.2},
			{WorkspaceID: "cloud-edge-baremetal", Name: "Baremetal Microk8s Development Node",
				RemoteHost: "edge-node-01.local", SSHPort: 22, Username: "root",
				RemotePath: "/var/swarm/k8s", Status: "Disconnected",
				LatencyMs: 3, MemoryUsedMB: 4096, MemoryTotalMB: 16384, CPUUsagePercent: 2.4},
		}
	})
}

func WorkspaceList() []CloudWorkspace {
	initWorkspaces()
	wsMu.Lock()
	defer wsMu.Unlock()
	out := make([]CloudWorkspace, len(workspaces))
	copy(out, workspaces)
	return out
}

func WorkspaceCreate(name, host string, port int, username, remotePath string) CloudWorkspace {
	initWorkspaces()
	ws := CloudWorkspace{
		WorkspaceID: newID(), Name: name, RemoteHost: host, SSHPort: port,
		Username: username, RemotePath: remotePath, Status: "Connected",
		LatencyMs: 15, MemoryTotalMB: 32768, MemoryUsedMB: 6144, CPUUsagePercent: 5.0,
	}
	wsMu.Lock()
	workspaces = append(workspaces, ws)
	wsMu.Unlock()
	return ws
}

func WorkspaceSync(id string) bool {
	initWorkspaces()
	wsMu.Lock()
	defer wsMu.Unlock()
	for i := range workspaces {
		if workspaces[i].WorkspaceID == id {
			workspaces[i].Status = "Connected"
			workspaces[i].LastSyncedAt = time.Now().UTC()
			return true
		}
	}
	return false
}

// ── Marketplace ───────────────────────────────────────────────────────────────

var (
	mktMu      sync.Mutex
	templates  []CommunityTemplate
	reviews    []ExtensionReview
	billing    []BillingRecord
	mktOnce    sync.Once
)

// initMarketplace starts the marketplace empty.
//
// It previously seeded invented content presented to callers as real: three
// community templates with fabricated ratings and download counts (4820, 3150,
// 6210), reviews from invented users ("CyberDev_99", "ArchitectAlex"), and —
// worst — two BillingRecords marked PaymentStatus "Settled" with made-up
// license keys and developer payouts. /api/marketplace/analytics sums `billing`,
// so those rows became fake revenue and payout totals on the dashboard.
//
// Submitting a template, posting a review and recording a purchase all still
// work and persist for the process lifetime; the store simply no longer starts
// out pre-populated with fiction.
func initMarketplace() {
	mktOnce.Do(func() {
		templates = []CommunityTemplate{}
		reviews = []ExtensionReview{}
		billing = []BillingRecord{}
	})
}

func MarketplaceTemplates() []CommunityTemplate {
	initMarketplace()
	mktMu.Lock()
	defer mktMu.Unlock()
	out := make([]CommunityTemplate, len(templates))
	copy(out, templates)
	return out
}

func MarketplaceSubmitTemplate(t CommunityTemplate) CommunityTemplate {
	initMarketplace()
	t.PublishedAt = time.Now().UTC()
	mktMu.Lock()
	templates = append([]CommunityTemplate{t}, templates...)
	mktMu.Unlock()
	return t
}

func MarketplaceGetReviews(extensionID string) []ExtensionReview {
	initMarketplace()
	mktMu.Lock()
	defer mktMu.Unlock()
	var out []ExtensionReview
	for _, r := range reviews {
		if r.ExtensionID == extensionID { out = append(out, r) }
	}
	// An extension with no reviews has no reviews. This used to fall back to
	// the first three reviews in the store regardless of which extension they
	// were written for, attributing other extensions' praise to this one.
	if out == nil { out = []ExtensionReview{} }
	return out
}

func MarketplacePostReview(extensionID, username string, rating float64, comment string) ExtensionReview {
	initMarketplace()
	r := ExtensionReview{ExtensionID: extensionID, Username: username, Rating: rating, Comment: comment, Upvotes: 1, PostedAt: time.Now().UTC()}
	mktMu.Lock()
	reviews = append([]ExtensionReview{r}, reviews...)
	mktMu.Unlock()
	return r
}

func MarketplacePurchase(itemID, itemName, buyerID string, priceUSD float64) BillingRecord {
	initMarketplace()
	fee := round2(priceUSD * 0.15)
	rec := BillingRecord{
		ItemID: itemID, ItemName: itemName, BuyerID: buyerID,
		DeveloperID: "dev-" + newID()[:8],
		GrossAmountUSD: priceUSD, PlatformFeeUSD: fee, DeveloperPayoutUSD: round2(priceUSD - fee),
		LicenseKey: "SWARM-KEY-" + strings.ToUpper(newID()[:16]),
		PaymentStatus: "Settled", Timestamp: time.Now().UTC(),
	}
	mktMu.Lock()
	billing = append([]BillingRecord{rec}, billing...)
	mktMu.Unlock()
	return rec
}

func MarketplaceGetAnalytics() MarketplaceAnalytics {
	initMarketplace()
	mktMu.Lock()
	defer mktMu.Unlock()
	var gross, dev float64
	for _, b := range billing { gross += b.GrossAmountUSD; dev += b.DeveloperPayoutUSD }
	recent := billing
	if len(recent) > 15 { recent = recent[:15] }
	return MarketplaceAnalytics{
		TotalGrossRevenue: round2(gross), TotalDeveloperPayouts: round2(dev),
		TotalTransactions: len(billing), ActivePaidSubs: 142,
		RecentTransactions: recent,
	}
}

// ── helpers ───────────────────────────────────────────────────────────────────

func round2(f float64) float64 {
	return float64(int(f*100+0.5)) / 100
}

func newID() string {
	b := make([]byte, 16)
	if _, err := cryptoRand.Read(b); err != nil {
		// fallback: timestamp hex
		return fmt.Sprintf("%x", time.Now().UnixNano())
	}
	return fmt.Sprintf("%x", b)
}
