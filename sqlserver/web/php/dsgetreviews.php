
<?php
/*
 * DVD Store Get Reviews PHP Page - dsgetreviews.php
 *
 * Copyright (C) 2026 Red Hat, Inc.
 *
 * Gets Reviews of products in SQL Server DVD store by product id, date, and star ranking
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

ds_html_header("DVD Store Get Product Reviews Page");

$customerid = $_REQUEST["customerid"];
$storenum = isset($_REQUEST["storenum"]) ? $_REQUEST["storenum"] : 1;
$review_title = isset($_REQUEST["review_title"]) ? $_REQUEST["review_title"] : NULL;
$date_order = isset($_REQUEST["date_order"]) ? $_REQUEST["date_order"] : NULL;
$review_stars = isset($_REQUEST["review_stars"]) ? $_REQUEST["review_stars"] : NULL;
$limit_num = isset($_REQUEST["limit_num"]) ? $_REQUEST["limit_num"] : NULL;
$getreviewtype = isset($_REQUEST["getreviewtype"]) ? $_REQUEST["getreviewtype"] : NULL;
$productid = isset($_REQUEST["productid"]) ? $_REQUEST["productid"] : NULL;

if (empty($customerid))
  {
  echo "<H2>You have not logged in - Please click below to Login to DVD Store</H2>\n";
  echo "<FORM ACTION='./dslogin.php' METHOD=GET>\n";
  echo "<INPUT TYPE=SUBMIT VALUE='Login'>\n";
  echo "</FORM>\n";
  ds_html_footer();
  exit;
  }

echo "<H2>Select Type of Search for $review_title </H2>\n";

echo "<FORM ACTION='./dsgetreviews.php' METHOD='GET'>\n";
echo "<INPUT NAME='getreviewtype' TYPE=RADIO VALUE='noorder'"; if($getreviewtype == 'noorder') echo "CHECKED";
echo ">Title  <INPUT NAME='review_title' VALUE='$review_title' readonly TYPE=TEXT SIZE=15> <BR>\n";
echo "<INPUT NAME='getreviewtype' TYPE=RADIO VALUE='date'"; if($getreviewtype == 'date') echo "CHECKED";
echo ">Date Order <BR>\n";
echo "<INPUT NAME='getreviewtype' TYPE=RADIO VALUE='star'"; if($getreviewtype == 'star') echo "CHECKED"; echo ">Star Level\n";
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
echo "<INPUT TYPE=HIDDEN NAME=storenum VALUE='$storenum'>\n";
echo "<INPUT TYPE=HIDDEN NAME=productid VALUE='$productid'>\n";
echo "<INPUT TYPE=SUBMIT VALUE='Search'>\n";
echo "</FORM>\n";

if (!empty($getreviewtype))
  {
  $conn = ds_connect();

  switch ($getreviewtype)
    {
    case "noorder":
      $sql = "EXEC GET_PROD_REVIEWS$storenum @batch_size_in = ?, @prod_in = ?";
      $params = array(
        array(intval($limit_num), SQLSRV_PARAM_IN, null, SQLSRV_SQLTYPE_INT),
        array(intval($productid), SQLSRV_PARAM_IN, null, SQLSRV_SQLTYPE_INT)
      );
      break;
    case "date":
      $sql = "EXEC GET_PROD_REVIEWS_BY_DATE$storenum @batch_size_in = ?, @prod_in = ?";
      $params = array(
        array(intval($limit_num), SQLSRV_PARAM_IN, null, SQLSRV_SQLTYPE_INT),
        array(intval($productid), SQLSRV_PARAM_IN, null, SQLSRV_SQLTYPE_INT)
      );
      break;
    case "star":
      $sql = "EXEC GET_PROD_REVIEWS_BY_STARS$storenum @batch_size_in = ?, @prod_in = ?, @stars_in = ?";
      $params = array(
        array(intval($limit_num), SQLSRV_PARAM_IN, null, SQLSRV_SQLTYPE_INT),
        array(intval($productid), SQLSRV_PARAM_IN, null, SQLSRV_SQLTYPE_INT),
        array(intval($review_stars), SQLSRV_PARAM_IN, null, SQLSRV_SQLTYPE_INT)
      );
      break;
    }

  $stmt = sqlsrv_query($conn, $sql, $params);
  if ($stmt === false) {
    die("Get reviews failed: " . print_r(sqlsrv_errors(), true));
  }

  $row = sqlsrv_fetch_array($stmt, SQLSRV_FETCH_ASSOC);
  if ($row === null)
    {
    echo "<H2>No Reviews Found</H2>\n";
    }
  else
    {
    echo "<BR>\n";
    echo "<H2> Most Helpful Reviews for $review_title </H2>\n";
    do {
      $review_date = ($row['REVIEW_DATE'] instanceof DateTime) ? $row['REVIEW_DATE']->format('Y-m-d') : $row['REVIEW_DATE'];
      echo "----------------------------------------------------------------------------------------------<BR>";
      echo " Review Summary - " . htmlspecialchars($row['REVIEW_SUMMARY']) . "<BR>\n";
      echo " Rated " . htmlspecialchars($row['STARS']) . " stars<BR>\n";
      echo " Review Created By " . htmlspecialchars($row['CUSTOMERID']) . " on " . htmlspecialchars($review_date) . "<BR>\n";
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
      echo "<INPUT TYPE=HIDDEN NAME=storenum VALUE='$storenum'>\n";
      echo "<INPUT TYPE=HIDDEN NAME=reviewid VALUE=" . $row['REVIEW_ID'] . ">\n";
      echo "<INPUT TYPE=HIDDEN NAME=productid VALUE=" . $row['PROD_ID'] . ">\n";
      $helpfulness = isset($row['TOTAL_HELPFULNESS']) ? $row['TOTAL_HELPFULNESS'] : 0;
      echo "<INPUT TYPE=HIDDEN NAME=helpfulness_sum VALUE=$helpfulness>\n";
      echo "<INPUT TYPE='submit' VALUE='Submit Helpfulness Rating'>\n";
      echo "</FORM>\n";
      echo "<FORM ACTION='./dsnewreview.php' METHOD='GET'>\n";
      echo "OR \n";
      echo "<INPUT TYPE=HIDDEN NAME=customerid VALUE=$customerid>\n";
      echo "<INPUT TYPE=HIDDEN NAME=storenum VALUE='$storenum'>\n";
      echo "<INPUT TYPE=HIDDEN NAME=productid VALUE=" . $row['PROD_ID'] . ">\n";
      echo "<INPUT TYPE=HIDDEN NAME=review_title VALUE='$review_title'>\n";
      echo "<INPUT TYPE='submit' VALUE='Create a New Review'>\n";
      echo "</FORM>\n";
      } while ($row = sqlsrv_fetch_array($stmt, SQLSRV_FETCH_ASSOC));
    }
  sqlsrv_free_stmt($stmt);
  sqlsrv_close($conn);
  }

ds_html_footer();
?>
