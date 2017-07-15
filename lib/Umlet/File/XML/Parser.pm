package Umlet::File::XML::Parser;

use Moose;

use Term::ANSIColor;

use XML::Twig;

use Umlet::DataMember::Record;
use Umlet::Method::Record;
use Umlet::Constant::Record;
use Umlet::Config::Manager;

use constant TRUE  => 1;

use constant FALSE => 0;

use constant DEFAULT_VERBOSE => TRUE;

use constant DEFAULT_TEST_MODE => TRUE;

use constant HEADER_SECTION => 0;

use constant PRIVATE_MEMBERS_SECTION => 1;

use constant PUBLIC_MEMBERS_SECTION => 2;


use constant DEFAULT_USERNAME => getlogin || getpwuid($<) || $ENV{USER} || "sundaramj";

use constant DEFAULT_OUTDIR => '/tmp/' . DEFAULT_USERNAME . '/' . File::Basename::basename($0) . '/' . time();

## Singleton support
my $instance;

my $this;

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

has 'infile' => (
    is       => 'rw',
    isa      => 'Str',
    writer   => 'setInfile',
    reader   => 'getInfile',
    required => FALSE
    );

has 'skip_green_modules' => (
    is       => 'rw',
    isa      => 'Bool',
    writer   => 'setSkipGreenModules',
    reader   => 'getSkipGreenModules',
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

        $instance = new Umlet::File::XML::Parser(@_);

        if (!defined($instance)){

            confess "Could not instantiate Umlet::File::XML::Parser";
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


sub getClassList {

    my $self = shift;
    if (! exists $self->{_class_record_list}){
        $self->_parse_file(@_);
    }

    return $self->{_class_record_list};
}

sub getModuleLookup {

    my $self = shift;

    if (! exists $self->{_module_lookup}){
        $self->_parse_file(@_);
    }

    return $self->{_module_lookup};    
}

sub getModuleCount {

    my $self = shift;

    if (! exists $self->{_module_ctr}){
        $self->_parse_file(@_);
    }

    return $self->{_module_ctr};    
}

sub _summarize_parsing_activity {

    my $self = shift;

    my $infile = $self->getInfile();
    
    $self->{_logger}->info("Finished parsing Umlet uxf file '$infile'");

    $self->{_logger}->info("Found the following '$self->{_module_ctr}' modules:");
    
    if ($self->getVerbose()){

        print "Finished parsing Umlet uxf file '$infile'\n";
        print "Found the folloiwng '$self->{_module_ctr}' modules\n";
    }

    foreach my $name (sort keys %{$self->{_module_lookup}}){

        if ($self->getVerbose()){

            print $name . "\n";
        }

        $self->{_logger}->info($name);
    }
}


sub _init_method_record {

    my $self = shift;
    my ($name, $data_type, $parameter_list) = @_;

    my $record = new Umlet::Method::Record(name => $name);
    
    if (!defined($record)){
        $self->{_logger}->logconfess("Could not instantiate Umlet::Method::Record");
    }

    if (defined($data_type)){
        $record->setReturnDataType($data_type);
    }

    return $record;
}

sub _init_data_member_record {

    my $self = shift;
    my ($name, $data_type) = @_;

    my $record = new Umlet::DataMember::Record(name => $name);
    
    if (!defined($record)){
        $self->{_logger}->logconfess("Could not instantiate Umlet::DataMember::Record");
    }

    if (defined($data_type)){
        $record->setDataType($data_type);
    }

    return $record;
}

sub _init_constant_record {

    my $self = shift;
    my ($name, $value) = @_;

    my $record = new Umlet::Constant::Record(name => $name);
    
    if (!defined($record)){
        $self->{_logger}->logconfess("Could not instantiate Umlet::DataMember::Record");
    }

    if (defined($value)){
        $record->setValue($value);
    }

    return $record;
}


no Moose;
__PACKAGE__->meta->make_immutable;

__END__


=head1 NAME

 Umlet::File::XML::Parser
 

=head1 VERSION

 1.0

=head1 SYNOPSIS

 use Umlet::File::XML::Parser;
 my $parser = new Umlet::File::XML::Parser(infile => $infile);
 my $class_record_list = $parser->getClassList();

=head1 AUTHOR

 Jaideep Sundaram

 Copyright Jaideep Sundaram

=head1 METHODS

=over 4

=cut
