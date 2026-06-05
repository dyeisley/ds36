Welcome to the **DVD Store 3.6** *dyeisley fork* - This is currently a development version and has been made public to allow for
collaboration and forward progress without impacting the previous version 3.5.  

*All testing has been done on Linux only.* 

The web driver (drivers/ds36webfns.cs) and PHP code have not been modified.  

## What's New in 3.6

- **Manager Thread System**: Background thread with 11 administrative operations (AddProduct, RemoveReviews, AdjustPrices, BulkPriceAdjustment, MarkSpecials, ExpireMemberships, PurgeOldOrders, UpgradeMembership, PromotionalMembership)
- **Analytics System**: Separate analytics thread tracks membership tiers, new customer acquisition, and review activity with delta tracking and configurable intervals
- **Membership Renewal**: Members can renew expired memberships (controlled by pct_renewmember parameter); non-members cannot browse by membership; BROWSE_BY_MEMBERSHIP uses customer's actual membership tier
- **MERGE/UPSERT Support**: NEW_REVIEW_HELPFULNESS and PromotionalMembership use MERGE/UPSERT with audit tracking - prevents duplicate ratings, handles race conditions, provides batch promotional upgrades, and adds database feature coverage (MERGE operations and trigger behavior testing)
- **Data Generation Improvements**: Linear database scaling (200:10:1 ratio from 4 GB baseline), dynamic popular products modulo for small databases
- **C# Code Modernization**: Cross-platform compatibility (Stopwatch), resource management (using statements), command pre-compilation, 20%+ code reduction
- **Parameter Parsing Rewrite**: Dictionary-based lookup, type-safe validators, centralized configuration
- **Code Formatting**: Applied dotnet format linter for consistent styling across all projects
- **Index and Trigger Consistency**: Standardized indexes and triggers across all 4 database platforms
- **Validation SQL Framework**: Before/after validation scripts for verifying manager operations and data integrity
- **LOGIN Performance Fix**: Added ORDER BY + LIMIT to return only 10 most recent orders (35% improvement on SQL Server)

See [CHANGES.md](CHANGES.md) for detailed changelog.


