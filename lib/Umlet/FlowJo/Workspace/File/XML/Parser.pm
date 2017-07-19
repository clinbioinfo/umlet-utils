package Umlet::FlowJo::Workspace::File::XML::Parser;

use Moose;
use XML::Twig;

extends 'Umlet::File::XML::Parser';

use constant TRUE  => 1;
use constant FALSE => 0;

## Singleton support
my $instance;

my $this;

sub getInstance {

    if (!defined($instance)){

        $instance = new Umlet::FlowJo::Workspace::File::XML::Parser(@_);

        if (!defined($instance)){

            confess "Could not instantiate Umlet::FlowJo::Workspace::File::XML::Parser";
        }
    }
    return $instance;
}

sub BUILD {

    my $self = shift;

    $self->_initLogger(@_);

    $self->_initConfigManager(@_);

    $self->{_is_parsed} = FALSE;

    $self->{_logger}->info("Instantiated ". __PACKAGE__);
}

sub _parse_file {

    my $self = shift;
    my ($infile) = @_;

    if (!defined($infile)){

        $infile = $self->getInfile();

        if (!defined($infile)){
            $self->{_logger}->logconfess("infile was not defined");
        }
    }
    else {
        $self->setInfile($infile);
    }

    $this = $self;

        my $twig = new XML::Twig(
        twig_handlers =>  { 
            Workspace => \&workspaceHandler 
        }
    );

    if (!defined($twig)){
        $self->{_logger}->logconfess("Could not instantiate XML::Twig");
    }

    if ($self->getVerbose()){
        print "About to parse input file '$infile'\n";
    }

    $self->{_logger}->info("About to parse input file '$infile'");

    $twig->parsefile($infile);

    $self->{_is_parsed} = TRUE;

    $self->{_logger}->info("Finished parsing the input file '$infile'");    
}

sub workspaceHandler {

    my $self = $this;
    my ($twig, $elem) = @_;

    my $parent_name = 'root';

    my $element_name = $elem->name();

    if (!defined($element_name)){
        $self->{_logger}->logconfess("element_name was not defined");
    }

    $self->_process_element_attributes($parent_name, $element_name, $elem);

    $self->_process_children_elements($parent_name, $elem);
}

sub _process_children_elements {

    my $self = shift;
    my ($parent_name, $elem) = @_;


    if ($elem->children_count() > 0){
     
        foreach my $child_elem ($elem->children()){

            my $element_name = $child_elem->name();

            print "Processing '$element_name', child of '$parent_name'\n";

            if (!defined($element_name)){
                $self->{_logger}->logconfess("element_name was not defined");
            }

            $self->_process_element_attributes($parent_name, $element_name, $child_elem);

            $self->_process_children_elements($parent_name, $child_elem);
        }
    }
}

sub _process_element_attributes {

    my $self = shift;
    my ($parent_name, $element_name, $elem) = @_;

    my @attribute_name_list = $elem->atts;

    my $lineage = $parent_name . '::' . $element_name;

    foreach my $attribute_name (@attribute_name_list){

        my $attribute_value = $elem->{att}->{$attribute_name};

        push(@{$self->{_attribute_lookup_lists}->{$lineage}->{$attribute_name}}, $attribute_value);   
    }
}

sub getAttributeLookupLists {

    my $self = shift;

    if (! $self->{_is_parsed}){
        $self->_parse_file(@_);
    }    
    
    return $self->{_attribute_lookup_lists};
}

no Moose;
__PACKAGE__->meta->make_immutable;

__END__


=head1 NAME

 Umlet::FlowJo::Workspace::File::XML::Parser
 

=head1 VERSION

 1.0

=head1 SYNOPSIS

 use Umlet::FlowJo::Workspace::File::XML::Parser;
 my $parser = new Umlet::FlowJo::Workspace::File::XML::Parser(infile => $infile);
 my $class_record_list = $parser->getClassList();

=head1 AUTHOR

 Jaideep Sundaram

 Copyright Jaideep Sundaram

=head1 METHODS

=over 4

=cut
