package Umlet::JavaScript::Class::File::Writer;

use Moose;
use Cwd;
use String::CamelCase qw(decamelize);
use Data::Dumper;
use File::Path;
use FindBin;
use Term::ANSIColor;
use Template;

use Umlet::Config::Manager;

extends 'Umlet::File::Writer';

use constant TRUE  => 1;

use constant FALSE => 0;

use constant DEFAULT_JAVASCRIPT_SINGLETON_CLASS_FILE => "$FindBin::Bin/../template/javascript_singleton_class_tmpl.tt";

use constant DEFAULT_JAVASCRIPT_CLASS_FILE => "$FindBin::Bin/../template/javascript_class_tmpl.tt";

## Singleton support
my $instance;

has 'singleton_class_template_file' => (
    is       => 'rw',
    isa      => 'Str',
    writer   => 'setSingletonClassTemplateFile',
    reader   => 'getSingletonClassTemplateFile',
    required => FALSE,
    default  => DEFAULT_JAVASCRIPT_SINGLETON_CLASS_FILE
    );

has 'class_template_file' => (
    is       => 'rw',
    isa      => 'Str',
    writer   => 'setClassTemplateFile',
    reader   => 'getClassTemplateFile',
    required => FALSE,
    default  => DEFAULT_JAVASCRIPT_CLASS_FILE
    );

sub getInstance {

    if (!defined($instance)){

        $instance = new Umlet::JavaScript::Class::File::Writer(@_);

        if (!defined($instance)){

            confess "Could not instantiate Umlet::JavaScript::Class::File::Writer";
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

sub _create_api {

    my $self = shift;
    my ($master_lookup) = @_;

    # $self->{_class_lookup} = $master_lookup;

    # print Dumper $master_lookup;die;

    my $outdir = $self->getOutdir();

    if ($self->getVerbose()){
        print "About to create the API in directory '$outdir'\n";
    }

    $self->{_logger}->info("About to create the JavaScript API in directory '$outdir'");

    foreach my $namespace (sort keys %{$master_lookup}){

        print "Processing JavaScript class '$namespace'\n";

        $self->{_logger}->info("Processing JavaScript class '$namespace'");        


        if ((exists $master_lookup->{$namespace}->{already_implemented}) && 
            ($master_lookup->{$namespace}->{already_implemented} ==  TRUE)){

            if ($self->getSkipGreenModules()){

                $self->{_logger}->info("Will skip creation of module '$namespace' since UXF indicates the module has already been implemented");
                
                next;
            }
        }

        $self->{_current_class_is_singleton} = TRUE;

        $self->{_current_namespace} = $namespace;

        $self->{_current_javascript_namespace} = $self->_derive_javascript_namespace();

        $self->{_current_class_lookup} = $master_lookup->{$namespace};

        # $self->{_logger}->fatal(Dumper $self->{_current_class_lookup});

        $self->_derive_class_details();

        $self->_derive_constants($master_lookup->{$namespace});

        $self->_derive_private_data_members($master_lookup->{$namespace});

        $self->_derive_dependencies_variables($master_lookup->{$namespace});

        # $self->_derive_dependencies_instantiations();

        $self->_derive_functions($master_lookup->{$namespace});

        $self->_derive_return_function_list($master_lookup->{$namespace});
  
        my $template_file = $self->getClassTemplateFile();

        if ($self->{_current_class_is_singleton}){

            $template_file = $self->getSingletonClassTemplateFile();
        }
        else {
            $template_file = $self->getSingletonClassTemplateFile();
        }

        $self->_write_file($template_file);
    }

    if ($self->getVerbose()){
        print "Have created the API in the directory '$outdir'\n";
    }

    $self->{_logger}->info("Have created the API in the directory '$outdir'");
}


sub _derive_javascript_namespace {

    my $self = shift;

    my $namespace = $self->{_current_namespace};

    if ($namespace =~ m|::|){

        my $original = $namespace;
        
        $namespace =~ s|::|\.|g;
        
        $self->{_logger}->info("Changed the namespace from '$original' to '$namespace'");
    }

    return $namespace;    
}


sub _derive_class_details {

    my $self = shift;

    $self->_derive_instance_variable_name();

    $self->_derive_namespace_declaration();
}


sub _derive_instance_variable_name {

    my $self = shift;

    my $namespace = $self->{_current_javascript_namespace};

    $namespace =~ s|::||g;

    $namespace =~ s|\.||g;
    
    $self->{_instance_variable_name} = lcfirst($namespace) . 'Instance';
}


sub _derive_namespace_declaration {

    my $self = shift;

    my @parts = split(/\./, $self->{_current_javascript_namespace});

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

sub _derive_private_data_members {

    my $self = shift;
    my ($class_lookup) = @_;

    if (( exists $class_lookup->{private_data_members_list}) && 
        ( defined $class_lookup->{private_data_members_list})){
        
        my $content = '';

        foreach my $record (@{$class_lookup->{private_data_members_list}}){

            my $name = $record->getName();

            $content .= '    var ' . $name . "\n";

        }

        $self->{_private_data_members_content} = $content;
    }
    else {
        $self->{_logger}->info("Looks like there are no private data members for class '$self->{_current_javascript_namespace}'");
    }
}


sub _derive_dependencies_variables {

    my $self = shift;


    if (( exists $self->{_current_class_lookup}->{depends_on_list}) && 
        ( defined $self->{_current_class_lookup}->{depends_on_list})){

        my $variable_name_list = [];
        
        my $dependency_namespace_list = [];

        my $lookup = {};

        my $list = [];

        foreach my $dependency (@{$self->{_current_class_lookup}->{depends_on_list}}){
            
            $dependency = $self->_derive_javascript_namespace($dependency);

            push(@{$dependency_namespace_list}, $dependency);

            $dependency =~ s|\.||g;

            my $variable_name = lcfirst($dependency);

            push(@{$list}, $variable_name);

            $lookup->{$dependency} = $variable_name;
        }

        my $dependencies_variables_content = '';

        foreach my $variable_name (@{$list}){
            $dependencies_variables_content .= "let $variable_name;\n";
        }

        $self->{_dependencies_variables_content} = $dependencies_variables_content;



        my $dependencies_instantiations_content = '';

        foreach my $dependency (@{$dependency_namespace_list}){

            my $variable_name = $lookup->{$dependency};
            
            $dependencies_instantiations_content .= "$variable_name = $dependency.getInstance();\n".
            "if (!defined($variable_name)){\n".
            "    throw new Error(\"Could not instantiate $dependency\");\n".
            "}\n\n";
        }


        $self->{_dependencies_instantiations_content} = $dependencies_instantiations_content;

    }
    else {
        $self->{_logger}->info("Looks like there are no dependencies for '$self->{_current_javascript_namespace}'");

    }
}


sub _derive_functions_backup {

    my $self = shift;


    if (( exists $self->{_current_class_lookup}->{depends_on_list}) && 
        ( defined $self->{_current_class_lookup}->{depends_on_list})){

        foreach my $dependency (@{$self->{_current_class_lookup}->{depends_on_list}}){
            
            $dependency = $self->_derive_javascript_namespace($dependency);

            $dependency =~ s|\.||g;

            my $variable_name = lcfirst($dependency);

            push(@{$self->{_dependencies_variables_list}}, $variable_name);

            $self->{_dependency_namespace_lookup}->{$dependency} = $variable_name;

        }
    }
    else {
        $self->{_logger}->info("Looks like there are no dependencies for '$self->{_current_javascript_namespace}'");

    }
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
        $self->{_logger}->info("Looks like there are no constants for class '$self->{_current_javascript_namespace}'");
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
        $self->{_logger}->info("Looks like there are no private methods/functions for class '$self->{_current_javascript_namespace}'");
    }
}
            
sub _derive_getters_and_setters {

    my $self = shift;
    my ($class_lookup) = @_;

    if (( exists $class_lookup->{private_data_members_list}) && 
        ( defined $class_lookup->{private_data_members_list})){
        
        my $content = '';

        foreach my $record (@{$class_lookup->{private_data_members_list}}){

            my $name = $record->getName();

            my $function_name = ucfirst(lc($name));

            $content .= '    const get' . $function_name . ' = function (){' . "\n";
            $content .= '        return ' . $name . ';' . "\n";
            $content .= '    };' . "\n\n";

            $content .= '    const set' . $function_name . ' = function (val){' . "\n";
            $content .= '        ' . $name . ' = val;' . "\n";
            $content .= '    };' . "\n\n";

        }

        $self->{_public_functions_content} = $content;
    }
    else {
        $self->{_logger}->info("Looks like there are no public methods/functions for class '$self->{_current_javascript_namespace}'");
    }
}

sub _derive_public_functions {

    my $self = shift;
    my ($class_lookup) = @_;

    $self->{_public_functions_content} = '';

    $self->_derive_getters_and_setters(@_);

    if (( exists $class_lookup->{public_methods_list}) && 
        ( defined $class_lookup->{public_methods_list})){
        
        my $content = '';

        foreach my $record (@{$class_lookup->{public_methods_list}}){

            $content .= 'const ' . $record->getName() . ' = function (){' . "\n".
            '};' . "\n\n";
        }

        $self->{_public_functions_content} .= $content;
    }
    else {
        $self->{_logger}->info("Looks like there are no public methods/functions for class '$self->{_current_javascript_namespace}'");
    }
}


sub _derive_return_function_list {

    my $self = shift;
    my ($class_lookup) = @_;

    if (( exists $class_lookup->{public_methods_list}) && 
        ( defined $class_lookup->{public_methods_list})){
        

        my $list = [];

        foreach my $record (@{$class_lookup->{public_methods_list}}){

            my $name = $record->getName();

            my $val = $name . " : " . $name;
            
            push(@{$list}, $val);
        }

        my $content = join(",\n", @{$list});

        $self->{_logger}->info("return_function_list_content '$content'");

        $self->{_return_function_list_content} = $content;
    }
    else {
        $self->{_logger}->info("Looks like there are no public methods/functions for class '$self->{_current_javascript_namespace}'");
    }
}

sub _write_file {

    my $self = shift;
    my ($template_file) = @_;


    my $outfile = $self->_get_outfile($self->{_current_namespace});


    my $tt = new Template({ABSOLUTE => 1});
    if (!defined($tt)){
        $self->{_logger}->logconfess("Could not instantiate TT");
    }


    my $lookup = {
        instance_variable_name              => $self->{_instance_variable_name},
        namespace_declaration_content       => $self->{_namespace_declaration_content},
        namespace                           => $self->{_current_javascript_namespace},
        constants_content                   => $self->{_constants_content},
        dependencies_variables_content      => $self->{_dependencies_variables_content},
        dependencies_instantiations_content => $self->{_dependencies_instantiations_content},
        private_funtions_content            => $self->{_private_functions_content},
        public_functions_content            => $self->{_public_functions_content},
        return_function_list_content        => $self->{_return_function_list_content},
        private_data_members_content        => $self->{_private_data_members_content}
    };

    $self->{_logger}->fatal(Dumper $lookup);

    $tt->process($template_file, $lookup, $outfile) || $self->{_logger}->logconfess("Encountered the following Template::process error:" . $tt->error());


    if ($self->getVerbose()){
        print "Wrote JavaScript class file '$outfile'\n";
    }

    $self->{_logger}->info("Wrote JavaScript class file '$outfile'");

    push(@{$self->{_module_file_list}}, $outfile);
}

sub _get_outfile {

    my $self = shift;
    my ($namespace) = @_;

    my $outdir = $self->getOutdir() . '/javascript/model/';

    my $outfile = $outdir . $namespace;

    $outfile =~ s|\.|/|g;

    my $dirname = File::Basename::dirname($outfile);

    if (!-e $dirname){

        mkpath($dirname) || $self->{_logger}->logconfess("Could not create directory '$dirname' : $!");
        
        $self->{_logger}->info("Created output directory '$dirname'");
    }


    $outfile .= '.js';

    return $outfile;
}


sub _print_summary {

    my $self = shift;
    
    if ($self->getVerbose()){

        print "\nCreated the following JavaScript files:\n";
        
        print join("\n", @{$self->{_module_file_list}}) . "\n";
    }
}


no Moose;
__PACKAGE__->meta->make_immutable;

__END__


=head1 NAME

 Umlet::JavaScript::Class::File::Writer
 

=head1 VERSION

 1.0

=head1 SYNOPSIS

 use Umlet::JavaScript::Class::File::Writer;
 my $manager = Umlet::JavaScript::Class::File::Writer::getInstance();
 $manager->commitCodeAndPush($comment);

=head1 AUTHOR

 Jaideep Sundaram

 Copyright Jaideep Sundaram

=head1 METHODS

=over 4

=cut