
<?php
/*
 * DVD Store Review Helpfulness Rating PHP Page - dsnewhelpfulness.php
 *
 * Copyright (C) 2005 Dell, Inc. <davejaffe7@gmail.com> and <tmuirhead@vmware.com>
 *
 * Allows for a product review to be rated for its helpfulness on a scale of 1 to 10.
 * Updates are made to the REVIEWS_HELPFULNESS table via a stored procedure
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

ds_html_header("Review Helpfulness Rating");

$customerid = $_REQUEST["customerid"];
$reviewid = isset($_REQUEST["reviewid"]) ? $_REQUEST["reviewid"] : NULL;
$review_helpfulness = isset($_REQUEST["review_helpfulness"]) ? $_REQUEST["review_helpfulness"] : NULL;
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

if (empty($reviewid))
  {
  echo "<H2>You have not selected a review to rate for helpfulness - Please click below to Browse Reviews</H2>\n";
  echo "<FORM ACTION='./dsgetreviews.php' METHOD=GET>\n";
  echo "<INPUT TYPE=HIDDEN NAME=customerid VALUE=$customerid>\n";
  echo "<INPUT TYPE=HIDDEN NAME=storenum VALUE=$storenum>\n";
  echo "<INPUT TYPE=SUBMIT VALUE='Browse Reviews'>\n";
  echo "</FORM>\n";
  ds_html_footer();
  exit;
  }

if (!(empty($reviewid) OR empty($review_helpfulness)))
  {
  $conn = oci_pconnect($oracle_user, $oracle_password, $oracle_connstr);
  if (!$conn) {
    $e = oci_error();
    die("Oracle connection failed: " . htmlentities($e['message'], ENT_QUOTES));
  }

  $sql = "BEGIN DS3.NEW_REVIEW_HELPFULNESS$storenum(:review_id, :customerid, :helpfulness, :helpfulness_id_out); END;";
  $stmt = oci_parse($conn, $sql);
  oci_bind_by_name($stmt, ':review_id', $reviewid, -1, SQLT_INT);
  oci_bind_by_name($stmt, ':customerid', $customerid, -1, SQLT_INT);
  oci_bind_by_name($stmt, ':helpfulness', $review_helpfulness, -1, SQLT_INT);
  oci_bind_by_name($stmt, ':helpfulness_id_out', $review_helpfulness_out, -1, SQLT_INT);
  oci_execute($stmt);
  oci_free_statement($stmt);

  echo "<H2>Review Helpfulness Rating Added.  Click below to return to shopping<H2>\n";
  echo "<FORM ACTION='./dsbrowse.php' METHOD=GET>\n";
  echo "<INPUT TYPE=HIDDEN NAME=customerid VALUE=$customerid>\n";
  echo "<INPUT TYPE=HIDDEN NAME=storenum VALUE=$storenum>\n";
  echo "<INPUT TYPE=HIDDEN NAME=helpfulnessid VALUE=$review_helpfulness_out>\n";
  echo "<INPUT TYPE=SUBMIT VALUE='Return to Shopping'>\n";
  echo "</FORM>\n";
  ds_html_footer();
  oci_close($conn);
  exit;
  }
else
  {
  $conn = oci_pconnect($oracle_user, $oracle_password, $oracle_connstr);
  if (!$conn) {
    $e = oci_error();
    die("Oracle connection failed: " . htmlentities($e['message'], ENT_QUOTES));
  }
  $sql = "SELECT REVIEW_ID, PROD_ID, REVIEW_DATE, STARS, CUSTOMERID, REVIEW_SUMMARY, REVIEW_TEXT FROM DS3.REVIEWS$storenum WHERE REVIEW_ID = :review_id";
  $stmt = oci_parse($conn, $sql);
  oci_bind_by_name($stmt, ':review_id', $reviewid, -1, SQLT_INT);
  oci_execute($stmt);
  $row = oci_fetch_array($stmt, OCI_NUM);
  oci_free_statement($stmt);
  oci_close($conn);

  echo "----------------------------------------------------------------------------------------------<BR>";
  echo " Review Summary - " . htmlspecialchars($row[5]) . "<BR>\n";
  echo " Rated " . htmlspecialchars($row[3]) . " stars<BR>\n";
  echo " Review Created By " . htmlspecialchars($row[4]) . " on " . htmlspecialchars($row[2]) . "<BR>\n";
  echo " " . htmlspecialchars($row[6]) . "<BR>\n";

  echo "<H2>Your Helpfulness Rating for This Review</H2>\n";
  echo "<FORM ACTION='./dsnewhelpfulness.php' METHOD='GET'>\n";
  echo "Helpfulness Ranking (10 is most helpful) \n";

  echo "<SELECT NAME='review_helpfulness'>\n";
  for ($i=1; $i<=10; $i++)
    {
    if ($i == $review_helpfulness)
      {echo "  <OPTION VALUE=$i SELECTED>$i</OPTION>\n";}
    else
      {echo "  <OPTION VALUE=$i>$i</OPTION>\n";}
    }
  echo "</SELECT><BR>\n";
  echo "<INPUT TYPE=HIDDEN NAME=customerid VALUE='$customerid'>\n";
  echo "<INPUT TYPE=HIDDEN NAME=storenum VALUE=$storenum>\n";
  echo "<INPUT TYPE=HIDDEN NAME=reviewid VALUE='$reviewid'>\n";
  echo "<INPUT TYPE='submit' VALUE='Submit Review Helpfulness Rating'>\n";
  echo "</FORM>\n";
  }

ds_html_footer();

?>
