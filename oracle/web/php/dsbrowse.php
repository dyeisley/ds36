
<?php
/*
 * DVD Store Browse PHP Oracle Page - dsbrowse.php
 *
 * Copyright (C) 2005 Dell, Inc. <dave_jaffe@dell.com> and <tmuirhead@vmware.com>
 *
 * Browses Oracle DVD store by author, title, category, or membership
 *
 * Last Updated 7/30/2026
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

ds_html_header("DVD Store Browse Page");

$customerid = $_REQUEST["customerid"];
$storenum = isset($_REQUEST["storenum"]) ? $_REQUEST["storenum"] : 1;
$membership_level = isset($_REQUEST["membership_level"]) ? $_REQUEST["membership_level"] : 0;
$browsetype = isset($_REQUEST["browsetype"]) ? $_REQUEST["browsetype"] : NULL;
$browsereviewtype = isset($_REQUEST["browsereviewtype"]) ? $_REQUEST["browsereviewtype"] : NULL;
$browse_title = isset($_REQUEST["browse_title"]) ? $_REQUEST["browse_title"] : NULL;
$browse_actor = isset($_REQUEST["browse_actor"]) ? $_REQUEST["browse_actor"] : NULL;
$browse_category = isset($_REQUEST["browse_category"]) ? $_REQUEST["browse_category"] : NULL;
$review_title = isset($_REQUEST["review_title"]) ? $_REQUEST["review_title"] : NULL;
$review_actor = isset($_REQUEST["review_actor"]) ? $_REQUEST["review_actor"] : NULL;
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

if (isset($selected_item))  // Add new selected items to shopping cart (item[] array)
  {
  $n_items = is_array($item) ? count($item) : 0;
  for ($i=0; $i<count($selected_item); $i++) $item[$n_items + $i] = $selected_item[$i];
  }

if (empty($item)) $n_items = 0;
else $n_items = count($item);

echo "<H2>Search for DVDs</H2>\n";

echo "<FORM ACTION='./dsbrowse.php' METHOD='GET'>\n";

echo "<INPUT NAME='browsetype' TYPE=RADIO VALUE='title'"; if($browsetype == 'title') echo "CHECKED";
echo ">Title  <INPUT NAME='browse_title' VALUE='$browse_title' TYPE=TEXT SIZE=15> <BR>\n";
echo "<INPUT NAME='browsetype' TYPE=RADIO VALUE='actor'"; if($browsetype == 'actor') echo "CHECKED";
echo ">Actor  <INPUT NAME='browse_actor' VALUE='$browse_actor' TYPE=TEXT SIZE=15> <BR>\n";
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
echo "<INPUT NAME='browsetype' TYPE=RADIO VALUE='membership'"; if($browsetype == 'membership') echo "CHECKED";
echo ">Membership (members only)<BR>\n";

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
for ($i=0; $i<$n_items; $i++) echo "<INPUT TYPE=HIDDEN NAME='item[]' VALUE=$item[$i]>\n";
echo "<INPUT TYPE=SUBMIT VALUE='Search'>\n";
echo "</FORM>\n";


echo "<H2>Or Browse DVD Reviews by Title or Actor Keyword</H2>\n";

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
echo "<INPUT TYPE=HIDDEN NAME=storenum VALUE='$storenum'>\n";
echo "<INPUT TYPE=HIDDEN NAME=membership_level VALUE='$membership_level'>\n";
for ($i=0; $i<$n_items; $i++) echo "<INPUT TYPE=HIDDEN NAME='item[]' VALUE=$item[$i]>\n";
echo "<INPUT TYPE=SUBMIT VALUE='Search'>\n";
echo "</FORM>\n";

if (!empty($browsetype))
  {
  $conn = oci_pconnect($oracle_user, $oracle_password, $oracle_connstr);
  if (!$conn) {
    $e = oci_error();
    die("Oracle connection failed: " . htmlentities($e['message'], ENT_QUOTES));
  }

  // Build query based on browse type - Oracle procedures return result sets via DBMS_SQL.RETURN_RESULT
  switch ($browsetype)
    {
    case "title":
      $sql = "BEGIN DS3.BROWSE_BY_TITLE$storenum(:p_title, :p_batch_size); END;";
      $stmt = oci_parse($conn, $sql);
      oci_bind_by_name($stmt, ':p_title', $browse_title, 60);
      oci_bind_by_name($stmt, ':p_batch_size', $limit_num, -1, SQLT_INT);
      break;
    case "actor":
      $sql = "BEGIN DS3.BROWSE_BY_ACTOR$storenum(:p_actor, :p_batch_size); END;";
      $stmt = oci_parse($conn, $sql);
      oci_bind_by_name($stmt, ':p_actor', $browse_actor, 60);
      oci_bind_by_name($stmt, ':p_batch_size', $limit_num, -1, SQLT_INT);
      break;
    case "category":
      $special = rand(0, 1);
      $sql = "BEGIN DS3.BROWSE_BY_CATEGORY$storenum(:p_category, :p_batch_size, :p_special); END;";
      $stmt = oci_parse($conn, $sql);
      oci_bind_by_name($stmt, ':p_category', $browse_category, -1, SQLT_INT);
      oci_bind_by_name($stmt, ':p_batch_size', $limit_num, -1, SQLT_INT);
      oci_bind_by_name($stmt, ':p_special', $special, -1, SQLT_INT);
      break;
    case "membership":
      if ($membership_level > 0) {
        $sql = "BEGIN DS3.BROWSE_BY_MEMBERSHIP$storenum(:p_batch_size, :p_membership_level); END;";
        $stmt = oci_parse($conn, $sql);
        oci_bind_by_name($stmt, ':p_batch_size', $limit_num, -1, SQLT_INT);
        oci_bind_by_name($stmt, ':p_membership_level', $membership_level, -1, SQLT_INT);
      } else {
        echo "<H2>Membership browsing requires an active membership</H2>\n";
        ds_html_footer();
        oci_close($conn);
        exit;
      }
      break;
    }

  oci_execute($stmt);

  // Get implicit result set returned via DBMS_SQL.RETURN_RESULT
  $browse_result = array();
  $implicit = oci_get_implicit_resultset($stmt);
  if ($implicit) {
    while ($row = oci_fetch_assoc($implicit)) {
      $browse_result[] = $row;
    }
  }

  if (count($browse_result) == 0)
    {
    echo "<H2>No DVDs Found</H2>\n";
    }
  else
    {
    echo "<BR>\n";
    echo "<H2>Search Results - Click Title for Product Reviews </H2>\n";
    echo "<FORM ACTION='./dsbrowse.php' METHOD=GET>\n";
    echo "<TABLE border=2>\n";
    echo "<TR>\n";
    echo "<TH>Add to Shopping Cart</TH>\n";
    echo "<TH>Title</TH>\n";
    echo "<TH>Actor</TH>\n";
    echo "<TH>Price</TH>\n";
    echo "</TR>\n";
    foreach ($browse_result as $row)
      {
      echo " <TR>\n";
      echo "<TD><INPUT NAME=selected_item[] TYPE=CHECKBOX VALUE=" . $row['PROD_ID'] . "></TD>\n";
      echo "<TD><a href='dsgetreviews.php?customerid=$customerid&storenum=$storenum&review_title=" . urlencode($row['TITLE']) . "&productid=" . $row['PROD_ID'] . "' target='_blank'>" . htmlspecialchars($row['TITLE']) . "</a></TD>\n";
      echo "<TD>" . htmlspecialchars($row['ACTOR']) . "</TD>\n";
      echo "<TD>" . htmlspecialchars($row['PRICE']) . "</TD>\n";
      echo "</TR>\n";
      }
    oci_free_statement($stmt);
    echo "</TABLE>\n";
    echo "<BR>\n";

    echo "<INPUT TYPE=HIDDEN NAME=customerid VALUE='$customerid'>\n";
    echo "<INPUT TYPE=HIDDEN NAME=storenum VALUE='$storenum'>\n";
    echo "<INPUT TYPE=HIDDEN NAME=membership_level VALUE='$membership_level'>\n";
    echo "<INPUT TYPE=HIDDEN NAME=browsetype VALUE='$browsetype'>\n";
    echo "<INPUT TYPE=HIDDEN NAME=browse_category VALUE='$browse_category'>\n";
    echo "<INPUT TYPE=HIDDEN NAME=browse_title VALUE='$browse_title'>\n";
    echo "<INPUT TYPE=HIDDEN NAME=browse_actor VALUE='$browse_actor'>\n";
    echo "<INPUT TYPE=HIDDEN NAME=limit_num VALUE='$limit_num'>\n";
    for ($i=0; $i<$n_items; $i++) echo "<INPUT TYPE=HIDDEN NAME='item[]' VALUE=$item[$i]>\n";
    echo "<INPUT TYPE=SUBMIT VALUE='Update Shopping Cart'>\n";
    echo "</FORM>\n";
    }
  oci_close($conn);
  }

if (isset($item))  // Show shopping cart
  {
  echo "<H2>Shopping Cart - Click Title for Product Reviews</H2>\n";
  echo "<FORM ACTION='./dspurchase.php' METHOD='GET'>\n";
  echo "<TABLE border=2>\n";
  echo "<TR>\n";
  echo "<TH>Item</TH>\n";
  echo "<TH>Title</TH>\n";
  echo "</TR>\n";

  $conn = oci_pconnect($oracle_user, $oracle_password, $oracle_connstr);
  if (!$conn) {
    $e = oci_error();
    die("Oracle connection failed: " . htmlentities($e['message'], ENT_QUOTES));
  }

  for ($i=0; $i<count($item); $i++)
    {
    $j=$i+1;
    $sql = "SELECT TITLE FROM DS3.PRODUCTS$storenum WHERE PROD_ID = :prod_id";
    $stmt = oci_parse($conn, $sql);
    oci_bind_by_name($stmt, ':prod_id', $item[$i], -1, SQLT_INT);
    oci_execute($stmt);
    $row = oci_fetch_array($stmt, OCI_ASSOC);
    $title = $row['TITLE'];
    echo "<TD>$j</TD><TD><a href='dsgetreviews.php?customerid=$customerid&storenum=$storenum&productid=$item[$i]&review_title=" . urlencode($title) . "' target='_blank'>" . htmlspecialchars($title) . "</a></TD></TR>\n";
    oci_free_statement($stmt);
    }
  echo "</TABLE>\n";
  echo "<BR>\n";
  for ($i=0; $i<count($item); $i++) echo "<INPUT TYPE=HIDDEN NAME='item[]' VALUE=$item[$i]>\n";
  echo "<INPUT TYPE=HIDDEN NAME=customerid VALUE='$customerid'>\n";
  echo "<INPUT TYPE=HIDDEN NAME=storenum VALUE='$storenum'>\n";
  echo "<INPUT TYPE=SUBMIT VALUE='Checkout'>\n";
  echo "</FORM>\n";
  oci_close($conn);
  }
ds_html_footer();
?>
