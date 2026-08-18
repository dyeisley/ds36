Oracle PHP Web Driver Setup
===========================

PHP interface to the Oracle DVD Store 3.6 database.
Tested on RHEL 10 with PHP 8.0.30 and Oracle 19c.

Requirements
------------
- Oracle Database (tested with 19c)
- Oracle Instant Client (tested with 23.26)
- Apache httpd
- PHP with php-fpm
- PHP OCI8 extension

Installation Steps
------------------

1. Install Apache and PHP:

   dnf install httpd php php-fpm

2. Install Oracle Instant Client:

   Download from https://www.oracle.com/database/technologies/instant-client.html
   or install via RPM:

   dnf install oracle-instantclient-basic oracle-instantclient-devel

   Set environment variables (add to /etc/profile.d/oracle.sh):

   export ORACLE_HOME=/usr/lib/oracle/instantclient_23_26
   export LD_LIBRARY_PATH=$ORACLE_HOME:$LD_LIBRARY_PATH

   Register the libraries so PHP-FPM can find them at runtime:

   echo /usr/lib/oracle/instantclient_23_26 > /etc/ld.so.conf.d/oracle.conf
   ldconfig

   Note: Adjust the path to match your Instant Client version and layout.
   Some installs use /usr/lib/oracle/<version>/client64/lib, others use
   /usr/lib/oracle/instantclient_<version> with no lib subdirectory.

3. Install PHP OCI8 extension:

   pecl install oci8-3.0.1

   When prompted for ORACLE_HOME, enter: instantclient,/usr/lib/oracle/instantclient_23_26

   Note: PHP 8.0 requires oci8-3.0.1 specifically. Later versions (3.2.1, 3.4.0)
   require PHP 8.1+.

   Create the extension config:

   echo "extension=oci8.so" > /etc/php.d/20-oci8.ini

   Verify: php -m | grep oci8

4. Deploy PHP pages:

   The driver programs expect these files in a virtual directory "ds3".
   Copy the PHP files to the appropriate directory:

   cp *.php *.inc *.html /var/www/html/ds3/

   Or create a symbolic link:

   ln -s /path/to/oracle/web/php /var/www/html/ds3

5. Configure database connection:

   Edit dscommon.inc and set the Oracle connection parameters:

   $oracle_host = "localhost";
   $oracle_port = "1521";
   $oracle_sid = "orcl";        # Match your Oracle SID (check with lsnrctl status)
   $oracle_user = "ds3";
   $oracle_password = "ds3";

6. Configure PHP-FPM environment:

   PHP-FPM does not inherit login shell environment variables. Add these
   to /etc/php-fpm.d/www.conf:

   env[ORACLE_HOME] = /ora/db
   env[LD_LIBRARY_PATH] = /usr/lib/oracle/instantclient_23_26

   ORACLE_HOME must point to the full Oracle database installation (not
   the Instant Client) because PHP OCI8 needs the timezone data files
   in $ORACLE_HOME/oracore/zoneinfo/. Without these, connections fail
   with ORA-01804 / OCIEnvNlsCreate() errors.

   LD_LIBRARY_PATH points to the Instant Client libraries.

   Then restart: systemctl restart php-fpm

8. SELinux:

   Allow Apache/PHP to make network connections to Oracle:

   setsebool -P httpd_can_network_connect on

9. Start services:

   systemctl enable --now httpd php-fpm

10. Verify:

   Open http://localhost/ds3/ in a browser. You should see the DVD Store login page.

Technical Notes
---------------

All pages use oci_pconnect() for persistent connections. This avoids
ORA-12519 (TNS:no appropriate service handler found) errors under load
by reusing Oracle connections across PHP-FPM requests instead of
opening/closing on every request.

Oracle stored procedures return result sets via DBMS_SQL.RETURN_RESULT
(implicit result sets). PHP OCI8 requires oci_get_implicit_resultset()
to read these -- oci_fetch_all() does not work with implicit result sets.

Oracle collection types (DS3_TYPES.N_TYPE) are associative arrays
(TABLE OF NUMBER INDEX BY BINARY_INTEGER). These do not use EXTEND()
or constructors -- assign values directly by index.

Files
-----
index.html                - Login page (static HTML)
dscommon.inc              - Shared config (connection parameters, HTML helpers)
dslogin.php               - Login via LOGIN stored procedure
dsbrowse.php              - Browse by title/actor/category/membership
dsbrowsereviews.php       - Browse reviews by title/actor keyword
dsgetreviews.php          - Get product reviews, filter by stars/date
dspurchase.php            - Purchase via PURCHASE stored procedure
dsnewcustomer.php         - New customer registration via NEW_CUSTOMER
dsnewmember.php           - New member signup via NEW_MEMBER
dsnewreview.php           - Submit product review via NEW_PROD_REVIEW
dsnewhelpfulness.php      - Rate review helpfulness via NEW_REVIEW_HELPFULNESS
dsgetmembershipstatus.php - Check membership via GET_MEMBERSHIP_STATUS
dsrenewmembership.php     - Renew membership via RENEW_MEMBERSHIP
dsgetrowcount.php         - Row count utility

