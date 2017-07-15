package Umlet::Constant::Record;

use Moose;

use constant TRUE  => 1;

use constant FALSE => 0;


has 'id' => (
    is       => 'rw',
    isa      => 'Str',
    writer   => 'setId',
    reader   => 'getId',
    required => FALSE
    );

has 'name' => (
    is       => 'rw',
    isa      => 'Str',
    writer   => 'setName',
    reader   => 'getName',
    required => FALSE
    );

has 'value' => (
    is       => 'rw',
    isa      => 'Str',
    writer   => 'setValue',
    reader   => 'getValue',
    required => FALSE
    );


sub BUILD {

    my $self = shift;

    $self->_initLogger(@_);

}

sub _initLogger {

    my $self = shift;

    my $logger = Log::Log4perl->get_logger(__PACKAGE__);
    if (!defined($logger)){
        confess "logger was not defined";
    }

    $self->{_logger} = $logger;
}



no Moose;
__PACKAGE__->meta->make_immutable;


__END__


=head1 NAME

 Umlet::Constant::Record
 Module for encapsulating representation of a constant

=head1 VERSION

 1.0

=head1 SYNOPSIS

 use Umlet::Constant::Record;
 my $record = new Umlet::Constant::Record(
     name  => 'MAX_COUNT, 
     value => 3, 
    );
 

=head1 AUTHOR

 Jaideep Sundaram

 Copyright Jaideep Sundaram

=head1 METHODS

=over 4

=cut