package Umlet::PerlAPIToClassDiagram::Converter;

use Moose;
use Cwd;
use Term::ANSIColor;

use Umlet::Config::Manager;
use Umlet::File::XML::Writer;
use Umlet::Perl::Module::File::Parser;

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

        $instance = new Umlet::PerlAPIToClassDiagram::Converter(@_);

        if (!defined($instance)){

            confess "Could not instantiate Umlet::PerlAPIToClassDiagram::Converter";
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

    my $file_ctr = 0;

    foreach my $file (@{$self->{_file_list}}){

        $file_ctr++;

        my $parser = new Umlet::Perl::Module::File::Parser(infile => $file);

        if (!defined($parser)){
            $self->{_logger}->logconfess("Could not instantiate Umlet::Perl::Module::File::Parser");
        }

        my $lookup = $parser->getLookup();
        if (!defined($lookup)){
            $self->{_logger}->logconfess("lookup was not defined for file '$file'");
        }

        push(@{$self->{_class_lookup_list}}, $lookup);
    }

    if ($self->getVerbose()){
        print "Processed '$file_ctr' Perl module files\n";
    }


    $self->{_writer}->writeFile($self->{_class_lookup_list});
}

sub _get_file_list_from_indir {

    my $self = shift;
    my ($indir) = @_;

    my $cmd = "find $indir -name '*.pm'";

    my $file_list = $self->_execute_cmd($cmd);

    return $file_list;
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

 Umlet::PerlAPIToClassDiagram::Converter
 

=head1 VERSION

 1.0

=head1 SYNOPSIS

 use Umlet::PerlAPIToClassDiagram::Converter;
 my $converter = Umlet::PerlAPIToClassDiagram::Converter::getInstance();
 $converter->runConversion();

=head1 AUTHOR

 Jaideep Sundaram

 Copyright Jaideep Sundaram

=head1 METHODS

=over 4

=cut
