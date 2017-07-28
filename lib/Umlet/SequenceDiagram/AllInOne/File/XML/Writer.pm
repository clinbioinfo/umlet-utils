package Umlet::SequenceDiagram::AllInOne::File::XML::Writer;

use Moose;
use Term::ANSIColor;
use Template;
use File::Slurp;
use File::Basename;
use File::Path;
use File::Copy;
use FindBin;

use Umlet::Config::Manager;

use constant MAX_CLASS_PER_ROW => 5;

use constant TRUE  => 1;

use constant FALSE => 0;

use constant DEFAULT_VERBOSE => TRUE;

use constant DEFAULT_TEST_MODE => FALSE;

use constant DEFAULT_USERNAME => getlogin || getpwuid($<) || $ENV{USER} || "sundaramj";

use constant DEFAULT_OUTDIR => '/tmp/' . DEFAULT_USERNAME . '/' . File::Basename::basename($0) . '/' . time();

use constant DEFAULT_TEMPLATE_UMLET_FILE => "$FindBin::Bin/../template/umlet_xml_tmpl.tt";

use constant DEFAULT_TEMPLATE_SEQUENCE_DIAGRAM_ALL_IN_ONE_FILE => "$FindBin::Bin/../template/sequence_diagram_all_in_one_xml_tmpl.tt";

use constant DEFAULT_ZOOM_LEVEL => 10;

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


has 'umlet_sequence_diagram_template_file' => (
    is       => 'rw',
    isa      => 'Str',
    writer   => 'setUmletSequenceDiagramTemplateFile',
    reader   => 'getUmletSequenceDiagramTemplateFile',
    required => FALSE,
    default  => DEFAULT_TEMPLATE_SEQUENCE_DIAGRAM_ALL_IN_ONE_FILE
    );


has 'verbose' => (
    is       => 'rw',
    isa      => 'Bool',
    writer   => 'setVerbose',
    reader   => 'getVerbose',
    required => FALSE,
    default  => DEFAULT_VERBOSE
    );

has 'zoom_level' => (
    is       => 'rw',
    isa      => 'Int',
    writer   => 'setZoomLevel',
    reader   => 'getZoomLevel',
    required => FALSE,
    default  => DEFAULT_ZOOM_LEVEL
    );

has 'zoom_level' => (
    is       => 'rw',
    isa      => 'Int',
    writer   => 'setZoomLevel',
    reader   => 'getZoomLevel',
    required => FALSE,
    default  => DEFAULT_ZOOM_LEVEL
    );

has 'outfile' => (
    is       => 'rw',
    isa      => 'Str',
    writer   => 'setOutfile',
    reader   => 'getOutfile',
    required => FALSE
    );


sub getInstance {

    if (!defined($instance)){

        $instance = new Umlet::SequenceDiagram::AllInOne::File::XML::Writer(@_);

        if (!defined($instance)){

            confess "Could not instantiate Umlet::SequenceDiagram::AllInOne::File::XML::Writer";
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
    my ($title, $content) = @_;

    if (!defined($title)){
        $self->{_logger}->logconfess("title was not defined");
    }

    if (!defined($content)){
        $self->{_logger}->logconfess("content was not defined");
    }

    my $umlet_template_file = $self->getUmletTemplateFile();

    if (! $self->_checkTemplateFileStatus($umlet_template_file)){
        $self->{_logger}->logconfess("Encountered some problem with template file '$umlet_template_file'");
    }

    my $outfile = $self->_get_outfile();

    my $final_lookup = {
        zoom_level => $self->getZoomLevel(),
        title      => $title,
        content    => $self->_prepare_sequence_diagram_content($title, $content)
    };
    
    my $tt = new Template({ABSOLUTE => 1});
    if (!defined($tt)){
        $self->{_logger}->logconfess("Could not instantiate TT");
    }

    $tt->process($umlet_template_file, $final_lookup, $outfile) || $self->{_logger}->logconfess("Encountered the following Template::process error:" . $tt->error());

    $self->{_logger}->info("Created file '$outfile' using template file '$umlet_template_file'");

    print "Wrote '$outfile'\n";
}

sub _prepare_sequence_diagram_content {

    my $self = shift;
    my ($title, $content) = @_;

    my $template_file = $self->getUmletSequenceDiagramTemplateFile();

    if (! $self->_checkTemplateFileStatus($template_file)){
        $self->{_logger}->logconfess("Encountered some problem with template file '$template_file'");
    }

    my $final_lookup = {
        title => $title,
        panel_attributes => $content,
        x_coord => $self->getXCoord(),
        y_coord => $self->getYCoord(),
        h_coord => $self->getWCoord(),
        w_coord => $self->getHCoord()
    };       

    my $tt = new Template({ABSOLUTE => 1});
    if (!defined($tt)){
        $self->{_logger}->logconfess("Could not instantiate TT");
    }

    my $tmp_outfile = $self->getOutdir() . '/out.uxf';

    $tt->process($template_file, $final_lookup, $tmp_outfile) || $self->{_logger}->logconfess("Encountered the following Template::process error:" . $tt->error());
    
    $self->{_logger}->info("Umlet element content for sequence diagram was written to temporary output file '$tmp_outfile'");

    my @lines = read_file($tmp_outfile);

    my $umlet_element_content = join("\n", @lines) . "\n";

    unlink($tmp_outfile) || $self->{_logger}->logconfess("Could not unlink temporary output file '$tmp_outfile' : $!");

    $self->{_logger}->info("temporary output file '$tmp_outfile' was removed");

    return $umlet_element_content;
}

sub _get_outfile {

    my $self = shift;

    my $outfile = $self->getOutfile();
    
    if (!defined($outfile)){

        my $outdir = $self->getOutdir();

        if (!-e $outdir){

            mkpath($outdir) || $self->{_logger}->logconfess("Could not create output directory '$outdir' : $!");
            
            $self->{_logger}->info("Created output directory '$outdir'");
        }

        $outfile = $outdir . '/sequence_diagram.xml';

        $self->setOutfile($outfile);
    }


    if ((-e $outfile) && (-s $outfile)){

        $self->_backup_file($outfile);
    }

    return $outfile;
}


sub _backup_file {

    my $self = shift;
    my ($file) = @_;

    my $bakfile = $file . '.bak';

    move($file, $bakfile) || $self->{_logger}->logconfess("Could not move '$file' to '$bakfile' : $!");

    $self->{_logger}->info("Backed-up '$file' to '$bakfile'");
}

sub _checkTemplateFileStatus {

    my $self = shift;
    my ($file) = @_;

    if (!defined($file)){
        $self->{_logger}->logconfess("file was not defined");
    }

    my $errorCtr = 0 ;

    if (!-e $file){
        $self->{_logger}->fatal("input template file '$file' does not exist");
        $errorCtr++;
    }
    else {
        
        if (!-f $file){
            $self->{_logger}->fatal("'$file' is not a regular file");
            $errorCtr++;
        }
        
        if (!-r $file){
            $self->{_logger}->fatal("input template file '$file' does not have read permissions");
            $errorCtr++;
        }
        
        if (!-s $file){
            $self->{_logger}->fatal("input template file '$file' does not have any content");
            $errorCtr++;
        }
    }
    
    if ($errorCtr > 0){
        $self->{_logger}->fatal("Encountered issues with input template file '$file'");
        return FALSE;
    }

    return TRUE;
}


no Moose;
__PACKAGE__->meta->make_immutable;

__END__


=head1 NAME

 Umlet::SequenceDiagram::AllInOne::File::XML::Writer
 

=head1 VERSION

 1.0

=head1 SYNOPSIS

 use Umlet::SequenceDiagram::AllInOne::File::XML::Writer;
 my $writer = new Umlet::SequenceDiagram::AllInOne::File::XML::Writer(outfile => $outfile);
 $writer->writeFile($class_lookup_list);

=head1 AUTHOR

 Jaideep Sundaram

 Copyright Jaideep Sundaram

=head1 METHODS

=over 4

=cut