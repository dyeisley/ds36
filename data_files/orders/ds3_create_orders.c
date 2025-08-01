
/*
 * DVD Store 3 Create Order data - ds3_create_orders.c
 *
 * Copyright (C) 2005 Dell, Inc. <dave_jaffe@dell.com> and <tmuirhead@vmware.com>
 *
 * Creates order data files for DVD Store Database V.2
 *
 * Syntax: ds3_create_orders n_first n_last filename S|M|L <i_month> n_Sys_Type n_Max_Prod_Id n_Max_Cust_Id
 *         (see details below)
 *
 * Creates <filename>_orders.csv, <filename>_orderlines.csv and <filename>_cust_hist.csv
 *   for month if specified, otherwise for randomly selected month, based on small, medium or large database
 *
 * Run on Linux to use large RAND_MAX (2e31-1)
 *
 * To compile: gcc -o ds3_create_orders ds3_create_orders.c -lm
 *
 * Last Updated 5/12/05
 * Last Updated 6/1/2010 by GSK
 * Last Updated 06/25/2010 by GSK (Newly created data will have latest orderdates from 2009 year)
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
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA  */

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <math.h>
#include <time.h>

//---------------------------------------random2---------------------------------------
//
// random2(i,j) - returns a random integer uniformly distributed between i and j,
//  inclusively  (assumes j >= i)
//
// Moved here so the compiler won't complain.
int random2(int i, int j)
    {
    return i + floor((1+j-i) * (double) rand()/(((double) RAND_MAX) + 1));
    } //random2
//

//--------------------------------------- main ---------------------------------------
int main(int argc, char* argv[]) {
  int i, j, n_first, n_last, orderid, i_month, i_month_in=0, i_day_of_month;
  int customerid, n_items_in_order, prod_id, quantity, orderlineid;
  int adder=0, max_prod_id = 1000, max_cust_id = 1000;
  double netamount, tax, totalamount;
  char* ind;
  char filename[20], fn_orders[35], fn_orderlines[35], fn_cust_hist[35], orderdate[10];
  FILE *FP_orders, *FP_orderlines, *FP_cust_hist;
  time_t tptr;

  int i_days_in_month[] = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31};
  int i_Sys_Type = 0;	 //0 for Linux, 1 for Windows        //Added by GSK

  time_t seconds=time(NULL);
  struct tm* current_time=localtime(&seconds);

  // Check syntax
  if (argc < 4) {
    fprintf(stderr, "Syntax: %s n_first n_last filename S|M|L <i_month> n_Sys_Type n_Max_Prod_Id n_Max_Cust_Id\n", argv[0]);
    fprintf(stderr, "Creates orders data files for DS3 database\n");
    fprintf(stderr, "Creates three files: <filename>_orders.csv, <filename>_orderlines.csv and <filename>_cust_hist.csv\n");
    fprintf(stderr, "  n_first: Starting order ID\n");
    fprintf(stderr, "  n_last:  Last order ID\n");
    fprintf(stderr, "  filename:  String less than 20 characters\n");
    fprintf(stderr, "  S,M,L: This doesn't do anything. Install_DVDStore.pl still passes it.\n");
    fprintf(stderr, "  i_month: optional, if not specified will be generated randomly\n");
    fprintf(stderr, "  n_Sys_Type: 0 (Linux) or 1 (Windows) -- Default Linux\n");
    fprintf(stderr, "  n_Max_Prod_Id: max number of rows in Product table -- Default 1000\n");
    fprintf(stderr, "  n_Max_Cust_Id: max number of rows in Customer table -- Default 1000\n");
    fprintf(stderr, "Example: %s 1 1000 filename L 3 0 10000 20000\n",argv[0]);
    exit(-1);
  }

  if ( strlen(argv[3]) >= 20 ) {
    printf("The filename '%s' is too long.\n",argv[3]);
    exit(-1);
  }

  n_first = atoi(argv[1]);
  n_last = atoi(argv[2]);
  strcpy(filename, argv[3]);

  if (argc > 5) {
    i_month_in = atoi(argv[5]);
  }
  if (argc > 6) {
    i_Sys_Type = atoi(argv[6]);
  }
  if (argc > 7) {
    max_prod_id = atoi(argv[7]);
  }
  if (argc > 8) {
    max_cust_id = atoi(argv[8]);
  }

  srand((unsigned int)time(NULL));

  sprintf(fn_orders, "%s_orders.csv", filename);
  sprintf(fn_orderlines, "%s_orderlines.csv", filename);
  sprintf(fn_cust_hist, "%s_cust_hist.csv", filename);

  FP_orders = fopen(fn_orders, "wb");
  FP_orderlines = fopen(fn_orderlines, "wb");
  FP_cust_hist = fopen(fn_cust_hist, "wb");

  for (i=n_first; i <= n_last; i++) {
    orderid = i;

    // order date
    if (i_month_in > 0 && i_month_in <= 12) {  // Check to see that the user entered a valid month
      i_month = i_month_in;
    }
    else {
      i_month = random2(1,12);
    }
    i_day_of_month = random2(1, i_days_in_month[i_month-1]);
    int i_year = current_time->tm_year + 1900 - (rand() % 15);  // All orders happened in the last 15 years.
    sprintf(orderdate,"%4d/%02d/%02d", i_year, i_month, i_day_of_month);

    // customerid
    customerid = random2(1, max_cust_id);

    // netamount, tax, totalamount
    netamount = 0.01 * random2(1, 40000);
    tax = 0.0825 * netamount;
    totalamount = netamount + tax;

    //fprintf(FP_orders, "%d,%s,%d,%.2f,%.2f,%.2f\n", orderid, orderdate, customerid, netamount, tax, totalamount);
    //Changed by GSK	
    if(i_Sys_Type == 0) {      //If System is Linux, Append LF only     //Added by GSK
	fprintf(FP_orders, "%d,%s,%d,%.2f,%.2f,%.2f%c", orderid, orderdate, customerid, netamount, tax, totalamount, 10);
    }
    else if(i_Sys_Type == 1) { //If System is Windows, Append CR and then LF	//Added by GSK
	fprintf(FP_orders, "%d,%s,%d,%.2f,%.2f,%.2f%c%c", orderid, orderdate, customerid, netamount, tax, totalamount, 13, 10);
    }

    n_items_in_order = random2(1, 9);

    // Add Cart item, Randomize productID
    for (j=1; j <= n_items_in_order; j++) {
      orderlineid = j;

      // prod_id
      prod_id = random2(1, max_prod_id);

      // quantity
      quantity = random2(1, 3);

      //fprintf(FP_orderlines, "%d,%d,%d,%d,%s\n", orderlineid, orderid, prod_id, quantity, orderdate);
      if(i_Sys_Type == 0) {  //If System is Linux, Append LF only     //Added by GSK
	  fprintf(FP_orderlines, "%d,%d,%d,%d,%s%c", orderlineid, orderid, prod_id, quantity, orderdate, 10);
      }
      else if(i_Sys_Type == 1) {  //If System is Windows, Append CR and then LF	//Added by GSK
	  fprintf(FP_orderlines, "%d,%d,%d,%d,%s%c%c", orderlineid, orderid, prod_id, quantity, orderdate, 13, 10);
      }	

      //fprintf(FP_cust_hist, "%d,%d,%d\n", customerid, orderid, prod_id);
      if(i_Sys_Type == 0) {   //If System is Linux, Append LF only     //Added by GSK
	  fprintf(FP_cust_hist, "%d,%d,%d%c", customerid, orderid, prod_id, 10);
      }
      else if(i_Sys_Type == 1) {  //If System is Windows, Append CR and then LF	//Added by GSK
	  fprintf(FP_cust_hist, "%d,%d,%d%c%c", customerid, orderid, prod_id, 13, 10);
      }	

    } // end for on orderlines file
  } // end for on orders file

  // close the files
  fclose(FP_orders);
  fclose(FP_orderlines);
  fclose(FP_cust_hist);

  return 0;
}
