#!/usr/bin/perl
use strict;
#Perl script created by GSK
#Last updated: 6/14/2010

#Purpose of this perl script:
#			This perl script will create a text file DriverConfig.txt.
#			This text file can be used to pass parameters to driver program through text file.
#Prerequisites for Perl script:
#			To run this perl script on windows machines, user needs to install cygwin with perl on windows machine.
#			To run this perl script on linux machines, user just needs to install perl package on linux machine.
#			To understand how to use this perl script and what parameter values should be given to this perl script,
#			please go through section 6 of documentation ds2.1_Documentation.txt in /ds2 folder

#This config file will be used for executing Driver to drive workload against database server

my $hostname = `hostname`;
chomp $hostname;

my $target_host = $hostname;				#Database/web server hostname or IP Address  Default = localhost
my $database_size = "10MB";				#Database Size Default = 10mb  (e.g. 30MB, 80GB)
my $n_threads = 1;					#number of driver threads against one DB Server
my $ramp_rate = 10;					#startup rate (users/sec) default = 10
my $run_time = 0;					#run time (min) - Default = 0 is infinite
my $warmup_time = 1;					#warmup_time (min) default = 1
my $think_time = 0;					#think time (sec) default = 0
my $pct_newcustomers = 10;				#percent of customers that are new customers default = 20
my $n_searches = 3; 					#average number of searches per order default = 3
my $search_batch_size = 5;				#average number of items returned in each search default = 5
my $n_line_items = 5;					#average number of items per order default = 5
my $virt_dir = "ds2";					#virtual directory (for web driver) default = ds2
my $page_type = "php";					#web page type (for web driver) default = php
my $windows_perf_host = "";				#target hostname for Perfmon CPU% display (Windows only)
my $detailed_view = "N";				#Parameter to display detailed view of Runtime Statistics on Each target machine default = N
my $linux_perf_host = "";				#Parameter for linux CPU utilization Required format for value: <username>:<password>:<IP Address>
my $use_vectors= "N";					#use vector search
my $enable_managers = "N";				#Enable manager operations default = N
my $manager_interval = 30;				#Manager operation interval in seconds default = 30
my $manager_batch_size_min = 10;			#Minimum batch size for manager operations default = 10
my $manager_batch_size_max = 100;			#Maximum batch size for manager operations default = 100
my $manager_add_product_pct = 0;			#Percentage chance for AddProduct operation default = 0
my $manager_delete_review_pct = 0;		        #Percentage chance for Remove Reviews operation default = 0
my $manager_update_price_pct = 0;			#Percentage chance for AdjustPrices operation default = 0
my $manager_update_special_pct = 0;			#Percentage chance for MarkSpecials operation default = 0
my $manager_expire_memberships_pct = 0;			#Percentage chance for ExpireMemberships operation default = 0
my $manager_purge_old_orders_pct = 0;			#Percentage chance for PurgeOldOrders operation default = 0
my $manager_upgrade_membership_pct = 0;			#Percentage chance for UpgradeMembership operation default = 0
my $manager_promo_membership_pct = 0;			#Percentage chance for PromotionalMembership operation default = 0
my $manager_analytics_interval = 0;			#Manager analytics interval in minutes (0 = disabled) default = 0
my $ds2_mode = "N";					#DS2 compatibility mode (3 browse types only) default = N
my $validate_post_test = "Y";				#Run validation SQL after benchmark completes default = Y

my $line = "";
my $end_line = "";					#End of line character

print "Please enter following parameters: \n";
print "***********************************\n";

# Read saved metadata from Install_DVDStore.pl if available
my $saved_db_size = "4GB";  # Default fallback
my $saved_db_type = "";
if (-f ".dvdstore_metadata") {
	open(my $META, "<", ".dvdstore_metadata");
	while (<$META>) {
		chomp;
		if (/database_size_mb=(\d+)/) {
			my $size_mb = $1;
			if (/database_size_str=(\w+)/) {
				# Will be read on next iteration
			}
		}
		if (/database_size_str=(\w+)/) {
			my $size_str = $1;
			# Look back to get size_mb from previous line - need to save it
		}
	}
	close $META;
	# Re-read to construct full size string
	open($META, "<", ".dvdstore_metadata");
	my ($size_mb, $size_str);
	while (<$META>) {
		if (/database_size_mb=(\d+)/) { $size_mb = $1; }
		if (/database_size_str=(\w+)/) { $size_str = $1; }
		if (/database_type=(\w+)/) { $saved_db_type = $1; }
	}
	close $META;
	if (defined $size_mb && defined $size_str) {
		$saved_db_size = "$size_mb" . uc($size_str);
	}
}

print "Please enter target host(s) (database/web server hostname or IP Address) [$target_host] : ";
chomp($target_host = <STDIN>);
$target_host ||= $hostname;
print "Please enter database size (e.g. Input can be like 30MB, 80GB ,etc) [$saved_db_size] : ";
chomp($database_size = <STDIN>);
$database_size ||= $saved_db_size;
print "Please enter target hostname for perfmon CPU% display (windows only) : ";
chomp($windows_perf_host = <STDIN>);
print "Please enter <username>:<password>:<IP Address> for linux machines for CPU % display (linux only) : ";
chomp($linux_perf_host = <STDIN>);
print "Please enter if you want detailed view of runtime statistics of each target machine ( Y / N ) [N] : ";
chomp($detailed_view = <STDIN>);
$detailed_view ||= "N";

if(lc($^O) eq lc("linux"))
{
  # Only MySQL and SQL Server support vector search
  if (defined $saved_db_type && (lc($saved_db_type) eq "MYSQL" || lc($saved_db_type) eq "MSSQL"))
  {
    print "Enable vector search ( Y / N ) [N] : ";
    chomp($use_vectors = <STDIN>);
    $use_vectors ||= "N";
  }
  else
  {
    $use_vectors = "N";  # PostgreSQL and Oracle don't support vectors yet
  }
}

print "DS2 compatibility mode - 3 browse types only, no review browse ( Y / N ) [N] : ";
chomp($ds2_mode = <STDIN>);
$ds2_mode ||= "N";

print "Run validation SQL after benchmark completes ( Y / N ) [Y] : ";
chomp($validate_post_test = <STDIN>);
$validate_post_test ||= "Y";

print "Enable manager operations ( Y / N ) [N] : ";
chomp($enable_managers = <STDIN>);
$enable_managers ||= "N";

if(uc($enable_managers) eq "Y")
{
print "\n--- Manager Operation Parameters ---\n";
print "Manager operation interval in seconds [30] : ";
chomp($manager_interval = <STDIN>);
$manager_interval ||= 30;
print "Manager batch size min [10] : ";
chomp($manager_batch_size_min = <STDIN>);
$manager_batch_size_min ||= 10;
print "Manager batch size max [100] : ";
chomp($manager_batch_size_max = <STDIN>);
$manager_batch_size_max ||= 100;
print "Manager AddProduct percentage (0-100) [0] : ";
chomp($manager_add_product_pct = <STDIN>);
$manager_add_product_pct ||= 0;
print "Manager DeleteReview percentage (0-100) [0] : ";
chomp($manager_delete_review_pct = <STDIN>);
$manager_delete_review_pct ||= 0;
print "Manager AdjustPrices percentage (0-100) [0] : ";
chomp($manager_update_price_pct = <STDIN>);
$manager_update_price_pct ||= 0;
print "Manager MarkSpecials percentage (0-100) [0] : ";
chomp($manager_update_special_pct = <STDIN>);
$manager_update_special_pct ||= 0;
print "Manager ExpireMemberships percentage (0-100) [0] : ";
chomp($manager_expire_memberships_pct = <STDIN>);
$manager_expire_memberships_pct ||= 0;
print "Manager UpgradeMembership percentage (0-100) [0] : ";
chomp($manager_upgrade_membership_pct = <STDIN>);
$manager_upgrade_membership_pct ||= 0;
print "Manager PromotionalMembership percentage (0-100) [0] : ";
chomp($manager_promo_membership_pct = <STDIN>);
$manager_promo_membership_pct ||= 0;
print "Manager analytics interval in minutes (0 = disabled) [0] : ";
chomp($manager_analytics_interval = <STDIN>);
$manager_analytics_interval ||= 0;
print "Manager PurgeOldOrders percentage (0-100) [0] : ";
chomp($manager_purge_old_orders_pct = <STDIN>);
$manager_purge_old_orders_pct ||= 0;
}

print "***********************************\n";

$end_line = "\n";

print "Creating config file: DriverConfig.txt to be used for Driver Program input parameters....\n";

open (FILE, ">DriverConfig.txt") || die "Creating new Config file to write failed : $!";  #Create new empty file
close (FILE);

open (NEWFILE, ">>DriverConfig.txt") || die "Creating new Config file to write failed : $!";

$line = "target=".$target_host;
print NEWFILE $line;
print NEWFILE $end_line;
$line = "n_threads=".$n_threads;
print NEWFILE $line;
print NEWFILE $end_line;
$line = "ramp_rate=".$ramp_rate;
print NEWFILE $line;
print NEWFILE $end_line;
$line = "run_time=".$run_time;
print NEWFILE $line;
print NEWFILE $end_line;
$line = "db_size=".$database_size;
print NEWFILE $line;
print NEWFILE $end_line;
$line = "warmup_time=".$warmup_time;
print NEWFILE $line;
print NEWFILE $end_line;
$line = "think_time=".$think_time;
print NEWFILE $line;
print NEWFILE $end_line;
$line = "pct_newcustomers=".$pct_newcustomers;
print NEWFILE $line;
print NEWFILE $end_line;
$line = "n_searches=".$n_searches;
print NEWFILE $line;
print NEWFILE $end_line;
$line = "search_batch_size=".$search_batch_size;
print NEWFILE $line;
print NEWFILE $end_line;
$line = "n_line_items=".$n_line_items;
print NEWFILE $line;
print NEWFILE $end_line;
$line = "virt_dir=".$virt_dir;
print NEWFILE $line;
print NEWFILE $end_line;
$line = "page_type=".$page_type;
print NEWFILE $line;
print NEWFILE $end_line;
$line = "windows_perf_host=".$windows_perf_host;
print NEWFILE $line;
print NEWFILE $end_line;
$line = "linux_perf_host=".$linux_perf_host;
print NEWFILE $line;
print NEWFILE $end_line;
$line = "detailed_view=".$detailed_view;
print NEWFILE $line;
print NEWFILE $end_line;
$line = "use_vectors=".$use_vectors;
print NEWFILE $line;
print NEWFILE $end_line;
$line = "enable_managers=".$enable_managers;
print NEWFILE $line;
print NEWFILE $end_line;
$line = "manager_interval=".$manager_interval;
print NEWFILE $line;
print NEWFILE $end_line;
$line = "manager_batch_size_min=".$manager_batch_size_min;
print NEWFILE $line;
print NEWFILE $end_line;
$line = "manager_batch_size_max=".$manager_batch_size_max;
print NEWFILE $line;
print NEWFILE $end_line;
$line = "manager_add_product_pct=".$manager_add_product_pct;
print NEWFILE $line;
print NEWFILE $end_line;
$line = "manager_delete_review_pct=".$manager_delete_review_pct;
print NEWFILE $line;
print NEWFILE $end_line;
$line = "manager_update_price_pct=".$manager_update_price_pct;
print NEWFILE $line;
print NEWFILE $end_line;
$line = "manager_update_special_pct=".$manager_update_special_pct;
print NEWFILE $line;
print NEWFILE $end_line;
$line = "manager_expire_memberships_pct=".$manager_expire_memberships_pct;
print NEWFILE $line;
print NEWFILE $end_line;
$line = "manager_purge_old_orders_pct=".$manager_purge_old_orders_pct;
print NEWFILE $line;
print NEWFILE $end_line;
$line = "manager_upgrade_membership_pct=".$manager_upgrade_membership_pct;
print NEWFILE $line;
print NEWFILE $end_line;
$line = "manager_promo_membership_pct=".$manager_promo_membership_pct;
print NEWFILE $line;
print NEWFILE $end_line;
$line = "manager_analytics_interval=".$manager_analytics_interval;
print NEWFILE $line;
print NEWFILE $end_line;
$line = "ds2_mode=".$ds2_mode;
print NEWFILE $line;
print NEWFILE $end_line;
$line = "validate_post_test=".$validate_post_test;
print NEWFILE $line;
print NEWFILE $end_line;

close (NEWFILE);

print "Completed creating config file: DriverConfig.txt to be used for Driver Program input parameters....\n";
print "Edit DriverConfig.txt for input parameters like n_threads, ramp_rate, run_time, warmup_time, think_time, etc....\n";

if(lc($^O) eq lc("linux"))
{
   print "Then Run the driver program from command prompt as follows: dotnet run --config_file=<path of config file>\n";
}
else
{
   print "Then Run the driver program from command prompt as follows: ds36webdriver.exe --config_file=<path of config file>\n";
}

