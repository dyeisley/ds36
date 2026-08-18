
<?php
/*
 * DVD Store Renew Membership PHP Page - dsrenewmembership.php
 *
 * Copyright (C) 2026 Red Hat, Inc.
 *
 * Renew customer membership using RENEW_MEMBERSHIP stored procedure
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

ds_html_header("Renew Membership");

$customerid = $_REQUEST["customerid"];
$storenum = isset($_REQUEST["storenum"]) ? $_REQUEST["storenum"] : 1;
$membership_level = isset($_REQUEST["membership_level"]) ? $_REQUEST["membership_level"] : 0;

$conn = ds_connect();

$sql = "SET NOCOUNT ON; EXEC RENEW_MEMBERSHIP$storenum @customerid_in = ?";
$params = array(array(intval($customerid), SQLSRV_PARAM_IN, null, SQLSRV_SQLTYPE_INT));
$stmt = sqlsrv_query($conn, $sql, $params);
if ($stmt === false) {
  die("RENEW_MEMBERSHIP failed: " . print_r(sqlsrv_errors(), true));
}

$row = sqlsrv_fetch_array($stmt, SQLSRV_FETCH_ASSOC);
$rows_affected = $row ? $row['rows_affected'] : 0;
sqlsrv_free_stmt($stmt);

if ($rows_affected > 0) {
  echo "<H2>Membership Renewed Successfully!</H2>\n";
  echo "<P>Your membership has been extended for another year.</P>\n";
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

sqlsrv_close($conn);
ds_html_footer();
?>
