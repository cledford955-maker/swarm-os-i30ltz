using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using LucyServer.Models.Marketplace;
using LucyServer.Data;

namespace LucyServer.Services.Marketplace
{
    /// <summary>
    /// Manages marketplace items (extensions, templates, tools)
    /// </summary>
    public class MarketplaceService
    {
        private readonly ApplicationDbContext _context;
        
        public MarketplaceService(ApplicationDbContext context)
        {
            _context = context;
        }

        // ==================== BROWSE & SEARCH ====================
        
        /// <summary>
        /// Get all published marketplace items with pagination
        /// </summary>
        public async Task<PaginatedResult<MarketplaceItem>> GetItemsAsync(
            int page = 1, 
            int pageSize = 20,
            string sortBy = "name")
        {
            var query = _context.MarketplaceItems
                .Where(x => x.Status == MarketplaceStatus.Published || x.Status == MarketplaceStatus.Featured)
                .AsQueryable();

            // Sort options
            query = sortBy.ToLower() switch
            {
                "rating" => query.OrderByDescending(x => x.AverageRating),
                "installs" => query.OrderByDescending(x => x.InstallCount),
                "recent" => query.OrderByDescending(x => x.PublishedAt),
                "trending" => query.OrderByDescending(x => x.InstallCount).ThenByDescending(x => x.PublishedAt),
                _ => query.OrderBy(x => x.Name)
            };

            var totalCount = await query.CountAsync();
            var items = await query
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .Include(x => x.Developer)
                .ToListAsync();

            return new PaginatedResult<MarketplaceItem>
            {
                Items = items,
                TotalCount = totalCount,
                Page = page,
                PageSize = pageSize,
                TotalPages = (int)Math.Ceiling(totalCount / (double)pageSize)
            };
        }

        /// <summary>
        /// Search marketplace items by name, description, and tags
        /// </summary>
        public async Task<PaginatedResult<MarketplaceItem>> SearchAsync(
            string query,
            string category = null,
            string[] tags = null,
            int page = 1,
            int pageSize = 20)
        {
            var q = query.ToLower();
            
            var items = _context.MarketplaceItems
                .Where(x => x.Status == MarketplaceStatus.Published || x.Status == MarketplaceStatus.Featured)
                .Where(x => x.Name.ToLower().Contains(q) || 
                           x.Description.ToLower().Contains(q) ||
                           x.Tags.Any(t => t.ToLower().Contains(q)))
                .AsQueryable();

            // Filter by category
            if (!string.IsNullOrEmpty(category))
            {
                items = items.Where(x => x.Category == category);
            }

            // Filter by tags
            if (tags?.Any() == true)
            {
                items = items.Where(x => tags.All(tag => x.Tags.Contains(tag)));
            }

            var totalCount = await items.CountAsync();
            var results = await items
                .OrderByDescending(x => x.InstallCount)
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .Include(x => x.Developer)
                .ToListAsync();

            return new PaginatedResult<MarketplaceItem>
            {
                Items = results,
                TotalCount = totalCount,
                Page = page,
                PageSize = pageSize,
                TotalPages = (int)Math.Ceiling(totalCount / (double)pageSize)
            };
        }

        /// <summary>
        /// Get featured/trending items for home page
        /// </summary>
        public async Task<List<MarketplaceItem>> GetFeaturedAsync(int limit = 10)
        {
            return await _context.MarketplaceItems
                .Where(x => x.Status == MarketplaceStatus.Featured)
                .OrderByDescending(x => x.AverageRating)
                .ThenByDescending(x => x.InstallCount)
                .Take(limit)
                .Include(x => x.Developer)
                .ToListAsync();
        }

        /// <summary>
        /// Get items by category
        /// </summary>
        public async Task<PaginatedResult<MarketplaceItem>> GetByCategory(
            string category,
            int page = 1,
            int pageSize = 20)
        {
            var query = _context.MarketplaceItems
                .Where(x => (x.Status == MarketplaceStatus.Published || x.Status == MarketplaceStatus.Featured) &&
                           x.Category == category)
                .OrderByDescending(x => x.InstallCount);

            var totalCount = await query.CountAsync();
            var items = await query
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .Include(x => x.Developer)
                .ToListAsync();

            return new PaginatedResult<MarketplaceItem>
            {
                Items = items,
                TotalCount = totalCount,
                Page = page,
                PageSize = pageSize,
                TotalPages = (int)Math.Ceiling(totalCount / (double)pageSize)
            };
        }

        /// <summary>
        /// Get single item by ID
        /// </summary>
        public async Task<MarketplaceItem> GetItemByIdAsync(Guid id)
        {
            return await _context.MarketplaceItems
                .Where(x => x.Id == id && (x.Status == MarketplaceStatus.Published || x.Status == MarketplaceStatus.Featured))
                .Include(x => x.Developer)
                .Include(x => x.Ratings.OrderByDescending(r => r.RatedAt))
                .FirstOrDefaultAsync();
        }

        // ==================== AUTHOR MANAGEMENT ====================

        /// <summary>
        /// Get all items published by a developer
        /// </summary>
        public async Task<List<MarketplaceItem>> GetDeveloperItemsAsync(Guid developerId)
        {
            return await _context.MarketplaceItems
                .Where(x => x.AuthorId == developerId)
                .OrderByDescending(x => x.UpdatedAt)
                .Include(x => x.Ratings)
                .Include(x => x.Installations)
                .ToListAsync();
        }

        /// <summary>
        /// Publish new marketplace item
        /// </summary>
        public async Task<MarketplaceItem> PublishItemAsync(CreateMarketplaceItemRequest request, Guid authorId)
        {
            var item = new MarketplaceItem
            {
                Name = request.Name,
                Description = request.Description,
                Category = request.Category,
                Type = request.Type,
                Version = request.Version ?? "1.0.0",
                Author = request.Author,
                AuthorId = authorId,
                IconUrl = request.IconUrl,
                RepositoryUrl = request.RepositoryUrl,
                DocumentationUrl = request.DocumentationUrl,
                LicenseType = request.LicenseType ?? "MIT",
                SupportedLanguages = request.SupportedLanguages ?? Array.Empty<string>(),
                SupportedPlatforms = request.SupportedPlatforms ?? Array.Empty<string>(),
                Tags = request.Tags ?? Array.Empty<string>(),
                IsFree = request.IsFree ?? true,
                PriceUsd = request.PriceUsd,
                DownloadUrl = request.DownloadUrl,
                ManifestUrl = request.ManifestUrl,
                FileSizeBytes = request.FileSizeBytes ?? 0,
                Status = MarketplaceStatus.PendingReview,
                PublishedAt = DateTime.UtcNow
            };

            _context.MarketplaceItems.Add(item);
            await _context.SaveChangesAsync();

            return item;
        }

        /// <summary>
        /// Update marketplace item
        /// </summary>
        public async Task<MarketplaceItem> UpdateItemAsync(Guid id, UpdateMarketplaceItemRequest request, Guid authorId)
        {
            var item = await _context.MarketplaceItems.FirstOrDefaultAsync(x => x.Id == id && x.AuthorId == authorId);
            if (item == null)
                throw new UnauthorizedAccessException("You don't have permission to update this item");

            if (!string.IsNullOrEmpty(request.Name))
                item.Name = request.Name;
            if (!string.IsNullOrEmpty(request.Description))
                item.Description = request.Description;
            if (!string.IsNullOrEmpty(request.DownloadUrl))
                item.DownloadUrl = request.DownloadUrl;
            if (request.Tags != null)
                item.Tags = request.Tags;
            if (!string.IsNullOrEmpty(request.IconUrl))
                item.IconUrl = request.IconUrl;
            
            item.UpdatedAt = DateTime.UtcNow;

            await _context.SaveChangesAsync();
            return item;
        }

        /// <summary>
        /// Create new version of item
        /// </summary>
        public async Task<ItemVersion> CreateVersionAsync(Guid itemId, CreateVersionRequest request, Guid authorId)
        {
            var item = await _context.MarketplaceItems.FirstOrDefaultAsync(x => x.Id == itemId && x.AuthorId == authorId);
            if (item == null)
                throw new UnauthorizedAccessException("Item not found or you don't have permission");

            var version = new ItemVersion
            {
                MarketplaceItemId = itemId,
                VersionNumber = request.VersionNumber,
                ChangeLog = request.ChangeLog,
                DownloadUrl = request.DownloadUrl,
                FileSizeBytes = request.FileSizeBytes ?? 0,
                ReleasedAt = DateTime.UtcNow
            };

            // Update item's current version
            item.Version = request.VersionNumber;
            item.UpdatedAt = DateTime.UtcNow;

            _context.ItemVersions.Add(version);
            await _context.SaveChangesAsync();

            return version;
        }

        // ==================== RATINGS & REVIEWS ====================

        /// <summary>
        /// Submit or update a rating
        /// </summary>
        public async Task<ItemRating> RateItemAsync(Guid itemId, Guid developerId, int rating, string reviewText, string reviewTitle)
        {
            if (rating < 1 || rating > 5)
                throw new ArgumentException("Rating must be between 1 and 5");

            var existingRating = await _context.ItemRatings
                .FirstOrDefaultAsync(x => x.MarketplaceItemId == itemId && x.DeveloperId == developerId);

            if (existingRating != null)
            {
                existingRating.Rating = rating;
                existingRating.ReviewText = reviewText;
                existingRating.ReviewTitle = reviewTitle;
            }
            else
            {
                existingRating = new ItemRating
                {
                    MarketplaceItemId = itemId,
                    DeveloperId = developerId,
                    Rating = rating,
                    ReviewText = reviewText,
                    ReviewTitle = reviewTitle
                };
                _context.ItemRatings.Add(existingRating);
            }

            // Recalculate average rating
            await RecalculateItemRatingAsync(itemId);

            await _context.SaveChangesAsync();
            return existingRating;
        }

        /// <summary>
        /// Get all ratings for an item
        /// </summary>
        public async Task<PaginatedResult<ItemRating>> GetItemRatingsAsync(Guid itemId, int page = 1, int pageSize = 10)
        {
            var query = _context.ItemRatings
                .Where(x => x.MarketplaceItemId == itemId)
                .OrderByDescending(x => x.RatedAt);

            var totalCount = await query.CountAsync();
            var ratings = await query
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .Include(x => x.Developer)
                .ToListAsync();

            return new PaginatedResult<ItemRating>
            {
                Items = ratings,
                TotalCount = totalCount,
                Page = page,
                PageSize = pageSize,
                TotalPages = (int)Math.Ceiling(totalCount / (double)pageSize)
            };
        }

        private async Task RecalculateItemRatingAsync(Guid itemId)
        {
            var ratings = await _context.ItemRatings
                .Where(x => x.MarketplaceItemId == itemId)
                .ToListAsync();

            if (ratings.Count == 0)
            {
                var item = await _context.MarketplaceItems.FirstOrDefaultAsync(x => x.Id == itemId);
                if (item != null)
                {
                    item.AverageRating = 0;
                    item.RatingCount = 0;
                }
            }
            else
            {
                var item = await _context.MarketplaceItems.FirstOrDefaultAsync(x => x.Id == itemId);
                if (item != null)
                {
                    item.AverageRating = (decimal)ratings.Average(x => x.Rating);
                    item.RatingCount = ratings.Count;
                }
            }
        }

        // ==================== INSTALLATIONS ====================

        /// <summary>
        /// Log an installation
        /// </summary>
        public async Task<Installation> RecordInstallationAsync(Guid itemId, Guid developerId, string version)
        {
            var installation = new Installation
            {
                MarketplaceItemId = itemId,
                DeveloperId = developerId,
                InstalledVersion = version,
                IsActive = true
            };

            var item = await _context.MarketplaceItems.FirstOrDefaultAsync(x => x.Id == itemId);
            if (item != null)
            {
                item.InstallCount++;
            }

            _context.Installations.Add(installation);
            await _context.SaveChangesAsync();

            return installation;
        }

        /// <summary>
        /// Log an uninstallation
        /// </summary>
        public async Task UninstallAsync(Guid itemId, Guid developerId)
        {
            var installation = await _context.Installations
                .FirstOrDefaultAsync(x => x.MarketplaceItemId == itemId && x.DeveloperId == developerId && x.IsActive);

            if (installation != null)
            {
                installation.IsActive = false;
                installation.UninstalledAt = DateTime.UtcNow;

                var item = await _context.MarketplaceItems.FirstOrDefaultAsync(x => x.Id == itemId);
                if (item != null && item.InstallCount > 0)
                {
                    item.InstallCount--;
                }

                await _context.SaveChangesAsync();
            }
        }

        /// <summary>
        /// Get installation history for developer
        /// </summary>
        public async Task<List<Installation>> GetDeveloperInstallationsAsync(Guid developerId, bool activeOnly = true)
        {
            var query = _context.Installations
                .Where(x => x.DeveloperId == developerId)
                .AsQueryable();

            if (activeOnly)
                query = query.Where(x => x.IsActive);

            return await query
                .Include(x => x.MarketplaceItem)
                .OrderByDescending(x => x.InstalledAt)
                .ToListAsync();
        }
    }

    // ==================== DTOs ====================

    public class CreateMarketplaceItemRequest
    {
        public string Name { get; set; }
        public string Description { get; set; }
        public string Category { get; set; }
        public string Type { get; set; }
        public string Author { get; set; }
        public string Version { get; set; }
        public string IconUrl { get; set; }
        public string RepositoryUrl { get; set; }
        public string DocumentationUrl { get; set; }
        public string LicenseType { get; set; }
        public bool? IsFree { get; set; }
        public decimal? PriceUsd { get; set; }
        public string[] SupportedLanguages { get; set; }
        public string[] SupportedPlatforms { get; set; }
        public string[] Tags { get; set; }
        public string DownloadUrl { get; set; }
        public string ManifestUrl { get; set; }
        public long? FileSizeBytes { get; set; }
    }

    public class UpdateMarketplaceItemRequest
    {
        public string Name { get; set; }
        public string Description { get; set; }
        public string DownloadUrl { get; set; }
        public string IconUrl { get; set; }
        public string[] Tags { get; set; }
    }

    public class CreateVersionRequest
    {
        public string VersionNumber { get; set; }
        public string ChangeLog { get; set; }
        public string DownloadUrl { get; set; }
        public long? FileSizeBytes { get; set; }
    }

    public class PaginatedResult<T>
    {
        public List<T> Items { get; set; }
        public int TotalCount { get; set; }
        public int Page { get; set; }
        public int PageSize { get; set; }
        public int TotalPages { get; set; }
    }
}
