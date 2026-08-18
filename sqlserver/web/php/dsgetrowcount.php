
<?php
/*
 * DVD Store Get Row Count PHP Page - dsgetrowcount.php
 *
 * Copyright (C) 2025 Red Hat, Inc.
 *
 * Returns row count for a specified table
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

ds_html_header("Get Row Count");

$tablename = $_REQUEST["tablename"];
$storenum = isset($_REQUEST["storenum"]) ? $_REQUEST["storenum"] : 1;

if (empty($tablename))
  {
  echo "<H2>Error: No table name specified</H2>\n";
  ds_html_footer();
  exit;
  }

$conn = ds_connect();

$query = "SELECT COUNT(*) FROM $tablename";
$stmt = sqlsrv_query($conn, $query);

if ($stmt === false)
  {
  echo "<H2>Error executing query: " . print_r(sqlsrv_errors(), true) . "</H2>\n";
  sqlsrv_close($conn);
  ds_html_footer();
  exit;
  }

$row = sqlsrv_fetch_array($stmt, SQLSRV_FETCH_NUMERIC);
$rowcount = $row[0];
sqlsrv_free_stmt($stmt);
sqlsrv_close($conn);

echo "<INPUT TYPE=HIDDEN NAME=rowcount VALUE=$rowcount>\n";

ds_html_footer();
?>
