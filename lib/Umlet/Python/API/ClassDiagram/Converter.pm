package Umlet::Python::API::ClassDiagram::Converter;

use Moose;
use Cwd;
use Term::ANSIColor;

use Umlet::Config::Manager;
use Umlet::File::XML::Writer;
use Umlet::Python::Module::File::Parser;

use constant TRUE  => 1;

use constant FALSE => 0;

use constant DEFAULT_VERBOSE => TRUE;

use constant DEFAULT_TEST_MODE => TRUE;

use constant DEFAULT_USERNAME => getlogin || getpwuid($<) || $ENV{USER} || "sundaramj";

use constant DEFAULT_OUTDIR => '/tmp/' . DEFAULT_USERNAME . '/' . File::Basename::basename($0) . '/' . time();

use constant DEFAULT_INDIR => File::Spec->rel2abs(cwd());


## Singleton support
my $instance;

has 'test_mode' => (
    is       => 'rw',
    isa      => 'Bool',
    writer   => 'setTestMode',
    reader   => 'getTestMode',
    required => FALSE,
    default  => DEFAULT_TEST_MODE
    );

has 'config_file' => (
    is       => 'rw',
    isa      => 'Str',
    writer   => 'setConfigfile',
    reader   => 'getConfigfile',
    required => FALSE,
    );

has 'outdir' => (
    is       => 'rw',
    isa      => 'Str',
    writer   => 'setOutdir',
    reader   => 'getOutdir',
    required => FALSE,
    default  => DEFAULT_OUTDIR
    );

has 'outfile' => (
    is       => 'rw',
    isa      => 'Str',
    writer   => 'setOutfile',
    reader   => 'getOutfile',
    required => FALSE
    );

has 'indir' => (
    is       => 'rw',
    isa      => 'Str',
    writer   => 'setIndir',
    reader   => 'getIndir',
    required => FALSE,
    default  => DEFAULT_INDIR
    );

has 'infile' => (
    is       => 'rw',
    isa      => 'Str',
    writer   => 'setInfile',
    reader   => 'getInfile',
    required => FALSE
    );

has 'verbose' => (
    is       => 'rw',
    isa      => 'Bool',
    writer   => 'setVerbose',
    reader   => 'getVerbose',
    required => FALSE,
    default  => DEFAULT_VERBOSE
    );



sub getInstance {

    if (!defined($instance)){

        $instance = new Umlet::Python::API::ClassDiagram::Converter(@_);

        if (!defined($instance)){

            confess "Could not instantiate Umlet::Python::API::ClassDiagram::Converter";
        }
    }
    return $instance;
}

sub BUILD {

    my $self = shift;

    $self->_initLogger(@_);

    $self->_initConfigManager(@_);

    $self->_initUmletFileWriter(@_);

    $self->{_logger}->info("Instantiated ". __PACKAGE__);
}

sub _initLogger {

    my $self = shift;

    my $logger = Log::Log4perl->get_logger(__PACKAGE__);

    if (!defined($logger)){
        confess "logger was not defined";
    }

    $self->{_logger} = $logger;
}

sub _initConfigManager {

    my $self = shift;

    my $manager = Umlet::Config::Manager::getInstance(@_);
    if (!defined($manager)){
        $self->{_logger}->logconfess("Could not instantiate Umlet::Config::Manager");
    }

    $self->{_config_manager} = $manager;
}

sub _initUmletFileWriter {

    my $self = shift;

    my $writer = new Umlet::File::XML::Writer(@_);
    if (!defined($writer)){
        $self->{_logger}->logconfess("Could not instantiate Umlet::File::XML::Writer");
    }

    my $outfile = $self->getOutfile();
    if (defined($outfile)){
        $writer->setOutfile($outfile);
    }

    $self->{_writer} = $writer;
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

sub printGreen {

    my ($msg) = @_;
    print color 'green';
    print $msg . "\n";
    print color 'reset';
}


sub run {

    my $self = shift;

    $self->runConversion(@_);
}

sub runConversion {

    my $self = shift;


    my $indir;

    my $infile = $self->getInfile();

    if (!defined($infile)){

        $indir = $self->getIndir();

        if (!defined($indir)){

            $indir = DEFAULT_INDIR;

            $self->{_logger}->warn("Neither infile nor indir were not defined and therefore indir was set to default '$indir'");
        }

        $self->_get_file_list_from_indir($indir);
    }
    else {
        push(@{$self->{_file_list}}, $infile);
    }

    if ((exists $self->{_file_list}) && (scalar($self->{_file_list}) > 0)){

        my $file_ctr = 0;

        foreach my $file (@{$self->{_file_list}}){

            if ($self->getVerbose()){
                print "Processing file '$file'\n";
            }

            $self->{_logger}->info("Processing file '$file'");

            $file_ctr++;

            my $parser = new Umlet::Python::Module::File::Parser(infile => $file);

            if (!defined($parser)){
                $self->{_logger}->logconfess("Could not instantiate Umlet::Python::Module::File::Parser");
            }

            my $indir = $self->getIndir();
            if (defined($indir)){
                $parser->setIndir($indir);
            }

            my $lookup = $parser->getLookup();
            if (!defined($lookup)){
                $self->{_logger}->warn("lookup was not defined for file '$file'");
                next;
            }

            for my $class (sort keys %{$lookup}){

                my $plookup = {};

                $plookup->{package_name} = $class;

                if (exists $lookup->{$class}->{method_list}){
                    $plookup->{sub_list} = $lookup->{$class}->{method_list};
                }

                if (exists $lookup->{$class}->{use_list}){
                    $plookup->{use_list} = $lookup->{$class}->{use_list};
                }

                push(@{$self->{_class_lookup_list}}, $plookup);
            }
        }

        if ($self->getVerbose()){
            print "Processed '$file_ctr' Perl module files\n";
        }


        $self->{_writer}->writeFile($self->{_class_lookup_list});
    }
    else {
        printBoldRed("Looks like there are no file to be processed.");
        exit(1);
    }
}


sub _get_file_list_from_indir {

    my $self = shift;
    my ($indir) = @_;

    my $cmd = "find $indir -name '*.py'";

    my $file_list = $self->_execute_cmd($cmd);

    foreach my $file (@{$file_list}){
        push(@{$self->{_file_list}}, $file);
    }
}

sub _execute_cmd {

    my $self = shift;

    my ($cmd) = @_;

    if (!defined($cmd)){
        $self->{_logger}->logconfess("cmd was not defined");
    }

    $self->{_logger}->info("About to execute '$cmd'");

    my @results;

    eval {
        @results = qx($cmd);
    };

    if ($?){
        $self->{_logger}->logconfess("Encountered some error while attempting to execute '$cmd' : $! $@");
    }

    chomp @results;

    return \@results;
}

no Moose;
__PACKAGE__->meta->make_immutable;

__END__


=head1 NAME

 Umlet::Python::API::ClassDiagram::Converter


=head1 VERSION

 1.0

=head1 SYNOPSIS

 use Umlet::Python::API::ClassDiagram::Converter;
 my $converter = Umlet::Python::API::ClassDiagram::Converter::getInstance();
 $converter->runConversion();

=head1 AUTHOR

 Jaideep Sundaram

 Copyright Jaideep Sundaram

=head1 METHODS

=over 4

=cut
