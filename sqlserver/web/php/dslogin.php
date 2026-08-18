
<?php
/*
 * DVD Store Login PHP Page - dslogin.php
 *
 * Copyright (C) 2005 Dell, Inc. <davejaffe7@gmail.com> and <tmuirhead@vmware.com>
 *
 * Login to SQL Server DVD store
 *
 * Last Updated 8/13/2026
 *
 * Support for PHP 8 and sqlsrv
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
*/

include("dscommon.inc");

ds_html_header("DVD Store Login Page");

$username = $_REQUEST["username"];
$password = $_REQUEST["password"];
$storenum = isset($_REQUEST["storenum"]) ? $_REQUEST["storenum"] : 1;

if (!(empty($username)))
  {
  $conn = ds_connect();

  $sql = "EXEC LOGIN$storenum @username_in = ?, @password_in = ?";
  $params = array($username, $password);
  $stmt = sqlsrv_query($conn, $sql, $params);

  if ($stmt === false) {
    die("LOGIN procedure failed: " . print_r(sqlsrv_errors(), true));
  }

  $row = sqlsrv_fetch_array($stmt, SQLSRV_FETCH_NUMERIC);
  $customerid = $row ? $row[0] : 0;

  if ($customerid > 0)
    {
    echo "<H2>Welcome to the DVD Store - Click below to begin shopping</H2>\n";

    if (sqlsrv_next_result($stmt))
      {
      $has_history = false;
      while ($row = sqlsrv_fetch_array($stmt, SQLSRV_FETCH_NUMERIC))
        {
        if (!$has_history)
          {
          echo "<H3>Your previous purchases:</H3>\n";
          echo "<TABLE border=2>\n";
          echo "<TR>\n";
          echo "<TH>Title</TH>\n";
          echo "<TH>Actor</TH>\n";
          echo "<TH>People who liked this DVD also liked</TH>\n";
          echo "</TR>\n";
          $has_history = true;
          }
        echo " <TR>\n";
        echo "<TD>" . htmlspecialchars($row[0]) . "</TD>";
        echo "<TD>" . htmlspecialchars($row[1]) . "</TD>";
        echo "<TD>" . htmlspecialchars($row[2]) . "</TD>";
        echo "</TR>\n";
        }
      if ($has_history)
        {
        echo "</TABLE>\n";
        echo "<BR>\n";
        }
      }

    sqlsrv_free_stmt($stmt);

    echo "<FORM ACTION=\"./dsbrowse.php\" METHOD=GET>\n";
    echo "<INPUT TYPE=HIDDEN NAME=customerid VALUE=$customerid>\n";
    echo "<INPUT TYPE=HIDDEN NAME=storenum VALUE=$storenum>\n";
    echo "<INPUT TYPE=HIDDEN NAME=membership_level VALUE=0>\n";
    echo "<INPUT TYPE=SUBMIT VALUE=\"Start Shopping\">\n";
    echo "</FORM>\n";

    echo "<FORM ACTION=\"./dsgetmembershipstatus.php\" METHOD=GET>\n";
    echo "<INPUT TYPE=HIDDEN NAME=customerid VALUE=$customerid>\n";
    echo "<INPUT TYPE=HIDDEN NAME=storenum VALUE=$storenum>\n";
    echo "<INPUT TYPE=SUBMIT VALUE=\"Check Membership Status\">\n";
    echo "</FORM>\n";
    }
  else
    {
    sqlsrv_free_stmt($stmt);
    echo "<H2>Username/password incorrect. Please re-enter your username and password</H2>\n";
    echo "<FORM  ACTION=\"./dslogin.php\" METHOD=GET>\n";
    echo "Username <INPUT TYPE=TEXT NAME=\"username\" VALUE=$username SIZE=16 MAXLENGTH=24>\n";
    echo <<<EOT
Password <INPUT TYPE=PASSWORD NAME="password" SIZE=16 MAXLENGTH=24>
<INPUT TYPE=SUBMIT VALUE="Login">
</FORM>
<H2>New customer? Please click New Customer</H2>
<FORM  ACTION="./dsnewcustomer.php" METHOD=GET >
<INPUT TYPE=SUBMIT VALUE="New Customer">
<INPUT TYPE=HIDDEN NAME=storenum VALUE=$storenum>
</FORM>
EOT;
    }
  sqlsrv_close($conn);
  }
else
  {
  echo <<<EOT
<H2>Returning customer? Please enter your username and password</H2>
<FORM  ACTION="./dslogin.php" METHOD=GET >
Username <INPUT TYPE=TEXT NAME="username" SIZE=16 MAXLENGTH=24>
Password <INPUT TYPE=PASSWORD NAME="password" SIZE=16 MAXLENGTH=24>
<INPUT TYPE=SUBMIT VALUE="Login">
<INPUT TYPE=HIDDEN NAME=storenum VALUE=$storenum>
</FORM>
<H2>New customer? Please click New Customer</H2>
<FORM  ACTION="./dsnewcustomer.php" METHOD=GET >
<INPUT TYPE=SUBMIT VALUE="New Customer">
<INPUT TYPE=HIDDEN NAME=storenum VALUE=$storenum>
</FORM>
EOT;
  }
ds_html_footer();
?>
