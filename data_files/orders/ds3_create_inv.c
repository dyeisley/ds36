/*
 * DVD Store 3 Create Inventory data - ds3_create_inv.c
 *
 * Copyright (C) 2005 Dell, Inc. <dave_jaffe@dell.com> and <tmuirhead@vmware.com>
 *
 * Creates inventory data files for DVD Store Database V.3
 *
 * Syntax: ds3_create_inv n_prods n_Sys_Type > inv.csv
 *
 * Builds inventory csv file from orderlines files for use in INVENTORY table load
 * Each line of output file: productid, quan_in_stock, quan_sold
 *
 * To compile: gcc -o ds3_create_inv ds2_create_inv.c -lm
 * Last Updated 5/13/05
 * Last Updated 6/11/2010 by GSK
 * Last Updated 8/2025 by DPY
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
#include <stdlib.h>
#include <math.h>
#include <time.h>

//---------------------------------------random2---------------------------------------
//
// random2(i,j) - returns a random integer uniformly distributed between i and j,
//  inclusively  (assumes j >= i)
//
// Moved to top so the compiler doesn't complain.
//
int random2(int i, int j) {
  return i + floor((1+j-i) * (double) rand()/(((double) RAND_MAX) + 1));
} //random2

//--------------------------------------- main ---------------------------------------
int main(int argc, char* argv[]) {

  char* months[] = {"jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"};
  int n_prods, i_month, orderline_id, order_id, prod_id, sales, quan_in_stock;
  char fname[25], line[101];
  FILE *FP_orderlines, *FP_inv;
  int* pTot_sales;
  int i_Sys_Type = 0;	 //0 for Linux, 1 for Windows        //Added by GSK

  if (argc < 2) {
    printf("Syntax:   %s n_prods n_Sys_Type\n",argv[0]);
    printf("  n_prods: Number of product IDs -- Automatically increased if the ID found is greater than the value entered.\n");
    printf("  n_Sys_Type: 0 (Linux) or 1 (Windows) -- Default: Linux\n");
    exit(-1);
  }

  n_prods = atoi(argv[1]);

  // Sys type defaults to Linux unless entered by user.
  if ( argc > 2 ) {
    i_Sys_Type = atoi(argv[2]);
  }

  pTot_sales = (int *) calloc(n_prods, sizeof(int));

  if (pTot_sales == NULL) {
    printf("Not enough memory\n");
    exit(-1);
  }

  for (i_month = 0; i_month < 12; i_month++) {
    sprintf(fname, "%s_orderlines.csv", months[i_month]);
    // printf("File Name: %s \n",fname);
    FP_orderlines = fopen(fname, "r");

    if (FP_orderlines != NULL) {

      while (fgets(line, 100, FP_orderlines)) {
        // printf("Line String read: %s", line);
        sscanf(line, "%d,%d,%d,%d", &orderline_id, &order_id, &prod_id, &sales);
        // printf("Line Read: %d,%d,%d,%d \n", orderline_id, order_id, prod_id, sales);

        // If prod_id > n_prods then allocate more space in the array
        if (prod_id > n_prods) {
          //printf("Allocating additional space prod_id: %d n_prods: %d\n",prod_id, n_prods);
          int *temp_arr = (int *)realloc(pTot_sales, prod_id * sizeof(int));
          pTot_sales = temp_arr;

          // zero the new array elements.
          for (size_t i = n_prods; i < prod_id; i++) {
            pTot_sales[i] = 0;
          }
          n_prods = prod_id;
        }

        pTot_sales[prod_id - 1] += sales;
      }

      fclose(FP_orderlines);
    }
  }

  FP_inv = fopen("inv.csv", "wb");

  srand((unsigned int)time(NULL)); // Seed rand() with current time.

  for (prod_id=0; prod_id<n_prods; prod_id++) {

    quan_in_stock = random2(0,500);

    if ((prod_id+1) % 10000 == 0)  {
	    quan_in_stock *= 10; // boost inventory for hot sellers
    }

    //printf("%d,%d,%d\n", prod_id+1, quan_in_stock, pTot_sales[prod_id]);
    //Changed by GSK
    if(i_Sys_Type == 0) { //If System type is Linux, Append LF only   //Added by GSK
	fprintf(FP_inv, "%d,%d,%d%c", prod_id+1, quan_in_stock, pTot_sales[prod_id], 10);
    }
    else if(i_Sys_Type == 1) { //If System type is Windows, Append CR + LF both   //Added by GSK
	fprintf(FP_inv, "%d,%d,%d%c%c", prod_id+1, quan_in_stock, pTot_sales[prod_id],13 ,10);
    }
  }

  fclose(FP_inv);
  free(pTot_sales);
  return 0 ;
}
