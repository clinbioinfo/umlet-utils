package Umlet::FlowJo::Workspace::File::XML::Parser;

use Moose;
use Data::Dumper;
use XML::Twig;
use Term::ANSIColor;

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

    printBrightBlue("About to parse input file '$infile'\n");

    $twig->parsefile($infile);

    $self->{_is_parsed} = TRUE;

    $self->{_logger}->info("Finished parsing the input file '$infile'");    

    printBrightBlue("Finished parsing input file '$infile'\n");    
}

sub workspaceHandler {

    my $self = $this;
    my ($twig, $elem) = @_;

    my $element_name = 'root';

    push(@{$self->{_stack}}, $element_name);

    $self->_process_element_attributes($element_name, $elem);

    $self->_process_children_elements($element_name, $elem);
}

sub _process_children_elements {

    my $self = shift;
    my ($parent_name, $elem) = @_;

    my $element_name = $elem->name();

    if (!defined($element_name)){
        $self->{_logger}->logconfess("element_name was not defined");
    }

    if ($elem->children_count() > 0){

        $self->{_logger}->info("Going to process the children of '$element_name' whose parent's name is '$parent_name'");

        push(@{$self->{_stack}}, $element_name);

        my $child_ctr = 0;

        foreach my $child_elem ($elem->children()){

            $child_ctr++;

            my $child_element_name = $child_elem->name();

            if (!defined($child_element_name)){
                $self->{_logger}->logconfess("child_element_name was not defined");
            }

            $self->_process_element_attributes($element_name, $child_elem);

            $self->_process_children_elements($element_name, $child_elem);
        }

        pop(@{$self->{_stack}});
    }
    else {
        $self->{_logger}->info("Element '$element_name' (whose parent's name is '$parent_name') does not have any children");
    }
}

sub _process_element_attributes {

    my $self = shift;
    my ($parent_name, $elem) = @_;

    my $element_name = $elem->name();

    if (!defined($element_name)){
        $self->{_logger}->logconfess("element_name was not defined");
    }

    if (exists $elem->{'att'}){

        foreach my $attribute_name (sort keys %{$elem->{'att'}}){

            my $attribute_value = 'N/A';

            if (exists $elem->{'att'}->{$attribute_name}){

                $attribute_value = $elem->{'att'}->{$attribute_name};
            }

            my $lineage = join('-->', @{$self->{_stack}}) . '-->' . $element_name;

            $self->{_logger}->info("lineage '$lineage'");

            push(@{$self->{_attribute_lookup_lists}->{$lineage2}->{$attribute_name}}, $attribute_value);   
        }
    }
    else {
        $self->{_logger}->info("'$element_name' does not have any attributes");
    }
}

sub getAttributeLookupLists {

    my $self = shift;

    if (! $self->{_is_parsed}){
        $self->_parse_file(@_);
    }    
    
    return $self->{_attribute_lookup_lists};
}

sub printGreen {

    my ($msg) = @_;
    print color 'green';
    print $msg;
    print color 'reset';
}

sub printBrightBlue {

    my ($msg) = @_;
    print color 'bright_blue';
    print $msg;
    print color 'reset';
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