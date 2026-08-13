
<?php
/*
 * DVD Store Purchase PHP Oracle Page - dspurchase.php
 *
 * Copyright (C) 2005 Dell, Inc. <dave_jaffe@dell.com> and <tmuirhead@vmware.com>
 *
 * Handles purchase of DVDs for Oracle DVD Store database
 * Calls PURCHASE stored procedure
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

  $conn = oci_pconnect($oracle_user, $oracle_password, $oracle_connstr);
  if (!$conn) {
    $e = oci_error();
    die("Oracle connection failed: " . htmlentities($e['message'], ENT_QUOTES));
  }

  $j = 0;
  for ($i=0; $i<count($item); $i++)
    {
    if (empty($drop) || !in_array($i, $drop))
      {
      ++$j;
      $sql = "SELECT PROD_ID, TITLE, ACTOR, PRICE FROM DS3.PRODUCTS$storenum WHERE PROD_ID = :prod_id";
      $stmt = oci_parse($conn, $sql);
      oci_bind_by_name($stmt, ':prod_id', $item[$i], -1, SQLT_INT);
      oci_execute($stmt);
      $purchase_result_row = oci_fetch_array($stmt, OCI_NUM);
      oci_free_statement($stmt);

      echo " <TR>";
      echo "<TD ALIGN=CENTER>$j</TD>";
      echo "<INPUT NAME='item[]' TYPE='HIDDEN' VALUE='$purchase_result_row[0]'>";
      echo "<TD><INPUT NAME='quan[]' TYPE='TEXT' SIZE=10 VALUE=" . max(1,$quan[$i]) . "></TD>";
      echo "<TD>" . htmlspecialchars($purchase_result_row[1]) . "</TD>";
      echo "<TD>" . htmlspecialchars($purchase_result_row[2]) . "</TD>";
      $amt = sprintf("$%.2f", $purchase_result_row[3]);
      echo "<TD ALIGN=RIGHT>$amt</TD>";
      echo "<TD ALIGN=CENTER><INPUT NAME='drop[]' TYPE=CHECKBOX VALUE=$i></TD>";
      echo "</TR>\n";
      $netamount = $netamount + max(1,$quan[$i])*$purchase_result_row[3];
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

  oci_close($conn);
  }
else  // confirmpurchase=yes  => call PURCHASE stored procedure
  {
  $conn = oci_pconnect($oracle_user, $oracle_password, $oracle_connstr);
  if (!$conn) {
    $e = oci_error();
    die("Oracle connection failed: " . htmlentities($e['message'], ENT_QUOTES));
  }

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
    $sql = "SELECT PROD_ID, TITLE, ACTOR, PRICE FROM DS3.PRODUCTS$storenum WHERE PROD_ID = :prod_id";
    $stmt = oci_parse($conn, $sql);
    oci_bind_by_name($stmt, ':prod_id', $item[$i], -1, SQLT_INT);
    oci_execute($stmt);
    $purchase_result_row = oci_fetch_array($stmt, OCI_NUM);
    oci_free_statement($stmt);

    echo " <TR>";
    echo "<TD ALIGN=CENTER>$j</TD>";
    echo "<INPUT NAME='item[]' TYPE=HIDDEN VALUE='$purchase_result_row[0]'>";
    echo "<TD><INPUT NAME='quan[]' TYPE=TEXT SIZE=10 VALUE=$quan[$i]></TD>";
    echo "<TD>" . htmlspecialchars($purchase_result_row[1]) . "</TD>";
    echo "<TD>" . htmlspecialchars($purchase_result_row[2]) . "</TD>";
    $amt = sprintf("$%.2f", $purchase_result_row[3]);
    echo "<TD ALIGN=RIGHT>$amt</TD>";
    echo "</TR>\n";
    $netamount = $netamount + $quan[$i]*$purchase_result_row[3];
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

  // Call PURCHASE stored procedure
  // Oracle signature: PURCHASE(customerid, number_items, netamount, taxamount, totalamount, neworderid_out, prod_id_array, qty_array)
  $number_items = count($item);

  // Create Oracle collection types for arrays
  $sql = "DECLARE
    v_prod_ids DS3_TYPES.N_TYPE;
    v_qtys DS3_TYPES.N_TYPE;
    v_orderid INTEGER;
  BEGIN
  ";

  // Build array assignments
  for ($i=0; $i<$number_items; $i++) {
    $idx = $i + 1;
    $sql .= "  v_prod_ids($idx) := " . $item[$i] . ";\n";
    $sql .= "  v_qtys($idx) := " . $quan[$i] . ";\n";
  }

  $sql .= "  DS3.PURCHASE$storenum(:customerid, :number_items, :netamount, :taxamount, :totalamount, v_orderid, v_prod_ids, v_qtys);\n";
  $sql .= "  :orderid := v_orderid;\n";
  $sql .= "END;";

  $stmt = oci_parse($conn, $sql);
  oci_bind_by_name($stmt, ':customerid', $customerid, -1, SQLT_INT);
  oci_bind_by_name($stmt, ':number_items', $number_items, -1, SQLT_INT);
  oci_bind_by_name($stmt, ':netamount', $netamount_fmt);
  oci_bind_by_name($stmt, ':taxamount', $taxamount_fmt);
  oci_bind_by_name($stmt, ':totalamount', $totalamount_fmt);
  oci_bind_by_name($stmt, ':orderid', $orderid, -1, SQLT_INT);

  $result = oci_execute($stmt);

  if (!$result) {
    $e = oci_error($stmt);
    die("purchase procedure failed: " . htmlentities($e['message'], ENT_QUOTES));
  }

  oci_free_statement($stmt);

  if ($orderid == 0)  // purchase transaction failed (insufficient stock)
    {
    echo "<H3>Insufficient stock - order not processed</H3>\n";
    }
  else  // purchase was successful
      {
      // Get credit card info
      $cctypes = array("MasterCard", "Visa", "Discover", "Amex", "Dell Preferred");

      $sql = "SELECT CREDITCARDTYPE, CREDITCARD, CREDITCARDEXPIRATION FROM DS3.CUSTOMERS$storenum WHERE CUSTOMERID = :customerid";
      $stmt = oci_parse($conn, $sql);
      oci_bind_by_name($stmt, ':customerid', $customerid, -1, SQLT_INT);
      oci_execute($stmt);
      $cc_result_row = oci_fetch_array($stmt, OCI_NUM);
      oci_free_statement($stmt);

      echo "<H3>$" . $totalamount_fmt . " charged to credit card " . htmlspecialchars($cc_result_row[1]) . " " .
        "(" .  $cctypes[$cc_result_row[0]-1] . "), expiration " . htmlspecialchars($cc_result_row[2]) . "</H3><BR>\n";
      echo "<H2>Order Completed Successfully --- ORDER NUMBER:  $orderid</H2><BR>\n";
      }

  oci_close($conn);
  echo "</FORM>\n";
  echo "<H2>Continue Shopping or Logoff</H2>\n";
  echo "<FORM ACTION='./dsbrowse.php' METHOD='GET'>\n";
  echo "<INPUT TYPE=HIDDEN NAME=customerid VALUE='$customerid'>\n";
  echo "<INPUT TYPE=HIDDEN NAME=storenum VALUE=$storenum>\n";
  echo "<INPUT TYPE=SUBMIT VALUE='Continue Shopping'>\n";
  echo "</FORM>\n";
  echo "<FORM ACTION='./dslogin.php' METHOD='GET'>\n";
  echo "<INPUT TYPE=HIDDEN NAME=storenum VALUE=$storenum>\n";
  echo "<INPUT TYPE=SUBMIT VALUE='Logoff'>\n";
  echo "</FORM>\n";
  }

ds_html_footer();
?>
