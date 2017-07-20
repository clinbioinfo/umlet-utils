package Umlet::FlowJo::Workspace::File::XML::Converter;

use Moose;
use Data::Dumper;

use Umlet::Config::Manager;
use Umlet::FlowJo::Workspace::File::XML::Parser;
use Umlet::Datatype::Helper;
use Umlet::ClassDiagram::File::XML::Writer;

extends 'Umlet::Converter';

use constant TRUE  => 1;

use constant FALSE => 0;


## Singleton support
my $instance;


sub getInstance {

    if (!defined($instance)){

        $instance = new Umlet::FlowJo::Workspace::File::XML::Converter(@_);

        if (!defined($instance)){

            confess "Could not instantiate Umlet::FlowJo::Workspace::File::XML::Converter";
        }
    }
    return $instance;
}

sub BUILD {

    my $self = shift;

    $self->_initLogger(@_);

    $self->_initConfigManager(@_);

    $self->_initAPI(@_);

    $self->{_logger}->info("Instantiated ". __PACKAGE__);
}

sub _initAPI {
    
    my $self = shift;

    $self->_initParser(@_);

    $self->_initDataHelper(@_);

    $self->_initFileWriter(@_);    
}

sub _initParser {

    my $self = shift;

    ## Module for parsing a Class Digram in UMLet where the classes represent Perl modules

    my $parser = Umlet::FlowJo::Workspace::File::XML::Parser::getInstance(@_);
    if (!defined($parser)){
        $self->{_logger}->logconfess("Could not instantiate Umlet::FlowJo::Workspace::File::XML::Parser");
    }

    $self->{_parser} = $parser;
}

sub _initDataHelper {

    my $self = shift;

    my $helper = Umlet::Datatype::Helper::getInstance(@_);
    if (!defined($helper)){
        $self->{_logger}->logconfess("Could not instantiate Umlet::Datatype::Helper");
    }

    $self->{_datatype_helper} = $helper;
}

sub _initFileWriter {

    my $self = shift;

    my $writer = Umlet::ClassDiagram::File::XML::Writer::getInstance(@_);
    if (!defined($writer)){
        $self->{_logger}->logconfess("Could not instantiate Umlet::ClassDiagram::File::XML::Writer");
    }

    $self->{_file_writer} = $writer;
}

sub runConversion {

    my $self = shift;

    my $attribute_lookup_lists = $self->{_parser}->getAttributeLookupLists();
    if (!defined($attribute_lookup_lists)){
        $self->{_logger}->logconfess("attribute_lookup_lists was not defined");
    }

    my $outfile = $self->getOutdir() . '/' . File::Basename::basename($0). '.txt';

    open (OUTFILE, ">$outfile") || $self->{_logger}->logconfess("Could not open '$outfile' in write mode : $!");

    print "Writing report file '$outfile'\n";    
    
    my $class_lookup_list = [];

    foreach my $lineage (sort keys %{$attribute_lookup_lists}){

        my $class_lookup = {};

        my $class_name = $lineage;

        $class_name =~ s|\-\-\>|::|g;

        $class_lookup->{'package_name'} = $class_name;

        print OUTFILE "\n$lineage\n";

        foreach my $attribute_name (sort keys %{$attribute_lookup_lists->{$lineage}}){

            my $list = $attribute_lookup_lists->{$lineage}->{$attribute_name};

            my $datatype = $self->{_datatype_helper}->getDatatype($list);

            if (!defined($datatype)){    
                $self->{_logger}->logconfess("datatype was not defined for lineage '$lineage' attribute name '$attribute_name' with values: " . Dumper $list);
            }

            $self->{_logger}->info("lineage '$lineage' attribute '$attribute_name' datatype '$datatype'");
 
            print OUTFILE "$attribute_name:$datatype\n";

            # $attribute_name =~ s|\-|_|g;

            # $attribute_name=~ s|:|_|g;

            push(@{$class_lookup->{'has_list'}}, "$attribute_name:$datatype;required=false");
        }

        push(@{$class_lookup_list}, $class_lookup);
    }

    close OUTFILE;

    $self->{_logger}->info("Wrote records to '$outfile'");
    
    $self->{_file_writer}->writeFile($class_lookup_list);

}


no Moose;
__PACKAGE__->meta->make_immutable;

__END__


=head1 NAME

 Umlet::FlowJo::Workspace::File::XML::Converter
 

=head1 VERSION

 1.0

=head1 SYNOPSIS

 use Umlet::FlowJo::Workspace::File::XML::Converter;
 my $converter = Umlet::FlowJo::Workspace::File::XML::Converter::getInstance();
 $converter->runConversion();

=head1 AUTHOR

 Jaideep Sundaram

 Copyright Jaideep Sundaram

=head1 METHODS

=over 4

=cut