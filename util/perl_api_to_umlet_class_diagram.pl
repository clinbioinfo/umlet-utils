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
use Pod::Usage;

use lib "$FindBin::Bin/../lib";

use Umlet::Logger;
use Umlet::Perl::API::ClassDiagram::Converter;

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

my $converter = Umlet::Perl::API::ClassDiagram::Converter::getInstance(
    config_file          => $config_file,
    outdir               => $outdir,
    verbose              => $verbose
    );

if (!defined($converter)){
    $logger->logdie("Could not instantiate Umlet::Perl::API::ClassDiagram::Converter");
}

if (defined($indir)){
    $converter->setIndir($indir);
}

if (defined($infile)){
    $converter->setInfile($infile);
}

if (defined($outfile)){
    $converter->setOutfile($outfile);
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

    if (!defined($outfile)){

        $outfile = $outdir . '/' . File::Basename::basename($0) . '.xml';

        printYellow("--outfile was not specified and therefore was set to '$outfile'");
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


__END__

=head1 NAME

 perl_api_to_umlet_class_diagram.pl - Program that parses a Perl API and then creates a set of Umlet class diagrams.

=head1 SYNOPSIS

 perl util/perl_api_to_umlet_class_diagram.pl --indir ~/projects/my-perl-project

=head1 OPTIONS

=over 8

=item B<--indir>

  A directory under which all Perl modules discovered will be processed and included
  in the set of Umlet class diagrams.
  Default is the current working directory.

=item B<--infile>

  A specific Perl module that should be processed.

=item B<--help|-h>

  Print a brief help message and exits.

=item B<--logfile>

  The Log4perl log file
  Default is [outdir]/perl_api_to_umlet_class_diagram.pl.log

=item B<--log_level>

  The Log4perl logging level
  Default is 4 i.e.: INFO

=item B<--man|-m>

  Prints the manual page and exits.

=item B<--outdir>

  The output directory were the logfile will be written to.
  The output file will also be written to this output directory
  if the --outfile option is not explicity specified on invocation
  of this program.
  Default is /tmp/perl_api_to_umlet_class_diagram.pl/[time]/

=item B<--outfile>

  The output XML file that this program will create
  The output XML file should be opened using Umlet.  the prepare reporting script.
  Default is /tmp/perl_api_to_umlet_class_diagram.pl/[time]/out.xml

=item B<--verbose>

  If set to true (i.e.: 1) then will print more details to STDOUT.
  Default is false (i.e.: 0)

=back

=head1 DESCRIPTION

  This program will parse all of the Perl module files it finds under the specified
  input directory or just the one Perl module file if the --infile option is specified.

=head1 CONTACT

 Jaideep Sundaram clinbioinfo@github.com

 Copyright Jaideep Sundaram

 Can be distributed under GNU General Public License terms

=cut
