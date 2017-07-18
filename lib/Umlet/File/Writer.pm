package Umlet::File::Writer;

use Moose;
use Cwd;
use String::CamelCase qw(decamelize);
use Data::Dumper;
use File::Path;
use FindBin;
use Term::ANSIColor;

use Umlet::Config::Manager;

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

has 'infile' => (
    is       => 'rw',
    isa      => 'Str',
    writer   => 'setInfile',
    reader   => 'getInfile',
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

has 'skip_green_modules' => (
    is       => 'rw',
    isa      => 'Bool',
    writer   => 'setSkipGreenModules',
    reader   => 'getSkipGreenModules',
    required => FALSE
    );

has 'suppress_checkpoints' => (
    is       => 'rw',
    isa      => 'Bool',
    writer   => 'setSuppressCheckpoints',
    reader   => 'getSuppressCheckpoints',
    required => FALSE
    );

has 'software_version' => (
    is       => 'rw',
    isa      => 'Str',
    writer   => 'setSoftwareVersion',
    reader   => 'getSoftwareVersion',
    required => FALSE
    );

has 'software_author' => (
    is       => 'rw',
    isa      => 'Str',
    writer   => 'setSoftwareAuthor',
    reader   => 'getSoftwareAuthor',
    required => FALSE
    );

has 'author_email_address' => (
    is       => 'rw',
    isa      => 'Str',
    writer   => 'setAuthorEmailAddress',
    reader   => 'getAuthorEmailAddress',
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

        $instance = new Umlet::File::Writer(@_);

        if (!defined($instance)){

            confess "Could not instantiate Umlet::File::Writer";
        }
    }
    return $instance;
}

sub BUILD {

    my $self = shift;

    $self->_initLogger(@_);

    $self->_initConfigManager(@_);


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

sub createAPI {

    my $self = shift;

    $self->_create_api(@_);

    # $self->_print_summary(@_);
}


no Moose;
__PACKAGE__->meta->make_immutable;

__END__


=head1 NAME

 Umlet::File::Writer
 

=head1 VERSION

 1.0

=head1 SYNOPSIS

 use Umlet::File::Writer;
 my $manager = Umlet::File::Writer::getInstance();
 $manager->commitCodeAndPush($comment);

=head1 AUTHOR

 Jaideep Sundaram

 Copyright Jaideep Sundaram

=head1 METHODS

=over 4

=cut