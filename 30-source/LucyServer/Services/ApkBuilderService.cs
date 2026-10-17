using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading;
using System.Threading.Tasks;

namespace LucyServer.Services.Android
{
    /// <summary>
    /// Manages APK building for Kotlin/Flutter Android projects
    /// </summary>
    public class ApkBuilderService
    {
        public class BuildConfig
        {
            public string ProjectPath { get; set; }
            public string BuildType { get; set; } = "debug"; // debug, release
            public string FlavorName { get; set; } // optional: paid, free, etc.
            public string VersionName { get; set; }
            public int VersionCode { get; set; }
            
            // Signing (for release builds)
            public string KeystorePath { get; set; }
            public string KeystorePassword { get; set; } // Should be encrypted
            public string KeyAlias { get; set; }
            public string KeyPassword { get; set; } // Should be encrypted
        }

        public class BuildProgress
        {
            public int ProgressPercentage { get; set; }
            public string CurrentStep { get; set; }
            public string Message { get; set; }
            public DateTime Timestamp { get; set; } = DateTime.UtcNow;
        }

        public class BuildResult
        {
            public bool Success { get; set; }
            public string ApkPath { get; set; }
            public long FileSizeBytes { get; set; }
            public string ErrorMessage { get; set; }
            public List<string> BuildLogs { get; set; } = new();
            public TimeSpan Duration { get; set; }
        }

        public class ApkInfo
        {
            public string PackageName { get; set; }
            public string VersionName { get; set; }
            public int VersionCode { get; set; }
            public long FileSizeBytes { get; set; }
            public List<string> Permissions { get; set; } = new();
            public string MinSdkVersion { get; set; }
            public string TargetSdkVersion { get; set; }
            public List<string> Activities { get; set; } = new();
        }

        /// <summary>
        /// Build APK using gradle
        /// </summary>
        public async Task<BuildResult> BuildApkAsync(
            BuildConfig config,
            IProgress<BuildProgress> progressHandler = null,
            CancellationToken cancellationToken = default)
        {
            var startTime = DateTime.UtcNow;
            var result = new BuildResult();

            try
            {
                if (!Directory.Exists(config.ProjectPath))
                    throw new DirectoryNotFoundException($"Project path not found: {config.ProjectPath}");

                // Determine build command
                var buildTask = config.BuildType == "debug"
                    ? "assembleDebug"
                    : $"assemble{config.FlavorName ?? "Release"}";

                var gradleWrapper = Path.Combine(config.ProjectPath,
                    RuntimeInformation.IsOSPlatform(OSPlatform.Windows) ? "gradlew.bat" : "gradlew");

                if (!File.Exists(gradleWrapper))
                    throw new FileNotFoundException($"Gradle wrapper not found: {gradleWrapper}");

                progressHandler?.Report(new BuildProgress
                {
                    ProgressPercentage = 5,
                    CurrentStep = "Preparing build",
                    Message = $"Building APK ({config.BuildType})..."
                });

                // Execute gradle build
                var psi = new ProcessStartInfo
                {
                    FileName = gradleWrapper,
                    Arguments = $"{buildTask} -q",
                    WorkingDirectory = config.ProjectPath,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true,
                    UseShellExecute = false,
                    CreateNoWindow = true
                };

                using (var process = Process.Start(psi))
                {
                    var output = new List<string>();
                    var error = new List<string>();

                    // Read output in real-time
                    while (!process.StandardOutput.EndOfStream)
                    {
                        var line = await process.StandardOutput.ReadLineAsync();
                        if (line != null)
                        {
                            output.Add(line);
                            result.BuildLogs.Add(line);

                            // Parse progress from gradle output
                            if (line.Contains("BUILD"))
                            {
                                progressHandler?.Report(new BuildProgress
                                {
                                    ProgressPercentage = 50,
                                    CurrentStep = "Compiling sources",
                                    Message = line
                                });
                            }
                        }

                        cancellationToken.ThrowIfCancellationRequested();
                    }

                    while (!process.StandardError.EndOfStream)
                    {
                        var line = await process.StandardError.ReadLineAsync();
                        if (line != null)
                        {
                            error.Add(line);
                            result.BuildLogs.Add($"ERROR: {line}");
                        }
                    }

                    await process.WaitForExitAsync(cancellationToken);

                    if (process.ExitCode != 0)
                    {
                        result.Success = false;
                        result.ErrorMessage = string.Join("\n", error);
                        return result;
                    }
                }

                // Locate APK file
                var apkPath = FindApk(config.ProjectPath, config.BuildType, config.FlavorName);
                if (string.IsNullOrEmpty(apkPath))
                    throw new FileNotFoundException("APK not found after build");

                // Sign if release build
                if (config.BuildType == "release" && !string.IsNullOrEmpty(config.KeystorePath))
                {
                    progressHandler?.Report(new BuildProgress
                    {
                        ProgressPercentage = 90,
                        CurrentStep = "Signing APK",
                        Message = "Signing with keystore..."
                    });

                    var signedPath = await SignApkAsync(apkPath, config);
                    apkPath = signedPath;
                }

                progressHandler?.Report(new BuildProgress
                {
                    ProgressPercentage = 100,
                    CurrentStep = "Build complete",
                    Message = $"APK ready: {Path.GetFileName(apkPath)}"
                });

                var fileInfo = new FileInfo(apkPath);
                result.Success = true;
                result.ApkPath = apkPath;
                result.FileSizeBytes = fileInfo.Length;
                result.Duration = DateTime.UtcNow - startTime;

                return result;
            }
            catch (Exception ex)
            {
                result.Success = false;
                result.ErrorMessage = ex.Message;
                result.Duration = DateTime.UtcNow - startTime;
                return result;
            }
        }

        /// <summary>
        /// Sign APK with keystore (jarsigner)
        /// </summary>
        public async Task<string> SignApkAsync(
            string apkPath,
            BuildConfig config)
        {
            if (!File.Exists(config.KeystorePath))
                throw new FileNotFoundException($"Keystore not found: {config.KeystorePath}");

            var signedApkPath = Path.Combine(
                Path.GetDirectoryName(apkPath),
                Path.GetFileNameWithoutExtension(apkPath) + "-signed.apk");

            // Use jarsigner to sign
            var psi = new ProcessStartInfo
            {
                FileName = "jarsigner",
                Arguments = $"-verbose -sigalg SHA1withRSA -digestalg SHA1 " +
                           $"-keystore \"{config.KeystorePath}\" " +
                           $"-storepass {config.KeystorePassword} " +
                           $"-keypass {config.KeyPassword} " +
                           $"\"{apkPath}\" {config.KeyAlias}",
                UseShellExecute = false,
                CreateNoWindow = true
            };

            using (var process = Process.Start(psi))
            {
                await process.WaitForExitAsync();
                if (process.ExitCode != 0)
                    throw new Exception($"APK signing failed with code {process.ExitCode}");
            }

            // Align APK (improves performance)
            var alignedPath = await AlignApkAsync(signedApkPath);
            File.Delete(signedApkPath); // Remove unaligned version

            return alignedPath;
        }

        /// <summary>
        /// Align APK with zipalign (improves runtime performance)
        /// </summary>
        private async Task<string> AlignApkAsync(string apkPath)
        {
            var alignedPath = Path.Combine(
                Path.GetDirectoryName(apkPath),
                Path.GetFileNameWithoutExtension(apkPath) + "-aligned.apk");

            var psi = new ProcessStartInfo
            {
                FileName = "zipalign",
                Arguments = $"-v 4 \"{apkPath}\" \"{alignedPath}\"",
                UseShellExecute = false,
                CreateNoWindow = true
            };

            using (var process = Process.Start(psi))
            {
                await process.WaitForExitAsync();
                if (process.ExitCode != 0)
                    throw new Exception($"APK alignment failed with code {process.ExitCode}");
            }

            return alignedPath;
        }

        /// <summary>
        /// Analyze APK structure and metadata
        /// </summary>
        public async Task<ApkInfo> AnalyzeApkAsync(string apkPath)
        {
            if (!File.Exists(apkPath))
                throw new FileNotFoundException($"APK not found: {apkPath}");

            var info = new ApkInfo();

            // Extract AndroidManifest.xml and parse
            // This is a simplified version - real implementation would use aapt or other tools
            
            var psi = new ProcessStartInfo
            {
                FileName = "aapt",
                Arguments = $"dump badging \"{apkPath}\"",
                RedirectStandardOutput = true,
                UseShellExecute = false,
                CreateNoWindow = true
            };

            using (var process = Process.Start(psi))
            {
                var output = await process.StandardOutput.ReadToEndAsync();
                
                // Parse output
                foreach (var line in output.Split('\n'))
                {
                    if (line.StartsWith("package:"))
                    {
                        var match = System.Text.RegularExpressions.Regex.Match(line, @"name='([^']+)'.*versionName='([^']+)'.*versionCode='([^']+)'");
                        if (match.Success)
                        {
                            info.PackageName = match.Groups[1].Value;
                            info.VersionName = match.Groups[2].Value;
                            info.VersionCode = int.Parse(match.Groups[3].Value);
                        }
                    }
                    else if (line.StartsWith("sdkVersion:"))
                    {
                        info.MinSdkVersion = line.Split(':')[1].Trim();
                    }
                    else if (line.StartsWith("targetSdkVersion:"))
                    {
                        info.TargetSdkVersion = line.Split(':')[1].Trim();
                    }
                    else if (line.StartsWith("uses-permission:"))
                    {
                        var perm = System.Text.RegularExpressions.Regex.Match(line, @"name='([^']+)'");
                        if (perm.Success)
                            info.Permissions.Add(perm.Groups[1].Value);
                    }
                }

                var fileInfo = new FileInfo(apkPath);
                info.FileSizeBytes = fileInfo.Length;
            }

            return info;
        }

        /// <summary>
        /// Find built APK in standard Gradle output directory
        /// </summary>
        private string FindApk(string projectPath, string buildType, string flavor = null)
        {
            var buildDir = Path.Combine(projectPath, "app", "build", "outputs", "apk");
            
            string searchPattern;
            if (buildType == "debug")
            {
                searchPattern = "debug-*.apk";
            }
            else
            {
                var flavorDir = flavor?.ToLower() ?? "release";
                buildDir = Path.Combine(buildDir, flavorDir);
                searchPattern = $"{flavorDir}-*.apk";
            }

            if (!Directory.Exists(buildDir))
                return null;

            var files = Directory.GetFiles(buildDir, searchPattern, SearchOption.AllDirectories);
            return files.Length > 0 ? files[0] : null;
        }
    }
}
