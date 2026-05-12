#!/usr/bin/perl
# pgsql_ds_perl_validate_multi.pl
# Script to generate and execute validation SQL for multiple stores
# Syntax: perl pgsql_ds_perl_validate_multi.pl <server> <num_stores> <before|after> [generate|execute]

use strict;
use warnings;
use File::Basename;
use File::Path qw(make_path);

my $PGPASSWORD = "ds3";
my $SYSDBA = "ds3";
my $DBNAME= "ds3";

# 1. PARSE COMMAND-LINE ARGUMENTS
my $pgsqltarget = $ARGV[0];
my $numberofstores = $ARGV[1];
my $mode = $ARGV[2];
my $action = $ARGV[3] || 'both';  # generate, execute, or both (default)

# Validate arguments
if (!defined $pgsqltarget || !defined $numberofstores || !defined $mode) {
    print "Usage: perl pgsql_ds_perl_validate_multi.pl <server> <num_stores> <before|after> [generate|execute]\n";
    print "\nExamples:\n";
    print "  perl pgsql_ds_perl_validate_multi.pl localhost 3 before generate\n";
    print "  perl pgsql_ds_perl_validate_multi.pl localhost 3 before execute\n";
    print "  perl pgsql_ds_perl_validate_multi.pl localhost 3 before (both)\n";
    exit 1;
}

# Validate mode parameter
if ($mode ne 'before' && $mode ne 'after') {
    die "Error: Mode must be 'before' or 'after'\n";
}

# Validate action parameter
if ($action ne 'generate' && $action ne 'execute' && $action ne 'both') {
    die "Error: Action must be 'generate', 'execute', or omitted (both)\n";
}

# 2. DIRECTORY SETUP
my $pgsqltargetdir = $pgsqltarget;
$pgsqltargetdir =~ s/\\//;  # Remove backslashes for directory name
make_path($pgsqltargetdir);  # Cross-platform directory creation

# 3. OS DETECTION
my $pathsep;
my $startcmd;
if ("$^O" eq "linux") {
    $pathsep = "/";
    $startcmd = "";
} else {
    $pathsep = "\\\\";
    $startcmd = "start";
}

# 4. GENERATE SQL FILES
if ($action eq 'generate' || $action eq 'both') {
    # SELECT TEMPLATE FILE
    my $template_file = "validate_${mode}.sql";
    my $script_dir = dirname(__FILE__);  # Get directory of this Perl script
    my $template_path = "${script_dir}${pathsep}${template_file}";

    # Check if template file exists
    if (!-f $template_path) {
        die "Error: Template file not found: $template_path\n";
    }

    # Read template file
    print "Reading template file: $template_path\n";
    open(my $TEMPLATE, "<$template_path") || die("Can't open template file: $template_path\n");
    my @template_content = <$TEMPLATE>;
    close $TEMPLATE;
    my $template = join('', @template_content);

    # GENERATE SQL FOR EACH STORE
    print "Generating validation SQL for $numberofstores stores...\n";

    foreach my $k (1 .. $numberofstores) {
        my $output_file = "$pgsqltargetdir${pathsep}pgsql_validate_${mode}${k}.sql";
        open(my $OUT, ">$output_file") || die("Can't open $output_file\n");

        # Substitute store number
        my $sql = $template;
        $sql =~ s/\{store_number\}/$k/g;  # Replace {store_number} placeholder

        print $OUT $sql;
        close $OUT;

        print "  Generated: $output_file\n";
    }

    print "SQL generation complete.\n";
}

# 5. EXECUTE SQL FILES
if ($action eq 'execute' || $action eq 'both') {
    print "\nExecuting validation SQL for $numberofstores stores...\n";

    # Check if SQL files exist
    my $first_file = "$pgsqltargetdir${pathsep}pgsql_validate_${mode}1.sql";
    if (!-f $first_file) {
        die "Error: SQL files not found. Run with 'generate' action first.\n";
    }

    # Execute all stores sequentially (keeps output clean)
    foreach my $k (1 .. $numberofstores) {
        my $output_file = "$pgsqltargetdir${pathsep}pgsql_validate_${mode}${k}.sql";
        print "  Executing store $k...\n";
        system("psql -h $pgsqltarget -U $SYSDBA -d $DBNAME -f $output_file");
    }

    print "Validation SQL execution complete.\n";
}
