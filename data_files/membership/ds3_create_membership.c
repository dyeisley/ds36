/*
 * DVD Store 3 Create Customer data - ds3_create_membership.c
 *
 * Copyright (C) 2014 VMware, Inc. <tmuirhead@vmware.com>
 *
 * Creates premier membership data files for DVD Store Database V.3
 * Syntax: ds3_create_membership n_customers n_pct
 *         (see details below)
 * Run on Linux to use large RAND_MAX (2e31-1)
 * To compile: gcc -o ds3_create_membership ds3_create_membership.c -lm
 *
 *  Adapted from ds2_create_cust.c originally written by Dave Jaffe, Todd Muirhead, and enhanced by Girish Khandke
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

// Functions
int random2(int i, int j);
double random2d(double i, double j);

int main(int argc, char* argv[])
  {
  int n_cust, n_pct, n_cust_members, n_interval_size, adder=0;
  int r_custid, r_membership_type, r_year, r_month;
  char* ind;

  char n_cust_str[20], n_pct_str[20], r_membership_exp[25];
  int i, prev_interval, next_n_interval_size;
  FILE   *FP_member;
  time_t tptr;

  time_t seconds=time(NULL);
  struct tm* current_time=localtime(&seconds);

  // Check syntax
    if (argc < 3)
    {
    fprintf(stderr, "Syntax: ds3_create_membership n_cust n_pct\n");
    fprintf(stderr, "        where n_cust is the total number of customers and can contain M or m for millions\n");
    fprintf(stderr, "Creates customer data membership files for DS3 database\n");
    fprintf(stderr, "Examples: ds3_create_membership  1000  20  =>  20%% of 1000 users are premier members \n");
    fprintf(stderr, "          ds3_create_membership  1M    50  =>  50%% of 1 million users are premier members\n");
    exit(-1);
    }

  strcpy(n_cust_str,  argv[1]);
  if (!(ind = strpbrk(n_cust_str, "Mm")))
    {
    n_cust = atoi(n_cust_str);
    }
  else
    {
    n_cust = 1000000 * atoi(n_cust_str) + adder;
    }

  strcpy(n_pct_str, argv[2]);
  n_pct = atoi(n_pct_str);

  FP_member = fopen("membership.csv", "wb");

  srand((unsigned int)time(NULL));

  n_cust_members = floor(n_cust * n_pct / 100);

  // Make sure n_cust_members != 0
  if (n_cust_members == 0)
    {
    n_cust_members = 10;
    }

  n_interval_size = floor(n_cust / n_cust_members);

  for (i=1; i<=n_cust; (i=i+n_interval_size) )
    {
      r_custid = random2(i, i+n_interval_size-1);

      r_membership_type = random2(1, 3);

      r_year = current_time->tm_year + 1900 + (rand() % 5);  // All memberships expire in the next 5 years.
      r_month = random2(1, 12);
      sprintf(r_membership_exp,"%4d/%02d/15", r_year, r_month);

      fprintf(FP_member, "%d,%d,%s\n",r_custid, r_membership_type, r_membership_exp);
    } //End of For

    fclose(FP_member);
  }

//---------------------------------------random2---------------------------------------
//
// random2(i,j) - returns a random integer uniformly distributed between i and j,
//  inclusively  (assumes j >= i)
//
int random2(int i, int j)
    {
    return i + floor((1+j-i) * (double) rand()/(((double) RAND_MAX) + 1));
    } //random2
//
//
//---------------------------------------random2d---------------------------------------
//
// random2d(i,j) - returns a random double uniformly distributed between i and j,
//  inclusively  (assumes j >= i)
//
double random2d(double i, double j)
    {
    return i + floor((1+j-i) * (double) rand()/(((double) RAND_MAX) + 1));
    } //random2
//
