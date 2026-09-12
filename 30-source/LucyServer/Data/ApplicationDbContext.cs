using Microsoft.EntityFrameworkCore;
using LucyServer.Models.Marketplace;

namespace LucyServer.Data
{
    public class ApplicationDbContext : DbContext
    {
        public ApplicationDbContext()
        {
        }

        public ApplicationDbContext(DbContextOptions<ApplicationDbContext> options) : base(options)
        {
        }

        public DbSet<MarketplaceItem> MarketplaceItems { get; set; } = null!;
        public DbSet<Developer> Developers { get; set; } = null!;
        public DbSet<ItemRating> ItemRatings { get; set; } = null!;
        public DbSet<Installation> Installations { get; set; } = null!;
        public DbSet<ItemVersion> ItemVersions { get; set; } = null!;

        protected override void OnConfiguring(DbContextOptionsBuilder optionsBuilder)
        {
            if (!optionsBuilder.IsConfigured)
            {
                optionsBuilder.UseSqlite("Data Source=marketplace.db");
            }
        }
    }
}
