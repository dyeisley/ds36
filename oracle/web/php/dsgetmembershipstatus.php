
<?php
/*
 * DVD Store Get Membership Status PHP Page - dsgetmembershipstatus.php
 *
 * Copyright (C) 2026 Red Hat, Inc.
 *
 * Check customer membership status using GET_MEMBERSHIP_STATUS stored procedure
 *
 * Last Updated 8/13/26
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

ds_html_header("Membership Status");

$customerid = $_REQUEST["customerid"];
$storenum = isset($_REQUEST["storenum"]) ? $_REQUEST["storenum"] : 1;

$conn = oci_pconnect($oracle_user, $oracle_password, $oracle_connstr);
if (!$conn) {
  $e = oci_error();
  die("Oracle connection failed: " . htmlentities($e['message'], ENT_QUOTES));
}

$sql = "BEGIN DS3.GET_MEMBERSHIP_STATUS$storenum(:p_customerid, :p_membership_level, :p_is_expired); END;";
$stmt = oci_parse($conn, $sql);
oci_bind_by_name($stmt, ':p_customerid', $customerid, -1, SQLT_INT);
oci_bind_by_name($stmt, ':p_membership_level', $membership_level, -1, SQLT_INT);
oci_bind_by_name($stmt, ':p_is_expired', $is_expired, -1, SQLT_INT);
oci_execute($stmt);
oci_free_statement($stmt);

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

oci_close($conn);
ds_html_footer();
?>
