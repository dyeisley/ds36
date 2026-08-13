
<?php
/*
 * DVD Store New Product Review PHP Page - dsnewreview.php
 *
 * Copyright (C) 2005 Dell, Inc. <davejaffe7@gmail.com> and <tmuirhead@vmware.com>
 *
 * Prompts for new review content; creates new entry in Oracle DVD Store REVIEWS table
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

ds_html_header("New Review Entry");

$customerid = $_REQUEST["customerid"];
$storenum = isset($_REQUEST["storenum"]) ? $_REQUEST["storenum"] : 1;
$productid = isset($_REQUEST["productid"]) ? $_REQUEST["productid"] : NULL;
$review_stars = isset($_REQUEST["review_stars"]) ? $_REQUEST["review_stars"] : NULL;
$review_summary = isset($_REQUEST["review_summary"]) ? $_REQUEST["review_summary"] : NULL;
$review_text = isset($_REQUEST["review_text"]) ? $_REQUEST["review_text"] : NULL;

if (empty($customerid))
  {
  echo "<H2>You have not logged in - Please click below to Login to DVD Store</H2>\n";
  echo "<FORM ACTION='./dslogin.php' METHOD=GET>\n";
  echo "<INPUT TYPE=SUBMIT VALUE='Login'>\n";
  echo "</FORM>\n";
  ds_html_footer();
  exit;
  }

if (empty($productid))
  {
  echo "<H2>You have not selected a product - Please click below to Browse DVD Store</H2>\n";
  echo "<FORM ACTION='./dsbrowse.php' METHOD=GET>\n";
  echo "<INPUT TYPE=HIDDEN NAME=customerid VALUE=$customerid>\n";
  echo "<INPUT TYPE=HIDDEN NAME=storenum VALUE=$storenum>\n";
  echo "<INPUT TYPE=SUBMIT VALUE='Browse'>\n";
  echo "</FORM>\n";
  ds_html_footer();
  exit;
  }

if (!(empty($productid) OR empty($review_stars) OR empty($review_summary) OR empty($review_text)))
  {
  $conn = oci_pconnect($oracle_user, $oracle_password, $oracle_connstr);
  if (!$conn) {
    $e = oci_error();
    die("Oracle connection failed: " . htmlentities($e['message'], ENT_QUOTES));
  }

  $sql = "BEGIN DS3.NEW_PROD_REVIEW$storenum(:prod_id, :stars, :customerid, :review_summary, :review_text, :review_id_out); END;";
  $stmt = oci_parse($conn, $sql);
  oci_bind_by_name($stmt, ':prod_id', $productid, -1, SQLT_INT);
  oci_bind_by_name($stmt, ':stars', $review_stars, -1, SQLT_INT);
  oci_bind_by_name($stmt, ':customerid', $customerid, -1, SQLT_INT);
  oci_bind_by_name($stmt, ':review_summary', $review_summary, 100);
  oci_bind_by_name($stmt, ':review_text', $review_text, 1000);
  oci_bind_by_name($stmt, ':review_id_out', $reviewid, -1, SQLT_INT);
  oci_execute($stmt);
  oci_free_statement($stmt);

  echo "<H2>New Review Added.  Click below to return to shopping<H2>\n";
  echo "<FORM ACTION='./dsbrowse.php' METHOD=GET>\n";
  echo "<INPUT TYPE=HIDDEN NAME=customerid VALUE=$customerid>\n";
  echo "<INPUT TYPE=HIDDEN NAME=storenum VALUE=$storenum>\n";
  echo "<INPUT TYPE=HIDDEN NAME=reviewid VALUE=$reviewid>\n";
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
  $sql = "SELECT TITLE FROM DS3.PRODUCTS$storenum WHERE PROD_ID = :prod_id";
  $stmt = oci_parse($conn, $sql);
  oci_bind_by_name($stmt, ':prod_id', $productid, -1, SQLT_INT);
  oci_execute($stmt);
  $row = oci_fetch_array($stmt, OCI_ASSOC);
  $producttitle = $row['TITLE'];
  oci_free_statement($stmt);
  oci_close($conn);

  echo "<H2>New Product Review  - Please Complete All Fields Below (marked with *)</H2>\n";
  dsnewreview_form($productid,$review_stars,$customerid,$review_summary,$review_text,$producttitle,$storenum);
  }

ds_html_footer();

function dsnewreview_form($productid,$review_stars,$customerid,$review_summary,$review_text,$producttitle,$storenum)
  {
  echo "<FORM ACTION='./dsnewreview.php' METHOD='GET'>\n";
  echo "Product ID <INPUT TYPE=TEXT NAME='productid' VALUE='$productid' SIZE=16 MAXLENGTH=50>* <BR>\n";
  echo "Movie Title <INPUT TYPE=TEXT NAME='producttitle' VALUE='$producttitle' SIZE=16 MAXLENGTH=50>* <BR>\n";
  echo "Review Summary <INPUT TYPE=TEXT NAME='review_summary' VALUE='$review_summary' SIZE=16 MAXLENGTH=50>* <BR>\n";
  echo "Review </BR><TEXTAREA NAME='review_text' COLS='70' ROWS='5'>$review_text </TEXTAREA> <BR>\n";
  echo "Stars Ranking \n";
  $star_levels = array("*", "**", "***", "****", "*****");

  echo "<SELECT NAME='review_stars'>\n";
  for ($i=0; $i<count($star_levels); $i++)
    {
    $j=$i+1;
    if ($j == $review_stars)
      {echo "  <OPTION VALUE=$j SELECTED>$star_levels[$i]</OPTION>\n";}
    else
      {echo "  <OPTION VALUE=$j>$star_levels[$i]</OPTION>\n";}
    }
  echo "</SELECT><BR>\n";
  echo "<INPUT TYPE=HIDDEN NAME=customerid VALUE='$customerid'>\n";
  echo "<INPUT TYPE=HIDDEN NAME=storenum VALUE=$storenum>\n";
  echo "<INPUT TYPE='submit' VALUE='Submit New Product Review'>\n";
  echo "</FORM>\n";
  }

?>
