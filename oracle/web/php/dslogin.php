
<?php
/*
 * DVD Store Login PHP Page - dslogin.php
 *
 * Copyright (C) 2005 Dell, Inc. <davejaffe7@gmail.com> and <tmuirhead@vmware.com>
 *
 * Login to Oracle DVD store
 *
 * Last Updated 7/30/2026
 *
 * Support for PHP 8 and Oracle OCI8
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
  // Connect to Oracle
  $conn = oci_pconnect($oracle_user, $oracle_password, $oracle_connstr);
  if (!$conn) {
    $e = oci_error();
    die("Oracle connection failed: " . htmlentities($e['message'], ENT_QUOTES));
  }

  // Call LOGIN stored procedure - returns customerid as OUT parameter and result set via DBMS_SQL.RETURN_RESULT
  $sql = "BEGIN DS3.LOGIN$storenum(:p_username, :p_password, :p_customerid); END;";
  $stmt = oci_parse($conn, $sql);

  oci_bind_by_name($stmt, ':p_username', $username, 24);
  oci_bind_by_name($stmt, ':p_password', $password, 24);
  oci_bind_by_name($stmt, ':p_customerid', $customerid, -1, SQLT_INT);

  oci_execute($stmt);

  // Get implicit result set (purchase history) via DBMS_SQL.RETURN_RESULT
  $history = array();
  $implicit = oci_get_implicit_resultset($stmt);
  if ($implicit) {
    while ($row = oci_fetch_assoc($implicit)) {
      $history[] = $row;
    }
  }

  if ($customerid > 0)
    {
    echo "<H2>Welcome to the DVD Store - Click below to begin shopping</H2>\n";

    if (count($history) > 0)
      {
      echo "<H3>Your previous purchases:</H3>\n";
      echo "<TABLE border=2>\n";
      echo "<TR>\n";
      echo "<TH>Title</TH>\n";
      echo "<TH>Actor</TH>\n";
      echo "<TH>People who liked this DVD also liked</TH>\n";
      echo "</TR>\n";

      foreach ($history as $row)
        {
        echo " <TR>\n";
        echo "<TD>" . htmlspecialchars($row['TITLE']) . "</TD>";
        echo "<TD>" . htmlspecialchars($row['ACTOR']) . "</TD>";
        echo "<TD>" . htmlspecialchars($row['RELATEDTITLE']) . "</TD>";
        echo "</TR>\n";
        }
      echo "</TABLE>\n";
      echo "<BR>\n";
      }

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

    oci_free_statement($stmt);
    }
  else
    {
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
  oci_close($conn);
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
