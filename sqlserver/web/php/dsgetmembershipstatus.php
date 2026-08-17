
<?php
/*
 * DVD Store Get Membership Status PHP Page - dsgetmembershipstatus.php
 *
 * Copyright (C) 2026 Red Hat, Inc.
 *
 * Check customer membership status using GET_MEMBERSHIP_STATUS stored procedure
 *
 * Last Updated 8/17/2026
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

ds_html_header("Membership Status");

$customerid = $_REQUEST["customerid"];
$storenum = isset($_REQUEST["storenum"]) ? $_REQUEST["storenum"] : 1;

$conn = ds_connect();

$sql = "SET NOCOUNT ON; EXEC GET_MEMBERSHIP_STATUS$storenum @customerid_in = ?";
$params = array(array(intval($customerid), SQLSRV_PARAM_IN, null, SQLSRV_SQLTYPE_INT));
$stmt = sqlsrv_query($conn, $sql, $params);
if ($stmt === false) {
  die("GET_MEMBERSHIP_STATUS failed: " . print_r(sqlsrv_errors(), true));
}

$row = sqlsrv_fetch_array($stmt, SQLSRV_FETCH_ASSOC);
$membership_level = $row ? $row['membership_level'] : 0;
$is_expired = $row ? $row['is_expired'] : 0;
sqlsrv_free_stmt($stmt);

if ($membership_level > 0) {
  $tier_names = ['', 'Bronze', 'Silver', 'Gold'];
  $tier_name = $tier_names[$membership_level];
  if ($is_expired == 1) {
    echo "<H2>Your membership: $tier_name (EXPIRED)</H2>\n";
    echo "<P>Your membership has expired. Please renew to continue enjoying member benefits.</P>\n";
  } else {
    echo "<H2>Your membership: $tier_name (Active)</H2>\n";
    echo "<P>Thank you for being a valued member!</P>\n";
  }
} else {
  echo "<H2>Not a premium member</H2>\n";
  echo "<P>You are currently browsing as a regular customer.</P>\n";
}

echo "<INPUT TYPE=HIDDEN NAME=membership_level VALUE=$membership_level>\n";
echo "<INPUT TYPE=HIDDEN NAME=is_expired VALUE=$is_expired>\n";

if ($membership_level > 0 && $is_expired == 1) {
  echo "<FORM ACTION='./dsrenewmembership.php' METHOD=GET>\n";
  echo "<INPUT TYPE=HIDDEN NAME=customerid VALUE=$customerid>\n";
  echo "<INPUT TYPE=HIDDEN NAME=storenum VALUE=$storenum>\n";
  echo "<INPUT TYPE=HIDDEN NAME=membership_level VALUE=$membership_level>\n";
  echo "<INPUT TYPE=SUBMIT VALUE='Renew Membership'>\n";
  echo "</FORM>\n";
  echo "<BR>\n";

  echo "<FORM ACTION='./dsbrowse.php' METHOD=GET>\n";
  echo "<INPUT TYPE=HIDDEN NAME=customerid VALUE=$customerid>\n";
  echo "<INPUT TYPE=HIDDEN NAME=storenum VALUE=$storenum>\n";
  echo "<INPUT TYPE=HIDDEN NAME=membership_level VALUE=0>\n";
  echo "<INPUT TYPE=SUBMIT VALUE='Browse Without Renewing'>\n";
  echo "</FORM>\n";
} else if ($membership_level == 0) {
  echo "<FORM ACTION='./dsnewmember.php' METHOD=GET>\n";
  echo "<INPUT TYPE=HIDDEN NAME=customerid VALUE=$customerid>\n";
  echo "<INPUT TYPE=HIDDEN NAME=storenum VALUE=$storenum>\n";
  echo "<INPUT TYPE=SUBMIT VALUE='Premium Member Signup'>\n";
  echo "</FORM>\n";
  echo "<BR>\n";

  echo "<FORM ACTION='./dsbrowse.php' METHOD=GET>\n";
  echo "<INPUT TYPE=HIDDEN NAME=customerid VALUE=$customerid>\n";
  echo "<INPUT TYPE=HIDDEN NAME=storenum VALUE=$storenum>\n";
  echo "<INPUT TYPE=HIDDEN NAME=membership_level VALUE=0>\n";
  echo "<INPUT TYPE=SUBMIT VALUE='Browse Without Membership'>\n";
  echo "</FORM>\n";
} else {
  echo "<FORM ACTION='./dsbrowse.php' METHOD=GET>\n";
  echo "<INPUT TYPE=HIDDEN NAME=customerid VALUE=$customerid>\n";
  echo "<INPUT TYPE=HIDDEN NAME=storenum VALUE=$storenum>\n";
  echo "<INPUT TYPE=HIDDEN NAME=membership_level VALUE=$membership_level>\n";
  echo "<INPUT TYPE=SUBMIT VALUE='Start Shopping'>\n";
  echo "</FORM>\n";
}

sqlsrv_close($conn);
ds_html_footer();
?>
