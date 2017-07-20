package Umlet::ClassDiagram::JavaScript::API::Converter;

## Converts Umlet Class Diagram into set of JavaScript class files.

use Moose;

use Umlet::Config::Manager;
use Umlet::JavaScript::ClassDiagram::File::XML::Parser;
use Umlet::JavaScript::API::Class::File::Writer;

extends 'Umlet::Converter';


## Singleton support
my $instance;

sub getInstance {

    if (!defined($instance)){

        $instance = new Umlet::ClassDiagram::JavaScript::API::Converter(@_);

        if (!defined($instance)){

            confess "Could not instantiate Umlet::ClassDiagram::JavaScript::API::Converter";
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

sub _initUmletFileParser {

    my $self = shift;

    my $parser = Umlet::JavaScript::ClassDiagram::File::XML::Parser::getInstance(@_);
    if (!defined($parser)){
        $self->{_logger}->logconfess("Could not instantiate Umlet::JavaScript::ClassDiagram::File::XML::Parser");
    }

    $self->{_parser} = $parser;
}

sub _initAPIWriter {

    my $self = shift;

    my $writer = new Umlet::JavaScript::API::Class::File::Writer(@_);
    if (!defined($writer)){
        $self->{_logger}->logconfess("Could not instantiate Umlet::JavaScript::API::Class::File::Writer");
    }

    $self->{_writer} = $writer;
}

sub runConversion {

    my $self = shift;
    
    my $module_count = $self->{_parser}->getModuleCount();
    if (!defined($module_count)){
        $self->{_logger}->logconfess("module_count was not defined");
    }

    if ($module_count > 0){

        my $module_lookup = $self->{_parser}->getModuleLookup();
        if (!defined($module_lookup)){
            $self->{_logger}->logconfess("module_lookup was not defined");
        }

        $self->{_writer}->createAPI($module_lookup);

        if ($self->getVerbose()){

            print "Conversion completed.\n";

            print "See output files in directory '$self->getOutdir()'\n";
        }
    }
    else {
        printBoldRed("There were no modules to process");
        exit(1);
    }
}


no Moose;
__PACKAGE__->meta->make_immutable;

__END__


=head1 NAME

 Umlet::ClassDiagram::JavaScript::API::Converter
 

=head1 VERSION

 1.0

=head1 SYNOPSIS

 use Umlet::ClassDiagram::JavaScript::API::Converter;
 my $converter = Umlet::ClassDiagram::JavaScript::API::Converter::getInstance();
 $converter->runConversion();

=head1 AUTHOR

 Jaideep Sundaram

 Copyright Jaideep Sundaram

=head1 METHODS

=over 4

=cut
