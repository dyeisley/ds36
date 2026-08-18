
<?php
/*
 * DVD Store Browse Reviews PHP Page - dsbrowsereviews.php
 *
 * Copyright (C) 2026 Red Hat, Inc.
 *
 * Browse Reviews of products in SQL Server DVD store by author and title keywords
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
  $conn = ds_connect();

  switch ($browsereviewtype)
    {
    case "title":
      $title_terms = '"' . implode('" AND "', preg_split('/\s+/', trim($review_title))) . '"';
      $sql = "EXEC GET_PROD_REVIEWS_BY_TITLE$storenum @batch_size_in = ?, @title_in = ?, @search_depth_in = ?";
      $params = array(
        array(intval($limit_num), SQLSRV_PARAM_IN, null, SQLSRV_SQLTYPE_INT),
        $title_terms,
        array(intval($search_depth), SQLSRV_PARAM_IN, null, SQLSRV_SQLTYPE_INT)
      );
      break;
    case "actor":
      $actor_terms = '"' . implode('" AND "', preg_split('/\s+/', trim($review_actor))) . '"';
      $sql = "EXEC GET_PROD_REVIEWS_BY_ACTOR$storenum @batch_size_in = ?, @actor_in = ?, @search_depth_in = ?";
      $params = array(
        array(intval($limit_num), SQLSRV_PARAM_IN, null, SQLSRV_SQLTYPE_INT),
        $actor_terms,
        array(intval($search_depth), SQLSRV_PARAM_IN, null, SQLSRV_SQLTYPE_INT)
      );
      break;
    }

  $stmt = sqlsrv_query($conn, $sql, $params);
  if ($stmt === false) {
    die("Browse reviews failed: " . print_r(sqlsrv_errors(), true));
  }

  $row = sqlsrv_fetch_array($stmt, SQLSRV_FETCH_ASSOC);
  if ($row === null)
    {
    echo "<H2>No Reviews Found</H2>\n";
    }
  else
    {
    echo "<BR>\n";
    echo "<H2> Most Helpful Reviews matching keyword </H2>\n";
    do {
      echo "----------------------------------------------------------------------------------------------<BR>";
      echo " " . htmlspecialchars($row['TITLE']) . " starring " . htmlspecialchars($row['ACTOR']) . "<BR>\n";
      echo " Review Summary - " . htmlspecialchars($row['REVIEW_SUMMARY']) . "<BR>\n";
      echo " Rated " . htmlspecialchars($row['STARS']) . " stars<BR>\n";
      echo " Review Created By " . htmlspecialchars($row['CUSTOMERID']) . " on " . htmlspecialchars($row['REVIEW_DATE']->format('Y-m-d')) . "<BR>\n";
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
      $helpfulness = isset($row['TOTAL_HELPFULNESS']) ? $row['TOTAL_HELPFULNESS'] : 0;
      echo "<INPUT TYPE=HIDDEN NAME=helpfulness_sum VALUE=$helpfulness>\n";
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
      } while ($row = sqlsrv_fetch_array($stmt, SQLSRV_FETCH_ASSOC));
    }
  sqlsrv_free_stmt($stmt);
  sqlsrv_close($conn);
  }

ds_html_footer();
?>
