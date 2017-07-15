package Umlet::Method::Record;

use Moose;

use constant TRUE  => 1;

use constant FALSE => 0;

use constant DEFAULT_IS_PRIVATE => TRUE;

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

has 'return_data_type' => (
    is       => 'rw',
    isa      => 'Str',
    writer   => 'setReturnDataType',
    reader   => 'getReturnDataType',
    required => FALSE
    );

has 'is_private' => (
    is       => 'rw',
    isa      => 'Bool',
    writer   => 'setIsPrivate',
    reader   => 'getIsPrivate',
    required => FALSE,
    default  => DEFAULT_IS_PRIVATE
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

 Umlet::Method::Record
 Module for encapsulating representation of a method

=head1 VERSION

 1.0

=head1 SYNOPSIS

 use Umlet::Method::Record;
 my $record = new Umlet::Method::Record(
     name => 'getCheese, 
     return_data_type => 'string', 
    );
 

=head1 AUTHOR

 Jaideep Sundaram

 Copyright Jaideep Sundaram

=head1 METHODS

=over 4

=cut