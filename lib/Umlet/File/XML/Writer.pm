package Umlet::File::XML::Writer;

use Moose;
use Term::ANSIColor;
use Template;

use Umlet::Config::Manager;


use constant TRUE  => 1;

use constant FALSE => 0;

use constant DEFAULT_VERBOSE => TRUE;

use constant DEFAULT_TEST_MODE => FALSE;

use constant DEFAULT_USERNAME => getlogin || getpwuid($<) || $ENV{USER} || "sundaramj";

use constant DEFAULT_OUTDIR => '/tmp/' . DEFAULT_USERNAME . '/' . File::Basename::basename($0) . '/' . time();

use constant DEFAULT_TEMPLATE_UMLET_FILE => "$FindBin::Bin/../template/umlet_xml_tmpl.tt";

use constant DEFAULT_TEMPLATE_CLASS_FILE => "$FindBin::Bin/../template/class_element_xml_tmpl.tt";

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


has 'outdir' => (
    is       => 'rw',
    isa      => 'Str',
    writer   => 'setOutdir',
    reader   => 'getOutdir',
    required => FALSE,
    default  => DEFAULT_OUTDIR
    );


has 'umlet_template_file' => (
    is       => 'rw',
    isa      => 'Str',
    writer   => 'setUmletTemplateFile',
    reader   => 'getUmletTemplateFile',
    required => FALSE,
    default  => DEFAULT_TEMPLATE_UMLET_FILE
    );


has 'umlet_class_template_file' => (
    is       => 'rw',
    isa      => 'Str',
    writer   => 'setUmletClassTemplateFile',
    reader   => 'getUmletClassTemplateFile',
    required => FALSE,
    default  => DEFAULT_TEMPLATE_CLASS_FILE
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

        $instance = new Umlet::File::XML::Writer(@_);

        if (!defined($instance)){

            confess "Could not instantiate Umlet::File::XML::Writer";
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


sub writeFile{

    my $self = shift;
    my ($class_lookup_list) = @_;

    if (!defined($class_lookup_list)){
        $self->{_logger}->logconfess("class_lookup_list was not defined");
    }


    $self->_load_class_content($class_lookup_list);    

}




no Moose;
__PACKAGE__->meta->make_immutable;

__END__


=head1 NAME

 Umlet::File::XML::Writer
 

=head1 VERSION

 1.0

=head1 SYNOPSIS

 use Umlet::File::XML::Writer;
 my $writer = new Umlet::File::XML::Writer(outfile => $outfile);
 $writer->writeFile($class_lookup_list);

=head1 AUTHOR

 Jaideep Sundaram

 Copyright Jaideep Sundaram

=head1 METHODS

=over 4

=cut