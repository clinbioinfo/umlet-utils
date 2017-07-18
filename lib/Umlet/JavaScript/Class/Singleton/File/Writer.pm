package Umlet::JavaScript::Class::Singleton::File::Writer;

use Moose;
use FindBin;

use Umlet::Config::Manager;

extends 'Umlet::JavaScript::Class::File::Writer';

use constant TRUE  => 1;

use constant FALSE => 0;

use constant DEFAULT_JAVASCRIPT_SINGLETON_CLASS_FILE => "$FindBin::Bin/../template/javascript_singleton_class_tmpl.tt";

## Singleton support
my $instance;

has 'class_template_file' => (
    is       => 'rw',
    isa      => 'Str',
    writer   => 'setClassTemplateFile',
    reader   => 'getClassTemplateFile',
    required => FALSE,
    default  => DEFAULT_JAVASCRIPT_SINGLETON_CLASS_FILE
    );

sub getInstance {

    if (!defined($instance)){

        $instance = new Umlet::JavaScript::Class::Singleton::File::Writer(@_);

        if (!defined($instance)){

            confess "Could not instantiate Umlet::JavaScript::Class::Singleton::File::Writer";
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

sub _derive_contents {

    my $self = shift;

    $self->_derive_class_details();

    $self->_derive_constants($self->{_class_lookup});

    $self->_derive_dependencies_variables($self->{_class_lookup});

    $self->_derive_functions($self->{_class_lookup});
  
    $self->_derive_private_data_members($self->{_class_lookup});

    $self->_derive_return_function_list($self->{_class_lookup});

    $self->{_template_lookup} = {
        instance_variable_name              => $self->{_instance_variable_name},
        namespace_declaration_content       => $self->{_namespace_declaration_content},
        namespace                           => $self->{_javascript_namespace},
        constants_content                   => $self->{_constants_content},
        dependencies_variables_content      => $self->{_dependencies_variables_content},
        dependencies_instantiations_content => $self->{_dependencies_instantiations_content},
        private_funtions_content            => $self->{_private_functions_content},
        public_functions_content            => $self->{_public_functions_content},
        return_function_list_content        => $self->{_return_function_list_content},
        private_data_members_content        => $self->{_private_data_members_content}
    };

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
        $self->{_logger}->info("Looks like there are no private data members for class '$self->{_javascript_namespace}'");
    }
}

sub _derive_dependencies_variables {

    my $self = shift;


    if (( exists $self->{_class_lookup}->{depends_on_list}) && 
        ( defined $self->{_class_lookup}->{depends_on_list})){

        my $variable_name_list = [];
        
        my $dependency_namespace_list = [];

        my $lookup = {};

        my $list = [];

        foreach my $dependency (@{$self->{_class_lookup}->{depends_on_list}}){
            
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
        $self->{_logger}->info("Looks like there are no dependencies for '$self->{_javascript_namespace}'");

    }
}


sub _derive_functions_backup {

    my $self = shift;


    if (( exists $self->{_class_lookup}->{depends_on_list}) && 
        ( defined $self->{_class_lookup}->{depends_on_list})){

        foreach my $dependency (@{$self->{_class_lookup}->{depends_on_list}}){
            
            $dependency = $self->_derive_javascript_namespace($dependency);

            $dependency =~ s|\.||g;

            my $variable_name = lcfirst($dependency);

            push(@{$self->{_dependencies_variables_list}}, $variable_name);

            $self->{_dependency_namespace_lookup}->{$dependency} = $variable_name;

        }
    }
    else {
        $self->{_logger}->info("Looks like there are no dependencies for '$self->{_javascript_namespace}'");

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

sub _derive_getters_and_setters {

    my $self = shift;
    my ($class_lookup) = @_;

    if (( exists $class_lookup->{private_data_members_list}) && 
        ( defined $class_lookup->{private_data_members_list})){
        
        my $content = '';

        foreach my $record (@{$class_lookup->{private_data_members_list}}){

            my $name = $record->getName();

            my $function_name = ucfirst(lc($name));

            if ($function_name =~ m|_|){

                $function_name = $self->_get_camel_case_function_name($function_name);
            }

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
        $self->{_logger}->info("Looks like there are no public methods/functions for class '$self->{_javascript_namespace}'");
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
        $self->{_logger}->info("Looks like there are no public methods/functions for class '$self->{_javascript_namespace}'");
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
        $self->{_logger}->info("Looks like there are no public methods/functions for class '$self->{_javascript_namespace}'");
    }
}

no Moose;
__PACKAGE__->meta->make_immutable;

__END__


=head1 NAME

 Umlet::JavaScript::Class::Singleton::File::Writer
 

=head1 VERSION

 1.0

=head1 SYNOPSIS

 use Umlet::JavaScript::Class::Singleton::File::Writer;
 my $manager = Umlet::JavaScript::Class::Singleton::File::Writer::getInstance();
 $manager->commitCodeAndPush($comment);

=head1 AUTHOR

 Jaideep Sundaram

 Copyright Jaideep Sundaram

=head1 METHODS

=over 4

=cut