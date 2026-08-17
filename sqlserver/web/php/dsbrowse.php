
<?php
/*
 * DVD Store Browse PHP Page - dsbrowse.php
 *
 * Copyright (C) 2005 Dell, Inc. <davejaffe7@gmail.com> and <tmuirhead@vmware.com>
 *
 * Browses SQL Server DVD store by author, title, or category
 *
 * Last Updated 8/13/2026
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

ds_html_header("DVD Store Browse Page");

$customerid = isset($_REQUEST["customerid"]) ? $_REQUEST["customerid"] : NULL;
$storenum = isset($_REQUEST["storenum"]) ? $_REQUEST["storenum"] : 1;
$membership_level = isset($_REQUEST["membership_level"]) ? $_REQUEST["membership_level"] : 0;
$browsetype = isset($_REQUEST["browsetype"]) ? $_REQUEST["browsetype"] : NULL;
$browse_title = isset($_REQUEST["browse_title"]) ? $_REQUEST["browse_title"] : NULL;
$browse_actor = isset($_REQUEST["browse_actor"]) ? $_REQUEST["browse_actor"] : NULL;
$browse_category = isset($_REQUEST["browse_category"]) ? $_REQUEST["browse_category"] : NULL;
$limit_num = isset($_REQUEST["limit_num"]) ? $_REQUEST["limit_num"] : NULL;
$selected_item = isset($_REQUEST["selected_item"]) ? $_REQUEST["selected_item"] : NULL;
$item = isset($_REQUEST["item"]) ? $_REQUEST["item"] : NULL;

if (empty($customerid))
  {
  echo "<H2>You have not logged in - Please click below to Login to DVD Store</H2>\n";
  echo "<FORM ACTION='./dslogin.php' METHOD=GET>\n";
  echo "<INPUT TYPE=SUBMIT VALUE='Login'>\n";
  echo "</FORM>\n";
  ds_html_footer();
  exit;
  }

if (isset($selected_item))
  {
  $n_items = is_array($item) ? count($item) : 0;
  $max_items = 10;
  for ($i=0; $i<count($selected_item) && ($n_items + $i) < $max_items; $i++)
    {
    $item[$n_items + $i] = $selected_item[$i];
    }
  }

echo "<H2>Search for DVDs</H2>\n";

echo "<FORM ACTION='./dsbrowse.php' METHOD='GET'>\n";

echo "<INPUT NAME='browsetype' TYPE=RADIO VALUE='title'"; if($browsetype == 'title') echo "CHECKED";
echo ">Title  <INPUT NAME='browse_title' VALUE='$browse_title' TYPE=TEXT SIZE=15> <BR>\n";
echo "<INPUT NAME='browsetype' TYPE=RADIO VALUE='actor'"; if($browsetype == 'actor') echo "CHECKED";
echo ">Actor  <INPUT NAME='browse_actor' VALUE='$browse_actor' TYPE=TEXT SIZE=15> <BR>\n";
echo "<INPUT NAME='browsetype' TYPE=RADIO VALUE='membership'"; if($browsetype == 'membership') echo "CHECKED";
echo ">Member Products (for your tier) <BR>\n";
echo "<INPUT NAME='browsetype' TYPE=RADIO VALUE='category'"; if($browsetype == 'category') echo "CHECKED"; echo ">Category\n";

$categories = array("Action", "Animation", "Children", "Classics", "Comedy", "Documentary", "Drama", "Family", "Foreign",
  "Games", "Horror", "Music", "New", "Sci-Fi", "Sports", "Travel");

echo "<SELECT NAME='browse_category'>\n";
for ($i=0; $i<count($categories); $i++)
  {
  $j=$i+1;
  if ($j == $browse_category)
    {echo "  <OPTION VALUE=$j SELECTED>$categories[$i]</OPTION>\n";}
  else
    {echo "  <OPTION VALUE=$j>$categories[$i]</OPTION>\n";}
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
echo "<INPUT TYPE=HIDDEN NAME=membership_level VALUE='$membership_level'>\n";
if (is_array($item)) {
  for ($i=0; $i<count($item); $i++) echo "<INPUT TYPE=HIDDEN NAME='item[]' VALUE=$item[$i]>\n";
}
echo "<INPUT TYPE=SUBMIT VALUE='Search'>\n";
echo "</FORM>\n";


echo "<H2>Or Browse DVD Reviews by Title or Actor Keyword</H2>\n";

echo "<FORM ACTION='./dsbrowsereviews.php' METHOD='GET'>\n";

echo "<INPUT NAME='browsereviewtype' TYPE=RADIO VALUE='title'";
echo ">Title  <INPUT NAME='review_title' TYPE=TEXT SIZE=15> <BR>\n";
echo "<INPUT NAME='browsereviewtype' TYPE=RADIO VALUE='actor'";
echo ">Actor  <INPUT NAME='review_actor' TYPE=TEXT SIZE=15> <BR>\n";
echo "Number of search results to return\n";
echo "<SELECT NAME='limit_num'>\n";
for ($i=1; $i<11; $i++)
  {
  echo "  <OPTION VALUE=$i>$i</OPTION>\n";
  }
echo "</SELECT><BR>\n";

echo "<INPUT TYPE=HIDDEN NAME=customerid VALUE='$customerid'>\n";
echo "<INPUT TYPE=HIDDEN NAME=storenum VALUE='$storenum'>\n";
echo "<INPUT TYPE=HIDDEN NAME=membership_level VALUE='$membership_level'>\n";
if (is_array($item)) {
  for ($i=0; $i<count($item); $i++) echo "<INPUT TYPE=HIDDEN NAME='item[]' VALUE=$item[$i]>\n";
}
echo "<INPUT TYPE=SUBMIT VALUE='Search'>\n";
echo "</FORM>\n";

if (!empty($browsetype))
  {
  $conn = ds_connect();

  switch ($browsetype)
    {
    case "title":
      $title_terms = '"' . implode('" AND "', preg_split('/\s+/', trim($browse_title))) . '"';
      $sql = "EXEC BROWSE_BY_TITLE$storenum @batch_size_in = ?, @title_in = ?";
      $params = array(array($limit_num, SQLSRV_PARAM_IN, null, SQLSRV_SQLTYPE_INT), $title_terms);
      break;
    case "actor":
      $actor_terms = '"' . implode('" AND "', preg_split('/\s+/', trim($browse_actor))) . '"';
      $sql = "EXEC BROWSE_BY_ACTOR$storenum @batch_size_in = ?, @actor_in = ?";
      $params = array(array($limit_num, SQLSRV_PARAM_IN, null, SQLSRV_SQLTYPE_INT), $actor_terms);
      break;
    case "membership":
      if ($membership_level > 0) {
        $sql = "EXEC BROWSE_BY_MEMBERSHIP$storenum @batch_size_in = ?, @membershiptype_in = ?";
        $params = array(
          array($limit_num, SQLSRV_PARAM_IN, null, SQLSRV_SQLTYPE_INT),
          array($membership_level, SQLSRV_PARAM_IN, null, SQLSRV_SQLTYPE_INT)
        );
      } else {
        $special = 1;
        $browse_category = 1;
        $sql = "EXEC BROWSE_BY_CATEGORY$storenum @batch_size_in = ?, @category_in = ?, @special_in = ?";
        $params = array(
          array($limit_num, SQLSRV_PARAM_IN, null, SQLSRV_SQLTYPE_INT),
          array($browse_category, SQLSRV_PARAM_IN, null, SQLSRV_SQLTYPE_INT),
          array($special, SQLSRV_PARAM_IN, null, SQLSRV_SQLTYPE_INT)
        );
      }
      break;
    case "category":
    default:
      $special = 1;
      $sql = "EXEC BROWSE_BY_CATEGORY$storenum @batch_size_in = ?, @category_in = ?, @special_in = ?";
      $params = array(
        array($limit_num, SQLSRV_PARAM_IN, null, SQLSRV_SQLTYPE_INT),
        array($browse_category, SQLSRV_PARAM_IN, null, SQLSRV_SQLTYPE_INT),
        array($special, SQLSRV_PARAM_IN, null, SQLSRV_SQLTYPE_INT)
      );
      break;
    }

  $stmt = sqlsrv_query($conn, $sql, $params);
  if ($stmt === false) {
    die("BROWSE procedure failed: " . print_r(sqlsrv_errors(), true));
  }

  $row = sqlsrv_fetch_array($stmt, SQLSRV_FETCH_NUMERIC);
  if ($row === null)
    {
    echo "<H2>No DVDs Found</H2>\n";
    }
  else
    {
    echo "<BR>\n";
    echo "<H2>Search Results</H2>\n";
    echo "<FORM ACTION='./dsbrowse.php' METHOD=GET>\n";
    echo "<TABLE border=2>\n";
    echo "<TR>\n";
    echo "<TH>Add to Shopping Cart</TH>\n";
    echo "<TH>Title</TH>\n";
    echo "<TH>Actor</TH>\n";
    echo "<TH>Price</TH>\n";
    echo "</TR>\n";
    do {
      echo " <TR>\n";
      echo "<TD><INPUT NAME=selected_item[] TYPE=CHECKBOX VALUE=$row[0]></TD>\n";
      echo "<TD>" . htmlspecialchars($row[2]) . "</TD>\n";
      echo "<TD>" . htmlspecialchars($row[3]) . "</TD>\n";
      echo "<TD>$row[4]</TD>\n";
      echo "</TR>\n";
      } while ($row = sqlsrv_fetch_array($stmt, SQLSRV_FETCH_NUMERIC));
    echo "</TABLE>\n";
    echo "<BR>\n";

    echo "<INPUT TYPE=HIDDEN NAME=customerid VALUE='$customerid'>\n";
    echo "<INPUT TYPE=HIDDEN NAME=storenum VALUE='$storenum'>\n";
    echo "<INPUT TYPE=HIDDEN NAME=membership_level VALUE='$membership_level'>\n";
    if (is_array($item)) {
      for ($i=0; $i<count($item); $i++) echo "<INPUT TYPE=HIDDEN NAME='item[]' VALUE=$item[$i]>\n";
    }
    echo "<INPUT TYPE=SUBMIT VALUE='Update Shopping Cart'>\n";
    echo "</FORM>\n";
    }
  sqlsrv_free_stmt($stmt);
  sqlsrv_close($conn);
  }

if (isset($item))
  {
  echo "<H2>Shopping Cart</H2>\n";
  echo "<FORM ACTION='./dspurchase.php' METHOD='GET'>\n";
  echo "<TABLE border=2>\n";
  echo "<TR>\n";
  echo "<TH>Item</TH>\n";
  echo "<TH>Title</TH>\n";
  echo "</TR>\n";
  $conn = ds_connect();
  for ($i=0; $i<count($item); $i++)
    {
    $j=$i+1;
    $query = "SELECT TITLE FROM PRODUCTS$storenum WHERE PROD_ID = ?";
    $stmt = sqlsrv_query($conn, $query, array(array($item[$i], SQLSRV_PARAM_IN, null, SQLSRV_SQLTYPE_INT)));
    $result_row = sqlsrv_fetch_array($stmt, SQLSRV_FETCH_NUMERIC);
    $title = $result_row[0];
    sqlsrv_free_stmt($stmt);
    echo "<TD>$j</TD><TD>" . htmlspecialchars($title) . "</TD></TR>\n";
    }
  echo "</TABLE>\n";
  echo "<BR>\n";
  if (is_array($item)) {
    for ($i=0; $i<count($item); $i++) echo "<INPUT TYPE=HIDDEN NAME='item[]' VALUE=$item[$i]>\n";
  }
  echo "<INPUT TYPE=HIDDEN NAME=customerid VALUE='$customerid'>\n";
  echo "<INPUT TYPE=HIDDEN NAME=storenum VALUE='$storenum'>\n";
  echo "<INPUT TYPE=SUBMIT VALUE='Checkout'>\n";
  echo "</FORM>\n";
  sqlsrv_close($conn);
  }
ds_html_footer();
?>
