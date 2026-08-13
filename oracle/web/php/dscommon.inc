
<!--
 * DVD Store Common Include PHP Page - dscommon.inc
 *
 * Copyright (C) 2005 Dell, Inc. <dave_jaffe@dell.com> and <tmuirhead@vmware.com>
 *
 * Used by DVD Store Oracle php pages
 *
 * Last Updated 7/30/2026
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
-->

<?php
function ds_html_header($title)
{
echo "<HTML>\n";
echo "<HEAD><TITLE>$title</TITLE></HEAD>\n";
echo "<BODY>\n";
echo "<FONT FACE=\"Arial\" COLOR=\"#0000FF\">\n";
echo "<H1 ALIGN=CENTER>DVD Store</H1>\n";
}

// Oracle connection parameters
$oracle_host = "localhost";
$oracle_port = "1521";
$oracle_sid = "orcl";
$oracle_user = "ds3";
$oracle_password = "ds3";
$oracle_connstr = "(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=$oracle_host)(PORT=$oracle_port))(CONNECT_DATA=(SID=$oracle_sid)))";
?>

<?php
function ds_html_footer()
{
echo <<<EOT
<HR>
<P ALIGN=CENTER>Thank You for Visiting the DVD Store!</A></P>
<HR>
<P ALIGN=CENTER>Copyright &copy; 2005 Dell</P>
</FONT>
</BODY>
</HTML>
EOT;
}
?>
