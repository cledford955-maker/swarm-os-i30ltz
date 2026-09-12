use reqwest::Client;
use serde::{Deserialize, Serialize};

const BASE: &str = "http://localhost:5000";

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
}
