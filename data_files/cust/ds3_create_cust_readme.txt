ds3_create_cust_readme.txt

The data creation programs (ds3_create_cust.c, etc.) work best when compiled and run on Linux (or a Linux-like Windows 
environment such as Cygwin) due to the larger RAND_MAX. The Windows binaries (ds3_create_cust.exe, etc.) provided in the
kit will run as is but will not provide a good degree of randomness to the data.

DVDStore 2.1 and later allows for any custom size database to be created. 

User must use perl scripts in DVDStore 2.1 and later to create database of any size. To know more 
about how to use perl scripts and general instructions on DVDStore 3,
please go through document /ds3/ds3_Documentation.txt

DVDStore 3 will provide all compiled linux and windows executables for data generation C programs.

In order to run the perl scripts on a windows system a perl utility of some sort is required. (Instructions for installing perl utility over windows
is included in document /ds3/ds3_Documentation.txt under prerequisites section)

-------------------------------------------------------------------------------------------------------------
Instructions for creating DVD Store Version 3 (DS3) database customer data
(for CUSTOMERS table)

  compile ds3_create_cust.c (see compilation directions in program)
  sh ds3_create_cust_small.sh (or medium or large) 

<davejaffe7@gmail.com> and <tmuirhead@vmware.com>  5/15/15

-------------------------------------------------------------------------------------------------------------

2025-07 Re-write of ds3_create_cust utility to create real looking fake user data. 

female_names_full.h  -- 1000 female names
last_names_full.h    -- 1000 last names
male_names_full.h    -- 1000 male names
street_names_full.h  -- 650 street names
us_cities.h	     -- 200 US Cities

Two C files for creating the data are available.

ds3_create_cust.c  		-- Randomly selects first & last names from the lists. 
ds3_create_cust-iterative.c	-- Iteratively selects first name + last name

The iterative code will create 2M unique Fist+Last name (male/female) combinations before repeating. 
(Note, some first names appear in both male and female first names lists.)

The random selection code is likely to generate more duplicate name combinations, but that doesn't really matter
since the customer IDs are all unique. 

	To compile on Linux:
	  gcc -o ds3_create_cust ds3_create_cust.c 
	  gcc -o ds3_create_cust-iterative ds3_create_cust-iterative.c 

You can also compile with -DNICE option for debugging. This creates nice human readable columns and the output is 
directed to the screen instead of a file.
	  gcc -DNICE -o ds3_create_cust ds3_create_cust.c 
	  gcc -DNICE -o ds3_create_cust-iterative ds3_create_cust-iterative.c 

<dyeisley@redhat.com>
