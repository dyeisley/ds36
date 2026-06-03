# DVD Store 3.6 Analytics Guide

## Overview

DVD Store 3.6 includes an analytics system for tracking business metrics during benchmark runs. Analytics queries run periodically in a separate analytics thread, providing visibility into membership tiers, product performance, and other key metrics.

**Current Analytics Features:**
- **GetMembershipAnalytics** - Tracks membership tier distribution, orders, and revenue (SQL Server ✓, MySQL ✓, Oracle ✓, PostgreSQL ✓)
- **GetNewCustomerAnalytics** - New customer acquisition and engagement metrics (SQL Server ✓, MySQL ✓, Oracle ✓, PostgreSQL ✓)
- **GetProductAnalytics** - Product performance metrics (planned)
- **GetReviewAnalytics** - Review activity metrics

**Why Analytics in a Benchmark?**

Beyond providing visibility into business metrics, analytics serves important database testing purposes:

- **Complex Read Operations:** Exercises advanced SQL features (CTEs, window functions, multi-table JOINs, aggregations)
- **Large Table Scans:** Tests query performance on tables with millions of rows (ORDERS, CUSTOMERS, MEMBERSHIP)
- **Mixed Workload:** Combines analytical queries (read-heavy, long-running) with OLTP operations (write-heavy, short transactions)
- **Query Optimizer Testing:** Forces database to choose execution plans for complex aggregations under concurrent load
- **Realistic Production Load:** Production databases handle both transactional and analytical workloads simultaneously

Analytics operations are designed to be **resource-intensive read queries** that stress-test the database differently than the OLTP customer threads.

**Key Concepts:**
- **Two-Thread Architecture:** Analytics runs in separate thread from manager operations (no blocking)
- **Baseline Capture:** Metrics captured at test start to establish starting point
- **Delta Tracking:** Analytics show changes since baseline (new orders, new revenue, etc.)
- **Time-Based Execution:** Runs on configurable interval (minimum time between analytics runs)

## Configuration

**Enable analytics in config file:**
```
analytics_interval=5  # Minutes between analytics runs (0 = disabled)
enable_membership_analytics=y  # Enable/disable membership analytics
enable_newcustomer_analytics=y  # Enable/disable new customer analytics
```

**Interval Guidelines:**
- **Small databases (<1GB):** 1-5 minutes acceptable
- **Large databases (4GB+):** 5-15 minutes recommended (analytics takes longer)
- **Short tests (10 minutes):** Use interval < test duration to see output
- **Set to 0 to disable analytics completely**

### Interval Timing Behavior

The `analytics_interval` parameter specifies the **minimum** time between analytics runs, not a hard schedule.

**How it works:**
- Interval is measured from when analytics **starts**, not when it **completes**
- If analytics queries take longer than the interval, the effective interval will be longer
- The timing check prevents analytics from running too frequently

**Example (MySQL, 60-second interval, 20-second query):**
1. Time 0: Analytics starts, timestamp set to 0
2. Time 0-20: Query executes (20 seconds)
3. Time 20: Sleep 60 seconds
4. Time 80: Wake up, check elapsed = 80 - 0 = 80 seconds
5. Time 80: 80 >= 59, run analytics again
6. **Effective interval:** 80 seconds (60s sleep + 20s query)

**Example (slow queries exceed interval):**
1. 60-second interval, but queries take 90 seconds
2. Effective interval becomes 150 seconds (60s sleep + 90s query)
3. Analytics skips intervals automatically when queries are slow

**Key points:**
- Analytics never runs faster than the configured interval (enforced minimum)
- Analytics may run slower if queries take a long time (automatic skip)
- This prevents database overload from analytics piling up
- Monitor analytics RT in statistics output to tune interval appropriately

## GetMembershipAnalytics

Tracks membership tier distribution and business metrics per tier.

### Metrics Displayed

```
Membership Analytics (Store 1) - Delta since baseline
=====================================================================
Tier    Active Members    Expired    New Orders  New Revenue     Rev/Order   Rev/Member    Ord/Member
-----   --------------    -------    ----------  -------------   ---------   -----------   ----------
   3            50,013     47,179        60,681   $13,444,370         $222        $268           1.21
   2           152,144    141,940       183,471   $40,593,055         $221        $267           1.21
   1           301,957    282,728       365,119   $79,903,023         $219        $265           1.21
 N/A         8,643,265          0     5,343,855 $1,157,542,324        $217        $134           0.62
=====================================================================
```

**Columns:**
- **Tier:** Membership level (3=Gold, 2=Silver, 1=Bronze, N/A=Non-members)
- **Active Members:** Current active members at this tier
- **Expired:** Members whose memberships have expired
- **New Orders:** Orders placed since baseline (delta)
- **New Revenue:** Revenue generated since baseline (delta)
- **Rev/Order:** Average revenue per order (calculated from deltas)
- **Rev/Member:** Revenue per active member (calculated from deltas)
- **Ord/Member:** Orders per active member (calculated from deltas)

**Tier Ordering:** Highest tier first (3 → 2 → 1 → N/A)

### Baseline and Delta Tracking

**Baseline capture happens at test start:**
- Analytics thread captures initial order counts and revenue for each tier
- Stored in memory for duration of test
- All subsequent analytics show **deltas** (changes since baseline)

**Why deltas?**
- Shows what happened during **this test run**
- Filters out pre-existing historical data
- Focuses on activity generated by the benchmark

**Example:**
- Baseline: Tier 3 has 1,000,000 total orders
- After 5 minutes: Tier 3 has 1,015,000 total orders
- Analytics shows: "New Orders: 15,000" (the delta)

### SQL Server Implementation

**Status:** ✓ Complete

**Performance:**
- Fast at all database sizes
- No special tuning required
- ~1-2 seconds even at 4GB
- No impact on customer thread throughput (28K+ OPM sustained)

**Query approach:**
- Single CTE aggregating ORDERS table (COUNT + SUM)
- LEFT JOIN to CUSTOMERS and MEMBERSHIP tables
- GROUP BY membership tier

**No special configuration needed.**

### MySQL Implementation

**Status:** ✓ Complete

**Performance:**
- **Isolated query:** 8.6s at 1GB, 46s at 4GB
- **Under load (15 threads):** 80-96s at 4GB
- Significantly slower than SQL Server due to aggregation behavior

**REQUIRED CONFIGURATION:**

#### 1. Buffer Tuning (Critical)

MySQL requires larger temporary table buffers to avoid spilling to disk during aggregation.

**Edit `/etc/my.cnf`:**
```ini
[mysqld]
tmp_table_size = 256M
max_heap_table_size = 256M
```

**Restart MariaDB/MySQL:**
```bash
sudo systemctl restart mariadb
```

**Verify settings:**
```bash
mariadb -u root -p -e "SHOW VARIABLES LIKE 'tmp_table_size'; SHOW VARIABLES LIKE 'max_heap_table_size';"
```

Should show **268435456** (256MB) for both, not **16777216** (16MB default).

**Performance impact of buffer tuning:**
- **Without tuning (16MB):** 1m16s at 1GB (unacceptable)
- **With tuning (256MB):** 8.6s at 1GB (acceptable) ✓

**Why 256MB?**
- Optimal performance-to-memory ratio
- Larger buffers (512MB, 1GB) tested slower (memory allocation overhead)
- Allows CustomerOrders CTE aggregation to stay in memory

#### 2. Isolation Level (Prevents Locking)

The stored procedure automatically uses **READ UNCOMMITTED** isolation to prevent table locks.

**Why this matters:**
- Analytics reads MEMBERSHIP table during 8-80 second query
- Default isolation (REPEATABLE READ) holds read locks
- Causes deadlocks with Renew_Membership operations
- READ UNCOMMITTED allows "dirty reads" (acceptable for analytics)

**Implemented in stored procedure:**
```sql
CREATE PROCEDURE DS3.GetMembershipAnalytics1()
BEGIN
  SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
  -- Analytics query...
END
```

**Result:** No more "Deadlock found" errors in Renew_Membership operations ✓

#### 3. MySQL Buffer Pool (General Performance)

For best overall MySQL performance (not just analytics), ensure InnoDB buffer pool is sized appropriately.

**Check current setting:**
```bash
mariadb -u root -p -e "SHOW VARIABLES LIKE 'innodb_buffer_pool_size';"
```

**Recommended:** 75-80% of available system RAM for dedicated database server.

**Example for 8GB RAM system:**
```ini
[mysqld]
innodb_buffer_pool_size = 6G
```

This improves all queries, not just analytics.

### PostgreSQL Implementation

**Status:** ✓ Complete

**Performance:**
- **Isolated query:** 18.7s at 4GB
- **Under load (15 threads):** 31s at 4GB
- Faster than MySQL, slower than SQL Server/Oracle
- No special tuning required

**Query approach:**
- Single CTE aggregating ORDERS table (COUNT + SUM)
- LEFT JOIN to CUSTOMERS and MEMBERSHIP tables
- GROUP BY membership tier
- Returns TABLE result set

**No special configuration needed** - performs well out of the box.

### Oracle Implementation

**Status:** ✓ Complete

**Performance:**
- **1GB:** ~2.8 seconds average
- **4GB under load (15 threads):** ~9.7 seconds average
- Excellent performance - second only to SQL Server
- Much faster than MySQL and PostgreSQL

**Query approach:**
- Single CTE aggregating ORDERS table (COUNT + SUM)
- LEFT JOIN to CUSTOMERS and MEMBERSHIP tables
- GROUP BY membership tier
- REF CURSOR for result set

**No special configuration needed** - performs well out of the box at all tested sizes.

## Performance and Thread Architecture

### Two-Thread Architecture

**Analytics runs in a separate thread from manager operations** - operations and analytics execute concurrently without blocking each other.

**Thread Structure:**
- **Manager Thread:** Runs operations (AddProduct, AdjustPrices, ExpireMemberships, etc.) on 30-second intervals
- **Analytics Thread:** Runs analytics queries (GetMembershipAnalytics, etc.) on configurable interval (1-15 minutes)
- **Independent Connections:** Each thread has its own database connection (Manager: ID +10000, Analytics: ID +20000)

**Before Two-Thread (Old Architecture):**
```
Total Operations: 36
  GetMembershipAnalytics:  4 operations, avg RT: 80.091 sec
  ExpireMemberships:      16 operations
  UpgradeMembership:       9 operations
  PromotionalMembership:   8 operations
  Other operations:        3 operations
```
- 4 analytics × 80s = 320 seconds on analytics
- 53% of manager time blocked
- Only 280 seconds available for operations

**After Two-Thread (Current Architecture):**
```
Manager Operations: 120+ operations
  ExpireMemberships:      40+ operations
  UpgradeMembership:      30+ operations
  PromotionalMembership:  25+ operations
  Other operations:       25+ operations

Analytics Operations: 10 operations
  GetMembershipAnalytics: 10 operations, avg RT: 80.091 sec
```
- Operations run continuously without blocking
- Analytics runs in parallel
- 3-4× more manager operations complete

**Benefits:**
- No blocking: Manager operations never wait for analytics
- Better resource utilization: Both threads use available CPUs
- Cleaner separation: Analytics complexity isolated from manager logic
- Easier to add new analytics: Just add to analytics thread

## Future Analytics Features

### GetProductAnalytics (Planned)

Track product performance and inventory metrics:

**Product Operations:**
- Products added by AddProduct manager operation
- Net product count change

**Sales Performance:**
- Top-selling products (by order count)
- Category distribution
- Revenue by category

**Price Adjustments:**
- Price changes (count, average adjustment)
- Products with .77 endings (BulkPriceAdjustment)
- Products with .99 endings (AdjustPrices)
- Price increase vs decrease ratio

**Inventory Metrics:**
- Products with zero/low inventory (out of stock)
- Products with high inventory (overstocked)
- Total inventory value (SUM(qty * price))
- Average stock levels by category
- Inventory added from AddProduct operations

**Status:** Not yet implemented

## GetReviewAnalytics

Tracks customer review generation activity during benchmark runs.

**Primary Focus:**
- **NEW_PROD_REVIEW** operations (customer threads creating reviews)
- **NEW_REVIEW_HELPFULNESS** operations (customer threads rating review helpfulness)
- Star rating distribution of new reviews
- Helpfulness metrics and TOTAL_HELPFULNESS accuracy

**Incidental tracking:**
- Manager operations that remove reviews created during test (RemoveUnhelpfulReviews, RemoveReviewByProduct)
- Manager operations removing old reviews won't show in "Removed" column

### Metrics Displayed

```
============================================================================================================
Review Analytics (Store 1) - Delta since baseline
============================================================================================================
Stars      Reviews      Added    Removed    Net Change    Avg Help     High Help      Low Help    % of Total
-----      -------      -----    -------    ----------    --------     ---------      --------    ----------
   5       62,768     15,148        332        14,816        87.2         44,972        13,708         18.8%
   4       70,682     22,861        329        22,532        77.7         45,284        20,187         21.2%
   3       85,108     37,745        295        37,450        64.2         44,850        33,267         25.5%
   2       62,935     15,283        332        14,951        87.3         45,067        13,439         18.9%
   1       51,799      3,874        331         3,543       106.2         45,388         3,433         15.5%
============================================================================================================
Total: 333,292 reviews    Avg: 3.09 stars, 82.3 helpfulness
============================================================================================================
```

**Columns:**
- **Stars:** Star rating (5 to 1)
- **Reviews:** Current total count of reviews at this star level
- **Added:** Reviews created during test (REVIEW_ID > baseline max)
- **Removed:** Reviews created during test that were deleted (Added - Net Change)
- **Net Change:** Current count - Baseline count (shows growth/decline per star level)
- **Avg Help:** Average TOTAL_HELPFULNESS for reviews at this star level
- **High Help:** Count of reviews with TOTAL_HELPFULNESS >= 20
- **Low Help:** Count of reviews with TOTAL_HELPFULNESS < 5
- **% of Total:** Percentage of all reviews at this star level

**Summary Line:**
- **Total reviews:** Current absolute count in database
- **Avg stars:** Weighted average star rating across all current reviews
- **Avg helpfulness:** Weighted average TOTAL_HELPFULNESS across all current reviews

### Baseline and Delta Tracking

**Baseline capture at test start (before Controller.Start = true):**
```sql
MAX(REVIEW_ID) FROM REVIEWS  -- e.g., 240,000 (last review before test)
COUNT(*) WHERE STARS=5       -- Baseline count for each star level
```

**Delta calculations:**
- **Added:** Reviews with REVIEW_ID > baseline (created during test)
- **Current:** Current count at each star level
- **Net Change:** Current - Baseline
- **Removed:** Added - Net Change (reviews created during test that were deleted)

**What "Removed" captures:**
- Reviews created during test (REVIEW_ID > baseline) that were then deleted
- Primarily RemoveUnhelpfulReviews hitting new reviews with low helpfulness
- RemoveReviewByProduct if it removes a new review

**What "Removed" misses:**
- RemoveReviewsByDate removing old reviews (REVIEW_ID < baseline)
- Manager operations removing historical reviews

This aligns with delta tracking philosophy - focus on lifecycle of reviews created during this test run.

### Use Cases

- **Validate manager operations:** Track RemoveUnhelpfulReviews, RemoveReviewByProduct impact on new reviews
- **Star distribution analysis:** See if benchmark generates realistic rating patterns (skewed positive: 5% / 16% / 40% / 24% / 15% for 1-5 stars)
- **Helpfulness trigger validation:** Verify TOTAL_HELPFULNESS calculations across databases

## GetNewCustomerAnalytics

Tracks new customer acquisition and engagement during benchmark runs.

### Metrics Displayed

```
New Customer Analytics (Store 1) - Delta since baseline
===============================================================================
Created    2+ Orders    3+ Orders    % Active    Orders    Ord/Cust    % Orders
-------    ---------    ---------    --------    ------    --------    --------
  6,262          193            4        3.1%     6,410        1.02       10.4%
===============================================================================
```

**Columns:**
- **Created:** New customers created since baseline (CUSTOMERID > baseline customer count)
- **2+ Orders:** Customers who returned for at least one more order ("Active" customers)
- **3+ Orders:** Highly engaged customers (returned twice or more)
- **% Active:** Percentage of new customers who returned (TwoPlus / Created × 100)
- **Orders:** Total orders from new customers
- **Ord/Cust:** Average orders per new customer (Orders / Created)
- **% Orders:** Percentage of all benchmark orders from new customers

### Baseline and Delta Tracking

**Baseline capture happens at test start:**
- Analytics thread captures initial customer count (SELECT COUNT(*) FROM CUSTOMERS)
- Analytics thread captures initial order count (SELECT COUNT(*) FROM ORDERS)
- Stored in memory for duration of test
- All subsequent analytics show **deltas** (changes since baseline)

**Delta calculations:**
- **Created:** Customers with CUSTOMERID > baseline customer count
- **Orders from new customers:** COUNT(*) where CUSTOMERID > baseline
- **% Orders:** (Orders from new customers) / (Current total orders - Baseline total orders) × 100

**Validation check:**
The **% Orders** metric should match the `pct_newcustomers` parameter:
- `pct_newcustomers=10` → expect ~10% of benchmark orders from new customers
- `pct_newcustomers=20` → expect ~20% of benchmark orders from new customers

This validates that the implementation correctly identifies new customers and their orders.

### Multi-Store Support

**All implementations validated with multi-store configurations:**
- Each analytics thread captures its own baseline (per store)
- Analytics output shows correct store number in header
- Works with or without membership analytics enabled

**Example (2 stores):**
```
New Customer Analytics (Store 1) - Delta since baseline
...
  6,050          190            6        3.1%     6,193        1.02       10.3%

New Customer Analytics (Store 2) - Delta since baseline
...
  6,000          174            1        2.9%     6,124        1.02       10.3%
```

## Future Analytics Features

### GetProductAnalytics (Planned)

---
