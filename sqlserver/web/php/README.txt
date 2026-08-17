SQL Server PHP Web Driver Setup
=================================

PHP interface to the SQL Server DVD Store 3.6 database.
For use on RHEL/Fedora with Apache, PHP-FPM, and the Microsoft ODBC Driver.

Requirements
------------
- SQL Server (tested with 2025)
- Microsoft ODBC Driver 18 for SQL Server
- Apache httpd
- PHP with php-fpm
- PHP sqlsrv extension

Installation Steps
------------------

1. Install Apache and PHP (if not already installed):

   dnf install httpd php php-fpm php-devel php-pear

2. Install Microsoft ODBC Driver for SQL Server:

   curl https://packages.microsoft.com/config/rhel/9/prod.repo | \
     sudo tee /etc/yum.repos.d/mssql-release.repo
   sudo ACCEPT_EULA=Y dnf install -y msodbcsql18 unixODBC-devel

   For RHEL 10 / Fedora, replace rhel/9 with the appropriate version.

3. Install PHP sqlsrv extension:

   pecl install sqlsrv
   echo "extension=sqlsrv.so" > /etc/php.d/20-sqlsrv.ini

   Verify: php -m | grep sqlsrv

4. Deploy PHP pages:

   The driver programs expect these files in a virtual directory "ds3".
   Copy the PHP files to the appropriate directory:

   cp *.php *.inc *.html /var/www/html/ds3/

   Or create a symbolic link:

   ln -s /path/to/sqlserver/web/php /var/www/html/ds3

5. Configure database connection:

   Edit dscommon.inc and set the SQL Server connection parameters:

   $sqlsrv_server = "localhost";
   $sqlsrv_database = "DS3";
   $sqlsrv_user = "ds3user";
   $sqlsrv_password = "";

6. Enable ODBC connection pooling:

   Add a [ODBC] section to /etc/odbcinst.ini (at the top of the file):

   [ODBC]
   Pooling=Yes

   Without this, every PHP request opens a new TCP connection to SQL
   Server, causing severe performance degradation and TCP port exhaustion
   under load.

7. TCP tuning for high thread counts:

   Under load, rapid connection cycling can fill the TCP TIME_WAIT queue,
   causing connection failures. Enable TCP port reuse:

   sysctl -w net.ipv4.tcp_tw_reuse=1

   To make it persistent across reboots:

   echo "net.ipv4.tcp_tw_reuse = 1" >> /etc/sysctl.d/99-dvdstore.conf

8. SELinux (if enforcing):

   Allow Apache/PHP to make network connections to SQL Server:

   setsebool -P httpd_can_network_connect on

9. Start services:

   systemctl enable --now httpd php-fpm

10. Verify:

   Open http://localhost/ds3/ in a browser. You should see the DVD Store login page.

Technical Notes
---------------

The PURCHASE stored procedure uses a Table-Valued Parameter (TVP)
called LineItemsType with columns (prod_id INT, qty INT). Since
direct TVP pass-through requires sqlsrv 5.10+, dspurchase.php uses
a SQL batch approach instead: it declares a @items table variable,
populates it with INSERT VALUES, then calls the PURCHASE SP. This
works with any version of the sqlsrv extension.

Files
-----
index.html                - Login page (static HTML)
dscommon.inc              - Shared config (connection parameters, HTML helpers)
dslogin.php               - Login via LOGIN stored procedure
dsbrowse.php              - Browse by title/actor/category/membership
dsbrowsereviews.php       - Browse reviews by title/actor keyword
dsgetreviews.php          - Get product reviews, filter by stars/date
dspurchase.php            - Purchase via PURCHASE stored procedure (TVP via SQL batch)
dsnewcustomer.php         - New customer registration via NEW_CUSTOMER
dsnewmember.php           - New member signup via NEW_MEMBER
dsnewreview.php           - Submit product review via NEW_PROD_REVIEW
dsnewhelpfulness.php      - Rate review helpfulness via NEW_REVIEW_HELPFULNESS
dsgetmembershipstatus.php - Check membership via GET_MEMBERSHIP_STATUS
dsrenewmembership.php     - Renew membership via RENEW_MEMBERSHIP
dsgetrowcount.php         - Row count utility
