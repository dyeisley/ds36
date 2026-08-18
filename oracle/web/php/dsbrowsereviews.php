
<?php
/*
 * DVD Store Browse Reviews PHP Page - dsbrowsereviews.php
 *
 * Copyright (C) 2005 Dell, Inc. <davejaffe7@gmail.com> and <tmuirhead@vmware.com>
 *
 * Browse Reviews of products in Oracle DVD store by author and title based on keywords
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

ds_html_header("DVD Store Browse Product Reviews Page");

$customerid = $_REQUEST["customerid"];
$storenum = isset($_REQUEST["storenum"]) ? $_REQUEST["storenum"] : 1;
$review_title = isset($_REQUEST["review_title"]) ? $_REQUEST["review_title"] : NULL;
$review_actor = isset($_REQUEST["review_actor"]) ? $_REQUEST["review_actor"] : NULL;
$limit_num = isset($_REQUEST["limit_num"]) ? $_REQUEST["limit_num"] : NULL;
$search_depth = isset($_REQUEST["search_depth"]) ? $_REQUEST["search_depth"] : 500;
$browsereviewtype = isset($_REQUEST["browsereviewtype"]) ? $_REQUEST["browsereviewtype"] : NULL;
$membership_level = isset($_REQUEST["membership_level"]) ? $_REQUEST["membership_level"] : 0;

if (empty($customerid))
  {
  echo "<H2>You have not logged in - Please click below to Login to DVD Store</H2>\n";
  echo "<FORM ACTION='./dslogin.php' METHOD=GET>\n";
  echo "<INPUT TYPE=SUBMIT VALUE='Login'>\n";
  echo "</FORM>\n";
  ds_html_footer();
  exit;
  }

echo "<H2>Browse for Product Reviews by Keyword in Title or Actor   </H2>\n";

echo "<FORM ACTION='./dsbrowsereviews.php' METHOD='GET'>\n";
echo "<INPUT NAME='browsereviewtype' TYPE=RADIO VALUE='title'"; if($browsereviewtype == 'title') echo "CHECKED";
echo ">Title  <INPUT NAME='review_title' VALUE='$review_title' TYPE=TEXT SIZE=15> <BR>\n";
echo "<INPUT NAME='browsereviewtype' TYPE=RADIO VALUE='actor'"; if($browsereviewtype == 'actor') echo "CHECKED";
echo ">Actor  <INPUT NAME='review_actor' VALUE='$review_actor' TYPE=TEXT SIZE=15> <BR>\n";
echo "Number of search results to return\n";
echo "<SELECT NAME='limit_num'>\n";
for ($i=1; $i<11; $i++)
  {
  if ($i == $limit_num)
    {echo "  <OPTION VALUE=$i SELECTED>$i</OPTION>\n";}
  else
    {echo "  <OPTION VALUE=$i>$i</OPTION>\n";}
  }
echo "</SELECT><BR>\n";

echo "<INPUT TYPE=HIDDEN NAME=customerid VALUE='$customerid'>\n";
echo "<INPUT TYPE=HIDDEN NAME=storenum VALUE=$storenum>\n";
echo "<INPUT TYPE=HIDDEN NAME=membership_level VALUE=$membership_level>\n";
echo "<INPUT TYPE=SUBMIT VALUE='Search'>\n";
echo "</FORM>\n";

if (!empty($browsereviewtype))
  {
  $conn = oci_pconnect($oracle_user, $oracle_password, $oracle_connstr);
  if (!$conn) {
    $e = oci_error();
    die("Oracle connection failed: " . htmlentities($e['message'], ENT_QUOTES));
  }

  switch ($browsereviewtype)
    {
    case "title":
      $sql = "BEGIN DS3.GET_PROD_REVIEWS_BY_TITLE$storenum(:p_title, :p_batch_size, :p_search_depth); END;";
      $stmt = oci_parse($conn, $sql);
      oci_bind_by_name($stmt, ':p_title', $review_title, 60);
      oci_bind_by_name($stmt, ':p_batch_size', $limit_num, -1, SQLT_INT);
      oci_bind_by_name($stmt, ':p_search_depth', $search_depth, -1, SQLT_INT);
      break;
    case "actor":
      $sql = "BEGIN DS3.GET_PROD_REVIEWS_BY_ACTOR$storenum(:p_actor, :p_batch_size, :p_search_depth); END;";
      $stmt = oci_parse($conn, $sql);
      oci_bind_by_name($stmt, ':p_actor', $review_actor, 60);
      oci_bind_by_name($stmt, ':p_batch_size', $limit_num, -1, SQLT_INT);
      oci_bind_by_name($stmt, ':p_search_depth', $search_depth, -1, SQLT_INT);
      break;
    }

  oci_execute($stmt);

  $reviews = array();
  $implicit = oci_get_implicit_resultset($stmt);
  if ($implicit) {
    while ($row = oci_fetch_assoc($implicit)) {
      $reviews[] = $row;
    }
  }
  oci_free_statement($stmt);

  if (count($reviews) == 0)
    {
    echo "<H2>No Reviews Found</H2>\n";
    }
  else
    {
    echo "<BR>\n";
    echo "<H2> Most Helpful Reviews matching keyword </H2>\n";
    foreach ($reviews as $row)
      {
      echo "----------------------------------------------------------------------------------------------<BR>";
      echo " " . htmlspecialchars($row['TITLE']) . " starring " . htmlspecialchars($row['ACTOR']) . "<BR>\n";
      echo " Review Summary - " . htmlspecialchars($row['REVIEW_SUMMARY']) . "<BR>\n";
      echo " Rated " . htmlspecialchars($row['STARS']) . " stars<BR>\n";
      echo " Review Created By " . htmlspecialchars($row['CUSTOMERID']) . " on " . htmlspecialchars($row['REVIEW_DATE']) . "<BR>\n";
      echo " " . htmlspecialchars($row['REVIEW_TEXT']) . "<BR>\n";
      echo "<FORM ACTION='./dsnewhelpfulness.php' METHOD='GET'>\n";
      echo "Helpfulness ranking of this review (10 is most helpful) \n";

      echo "<SELECT NAME='review_helpfulness'>\n";
      for ($i=1; $i<=10; $i++)
        {
        echo "  <OPTION VALUE=$i>$i</OPTION>\n";
        }
      echo "</SELECT><BR>\n";
      echo "<INPUT TYPE=HIDDEN NAME=customerid VALUE=$customerid>\n";
      echo "<INPUT TYPE=HIDDEN NAME=storenum VALUE=$storenum>\n";
      echo "<INPUT TYPE=HIDDEN NAME=reviewid VALUE=" . $row['REVIEW_ID'] . ">\n";
      echo "<INPUT TYPE=HIDDEN NAME=productid VALUE=" . $row['PROD_ID'] . ">\n";
      echo "<INPUT TYPE=HIDDEN NAME=helpfulness_sum VALUE=" . $row['HELPFULNESS_TOTAL'] . ">\n";
      echo "<INPUT TYPE='submit' VALUE='Submit Helpfulness Rating'>\n";
      echo "</FORM>\n";
      echo "<FORM ACTION='./dsnewreview.php' METHOD='GET'>\n";
      echo "OR \n";
      echo "<INPUT TYPE=HIDDEN NAME=customerid VALUE=$customerid>\n";
      echo "<INPUT TYPE=HIDDEN NAME=storenum VALUE=$storenum>\n";
      echo "<INPUT TYPE=HIDDEN NAME=productid VALUE=" . $row['PROD_ID'] . ">\n";
      echo "<INPUT TYPE=HIDDEN NAME=review_title VALUE='" . htmlspecialchars($row['TITLE']) . "'>\n";
      echo "<INPUT TYPE='submit' VALUE='Create a New Review'>\n";
      echo "</FORM>\n";
      }
    }
  oci_close($conn);
  }

ds_html_footer();
?>
