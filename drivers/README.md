# Shared Driver Files

These three files contain the database-independent driver logic. Each database directory (`mysql/`, `pgsql/`, `sqlserver/`, `oracle/`, `web/`) has a `.csproj` that references these files along with its own `ds36{db}fns.cs` implementing the database-specific calls.

| File | Purpose |
|------|---------|
| `ds36xdriver.cs` | Main driver. Parameter parsing, thread management, user simulation (login, browse, purchase, reviews, membership), OPM reporting. |
| `ds36xmanager.cs` | Manager thread. Periodic maintenance operations (AddProduct, DeleteReview, AdjustPrices, MarkSpecials, ExpireMemberships, PurgeOldOrders, UpgradeMembership, PromotionalMembership). |
| `ds36xanalytics.cs` | Analytics thread. Periodic analytics queries (membership, new customer, review, price point, inventory). |

To run the driver, build and execute from a database directory:

```
cd mysql
dotnet run -- --target=localhost --n_threads=16 --run_time=10
```

To see all parameters and defaults:

```
dotnet run
```
