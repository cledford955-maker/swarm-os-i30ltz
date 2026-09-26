use futures_util::StreamExt;
use reqwest::Client;
use serde::{Deserialize, Serialize};

const BASE: &str = "http://localhost:5000";

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct ChatMsg {
    pub role: String,
    pub content: String,
}

#[derive(Debug, Deserialize, Clone, Default)]
pub struct LucilleEngineStatus {
    pub status: String,
    #[serde(default)] pub user: String,
    #[serde(default)] pub uid: i32,
    #[serde(default)] pub p_cores: i32,
    #[serde(default)] pub e_cores: i32,
    #[serde(default)] pub total_ram_mb: i64,
    #[serde(default)] pub cgroup_memory_high_mb: i64,
    #[serde(default)] pub soul_sha256: String,
    #[serde(default)] pub active_processes: i32,
}

impl LucilleEngineStatus {
    pub fn is_running(&self) -> bool {
        self.status == "running"
    }
}

#[derive(Debug, Deserialize, Clone, Default)]
pub struct PipelineResult {
    #[serde(default)] pub success: bool,
    #[serde(default)] pub blocks: i32,
    #[serde(default)] pub passed: i32,
    #[serde(default)] pub rejected: i32,
    #[serde(default)] pub high_risk: bool,
    #[serde(default)] pub consensus: bool,
    #[serde(default)] pub human: bool,
    #[serde(default)] pub applied: bool,
    #[serde(default)] pub checkpoint: String,
    #[serde(default)] pub latency_ms: i64,
    #[serde(rename = "mock", default)] pub is_mock: bool,
    #[serde(default)] pub error: Option<String>,
}

// Field names verified against LucyServer/Services/ISystemIntegrationService.cs —
// ASP.NET's default Web JSON policy (camelCase) applies, no [JsonPropertyName] overrides exist.
// NOTE: LucyServer has NO disk-usage endpoint at all — do not fabricate one here.
#[derive(Debug, Deserialize, Clone, Default)]
pub struct SystemStats {
    #[serde(rename = "cpuUsagePercentage")] pub cpu_usage_percentage: f64,
    #[serde(rename = "totalMemoryMb")]      pub total_memory_mb: f64,
    #[serde(rename = "usedMemoryMb")]       pub used_memory_mb: f64,
    // Mirrors the server's field for shape fidelity; not shown separately
    // since used/total already conveys it. Wire it up if the UI ever needs it.
    #[allow(dead_code)]
    #[serde(rename = "freeMemoryMb")]       pub free_memory_mb: f64,
}

#[derive(Debug, Deserialize, Clone)]
pub struct ProcessInfo {
    pub pid: i32,
    pub name: String,
    #[serde(rename = "memoryUsageMb")] pub memory_usage_mb: f64,
}

#[derive(Clone)]
pub struct LucyClient {
    client: Client,
}

impl LucyClient {
    pub fn new() -> Self {
        Self { client: Client::new() }
    }

    pub async fn lucille_status(&self) -> reqwest::Result<LucilleEngineStatus> {
        self.client.get(format!("{BASE}/api/lucille/status"))
            .send().await?
            .json::<LucilleEngineStatus>().await
    }

    pub async fn lucille_pipeline(&self, task_id: &str, instruction: &str, target_file: &str, content: &str, language: &str, workspace: &str) -> reqwest::Result<PipelineResult> {
        #[derive(Serialize)]
        struct Body {
            task_id: String,
            instruction: String,
            target_file: String,
            content: String,
            language: String,
            workspace: String,
        }
        self.client.post(format!("{BASE}/api/lucille/pipeline"))
            .json(&Body {
                task_id: task_id.to_string(),
                instruction: instruction.to_string(),
                target_file: target_file.to_string(),
                content: content.to_string(),
                language: language.to_string(),
                workspace: workspace.to_string(),
            })
            .send().await?
            .json::<PipelineResult>().await
    }

    pub async fn get_system_stats(&self) -> reqwest::Result<SystemStats> {
        self.client.get(format!("{BASE}/api/system/stats"))
            .send().await?
            .json::<SystemStats>().await
    }

    pub async fn get_processes(&self) -> reqwest::Result<Vec<ProcessInfo>> {
        self.client.get(format!("{BASE}/api/system/processes"))
            .send().await?
            .json::<Vec<ProcessInfo>>().await
    }

    pub async fn kill_process(&self, pid: i32) -> reqwest::Result<()> {
        #[derive(Serialize)]
        struct Body { pid: i32 }
        self.client.post(format!("{BASE}/api/system/process/kill"))
            .json(&Body { pid })
            .send().await?;
        Ok(())
    }

    /// Streams a chat reply token-by-token from LucyServer's general
    /// orchestrator endpoint (`/lucy`, NOT `/api/lucy` — it sits outside the
    /// `/api/` prefix and so isn't behind swarmAuthMiddleware, same as the
    /// system-stats calls above; no auth header needed). This is the real
    /// general-purpose Lucille — distinct from GamingClient::chat_stream,
    /// which is GamingAgent's gaming-context chat on a different port.
    ///
    /// modelId defaults to the coding swarm's lead model (moonshotai/kimi-k2.6,
    /// see frontend/lib/models/swarm.dart's default-coding-swarm) rather than
    /// leaving it blank — StreamChat on the Go side falls back to a Nemotron
    /// NIM model on an empty modelId, which would silently make this "coding"
    /// panel gaming-flavored again.
    ///
    /// /lucy's SSE framing is simpler than GamingAgent's: plain `data: <chunk>`
    /// lines with no `event:` frames, terminated by `data: [DONE]` — no
    /// session id is emitted, so multi-turn context here is client-side only
    /// (the full message history is resent every call, same as a stateless
    /// completion API).
    pub async fn chat_stream<F>(&self, messages: Vec<ChatMsg>, mut on_token: F) -> reqwest::Result<()>
    where
        F: FnMut(String) + Send,
    {
        #[derive(Serialize)]
        struct Body {
            #[serde(rename = "modelId")]
            model_id: String,
            messages: Vec<ChatMsg>,
            #[serde(rename = "autoRoute")]
            auto_route: bool,
        }

        let resp = self.client.post(format!("{BASE}/lucy"))
            .json(&Body { model_id: "moonshotai/kimi-k2.6".to_string(), messages, auto_route: false })
            .send().await?;

        let mut stream = resp.bytes_stream();
        let mut buf = String::new();

        while let Some(chunk) = stream.next().await {
            let chunk = chunk?;
            buf.push_str(&String::from_utf8_lossy(&chunk));

            while let Some(pos) = buf.find('\n') {
                let line = buf[..pos].trim_end_matches('\r').to_string();
                buf.drain(..=pos);

                if let Some(rest) = line.strip_prefix("data: ") {
                    if rest != "[DONE]" {
                        // The handler escapes literal newlines within a chunk as
                        // the two characters \n (see LucyHandler's sseWrite) so a
                        // multi-line reply still round-trips as a single SSE line.
                        on_token(rest.replace("\\n", "\n"));
                    }
                }
            }
        }
        Ok(())
    }
}
