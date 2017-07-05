#!/usr/bin/env perl

use strict;
use Cwd;
use Carp;
use File::Path;
use File::Basename;
use File::Spec;
use Term::ANSIColor;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);
use FindBin;

use lib "$FindBin::Bin/../lib";

use Umlet::Logger;
use Umlet::PerlAPIToSequenceDiagram::Converter;

use constant TRUE => 1;

use constant FALSE => 0;

use constant DEFAULT_VERBOSE => FALSE;

use constant DEFAULT_USERNAME => $ENV{USER};

use constant DEFAULT_INDIR => File::Spec->rel2abs(cwd());

use constant DEFAULT_LOG_LEVEL => 4;

use constant DEFAULT_OUTDIR => '/tmp/' . DEFAULT_USERNAME . '/' . File::Basename::basename($0) . '/' . time();

use constant DEFAULT_CONFIG_FILE => "$Find::Bin/../conf/umlet_converter.ini";

$|=1; ## do not buffer output stream

## Parse command line options
my ($infile, 
    $indir,
    $outdir, 
    $outfile,
    $log_level, 
    $help, 
    $logfile, 
    $man,
    $verbose, 
    $config_file
);

my $results = GetOptions (
      'log_level|d=s'           => \$log_level, 
      'help|h'                  => \$help,
      'man|m'                   => \$man,
      'infile=s'                => \$infile,
      'indir=s'                 => \$indir,
      'config_file=s'           => \$config_file,
      'outdir=s'                => \$outdir,
      'outfile=s'               => \$outfile,
      'logfile=s'               => \$logfile,
      'verbose=s'               => \$verbose,
);

&checkCommandLineArguments();

my $logger = new Umlet::Logger(
    logfile   => $logfile, 
    log_level => $log_level
);

if (!defined($logger)){
    die "Could not instantiate Umlet::Logger";
}

my $converter = Umlet::PerlAPIToSequenceDiagram::Converter::getInstance(
    config_file          => $config_file,
    outdir               => $outdir,
    verbose              => $verbose,
    outfile              => $outfile
    );

if (!defined($converter)){
    $logger->logdie("Could not instantiate Umlet::PerlAPIToSequenceDiagram::Converter");
}

if (defined($indir)){
    $converter->setIndir($indir);
}

if (defined($infile)){
    $converter->setInfile($infile);
}


$converter->run();

printGreen(File::Spec->rel2abs($0) . " execution completed");

print "The log file is '$logfile'\n";

exit(0);

##-----------------------------------------------------------
##
##    END OF MAIN -- SUBROUTINES FOLLOW
##
##-----------------------------------------------------------

sub printGreen {

    my ($msg) = @_;
    print color 'green';
    print $msg . "\n";
    print color 'reset';
}

sub printBoldRed {

    my ($msg) = @_;
    print color 'bold red';
    print $msg . "\n";
    print color 'reset';
}

sub printYellow {

    my ($msg) = @_;
    print color 'yellow';
    print $msg . "\n";
    print color 'reset';
}

sub checkCommandLineArguments {
   
    if ($man){

    	&pod2usage({-exitval => 1, -verbose => 2, -output => \*STDOUT});
    }
    
    if ($help){

    	&pod2usage({-exitval => 1, -verbose => 1, -output => \*STDOUT});
    }

    my $fatalCtr=0;

    if (!defined($infile)){

        if (!defined($indir)){

            $indir = DEFAULT_INDIR;
            
            printYellow("Neither --infile nor --indir were specified and therefore indir was set to default '$indir'");
        }


        $indir = File::Spec->rel2abs($indir);
    }
    else {

        $infile = File::Spec->rel2abs($infile);

        &checkInfileStatus($infile);
    }


    if ($fatalCtr> 0 ){
    	die "Required command-line arguments were not specified\n";
    }

    if (!defined($verbose)){

        $verbose = DEFAULT_VERBOSE;

        printYellow("--verbose was not specified and therefore was set to default '$verbose'");
        
    }

    if (!defined($config_file)){

        $config_file = DEFAULT_CONFIG_FILE;

        printYellow("--config_file was not specified and therefore was set to default '$config_file'");
        
    }

    if (!defined($log_level)){

        $log_level = DEFAULT_LOG_LEVEL;
        
        printYellow("--log_level was not specified and therefore was set to default '$log_level'");        
    }

    if (!defined($outdir)){

        $outdir = DEFAULT_OUTDIR;

        printYellow("--outdir was not specified and therefore was set to default '$outdir'");
    }

    if (!-e $outdir){

        mkpath ($outdir) || die "Could not create output directory '$outdir' : $!";
        
        printYellow("Created output directory '$outdir'");        
    }

    &checkOutdirStatus($outdir);

    if (!defined($logfile)){
    	
        $logfile = $outdir . '/' . File::Basename::basename($0) . '.log';
        
    	printYellow("--logfile was not specified and therefore was set to '$logfile'");        
    }
}

sub getInputFileBasename {

    my ($infile) = @_;

    my $basename = File::Basename::basename($infile);

    my @parts = split(/\./, $basename);

    pop(@parts); ## get rid of the filename extension

    return join('', @parts);
}


sub checkInfileStatus {

    my ($infile) = @_;
    
    if (!defined($infile)){
        die("infile was not defined");
    }

    my $errorCtr = 0 ;

    if (!-e $infile){
    
        printBoldRed("input file '$infile' does not exist");
        
        $errorCtr++;
    }
    else {

        if (!-f $infile){
        
            printBoldRed("'$infile' is not a regular file");
        
            $errorCtr++;
        }

        if (!-r $infile){
            
            printBoldRed("input file '$infile' does not have read permissions");
            
            $errorCtr++;
        }

        if (!-s $infile){

            printBoldRed("input file '$infile' does not have any content");

            $errorCtr++;
        }
    }

    if ($errorCtr > 0){
        
        printBoldRed("Encountered issues with input file '$infile'");
        
        exit(1);
    }
}

sub checkOutdirStatus {

    my ($outdir) = @_;

    if (!-e $outdir){
        
        mkpath($outdir) || die "Could not create output directory '$outdir' : $!";
        
        printYellow("Created output directory '$outdir'");        
    }
    
    if (!-d $outdir){
        
        printBoldRed("'$outdir' is not a regular directory");
        
    }
}