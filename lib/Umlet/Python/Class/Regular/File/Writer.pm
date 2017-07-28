package Umlet::Python::Class::Regular::File::Writer;

use Moose;
use FindBin;

use Umlet::Config::Manager;

extends 'Umlet::Python::Class::File::Writer';

use constant TRUE  => 1;

use constant FALSE => 0;

use constant DEFAULT_CLASS_FILE => "$FindBin::Bin/../template/python_class_file_tmpl.tt";

## Singleton support
my $instance;

has 'class_template_file' => (
    is       => 'rw',
    isa      => 'Str',
    writer   => 'setClassTemplateFile',
    reader   => 'getClassTemplateFile',
    required => FALSE,
    default  => DEFAULT_CLASS_FILE
    );

sub getInstance {

    if (!defined($instance)){

        $instance = new Umlet::Python::Class::Regular::File::Writer(@_);

        if (!defined($instance)){

            confess "Could not instantiate Umlet::Python::Class::Regular::File::Writer";
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

    $self->_derive_private_data_members($self->{_class_lookup});

    $self->_derive_functions($self->{_class_lookup});

    $self->_derive_getters_and_setters($self->{_class_lookup});   

    $self->{_template_lookup} = {
        namespace                           => $self->{_language_namespace},
        namespace_declaration_content       => $self->{_namespace_declaration_content},
        private_data_members_content        => $self->{_private_data_members_content},
        constants_content                   => $self->{_constants_content},
        getter_functions_content            => $self->{_getter_functions_content},
        setter_functions_content            => $self->{_setter_functions_content},
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

            $content .= '    this.' . $name . " = null;\n";
        }

        $self->{_private_data_members_content} = $content;
    }
    else {
        $self->{_logger}->info("Looks like there are no private data members for class '$self->{_language_namespace}'");
    }
}

sub _derive_functions {

    my $self = shift;
    my ($class_lookup) = @_;

    $self->{_logger}->fatal("NOT YET IMPLEMENTED");
}

sub _derive_getters_and_setters {

    my $self = shift;
    my ($class_lookup) = @_;

    if (( exists $class_lookup->{private_data_members_list}) && 
        ( defined $class_lookup->{private_data_members_list})){
        
        my $setter_template_file = $self->getSetterTemplateFile();

        my $getter_template_file = $self->getGetterTemplateFile();

        foreach my $record (@{$class_lookup->{private_data_members_list}}){

            my $name = $record->getName();

            my $function_name = ucfirst(lc($name));

            if ($function_name =~ m|_|){

                $function_name = $self->_get_camel_case_function_name($function_name);
            }

            my $lookup = {
                namespace      => $self->{_language_namespace},
                variable_name  => $name,
                attribute_name => $name,
                method_name    => $function_name
            };

            my $getter_content = $self->_generate_content_from_template($getter_template_file, $lookup);

            $self->{_getter_functions_content} .= $getter_content . "\n";

            my $setter_content = $self->_generate_content_from_template($setter_template_file, $lookup);

            $self->{_setter_functions_content} .= $setter_content . "\n";
        }
    }
    else {
        $self->{_logger}->info("Looks like there are no private data members for class '$self->{_language_namespace}' so will not attempt to derive setter and getter functions");
    }
}

no Moose;
__PACKAGE__->meta->make_immutable;

__END__


=head1 NAME

 Umlet::Python::Class::Regular::File::Writer
 

=head1 VERSION

 1.0

=head1 SYNOPSIS

 use Umlet::Python::Class::Regular::File::Writer;
 my $writer = new Umlet::Python::Class::Regular::File::Writer();
 $writer->writeFile();

=head1 AUTHOR

 Jaideep Sundaram

 Copyright Jaideep Sundaram

=head1 METHODS

=over 4

=cut