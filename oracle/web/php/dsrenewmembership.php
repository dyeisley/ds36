
<?php
/*
 * DVD Store Renew Membership PHP Page - dsrenewmembership.php
 *
 * Copyright (C) 2026 Red Hat, Inc.
 *
 * Renew customer membership using RENEW_MEMBERSHIP stored procedure
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

ds_html_header("Renew Membership");

$customerid = $_REQUEST["customerid"];
$storenum = isset($_REQUEST["storenum"]) ? $_REQUEST["storenum"] : 1;
$membership_level = isset($_REQUEST["membership_level"]) ? $_REQUEST["membership_level"] : 0;

$conn = oci_pconnect($oracle_user, $oracle_password, $oracle_connstr);
if (!$conn) {
  $e = oci_error();
  die("Oracle connection failed: " . htmlentities($e['message'], ENT_QUOTES));
}

$sql = "BEGIN DS3.RENEW_MEMBERSHIP$storenum(:p_customerid, :p_rows_affected); END;";
$stmt = oci_parse($conn, $sql);
oci_bind_by_name($stmt, ':p_customerid', $customerid, -1, SQLT_INT);
oci_bind_by_name($stmt, ':p_rows_affected', $rows_affected, -1, SQLT_INT);
oci_execute($stmt);
oci_free_statement($stmt);

if ($rows_affected > 0) {
  echo "<H2>Membership Renewed Successfully!</H2>\n";
  echo "<P>Your membership has been extended for another year.</P>\n";
  echo "<P>Thank you for your continued support!</P>\n";
} else {
  echo "<H2>Membership Renewal Failed</H2>\n";
  echo "<P>We were unable to renew your membership. Please contact customer support.</P>\n";
}

echo "<INPUT TYPE=HIDDEN NAME=rows_affected VALUE=$rows_affected>\n";

echo "<FORM ACTION='./dsbrowse.php' METHOD=GET>\n";
echo "<INPUT TYPE=HIDDEN NAME=customerid VALUE=$customerid>\n";
echo "<INPUT TYPE=HIDDEN NAME=storenum VALUE=$storenum>\n";
echo "<INPUT TYPE=HIDDEN NAME=membership_level VALUE=$membership_level>\n";
echo "<INPUT TYPE=SUBMIT VALUE='Start Shopping'>\n";
echo "</FORM>\n";

oci_close($conn);
ds_html_footer();
?>
