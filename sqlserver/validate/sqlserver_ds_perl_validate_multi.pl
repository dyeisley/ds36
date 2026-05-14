#!/usr/bin/perl
# sqlserver_ds_perl_validate_multi.pl
# Script to generate and execute validation SQL for multiple stores
# Syntax: perl sqlserver_ds_perl_validate_multi.pl <server> <num_stores> <password> <pre_test|post_test> [generate|execute]

use strict;
use warnings;
use File::Basename;
use File::Path qw(make_path);

# 1. PARSE COMMAND-LINE ARGUMENTS
my $sqlservertarget = $ARGV[0];
my $numberofstores = $ARGV[1];
my $password = $ARGV[2] || 'password';
my $mode = $ARGV[3];
my $action = $ARGV[4] || 'both';  # generate, execute, or both (default)
my $popular_modulo = $ARGV[5] || 10000;  # Optional modulo value, default 10000

# Validate arguments
if (!defined $sqlservertarget || !defined $numberofstores || !defined $mode) {
    print "Usage: perl sqlserver_ds_perl_validate_multi.pl <server> <num_stores> <password> <pre_test|post_test> [generate|execute] [popular_modulo]\n";
    print "\nExamples:\n";
    print "  perl sqlserver_ds_perl_validate_multi.pl localhost 3 mypassword pre_test generate\n";
    print "  perl sqlserver_ds_perl_validate_multi.pl localhost 3 mypassword pre_test execute\n";
    print "  perl sqlserver_ds_perl_validate_multi.pl localhost 3 mypassword pre_test both 1000\n";
    print "  perl sqlserver_ds_perl_validate_multi.pl localhost 3 mypassword pre_test (defaults to both, modulo 10000)\n";
    exit 1;
}

# Validate mode parameter
if ($mode ne 'pre_test' && $mode ne 'post_test') {
    die "Error: Mode must be 'pre_test' or 'post_test'\n";
}

# Validate action parameter
if ($action ne 'generate' && $action ne 'execute' && $action ne 'both') {
    die "Error: Action must be 'generate', 'execute', or omitted (both)\n";
}

# 2. DIRECTORY SETUP
my $sqlservertargetdir = $sqlservertarget;
$sqlservertargetdir =~ s/\\//;  # Remove backslashes for directory name
make_path($sqlservertargetdir);  # Cross-platform directory creation

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
        my $output_file = "$sqlservertargetdir${pathsep}sqlserver_validate_${mode}${k}.sql";
        open(my $OUT, ">$output_file") || die("Can't open $output_file\n");

        # Substitute store number and popular modulo
        my $sql = $template;
        $sql =~ s/\{store_number\}/$k/g;  # Replace {store_number} placeholder
        $sql =~ s/\{popular_modulo\}/$popular_modulo/g;  # Replace {popular_modulo} placeholder

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
    my $first_file = "$sqlservertargetdir${pathsep}sqlserver_validate_${mode}1.sql";
    if (!-f $first_file) {
        die "Error: SQL files not found. Run with 'generate' action first.\n";
    }

    # Execute all stores sequentially (keeps output clean)
    foreach my $k (1 .. $numberofstores) {
        my $output_file = "$sqlservertargetdir${pathsep}sqlserver_validate_${mode}${k}.sql";
        print "  Executing store $k...\n";
        system("sqlcmd -C -S $sqlservertarget -U sa -P $password -i $output_file");
    }

    print "Validation SQL execution complete.\n";
}
