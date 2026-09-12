using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using LucyServer.Models;

namespace LucyServer.Services.Ecosystem
{
    public class MarketplaceManagementService
    {
        private readonly List<CommunityTemplate> _templates = new();
        private readonly List<SocialExtensionReview> _reviews = new();
        private readonly List<MarketplaceBillingRecord> _billingRecords = new();

        public MarketplaceManagementService()
        {
            SeedCommunityTemplates();
            SeedSocialReviews();
            SeedBillingRecords();
        }

        // --- Community Templates ---
        public Task<List<CommunityTemplate>> GetCommunityTemplatesAsync()
        {
            return Task.FromResult(_templates.ToList());
        }

        public Task<CommunityTemplate> SubmitCommunityTemplateAsync(CommunityTemplate template)
        {
            template.PublishedAt = DateTime.UtcNow;
            _templates.Insert(0, template);
            return Task.FromResult(template);
        }

        // --- Social Discovery & Reviews ---
        public Task<List<SocialExtensionReview>> GetReviewsForExtensionAsync(string extensionId)
        {
            var list = _reviews.Where(r => r.ExtensionId == extensionId).ToList();
            if (!list.Any())
            {
                list = _reviews.Take(3).ToList(); // Provide top community reviews
            }
            return Task.FromResult(list);
        }

        public Task<SocialExtensionReview> PostReviewAsync(string extensionId, string username, double rating, string comment)
        {
            var rev = new SocialExtensionReview
            {
                ExtensionId = extensionId,
                Username = username,
                Rating = rating,
                Comment = comment,
                Upvotes = 1
            };
            _reviews.Insert(0, rev);
            return Task.FromResult(rev);
        }

        // --- Monetization, Billing & Analytics ---
        public Task<MarketplaceBillingRecord> ProcessItemPurchaseAsync(string itemId, string itemName, string buyerId, decimal priceUsd)
        {
            var platformFee = Math.Round(priceUsd * 0.15m, 2); // 15% platform split
            var developerPayout = priceUsd - platformFee;       // 85% creator royalty

            var record = new MarketplaceBillingRecord
            {
                ItemId = itemId,
                ItemName = itemName,
                BuyerId = buyerId,
                DeveloperId = "dev-" + Guid.NewGuid().ToString("N").Substring(0, 8),
                GrossAmountUsd = priceUsd,
                PlatformFeeUsd = platformFee,
                DeveloperPayoutUsd = developerPayout,
                LicenseKey = "SWARM-KEY-" + Guid.NewGuid().ToString("N").ToUpper().Substring(0, 16),
                PaymentStatus = "Settled"
            };

            _billingRecords.Insert(0, record);
            return Task.FromResult(record);
        }

        public Task<MarketplaceAnalyticsSummary> GetMarketplaceAnalyticsAsync()
        {
            var totalGross = _billingRecords.Sum(b => b.GrossAmountUsd);
            var totalDev = _billingRecords.Sum(b => b.DeveloperPayoutUsd);

            var summary = new MarketplaceAnalyticsSummary
            {
                TotalGrossRevenue = totalGross,
                TotalDeveloperPayouts = totalDev,
                TotalTransactions = _billingRecords.Count,
                ActivePaidSubscriptions = 142,
                RecentTransactions = _billingRecords.Take(15).ToList()
            };

            return Task.FromResult(summary);
        }

        private void SeedCommunityTemplates()
        {
            _templates.Add(new CommunityTemplate
            {
                TemplateId = "tpl-flutter-cyber",
                Title = "Flutter 3D Cyberpunk HUD Template",
                Description = "Complete Wayland-optimized HUD with glowing glassmorphic panels and audio synthesizer.",
                Category = "Desktop",
                Author = "DrBoltz",
                RepoUrl = "https://github.com/cledford955-maker/flutter-cyber-hud",
                Tags = new() { "flutter", "cyberpunk", "hud", "audio" },
                Rating = 4.95,
                Downloads = 4820,
                IsVerified = true,
                IsPaid = true,
                PriceUsd = 14.99m
            });

            _templates.Add(new CommunityTemplate
            {
                TemplateId = "tpl-rust-microservice",
                Title = "High-Throughput Rust IPC Microservice",
                Description = "Zero-copy shared memory daemon with async Tokio and protobuf bindings.",
                Category = "Systems",
                Author = "RustaceanSwarm",
                RepoUrl = "https://github.com/swarm-community/rust-ipc-daemon",
                Tags = new() { "rust", "tokio", "ipc", "low-latency" },
                Rating = 4.88,
                Downloads = 3150,
                IsVerified = true,
                IsPaid = false,
                PriceUsd = 0.00m
            });

            _templates.Add(new CommunityTemplate
            {
                TemplateId = "tpl-android-compose-ai",
                Title = "Android Jetpack Compose + Local LLM",
                Description = "Companion mobile app with MediaPipe LLM inference and Wi-Fi ADB bridge.",
                Category = "Mobile",
                Author = "MobileArchitect",
                RepoUrl = "https://github.com/swarm-community/android-ai-compose",
                Tags = new() { "android", "kotlin", "compose", "llm" },
                Rating = 4.92,
                Downloads = 6210,
                IsVerified = true,
                IsPaid = true,
                PriceUsd = 9.99m
            });
        }

        private void SeedSocialReviews()
        {
            _reviews.Add(new SocialExtensionReview
            {
                ExtensionId = "dart-lang",
                Username = "CyberDev_99",
                Rating = 5.0,
                Comment = "Outstanding IntelliSense performance. Zero latency on large multi-module repositories.",
                Upvotes = 42
            });

            _reviews.Add(new SocialExtensionReview
            {
                ExtensionId = "lucille-ai",
                Username = "ArchitectAlex",
                Rating = 5.0,
                Comment = "The autonomous refactoring specialist saved us 3 days of tedious migration work.",
                Upvotes = 88
            });
        }

        private void SeedBillingRecords()
        {
            _billingRecords.Add(new MarketplaceBillingRecord
            {
                ItemId = "tpl-flutter-cyber",
                ItemName = "Flutter 3D Cyberpunk HUD Template",
                BuyerId = "user_7719",
                DeveloperId = "dev_drboltz",
                GrossAmountUsd = 14.99m,
                PlatformFeeUsd = 2.25m,
                DeveloperPayoutUsd = 12.74m,
                LicenseKey = "SWARM-KEY-99F12A08B342C110",
                PaymentStatus = "Settled",
                Timestamp = DateTime.UtcNow.AddHours(-2)
            });

            _billingRecords.Add(new MarketplaceBillingRecord
            {
                ItemId = "tpl-android-compose-ai",
                ItemName = "Android Jetpack Compose + Local LLM",
                BuyerId = "user_4401",
                DeveloperId = "dev_mobilearch",
                GrossAmountUsd = 9.99m,
                PlatformFeeUsd = 1.50m,
                DeveloperPayoutUsd = 8.49m,
                LicenseKey = "SWARM-KEY-A10988FF432DEB80",
                PaymentStatus = "Settled",
                Timestamp = DateTime.UtcNow.AddHours(-14)
            });
        }
    }
}
