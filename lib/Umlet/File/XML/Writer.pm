package Umlet::File::XML::Writer;

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

use constant DEFAULT_TEMPLATE_CLASS_FILE => "$FindBin::Bin/../template/class_element_xml_tmpl.tt";

use constant DEFAULT_ZOOM_LEVEL => 10;

use constant DEFAULT_SET_BACKGROUND_COLOR_GREEN => FALSE;

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

has 'set_background_color_green' => (
    is       => 'rw',
    isa      => 'Bool',
    writer   => 'setBackgroundColorGreen',
    reader   => 'getBackgroundColorGreen',
    required => FALSE,
    default  => DEFAULT_SET_BACKGROUND_COLOR_GREEN
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

    my $umlet_template_file = $self->getUmletTemplateFile();

    if (! $self->_checkTemplateFileStatus($umlet_template_file)){
        $self->{_logger}->logconfess("Encountered some problem with template file '$umlet_template_file'");
    }

    my $outfile = $self->_get_outfile();

    my $final_lookup = {
        zoom_level => $self->getZoomLevel(),
        classes    => join("\n", @{$self->{_classes_content}})
    };

    my $tt = new Template({ABSOLUTE => 1});
    if (!defined($tt)){
        $self->{_logger}->logconfess("Could not instantiate TT");
    }

    $tt->process($umlet_template_file, $final_lookup, $outfile) || $self->{_logger}->logconfess("Encountered the following Template::process error:" . $tt->error());

    $self->{_logger}->info("Created file '$outfile' using template file '$umlet_template_file'");

    print "Wrote '$outfile'\n";
}

sub _load_class_content {

    my $self = shift;
    my ($class_lookup_list) = @_;

    my $class_element_list = [];

    my $template_file = $self->getUmletClassTemplateFile();

    if (! $self->_checkTemplateFileStatus($template_file)){
        $self->{_logger}->logconfess("Encountered some problem with template file '$template_file'");
    }

    my $class_ctr = 0;
    my $max_height = 0;

    my $x_coord = 10;
    my $y_coord = 10;
    my $w_coord = 0;
    my $h_coord = 5;

    foreach my $class_lookup (@{$class_lookup_list}){

        $class_ctr++;

        my $class_content_stack = [];

        push(@{$class_content_stack}, $class_lookup->{package_name});

        my $width = length($class_lookup->{package_name}) * 7;

        push(@{$class_content_stack}, '--');

        $w_coord = $width + 10;

        if ($self->setBackgroundColorGreen()){
            push(@{$class_content_stack}, "bg=green");
        }

        if (exists $class_lookup->{use_list}){

            my $ctr = 0;

            foreach my $use (sort @{$class_lookup->{use_list}}){

                if ($use =~ /import/){
                    push(@{$class_content_stack}, "//$use");
                }
                else {
                    push(@{$class_content_stack}, "//use $use");
                }

                $ctr++;
            }

            # push(@{$class_content_stack}, "\n");

            $h_coord += $ctr;
        }

        if (exists $class_lookup->{extends_list}){

            my $ctr = 0;

            foreach my $extends (sort @{$class_lookup->{extends_list}}){

                push(@{$class_content_stack}, "//extends '$extends'");

                $ctr++;
            }

            # push(@{$class_content_stack}, "\n");

            $h_coord += $ctr;
        }


        if (exists $class_lookup->{constant_list}){

            my $ctr = 0;

            foreach my $constant_array (sort @{$class_lookup->{constant_list}}){

                push(@{$class_content_stack}, "//use constant $constant_array->[0] => $constant_array->[1]");

                $ctr++;
            }

            # push(@{$class_content_stack}, "\n");

            $h_coord += $ctr;
        }


        if (exists $class_lookup->{has_list}){

            my $ctr = 0;

            foreach my $has (sort @{$class_lookup->{has_list}}){

                # $has =~ s|:|_|g;

                # $has =~ s|\-|_|g;

                push(@{$class_content_stack}, "-$has");

                $ctr++;
            }

            # push(@{$class_content_stack}, "\n");

            $h_coord += $ctr;
        }

        if (exists $class_lookup->{private_data_member_list}){

            my $ctr = 0;

            foreach my $member (sort @{$class_lookup->{private_data_member_list}}){

                push(@{$class_content_stack}, $member);

                $ctr++;
            }

            $h_coord += $ctr;
        }

        push(@{$class_content_stack}, '--');

        if (exists $class_lookup->{sub_list}){

            my $ctr = 0;

            foreach my $sub (sort @{$class_lookup->{sub_list}}){

                push(@{$class_content_stack}, "+$sub()");

                $ctr++;
            }

            # push(@{$class_content_stack}, "\n");

            $h_coord += $ctr;
        }

        my $panel_attributes = join("\n", @{$class_content_stack});

        $h_coord += 10;

        my $final_lookup = {
            panel_attributes => $panel_attributes,
            x_coord => $x_coord,
            y_coord => $y_coord,
            h_coord => $h_coord,
            w_coord => $w_coord
        };


        $self->_prepare_umlet_elememnt_content($class_lookup->{package_name}, $final_lookup, $template_file);

        ## Make sure the next class is rendered to the right of the
        ## current one.
        $x_coord = $x_coord + $width + 20;

        if ($h_coord > $max_height){

            $max_height = $h_coord;
        }

        # $h_coord = $h_coord * 3;

        if ($class_ctr == MAX_CLASS_PER_ROW){

            ## Have processed 5 classes time to move to the next line

            $x_coord = 10; ## reset

            $y_coord = $y_coord + $max_height; ## set the y_coord for the next row of classes

            $max_height = 0; ## reset
        }

        $h_coord = 10;
    }
}


sub _prepare_umlet_elememnt_content {

    my $self = shift;
    my ($package_name, $final_lookup, $template_file) = @_;

    my $tt = new Template({ABSOLUTE => 1});
    if (!defined($tt)){
        $self->{_logger}->logconfess("Could not instantiate TT");
    }

    my $tmp_outfile = $self->getOutdir() . '/out.uxf';

    $tt->process($template_file, $final_lookup, $tmp_outfile) || $self->{_logger}->logconfess("Encountered the following Template::process error:" . $tt->error());

    $self->{_logger}->info("Umlet element content for package '$package_name' was written to temporary output file '$tmp_outfile'");

    my @lines = read_file($tmp_outfile);

    my $umlet_element_content = join("\n", @lines) . "\n";

    push(@{$self->{_classes_content}}, $umlet_element_content);

    unlink($tmp_outfile) || $self->{_logger}->logconfess("Could not unlink temporary output file '$tmp_outfile' : $!");

    $self->{_logger}->info("temporary output file '$tmp_outfile' was removed");
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

        $outfile = $outdir . '/out.xml';

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