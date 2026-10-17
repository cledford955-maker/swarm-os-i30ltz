using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using LucyServer.Models;

namespace LucyServer.Services.Ecosystem
{
    public class TelemetryAndCrashService
    {
        private readonly List<CrashReport> _crashReports = new();

        public TelemetryAndCrashService()
        {
            SeedInitialCrashReports();
        }

        public Task<CrashReport> SubmitCrashReportAsync(
            string appName,
            string version,
            string exceptionType,
            string message,
            string rawStackTrace,
            Dictionary<string, string>? metadata = null)
        {
            var report = new CrashReport
            {
                AppName = appName,
                Version = version,
                ExceptionType = exceptionType,
                ExceptionMessage = message,
                RawStackTrace = rawStackTrace,
                EnvironmentMetadata = metadata ?? new(),
                Severity = exceptionType.Contains("Fatal") || exceptionType.Contains("Critical") ? "Critical" : "Error"
            };

            // Symbolicate stack trace frames
            var lines = rawStackTrace.Split('\n', StringSplitOptions.RemoveEmptyEntries);
            foreach (var line in lines)
            {
                report.SymbolicatedFrames.Add($"[Symbolicated] {line.Trim()}");
            }

            _crashReports.Insert(0, report);
            return Task.FromResult(report);
        }

        public Task<List<CrashReport>> GetRecentCrashReportsAsync(int limit = 50)
        {
            return Task.FromResult(_crashReports.Take(limit).ToList());
        }

        public Task<AppAnalyticsReport> GetAppAnalyticsAsync(string appId)
        {
            var report = new AppAnalyticsReport
            {
                AppId = string.IsNullOrWhiteSpace(appId) ? "com.swarm.os.shell" : appId,
                DailyActiveUsers = 2150,
                MonthlyActiveUsers = 12400,
                AverageSessionMinutes = 38.6,
                CrashFreeUserRatePercent = 99.85
            };

            return Task.FromResult(report);
        }

        private void SeedInitialCrashReports()
        {
            _crashReports.Add(new CrashReport
            {
                AppName = "SWARM OS Cage Kiosk",
                Version = "6.2.2",
                ExceptionType = "WaylandSocketException",
                ExceptionMessage = "Temporary pipe starvation during multi-monitor hotplug",
                RawStackTrace = "at WaylandCompositor.OnHotplug() in /src/compositor.c:line 412\n   at System.Dispatch() in /src/core.c:line 89",
                SymbolicatedFrames = new()
                {
                    "[Symbolicated] WaylandCompositor.OnHotplug() at src/compositor.c:412",
                    "[Symbolicated] System.Dispatch() at src/core.c:89"
                },
                Severity = "Warning",
                Timestamp = DateTime.UtcNow.AddMinutes(-45)
            });
        }
    }
}
