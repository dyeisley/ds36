
<?php
/*
 * DVD Store New Member PHP Page - dsnewmember.php
 *
 * Copyright (C) 2026 Red Hat, Inc.
 *
 * New premium membership signup using NEW_MEMBER stored procedure
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

ds_html_header("New Premium Membership Signup");

$customerid = $_REQUEST["customerid"];
$membershiplevel = isset($_REQUEST["membershiplevel"]) ? $_REQUEST["membershiplevel"] : NULL;
$storenum = isset($_REQUEST["storenum"]) ? $_REQUEST["storenum"] : 1;

if (empty($customerid))
  {
  echo "<H2>You have not logged in - Please click below to Login to DVD Store</H2>\n";
  echo "<FORM ACTION='./dslogin.php' METHOD=GET>\n";
  echo "<INPUT TYPE=SUBMIT VALUE='Login'>\n";
  echo "</FORM>\n";
  ds_html_footer();
  exit;
  }

if (!(empty($membershiplevel)))
  {
  $conn = ds_connect();

  $sql = "SELECT COUNT(*) FROM MEMBERSHIP$storenum WHERE CUSTOMERID = ?";
  $stmt = sqlsrv_query($conn, $sql, array(array(intval($customerid), SQLSRV_PARAM_IN, null, SQLSRV_SQLTYPE_INT)));
  $row = sqlsrv_fetch_array($stmt, SQLSRV_FETCH_NUMERIC);
  sqlsrv_free_stmt($stmt);

  if ($row[0] != 0)
    {
    echo "<H2>You are already a Premium Member! Enjoy Shopping the DVD Store!</H2>\n";
    echo "<FORM ACTION='./dsbrowse.php' METHOD=GET>\n";
    echo "<INPUT TYPE=HIDDEN NAME=customerid VALUE=$customerid>\n";
    echo "<INPUT TYPE=HIDDEN NAME=storenum VALUE=$storenum>\n";
    echo "<INPUT TYPE=SUBMIT VALUE='Browse'>\n";
    echo "</FORM>\n";
    ds_html_footer();
    sqlsrv_close($conn);
    exit;
    }
  else
    {
    if (($membershiplevel >= 1) AND ($membershiplevel <= 3))
      {
      $sql = "SET NOCOUNT ON; EXEC NEW_MEMBER$storenum @customerid_in = ?, @membershiplevel_in = ?";
      $params = array(
        array(intval($customerid), SQLSRV_PARAM_IN, null, SQLSRV_SQLTYPE_INT),
        array(intval($membershiplevel), SQLSRV_PARAM_IN, null, SQLSRV_SQLTYPE_INT)
      );
      $stmt = sqlsrv_query($conn, $sql, $params);
      if ($stmt === false) {
        die("NEW_MEMBER failed: " . print_r(sqlsrv_errors(), true));
      }
      sqlsrv_free_stmt($stmt);

      echo "<H2>New Premium Membership Successful.  Click below to begin shopping<H2>\n";
      echo "<FORM ACTION='./dsbrowse.php' METHOD=GET>\n";
      echo "<INPUT TYPE=HIDDEN NAME=customerid VALUE=$customerid>\n";
      echo "<INPUT TYPE=HIDDEN NAME=storenum VALUE=$storenum>\n";
      echo "<INPUT TYPE=HIDDEN NAME=membership_level VALUE=$membershiplevel>\n";
      echo "<INPUT TYPE=SUBMIT VALUE='Start Shopping'>\n";
      echo "</FORM>\n";
      ds_html_footer();
      sqlsrv_close($conn);
      exit;
      }
    }
  }
else
  {
  echo "<H2>New Premium Membership - Select Desired Level</H2>\n";
  echo "<FORM ACTION='./dsnewmember.php' METHOD='GET'>\n";
  echo "<INPUT TYPE='radio' name='membershiplevel' value='1'>Gold <BR>\n";
  echo "<INPUT TYPE='radio' name='membershiplevel' value='2'>Silver <BR>\n";
  echo "<INPUT TYPE='radio' name='membershiplevel' value='3'>Bronze <BR>\n";
  echo "<INPUT TYPE=HIDDEN NAME=customerid VALUE=$customerid>\n";
  echo "<INPUT TYPE=HIDDEN NAME=storenum VALUE=$storenum>\n";
  echo "<INPUT TYPE=submit value='Submit'>\n";
  echo "</FORM>\n";
  }
ds_html_footer();
?>
