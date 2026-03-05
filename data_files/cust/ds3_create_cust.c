/*
 * Create real looking fake customer data for DVD Store test - ds3_create_cust.c
 *
 * Copyright (C) 2025 Red Hat Inc. <dyeisley@redhat.com>
 *
 * Rewrite of ds3_create_cust.c by <dave_jaffe@dell.com> and <tmuirhead@vmware.com>
 *
 * This code randomly selects a first and last name.
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
#include <string.h>
#include <time.h>
#include <ctype.h>

#include "female_names_full.h"
#include "male_names_full.h"
#include "last_names_full.h"
#include "street_names_full.h"
#include "us_cities.h"

#define COUNTRY_COUNT 10
#define DOMAIN_COUNT 5
#define SUFFIX_COUNT 8

const char *countries[] = { "Australia", "Canada", "Chile", "China", "France", "Germany", "Japan", "Russia", "South Africa", "UK" };
const char *row_cities[] = { "Sydney", "Toronto", "Santiago", "Beijing", "Paris", "Berlin", "Tokyo", "Moscow", "Cape Town", "London" };
const char *suffixes[] = { "Boulevard", "Lane", "Avenue", "Circle", "Street", "Drive", "Way", "Road" };
const char *email_domains[DOMAIN_COUNT] = { "example.com", "mail.com", "myemail.org", "webmail.net", "inbox.us" };

void to_lower(char *dest, const char *src) {
    while (*src) {
        *dest++ = tolower((unsigned char)*src++);
    }
    *dest = '\0';
}

int main(int argc, char* argv[]) {
    int i, n_first = 1, n_last = 100;
    int region = 1;
    char creditcard_exp[25];
    char creditcard[25];
    char username[25];
    char fn_cust[15];
    FILE *FP_cust;

    time_t seconds=time(NULL);
    struct tm* current_time=localtime(&seconds);

    sprintf(fn_cust, "%s_cust.csv", "us");

    srand((unsigned int)time(NULL));

    if (argc >= 2) {
	// Check for first parameter starting with a '-'.
	if (strncmp(argv[1],"-", 1) == 0) {
		fprintf(stderr, "Syntax: %s n_first n_last region_str\n",argv[0]);
		exit(-1);
	}

	n_first = atoi(argv[1]);
	n_last = n_first + 100;
    }
    if (argc >= 3) {
	n_last = atoi(argv[2]);
    }
    if (argc >= 4) {
	if (strncmp(argv[3],"ROW", 3) == 0) {
		region = 2;
		sprintf(fn_cust, "%s_cust.csv", "row");
	}
    }

    FP_cust = fopen(fn_cust, "wb");

    for (i = n_first; i <= n_last; i++) {
        int use_female = rand() % 2;
        int first_index = rand() % FIRSTNAME_POOL_SIZE;
        int last_index = rand() % LAST_NAMES_COUNT;
        int street_index = rand() % STREET_NAME_COUNT;
        int city_index = rand() % US_CITY_COUNT;
        int suffix_index = rand() % SUFFIX_COUNT;
        int street_number = rand() % 1000 + 1;
        int zip = 10000 + rand() % 90000;
        int domain_index = rand() % DOMAIN_COUNT;
        int income = 25000 + rand() % 150000;
	int country_index = rand() % COUNTRY_COUNT;
	int age = rand() % 70 + 18;
	int creditcard_type = rand() % 5 + 1;

        const char *gender = use_female ? "F" : "M";
        const char *first_name = use_female ? female_names[first_index] : male_names[first_index];
        const char *last_name = last_names[last_index];

	sprintf(username, "user%d", i);

	char country[50];
	char state[5];
	char city[50];

	if ( region == 1 ) {
		strcpy(country,"US");
		strcpy(state,cityStates[city_index].state);
		strcpy(city,cityStates[city_index].city);
	}
	else {
		strcpy(country,countries[country_index]);
		strcpy(state,"");
		strcpy(city,row_cities[country_index]);
		zip = 0;
	}

	sprintf(creditcard, "%04d %04d %04d %04d", rand() % 10000, rand() % 10000, rand() % 10000, rand() % 10000 );

	int i_year  = current_time->tm_year + 1900 + (rand() % 10);
	int i_month = (rand() % 12) + 1;
	sprintf(creditcard_exp,"%04d/%02d", i_year, i_month);

	char street[50];
	sprintf(street,"%3d %s %s",street_number,street_names[street_index],suffixes[suffix_index]);

        char first_lower[64], last_lower[64];
        to_lower(first_lower, first_name);
        to_lower(last_lower, last_name);
        char email[128];
        snprintf(email, sizeof(email), "%s.%s@%s", first_lower, last_lower, email_domains[domain_index]);

        int area_code = 200 + rand() % 800;
        int exchange = 200 + rand() % 800;
        int subscriber = rand() % 10000;
        char phone[32];
        snprintf(phone, sizeof(phone), "%03d-%03d-%04d", area_code, exchange, subscriber);

// nice human readable formatting, gcc -DNICE ds3_create_cust.c
#ifdef NICE
	printf("%d,%-12s,%-12s,%-33s,,%-20s,%s,%05d,%-12s,%d,%-32s,%s,%d,%8s,%s,%s,password,%d,%6d,%s\n",
#else
	fprintf(FP_cust, "%d,%s,%s,%s,,%s,%s,%05d,%s,%d,%s,%s,%d,%s,%s,%s,password,%d,%d,%s\n",
#endif
	       i,
               first_name,
               last_name,
               street,
               city,
               state,
               zip,
               country,
               region,
               email,
               phone,
               creditcard_type,
               creditcard,
               creditcard_exp,
               username,
               age,
               income,
               gender);
    }

    fclose(FP_cust);

    return 0;
}
