# Web Driver

C# driver for 3-tier web benchmarking. Instead of calling stored procedures directly, this driver sends HTTP requests to PHP pages hosted on a web server, which in turn call the database.

## Files

| File | Purpose |
|------|---------|
| `ds36webfns.cs` | Web-specific function implementations. Customer operations (login, browse, purchase, membership) make HTTP calls to PHP pages. Manager and analytics operations are stubs that return defaults since those are backend-only. |
| `web_ds.csproj` | Project file referencing this file plus the shared driver files from `../drivers/`. |

## PHP Pages

The PHP pages are located in each database directory:

- `mysql/web/php7/` — MySQL (PHP 7+)
- `pgsql/web/php7/` — PostgreSQL (PHP 7+)
- `oracle/web/php/` — Oracle
- `sqlserver/web/php/` — SQL Server

## Web Server Setup

Install Apache and PHP-FPM:

```bash
sudo dnf install -y httpd php php-fpm
sudo systemctl enable --now httpd php-fpm
```

Install the PHP database extension for your database:

| Database | Install |
|----------|---------|
| MySQL | `dnf install php-mysqlnd` |
| PostgreSQL | `dnf install php-pgsql` |
| Oracle | `dnf install php-devel php-pear` then `pecl install oci8-3.0.1` (requires Oracle Instant Client) |
| SQL Server | `dnf install php-devel php-pear` then `pecl install sqlsrv` (requires Microsoft ODBC Driver 18) |

See `oracle/web/php/README.txt` and `sqlserver/web/php/README.txt` for detailed Oracle and SQL Server setup instructions.

Copy the PHP pages to the web root:

```bash
cp -r mysql/web/php7/* /var/www/html/ds3/
```

Replace `mysql/web/php7` with the appropriate directory for your database. The virtual directory name `ds3` matches the default `--virt_dir=ds3` parameter.

Edit `dscommon.inc` in the copied directory to set the database hostname and credentials.

## Usage

```
cd web
dotnet run -- --target=webserver-hostname --virt_dir=ds3 --page_type=php --n_threads=16 --run_time=10
```
