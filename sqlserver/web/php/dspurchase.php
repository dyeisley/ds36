
<?php
/*
 * DVD Store Purchase PHP Page - dspurchase.php
 *
 * Copyright (C) 2005 Dell, Inc. <davejaffe7@gmail.com> and <tmuirhead@vmware.com>
 *
 * Handles purchase of DVDs for SQL Server DVD Store database
 * Calls PURCHASE stored procedure with Table-Valued Parameter
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

ds_html_header("DVD Store Purchase Page");

$confirmpurchase = isset($_REQUEST["confirmpurchase"]) ? $_REQUEST["confirmpurchase"] : NULL;
$item = isset($_REQUEST["item"]) ? $_REQUEST["item"] : NULL;
$quan = isset($_REQUEST["quan"]) ? $_REQUEST["quan"] : NULL;
$drop = isset($_REQUEST["drop"]) ? $_REQUEST["drop"] : NULL;
$customerid = $_REQUEST["customerid"];
$storenum = isset($_REQUEST["storenum"]) ? $_REQUEST["storenum"] : 1;
$netamount = 0;

if (empty($confirmpurchase))
  {
  echo "<H2>Selected Items: specify quantity desired; click Purchase when finished</H2>\n";
  echo "<BR>\n";
  echo "<FORM ACTION='./dspurchase.php' METHOD='GET'>\n";
  echo "<TABLE border=2>\n";
  echo "<TR>\n";
  echo "<TH>Item</TH>\n";
  echo "<TH>Quantity</TH>\n";
  echo "<TH>Title</TH>\n";
  echo "<TH>Actor</TH>\n";
  echo "<TH>Price</TH>\n";
  echo "<TH>Remove From Order?</TH>\n";
  echo "</TR>\n";

  $conn = ds_connect();

  $j = 0;
  for ($i=0; $i<count($item); $i++)
    {
    if (empty($drop) || !in_array($i, $drop))
      {
      ++$j;
      $query = "SELECT PROD_ID, TITLE, ACTOR, PRICE FROM PRODUCTS$storenum WHERE PROD_ID = ?";
      $stmt = sqlsrv_query($conn, $query, array(array($item[$i], SQLSRV_PARAM_IN, null, SQLSRV_SQLTYPE_INT)));
      $row = sqlsrv_fetch_array($stmt, SQLSRV_FETCH_NUMERIC);
      sqlsrv_free_stmt($stmt);
      echo " <TR>";
      echo "<TD ALIGN=CENTER>$j</TD>";
      echo "<INPUT NAME='item[]' TYPE='HIDDEN' VALUE='$row[0]'>";
      echo "<TD><INPUT NAME='quan[]' TYPE='TEXT' SIZE=10 VALUE=" . max(1,$quan[$i]) . "></TD>";
      echo "<TD>" . htmlspecialchars($row[1]) . "</TD>";
      echo "<TD>" . htmlspecialchars($row[2]) . "</TD>";
      $amt = sprintf("$%.2f", $row[3]);
      echo "<TD ALIGN=RIGHT>$amt</TD>";
      echo "<TD ALIGN=CENTER><INPUT NAME='drop[]' TYPE=CHECKBOX VALUE=$i></TD>";
      echo "</TR>\n";
      $netamount = $netamount + max(1,$quan[$i])*$row[3];
      }
    }

  $taxpct = 8.25;
  $taxamount = $netamount * $taxpct/100.0;
  $totalamount = $taxamount + $netamount;
  $amt = sprintf("$%.2f", $netamount);
  echo "<TR><TD></TD><TD></TD><TD></TD><TD>Subtotal</TD><TD ALIGN=RIGHT>$amt</TD></TR>\n";
  $amt = sprintf("$%.2f", $taxamount);
  echo "<TR><TD></TD><TD></TD><TD></TD><TD>Tax ($taxpct%)</TD><TD ALIGN=RIGHT>$amt</TD></TR>\n";
  $amt = sprintf("$%.2f", $totalamount);
  echo "<TR><TD></TD><TD></TD><TD></TD><TD>Total</TD><TD ALIGN=RIGHT>$amt</TD></TR>\n";
  echo "</TABLE><BR>\n";

  echo "<INPUT TYPE=HIDDEN NAME=customerid VALUE='$customerid'>\n";
  echo "<INPUT TYPE=HIDDEN NAME=storenum VALUE=$storenum>\n";

  echo "<INPUT TYPE=SUBMIT VALUE='Update and Recalculate Total'>\n";
  echo "</FORM><BR>\n";

  echo "<FORM ACTION='./dspurchase.php' METHOD='GET'>\n";
  echo "<INPUT TYPE=HIDDEN NAME=confirmpurchase VALUE='yes'>\n";
  echo "<INPUT TYPE=HIDDEN NAME=customerid VALUE='$customerid'>\n";
  echo "<INPUT TYPE=HIDDEN NAME=storenum VALUE=$storenum>\n";
  for ($i=0; $i<count($item); $i++)
    {
    if (empty($drop) || !in_array($i, $drop))
      {
      echo "<INPUT NAME='item[]' TYPE='HIDDEN' VALUE='$item[$i]'>";
      echo "<INPUT NAME='quan[]' TYPE='HIDDEN' VALUE='$quan[$i]'>\n";
      }
    }
  echo "<INPUT TYPE=SUBMIT VALUE='Purchase'>\n";
  echo "</FORM>\n";

  sqlsrv_close($conn);
  }
else
  {
  $conn = ds_connect();

  echo "<H2>Purchase complete</H2>\n";
  echo "<TABLE border=2>";
  echo "<TR>";
  echo "<TH>Item</TH>";
  echo "<TH>Quantity</TH>";
  echo "<TH>Title</TH>";
  echo "<TH>Actor</TH>";
  echo "<TH>Price</TH>";
  echo "</TR>\n";

  for ($i=0; $i<count($item); $i++)
    {
    $j = $i + 1;
    $quan[$i] = max(1,$quan[$i]);
    $query = "SELECT PROD_ID, TITLE, ACTOR, PRICE FROM PRODUCTS$storenum WHERE PROD_ID = ?";
    $stmt = sqlsrv_query($conn, $query, array(array($item[$i], SQLSRV_PARAM_IN, null, SQLSRV_SQLTYPE_INT)));
    $row = sqlsrv_fetch_array($stmt, SQLSRV_FETCH_NUMERIC);
    sqlsrv_free_stmt($stmt);
    echo " <TR>";
    echo "<TD ALIGN=CENTER>$j</TD>";
    echo "<TD>$quan[$i]</TD>";
    echo "<TD>" . htmlspecialchars($row[1]) . "</TD>";
    echo "<TD>" . htmlspecialchars($row[2]) . "</TD>";
    $amt = sprintf("$%.2f", $row[3]);
    echo "<TD ALIGN=RIGHT>$amt</TD>";
    echo "</TR>\n";
    $netamount = $netamount + $quan[$i]*$row[3];
    }

  $taxpct = 8.25;
  $taxamount = $netamount * $taxpct/100.0;
  $totalamount = $taxamount + $netamount;
  $netamount_fmt = sprintf("%.2f", $netamount);
  echo "<TR><TD></TD><TD></TD><TD></TD><TD>Subtotal</TD><TD ALIGN=RIGHT>$" . $netamount_fmt . "</TD></TR>\n";
  $taxamount_fmt = sprintf("%.2f", $taxamount);
  echo "<TR><TD></TD><TD></TD><TD></TD><TD>Tax ($taxpct%)</TD><TD ALIGN=RIGHT>$" . $taxamount_fmt . "</TD></TR>\n";
  $totalamount_fmt = sprintf("%.2f", $totalamount);
  echo "<TR><TD></TD><TD></TD><TD></TD><TD>Total</TD><TD ALIGN=RIGHT>$" . $totalamount_fmt . "</TD></TR>\n";
  echo "</TABLE><BR>\n";

  // Build SQL batch: declare TVP table variable, populate it, call PURCHASE SP
  $number_items = count($item);
  $values = array();
  for ($i = 0; $i < $number_items; $i++) {
    $prod_id = intval($item[$i]);
    $qty = intval(max(1, $quan[$i]));
    $values[] = "($prod_id, $qty)";
  }
  $values_str = implode(", ", $values);

  $sql = "SET NOCOUNT ON; DECLARE @items LineItemsType$storenum; " .
    "INSERT INTO @items (prod_id, qty) VALUES $values_str; " .
    "EXEC PURCHASE$storenum @customerid_in = ?, @netamount_in = ?, @taxamount_in = ?, " .
    "@totalamount_in = ?, @line_items = @items";

  $params = array(
    array(intval($customerid), SQLSRV_PARAM_IN, null, SQLSRV_SQLTYPE_INT),
    array(floatval($netamount_fmt), SQLSRV_PARAM_IN, null, SQLSRV_SQLTYPE_MONEY),
    array(floatval($taxamount_fmt), SQLSRV_PARAM_IN, null, SQLSRV_SQLTYPE_MONEY),
    array(floatval($totalamount_fmt), SQLSRV_PARAM_IN, null, SQLSRV_SQLTYPE_MONEY)
  );

  $stmt = sqlsrv_query($conn, $sql, $params);
  if ($stmt === false) {
    echo "<H3>Purchase failed: " . print_r(sqlsrv_errors(), true) . "</H3>\n";
  } else {
    $row = sqlsrv_fetch_array($stmt, SQLSRV_FETCH_NUMERIC);
    $orderid = $row ? $row[0] : 0;
    sqlsrv_free_stmt($stmt);

    if ($orderid > 0)
      {
      $cctypes = array("MasterCard", "Visa", "Discover", "Amex", "Dell Preferred");

      $cc_query = "SELECT CREDITCARDTYPE, CREDITCARD, CREDITCARDEXPIRATION FROM CUSTOMERS$storenum WHERE CUSTOMERID = ?";
      $stmt = sqlsrv_query($conn, $cc_query, array(array(intval($customerid), SQLSRV_PARAM_IN, null, SQLSRV_SQLTYPE_INT)));
      $cc_row = sqlsrv_fetch_array($stmt, SQLSRV_FETCH_NUMERIC);
      sqlsrv_free_stmt($stmt);
      echo "<H3>$" . $totalamount_fmt . " charged to credit card $cc_row[1] " .
        "(" .  $cctypes[$cc_row[0]-1] . "), expiration $cc_row[2]</H3><BR>\n";
      echo "<H2>Order Completed Successfully --- ORDER NUMBER:  $orderid</H2><BR>\n";
      }
    else
      {
      echo "<H3>Insufficient stock - order not processed</H3>\n";
      }
    }

  echo "<FORM ACTION='./dsbrowse.php' METHOD=GET>\n";
  echo "<INPUT TYPE=HIDDEN NAME=customerid VALUE=$customerid>\n";
  echo "<INPUT TYPE=HIDDEN NAME=storenum VALUE=$storenum>\n";
  echo "<INPUT TYPE=SUBMIT VALUE='Continue Shopping'>\n";
  echo "</FORM>\n";

  sqlsrv_close($conn);
  }

ds_html_footer();
?>
