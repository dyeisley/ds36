
<?php
/*
 * DVD Store New Member PHP Page - dsnewmember.php
 *
 * Copyright (C) 2005 Dell, Inc. <davejaffe7@gmail.com> and <tmuirhead@vmware.com>
 *
 * Prompts for new member data; creates new entry in Oracle DVD Store MEMBERSHIP table
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
  $conn = oci_pconnect($oracle_user, $oracle_password, $oracle_connstr);
  if (!$conn) {
    $e = oci_error();
    die("Oracle connection failed: " . htmlentities($e['message'], ENT_QUOTES));
  }

  $sql = "SELECT COUNT(*) FROM DS3.MEMBERSHIP$storenum WHERE CUSTOMERID = :customerid";
  $stmt = oci_parse($conn, $sql);
  oci_bind_by_name($stmt, ':customerid', $customerid, -1, SQLT_INT);
  oci_execute($stmt);
  $row = oci_fetch_array($stmt, OCI_NUM);
  oci_free_statement($stmt);

  if ($row[0] != 0)
    {
    echo "<H2>You are already a Premium Member! Enjoy Shopping the DVD Store!</H2>\n";
    echo "<FORM ACTION='./dsbrowse.php' METHOD=GET>\n";
    echo "<INPUT TYPE=HIDDEN NAME=customerid VALUE=$customerid>\n";
    echo "<INPUT TYPE=HIDDEN NAME=storenum VALUE=$storenum>\n";
    echo "<INPUT TYPE=SUBMIT VALUE='Browse'>\n";
    echo "</FORM>\n";
    ds_html_footer();
    oci_close($conn);
    exit;
    }
  else
    {
    if (($membershiplevel >= 1) AND ($membershiplevel <= 3))
      {
      $sql = "BEGIN DS3.NEW_MEMBER$storenum(:customerid_in, :membershiplevel_in, :customerid_out); END;";
      $stmt = oci_parse($conn, $sql);
      oci_bind_by_name($stmt, ':customerid_in', $customerid, -1, SQLT_INT);
      oci_bind_by_name($stmt, ':membershiplevel_in', $membershiplevel, -1, SQLT_INT);
      oci_bind_by_name($stmt, ':customerid_out', $customerid_out, -1, SQLT_INT);
      oci_execute($stmt);
      oci_free_statement($stmt);

      echo "<H2>New Premium Membership Successful.  Click below to begin shopping<H2>\n";
      echo "<FORM ACTION='./dsbrowse.php' METHOD=GET>\n";
      echo "<INPUT TYPE=HIDDEN NAME=customerid VALUE=$customerid>\n";
      echo "<INPUT TYPE=HIDDEN NAME=storenum VALUE=$storenum>\n";
      echo "<INPUT TYPE=HIDDEN NAME=membership_level VALUE=$membershiplevel>\n";
      echo "<INPUT TYPE=SUBMIT VALUE='Start Shopping'>\n";
      echo "</FORM>\n";
      ds_html_footer();
      oci_close($conn);
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
