# DVD Store 3.6 Validation System

## Overview

The validation system provides automated verification of benchmark correctness by capturing database state before and after test runs. It validates:

- **Data volume changes** - Table row counts (CUSTOMERS, ORDERS, REVIEWS, etc.)
- **Manager operations** - Product additions, review deletions, price adjustments, membership upgrades
- **Data integrity** - Foreign key cascades, trigger behavior, referential constraints
- **Workload distribution** - Popular product skewing, purchase history growth

## Two-Step Workflow

### Step 1: Generate Validation SQL (Perl)

Perl scripts generate store-specific SQL files from templates:

**SQL Server:**
```bash
cd sqlserver/validate
perl sqlserver_ds_perl_validate_multi.pl localhost 3 mypassword pre_test generate
perl sqlserver_ds_perl_validate_multi.pl localhost 3 mypassword post_test generate
```

**MySQL:**
```bash
cd mysql/validate
perl mysql_ds_perl_validate_multi.pl localhost 3 pre_test generate
perl mysql_ds_perl_validate_multi.pl localhost 3 post_test generate
```

**PostgreSQL:**
```bash
cd pgsql/validate
perl pgsql_ds_perl_validate_multi.pl localhost 3 pre_test generate
perl pgsql_ds_perl_validate_multi.pl localhost 3 post_test generate
```

**Oracle:**
```bash
cd oracle/validate
perl oracle_ds_perl_validate_multi.pl localhost 3 pre_test generate
perl oracle_ds_perl_validate_multi.pl localhost 3 post_test generate
```

**Generated files:** `{database}/validate/{server}/{database}_validate_pre_test{N}.sql`, `{database}_validate_post_test{N}.sql`

### Step 2: Execute Validation (C# Driver)

**Capture baseline (before benchmark):**
```bash
cd sqlserver/validate
perl sqlserver_ds_perl_validate_multi.pl localhost 3 mypassword pre_test execute
```

**Run benchmark with automatic post-validation:**
```bash
cd sqlserver
dotnet run --config_file=../DriverConfig.txt --target=localhost --run_time=60 --validate_post_test=Y
```

**Output file:** `validation_{database}_store{N}_{timestamp}.txt`

## Isolating Operations for Testing

**IMPORTANT:** To cleanly test specific operations, disable interfering operations:

### Testing ExpireMemberships

Prevent new memberships from interfering with expiration counts:

```bash
./sqlserver_ds --target=localhost --run_time=60 \
  --enable_managers=Y \
  --pct_newmember=0 \
  --manager_expire_memberships_pct=100 \
  --validate_post_test=Y
```

**Why:** New memberships (`pct_newmember`) would add rows to MEMBERSHIP table while ExpireMemberships is deleting them, making delta analysis unclear.

### Testing UpgradeMembership

Prevent new memberships and expirations from interfering with tier changes:

```bash
./sqlserver_ds --target=localhost --run_time=60 \
  --enable_managers=Y \
  --pct_newmember=0 \
  --manager_expire_memberships_pct=0 \
  --manager_upgrade_membership_pct=100 \
  --validate_post_test=Y
```

**Why:** 
- New memberships add members
- Expiring memberships removes rows (changes membership snapshot comparison)


### Testing RemoveReviews Operations

Use DS2 mode to focus on review removal (DS2 mode automatically disables newreviews and newhelpfulness):

```bash
./sqlserver_ds --target=localhost --run_time=60 \
  --enable_managers=Y \
  --ds2_mode=Y \
  --manager_delete_review_pct=100 \
  --validate_post_test=Y
```

**Why:** 
- DS2 mode (`ds2_mode=Y`) automatically disables customer review operations (newreviews, newhelpfulness)
- Also disables Browse by Membership (only category, actor, title browsing)
- Prevents new reviews from being added while manager is deleting them
- Matches DVD Store 2.x behavior for simpler workload

## Multi-Store Support

Validation SQL is generated per-store using `{store_number}` placeholders:

**Template (before generation):**
```sql
SELECT COUNT(*) FROM CUSTOMERS{store_number};
```

**After generation (store 1, 2, 3):**
```sql
-- customers_validate_post_test1.sql
SELECT COUNT(*) FROM CUSTOMERS1;

-- customers_validate_post_test2.sql
SELECT COUNT(*) FROM CUSTOMERS2;

-- customers_validate_post_test3.sql
SELECT COUNT(*) FROM CUSTOMERS3;
```

**Snapshot tables are store-specific:**
- `VALIDATION_METRICS_1`, `VALIDATION_METRICS_2`, `VALIDATION_METRICS_3`
- `MEMBERSHIP_SNAPSHOT_1`, `MEMBERSHIP_SNAPSHOT_2`, `MEMBERSHIP_SNAPSHOT_3`

This isolates validation data per store.

## Validation Checks

### 1. Table Row Counts

**Validated tables:**
- CUSTOMERS, ORDERS, ORDERLINES (should increase during benchmark)
- PRODUCTS (may increase if AddProduct manager enabled)
- REVIEWS, REVIEWS_HELPFULNESS (may decrease if review removal enabled)
- MEMBERSHIP (increases with pct_newmember, decreases with ExpireMemberships)
- INVENTORY, CUST_HIST, REORDER

**Output format:**
```
Table           Pre             Post            Delta
------------------------------------------------------------
CUSTOMERS       20000           20543           543
ORDERS          60000           62187           2187
PRODUCTS        10000           10025           25
MEMBERSHIP      6000            5973            -27
```

### 2. Manager Operations Validation

**AddProduct:**
- Products with `.01` price endings (new products default to $X.01)
- INVENTORY rows for new products
- Random category, actor, special flag assignments

**ExpireMemberships:**
- MEMBERSHIP rows deleted where `EXPIREDATE < CURRENT_DATE`
- Membership tier distribution changes

**UpgradeMembership:**
- Tier transitions: Bronze→Silver, Silver→Gold, Bronze→Gold
- Percentile-based thresholds (90th percentile → Gold, 75th percentile → Silver)
- Time-sliced processing (1% of customers per minute, 100-minute full cycle)

**RemoveReviews (3 operations):**
- RemoveReviewByProduct: All reviews for random products deleted
- RemoveUnhelpfulReviews: Reviews with low helpfulness scores deleted
- RemoveReviewsByDate: Oldest reviews deleted
- CASCADE to REVIEWS_HELPFULNESS verified

**AdjustPrices vs BulkPriceAdjustment:**
- Individual adjustments: ±10% factor (0.90-1.10)
- Bulk adjustments: ±25% factor (0.75-1.25), `.77` price endings, category-wide
- Validation shows price ending distribution

**PurgeOldOrders:**
- Oldest orders deleted
- CASCADE to ORDERLINES and CUST_HIST verified

### 3. Data Integrity Checks

**Foreign key cascades:**
- ORDERS deleted → ORDERLINES deleted (PurgeOldOrders)
- REVIEWS deleted → REVIEWS_HELPFULNESS deleted (RemoveReviews)

**Trigger verification:**
- RESTOCK trigger: INVENTORY `QUAN_IN_STOCK < 3` → REORDER entry created
- after_helpfulness_insert trigger: REVIEWS.TOTAL_HELPFULNESS updated

**Skewed product distribution:**
- Products with `PROD_ID % 10000 = 0` have 10× inventory and higher sales
- Top 10 inventory by sales should show **POPULAR** products

### 4. Membership Snapshot Comparison

**Full membership snapshot captured in validate_pre_test.sql:**
- All CUSTOMERID, MEMBERSHIPTYPE, EXPIREDATE rows

**Comparison in validate_post_test.sql shows:**
- New memberships added during benchmark
- Tier upgrades (1→2, 2→3, 1→3)
- Expired memberships removed
- Expiration date changes

**Sample output:**
```
Membership Tier Changes (Top 30 - Diverse Sample):
CustID    Before    After     Change
----------------------------------------
12543     1         2         BRONZE → SILVER
45021     2         3         SILVER → GOLD
8934      NULL      1         NEW MEMBERSHIP
```

## Output File Format

**Filename:** `validation_{database}_store{N}_{timestamp}.txt`

**Examples:**
- `validation_sqlserver_store1_20260512_143055.txt`
- `validation_mysql_store2_20260512_150230.txt`

**File structure:**
```
========================================================================
DVD Store 3.6 Benchmark - Validation Report
Generated: 2026-05-12 14:30:55
========================================================================

BENCHMARK PARAMETERS:
  Database Type:          sqlserver
  Store Number:           1
  Target Server:          localhost
  Run Time:               60 minutes
  Threads:                16
  Manager Threads:        1
  manager_expire_member:  5%
  manager_upgrade_member: 5%
  ...

========================================================================
VALIDATION RESULTS:
========================================================================

--- TABLE ROW COUNTS (Post-Test) ---
...

--- MEMBERSHIP TIER CHANGES ---
...

--- PRICE ADJUSTMENTS ---
...
```

## Database-Specific Implementation

### SQL Server

**Execution method:** SMO (SQL Server Management Objects)
```csharp
ServerConnection svrConn = new ServerConnection(objConn);
Server server = new Server(svrConn);
server.ConnectionContext.ExecuteNonQuery(script); // Handles GO batches
```

**Output capture:** `InfoMessage` event handler
**Batch separator:** `GO`

### MySQL

**Execution method:** `MySqlCommand.ExecuteNonQuery()`
```csharp
MySqlCommand cmd = new MySqlCommand(script, objConn);
cmd.ExecuteNonQuery(); // MySQL handles multiple statements
```

**Output capture:** `MySqlDataReader` for SELECT results
**Notes:** Uses `-N -s` flags in Perl scripts to suppress column headers

### PostgreSQL

**Execution method:** `NpgsqlCommand.ExecuteReader()`
```csharp
NpgsqlCommand cmd = new NpgsqlCommand(sqlContent, objConn);
using (NpgsqlDataReader reader = cmd.ExecuteReader()) { ... }
```

**Output capture:** `Notice` event handler for `RAISE NOTICE` statements
**Filtering:** Removes psql meta-commands (`\c`, `\timing`)

### Oracle

**Execution method:** `sqlplus` via `Process.Start()`
```csharp
Process.Start("sqlplus", "-S sys/oracle@server as sysdba @file.sql");
```

**Output capture:** Redirect `StandardOutput` to file
**Batch separator:** `/` (handled by sqlplus automatically)
**Notes:** Uses sqlplus CLI because ADO.NET cannot handle SQL*Plus commands (SET, COLUMN, DBMS_OUTPUT)

## Troubleshooting

### No validation output in file

**Cause:** Validation SQL files not generated
**Solution:** Run Perl generation script first:
```bash
perl {database}_ds_perl_validate_multi.pl {server} {num_stores} pre_test generate
perl {database}_ds_perl_validate_multi.pl {server} {num_stores} post_test generate
```

### "File not found" error

**Cause:** Wrong working directory or incorrect file path
**Solution:** Always run driver from database root directory (e.g., `sqlserver/`, `mysql/`)
**File path:** `validate/{server}/{database}_validate_post_test{N}.sql`

### Validation shows no changes

**Cause:** Benchmark run time too short or operations disabled
**Solution:**
- Increase `--run_time` (60+ minutes for meaningful data)
- Enable relevant operations (e.g., `--manager_expire_memberships_pct=100`)
- Disable interfering operations (see "Isolating Operations" above)

### Membership snapshot comparison empty

**Cause:** validate_pre_test.sql not executed before benchmark
**Solution:**
```bash
perl {database}_ds_perl_validate_multi.pl {server} {num_stores} pre_test execute
# Run benchmark
# validate_post_test will now have baseline to compare against
```

## Important Notes

### Baseline Comparison Caveat

**Validation SQL compares against the snapshot from validate_pre_test.sql execution, NOT the start of the current benchmark run.**

**Example:**
```bash
# Run validate_pre_test (captures baseline)
perl sqlserver_ds_perl_validate_multi.pl localhost 1 mypassword pre_test execute

# Run 1: benchmark with validation
./sqlserver_ds --run_time=60 --validate_post_test=Y
# Manager stats:     25 products added, 150 reviews deleted
# Validation output: 25 products added, 150 reviews deleted ✓ MATCHES

# Run 2: benchmark again (same baseline)
./sqlserver_ds --run_time=60 --validate_post_test=Y
# Manager stats:     30 products added, 200 reviews deleted
# Validation output: 55 products added, 350 reviews deleted ✗ DOESN'T MATCH
#                    (cumulative from Run 1 + Run 2)
```

**Solution:** Re-execute validate_pre_test.sql before each benchmark to reset the baseline:
```bash
perl sqlserver_ds_perl_validate_multi.pl localhost 1 mypassword pre_test execute
./sqlserver_ds --run_time=60 --validate_post_test=Y  # Now validation matches manager stats
```

**When this matters:**
- Comparing manager statistics to validation deltas
- Running multiple benchmarks without resetting database state
- Automated test harness loops

**When this doesn't matter:**
- Comparing before/after table counts (still accurate)
- One-time validation runs
- Resetting database between tests

## Best Practices

1. **Always generate before/after SQL together** - Ensures template versions match
2. **Execute validate_pre_test.sql before EACH benchmark** - Captures fresh baseline for accurate manager statistics comparison
3. **Use meaningful run times** - 60+ minutes for manager operations to show clear patterns
4. **Isolate operations** - Disable interfering parameters when testing specific functionality
5. **Compare multiple runs** - Timestamps in filenames allow historical comparison
6. **Review validation output** - Don't just collect files, actually read the results

## Example Workflow

**Complete validation workflow for testing UpgradeMembership:**

```bash
# 1. Generate validation SQL for 1 store
cd sqlserver/validate
perl sqlserver_ds_perl_validate_multi.pl localhost 1 mypassword pre_test generate
perl sqlserver_ds_perl_validate_multi.pl localhost 1 mypassword post_test generate

# 2. Capture baseline
perl sqlserver_ds_perl_validate_multi.pl localhost 1 mypassword pre_test execute

# 3. Run benchmark (isolated parameters for UpgradeMembership)
cd ..
./bin/Release/net10.0/sqlserver_ds \
  --target=localhost \
  --run_time=120 \
  --n_threads=16 \
  --enable_managers=Y \
  --pct_newmember=0 \
  --manager_expire_memberships_pct=0 \
  --manager_upgrade_membership_pct=100 \
  --validate_post_test=Y

# 4. Review validation output
cat validation_sqlserver_store1_*.txt
```

**Expected validation output:**
- MEMBERSHIP table row count unchanged (no new members, no expirations)
- Tier upgrade transitions shown: Bronze→Silver, Silver→Gold
- Percentile thresholds applied correctly
- Time-sliced processing verified (1% per minute)

## See Also

- `CHANGES.md` - Validation system changelog
- `{database}/validate/validate_pre_test.sql` - Template SQL (before generation)
- `{database}/validate/validate_post_test.sql` - Template SQL (before generation)
- `{database}/validate/{database}_ds_perl_validate_multi.pl` - Generation/execution scripts
