package Umlet::ClassDiagram::File::XML::Writer;

use Moose;

extends 'Umlet::File::XML::Writer';

use constant TRUE  => 1;

use constant FALSE => 0;

## Singleton support
my $instance;

my $this;

sub getInstance {

    if (!defined($instance)){

        $instance = new Umlet::ClassDiagram::File::XML::Writer(@_);

        if (!defined($instance)){

            confess "Could not instantiate Umlet::ClassDiagram::File::XML::Writer";
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

no Moose;
__PACKAGE__->meta->make_immutable;

__END__


=head1 NAME

 Umlet::ClassDiagram::File::XML::Writer
 

=head1 VERSION

 1.0

=head1 SYNOPSIS

 use Umlet::ClassDiagram::File::XML::Writer;
 my $writer = new Umlet::ClassDiagram::File::XML::Writer(outfile => $outfile);
 $writer->writeFile($class_lookup_list);

=head1 AUTHOR

 Jaideep Sundaram

 Copyright Jaideep Sundaram

=head1 METHODS

=over 4

=cut