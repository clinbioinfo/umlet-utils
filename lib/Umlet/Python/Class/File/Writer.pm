package Umlet::Python::Class::File::Writer;

use Moose;
# use String::CamelCase qw(decamelize);
use File::Path;
use FindBin;
use Template;
use File::Slurp;

use Umlet::Config::Manager;

extends 'Umlet::File::Writer';

use constant TRUE  => 1;

use constant FALSE => 0;

use constant DEFAULT_SETTER_TEMPLATE_FILE => "$FindBin::Bin/../template/python_setter_method_tmpl.tt";

use constant DEFAULT_GETTER_TEMPLATE_FILE => "$FindBin::Bin/../template/python_getter_method_tmpl.tt";

## Singleton support
my $instance;

has 'class_lookup' => (
    is       => 'rw',
    isa      => 'HashRef',
    writer   => 'setClassLookup',
    reader   => 'getClassLookup',
    required => TRUE
    );

has 'namespace' => (
    is       => 'rw',
    isa      => 'Str',
    writer   => 'setNamespace',
    reader   => 'getNamespace',
    required => TRUE
    );

has 'language_namespace' => (
    is       => 'rw',
    isa      => 'Str',
    writer   => 'setLanguageNamespace',
    reader   => 'getLanguageNamespace',
    required => TRUE
    );

has 'getter_method_template_file' => (
    is       => 'rw',
    isa      => 'Str',
    writer   => 'setGetterTemplateFile',
    reader   => 'getGetterTemplateFile',
    required => FALSE,
    default  => DEFAULT_GETTER_TEMPLATE_FILE
    );

has 'setter_method_template_file' => (
    is       => 'rw',
    isa      => 'Str',
    writer   => 'setSetterTemplateFile',
    reader   => 'getSetterTemplateFile',
    required => FALSE,
    default  => DEFAULT_SETTER_TEMPLATE_FILE
    );

sub getInstance {

    if (!defined($instance)){

        $instance = new Umlet::Python::Class::File::Writer(@_);

        if (!defined($instance)){

            confess "Could not instantiate Umlet::Python::Class::File::Writer";
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

sub writeFile {

    my $self = shift;

    my $namespace = $self->getNamespace();
    if (!defined($namespace)){
        $self->{_logger}->logconfess("namespace was not defined");
    }    

    my $class_lookup = $self->getClassLookup();
    if (!defined($class_lookup)){
        $self->{_logger}->logconfess("class_lookup was not defined");
    }

    my $language_namespace = $self->getLanguageNamespace();
    if (!defined($language_namespace)){
        $self->{_logger}->logconfess("language_namespace was not defined");
    }
   
    $self->{_namespace} = $namespace;

    $self->{_language_namespace} = $language_namespace;

    $self->{_class_lookup} = $class_lookup;

    $self->_derive_contents();

    my $template_file = $self->getClassTemplateFile();

    my $outfile = $self->_get_outfile($self->{_namespace});

    $self->_write_file($template_file, $self->{_template_lookup}, $outfile);
}

sub _derive_class_details {

    my $self = shift;

    $self->_derive_instance_variable_name();

    $self->_derive_namespace_declaration();
}


sub _derive_instance_variable_name {

    my $self = shift;

    my $namespace = $self->{_language_namespace};

    $namespace =~ s|::||g;

    $namespace =~ s|\.||g;
    
    $self->{_instance_variable_name} = lcfirst($namespace) . 'Instance';
}


sub _derive_namespace_declaration {

    my $self = shift;

    my @parts = split(/\./, $self->{_language_namespace});

    my $portion;

    my $ctr = 0;

    my $content;

    my $list = [];

    for (my $i = 0; $i < scalar(@parts) ; $i++){

        my $part = $parts[$i];

        push(@{$list}, $part);

        if ($i == 0){

            $content = "var $part = $part || {};\n";                    
        }
        else {

            my $compounded_parts = join('.', @{$list});

            $content .= "$compounded_parts = $compounded_parts || {};\n";
        }    
    }
    
    $self->{_namespace_declaration_content} = $content;
}

sub _derive_constants {

    my $self = shift;
    my ($class_lookup) = @_;

    if (( exists $class_lookup->{constant_list}) &&
        ( defined $class_lookup->{constant_list})){

        my $content = '';

        foreach my $record (@{$class_lookup->{constant_list}}){
            
            my $name = $record->getName();
            
            if ((lc($name) eq 'true') || (lc($name) eq 'false')){
                next;
            }

            my $val = $record->getValue();
            
            if (!defined($val)){
                $val = undef;
            }

            $content .= "const $name = $val;\n";
        }

        $self->{_constants_content} = $content;
    }
    else {
        $self->{_logger}->info("Looks like there are no constants for class '$self->{_javascript_namespace}'");
    }
}

sub _derive_functions {

    my $self = shift;
    my ($class_lookup) = @_;

    $self->_derive_public_functions(@_);

    $self->_derive_private_functions(@_);
}

sub _derive_private_functions {

    my $self = shift;
    my ($class_lookup) = @_;

    if (( exists $class_lookup->{private_methods_list}) && 
        ( defined $class_lookup->{private_methods_list})){
        
        my $content = '';

        foreach my $record (@{$class_lookup->{private_methods_list}}){

            $content .= 'const ' . $record->getName() . ' = function (){' . "\n".
            '};' . "\n\n";
        }

        $self->{_private_functions_content} = $content;
    }
    else {
        $self->{_logger}->info("Looks like there are no private methods/functions for class '$self->{_javascript_namespace}'");
    }
}
            

sub _get_camel_case_function_name {

    my $self = shift;
    my ($function_name) = @_;

    my @parts = split(/_/, $function_name);

    my $final_function_name = '';

    my $ctr = 0;

    foreach my $part (@parts){

        $ctr++;

        if ($ctr == 1){

            $final_function_name .= $part;
        }
        else {

            $final_function_name .= ucfirst($part);
        }
    }

    return $final_function_name;
}


sub _write_file {

    my $self = shift;
    my ($template_file, $lookup, $outfile) = @_;

    my $tt = new Template({ABSOLUTE => 1});
    if (!defined($tt)){
        $self->{_logger}->logconfess("Could not instantiate TT");
    }

    $tt->process($template_file, $lookup, $outfile) || $self->{_logger}->logconfess("Encountered the following Template::process error:" . $tt->error());

    if ($self->getVerbose()){
        print "Wrote class file '$outfile'\n";
    }

    $self->{_logger}->info("Wrote class file '$outfile'");
}

sub _get_outfile {

    my $self = shift;
    my ($namespace) = @_;

    my $outdir = $self->getOutdir() . '/python-lib/';

    my $outfile = $outdir . $namespace;

    $outfile =~ s|\.|/|g;

    my $dirname = File::Basename::dirname($outfile);

    if (!-e $dirname){

        mkpath($dirname) || $self->{_logger}->logconfess("Could not create directory '$dirname' : $!");
        
        $self->{_logger}->info("Created output directory '$dirname'");
    }


    $outfile .= '.py';

    return $outfile;
}

sub _print_summary {

    my $self = shift;
    
    if ($self->getVerbose()){

        print "\nCreated the following class files:\n";
        
        print join("\n", @{$self->{_module_file_list}}) . "\n";
    }
}

sub _generate_content_from_template {

    my $self = shift;
    my ($template_file, $lookup) = @_;

    my $tt = new Template({ABSOLUTE => 1});
    if (!defined($tt)){
        $self->{_logger}->logconfess("Could not instantiate TT");
    }

    my $tmp_outfile = $self->getOutdir() . '/out.pm';

    $tt->process($template_file, $lookup, $tmp_outfile) || $self->{_logger}->logconfess("Encountered the following Template::process error:" . $tt->error());
    
    $self->{_logger}->info("Wrote temporary output file '$tmp_outfile'");

    my @lines = read_file($tmp_outfile);

    my $content = join("", @lines);

    unlink($tmp_outfile) || $self->{_logger}->logconfess("Could not unlink temporary output file '$tmp_outfile' : $!");

    $self->{_logger}->info("temporary output file '$tmp_outfile' was removed");

    return $content;
}


no Moose;
__PACKAGE__->meta->make_immutable;

__END__


=head1 NAME

 Umlet::Python::Class::File::Writer
 

=head1 VERSION

 1.0

=head1 SYNOPSIS

 use Umlet::Python::Class::File::Writer;
 my $manager = Umlet::Python::Class::File::Writer::getInstance();
 $manager->commitCodeAndPush($comment);

=head1 AUTHOR

 Jaideep Sundaram

 Copyright Jaideep Sundaram

=head1 METHODS

=over 4

=cut