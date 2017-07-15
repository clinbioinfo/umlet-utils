package Umlet::ClassDiagram::Perl::API::Converter;

use Moose;

use Umlet::Config::Manager;
use Umlet::Perl::ClassDiagram::File::XML::Parser;
use Umlet::Perl::Module::File::Writer;

extends 'Umlet::Converter';

use constant TRUE  => 1;

use constant FALSE => 0;


## Singleton support
my $instance;


sub getInstance {

    if (!defined($instance)){

        $instance = new Umlet::ClassDiagram::Perl::API::Converter(@_);

        if (!defined($instance)){

            confess "Could not instantiate Umlet::ClassDiagram::Perl::API::Converter";
        }
    }
    return $instance;
}

sub BUILD {

    my $self = shift;

    $self->_initLogger(@_);

    $self->_initConfigManager(@_);

    $self->_initUmletFileParser(@_);

    $self->_initAPIWriter(@_);

    $self->{_logger}->info("Instantiated ". __PACKAGE__);
}


sub _initUmletFileParser {

    my $self = shift;

    ## Module for parsing a Class Digram in UMLet where the classes represent Perl modules

    my $parser = Umlet::Perl::ClassDiagram::File::XML::Parser::getInstance(@_);
    if (!defined($parser)){
        $self->{_logger}->logconfess("Could not instantiate Umlet::Perl::ClassDiagram::File::XML::Parser");
    }

    $self->{_parser} = $parser;
}

sub _initAPIWriter {

    my $self = shift;

    my $writer = new Umlet::Perl::Module::File::Writer(@_);
    if (!defined($writer)){
        $self->{_logger}->logconfess("Could not instantiate Umlet::Perl::Module::File::Writer");
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

        # &parseUxfFile($infile);

        $self->{_writer}->createAPI($module_lookup);

        # &createAPI();

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

 Umlet::ClassDiagram::Perl::API::Converter
 

=head1 VERSION

 1.0

=head1 SYNOPSIS

 use Umlet::ClassDiagram::Perl::API::Converter;
 my $converter = Umlet::ClassDiagram::Perl::API::Converter::getInstance();
 $converter->runConversion();

=head1 AUTHOR

 Jaideep Sundaram

 Copyright Jaideep Sundaram

=head1 METHODS

=over 4

=cut
