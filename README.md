Welcome to DVD Store 3.6 dyeisley fork - This is currently a development version and has been made public to allow for
collaboration and forward progress without impacting the previous version 3.5.  

This version has not been fully tested, but does have some improvements over 3.5. 

All testing has been done on Linux only. The web driver (drivers/ds36webfns.cs) and PHP code have not been modified.  

## What's New in 3.6

- **Manager Thread System**: Background thread with 10 administrative operations (AddProduct, RemoveReviews, AdjustPrices, BulkPriceAdjustment, MarkSpecials, ExpireMemberships, PurgeOldOrders, UpgradeMembership)
- **C# Code Modernization**: Cross-platform compatibility (Stopwatch), resource management (using statements), command pre-compilation, 20%+ code reduction
- **Parameter Parsing Rewrite**: Dictionary-based lookup, type-safe validators, centralized configuration
- **Code Formatting**: Applied dotnet format linter for consistent styling across all projects
- **Index and Trigger Consistency**: Standardized indexes and triggers across all 4 database platforms
- **Validation SQL Framework**: Before/after validation scripts for verifying manager operations and data integrity
- **LOGIN Performance Fix**: Added ORDER BY + LIMIT to return only 10 most recent orders (35% improvement on SQL Server)

See [CHANGES.md](CHANGES.md) for detailed changelog.


