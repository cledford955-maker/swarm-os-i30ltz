using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using LucyServer.Models;

namespace LucyServer.Services.Ecosystem
{
    public class CloudWorkspaceService
    {
        private readonly List<CloudWorkspace> _workspaces = new();

        public CloudWorkspaceService()
        {
            // Seed default ready-to-connect remote cloud dev environments
            _workspaces.Add(new CloudWorkspace
            {
                WorkspaceId = "cloud-us-east-gpu",
                Name = "NVIDIA Tensor Swarm Cluster (US-East)",
                RemoteHost = "cluster-east.swarm-os.cloud",
                SshPort = 2222,
                Username = "swarm-developer",
                RemotePath = "/opt/swarm/ai-workspace",
                Status = "Connected",
                LatencyMs = 24,
                MemoryUsedMb = 24576,
                MemoryTotalMb = 65536,
                CpuUsagePercent = 18.5
            });

            _workspaces.Add(new CloudWorkspace
            {
                WorkspaceId = "cloud-eu-west-arm",
                Name = "Ampere Arm64 Enterprise Sandbox (Frankfurt)",
                RemoteHost = "arm-eu.swarm-os.cloud",
                SshPort = 22,
                Username = "i30ltz",
                RemotePath = "/home/i30ltz/src/lucille",
                Status = "Connected",
                LatencyMs = 68,
                MemoryUsedMb = 8192,
                MemoryTotalMb = 32768,
                CpuUsagePercent = 9.2
            });

            _workspaces.Add(new CloudWorkspace
            {
                WorkspaceId = "cloud-edge-baremetal",
                Name = "Baremetal Microk8s Development Node",
                RemoteHost = "edge-node-01.local",
                SshPort = 22,
                Username = "root",
                RemotePath = "/var/swarm/k8s",
                Status = "Disconnected",
                LatencyMs = 3,
                MemoryUsedMb = 4096,
                MemoryTotalMb = 16384,
                CpuUsagePercent = 2.4
            });
        }

        public Task<List<CloudWorkspace>> GetAllWorkspacesAsync()
        {
            return Task.FromResult(_workspaces.ToList());
        }

        public Task<CloudWorkspace> CreateWorkspaceAsync(string name, string host, int port, string username, string remotePath)
        {
            var ws = new CloudWorkspace
            {
                Name = name,
                RemoteHost = host,
                SshPort = port,
                Username = username,
                RemotePath = remotePath,
                Status = "Connected",
                LatencyMs = 15,
                MemoryTotalMb = 32768,
                MemoryUsedMb = 6144,
                CpuUsagePercent = 5.0
            };
            _workspaces.Add(ws);
            return Task.FromResult(ws);
        }

        public Task<bool> SyncWorkspaceFilesAsync(string workspaceId)
        {
            var ws = _workspaces.FirstOrDefault(w => w.WorkspaceId == workspaceId);
            if (ws == null) return Task.FromResult(false);

            ws.Status = "Syncing";
            ws.LastSyncedAt = DateTime.UtcNow;
            ws.Status = "Connected";
            return Task.FromResult(true);
        }

        public Task<bool> DeleteWorkspaceAsync(string workspaceId)
        {
            var ws = _workspaces.FirstOrDefault(w => w.WorkspaceId == workspaceId);
            if (ws == null) return Task.FromResult(false);
            _workspaces.Remove(ws);
            return Task.FromResult(true);
        }
    }
}
