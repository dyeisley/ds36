# Data Files

C programs that generate the CSV data loaded into the database tables. These are compiled and executed by `Install_DVDStore.pl`.

| Directory | Program | Generates |
|-----------|---------|-----------|
| `cust/` | `ds3_create_cust.c` | Customer data |
| `membership/` | `ds3_create_membership.c` | Membership data |
| `orders/` | `ds3_create_orders.c`, `ds3_create_inv.c` | Orders, order lines, customer history, and inventory |
| `prod/` | `ds3_create_prod.c` | Products (with optional vector embeddings) |
| `reviews/` | `ds3_create_reviews.c` | Product reviews and helpfulness ratings |
