package Umlet::Python::API::Class::File::Writer;

use Moose;

use Umlet::Config::Manager;
use Umlet::Python::Class::Regular::File::Writer;
use Umlet::Python::Class::Singleton::File::Writer;

extends 'Umlet::API::Class::File::Writer';

use constant TRUE  => 1;

use constant FALSE => 0;

## Singleton support
my $instance;

sub getInstance {

    if (!defined($instance)){

        $instance = new Umlet::Python::API::Class::File::Writer(@_);

        if (!defined($instance)){

            confess "Could not instantiate Umlet::Python::API::Class::File::Writer";
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

sub _initClassSingletonFileWriter {

    my $self = shift;
    my ($class_lookup, $current_namespace, $language_namespace, $outdir) = @_;

   
    my $writer = new Umlet::Python::Class::Singleton::File::Writer(
        class_lookup         => $class_lookup,
        namespace            => $current_namespace,
        python_namespace     => $language_namespace,
        outdir               => $outdir
        );

    if (!defined($writer)){
        $self->{_logger}->logconfess("Could not instantiate Umlet::Python::Class::Singleton::File::Writer");
    }

    return $writer;
}


sub _initClassRegularFileWriter {

    my $self = shift;
    my ($class_lookup, $current_namespace, $language_namespace, $outdir) = @_;


    my $writer = new Umlet::Python::Class::Regular::File::Writer(
        class_lookup         => $class_lookup,
        namespace            => $current_namespace,
        python_namespace     => $language_namespace,
        outdir               => $outdir
        );

    if (!defined($writer)){
        $self->{_logger}->logconfess("Could not instantiate Umlet::Python::Class::Regular::File::Writer");
    }

    return $writer;
}


no Moose;
__PACKAGE__->meta->make_immutable;

__END__


=head1 NAME

 Umlet::Python::API::Class::File::Writer
 

=head1 VERSION

 1.0

=head1 SYNOPSIS

 use Umlet::Python::API::Class::File::Writer;
 my $manager = Umlet::Python::API::Class::File::Writer::getInstance();
 $manager->commitCodeAndPush($comment);

=head1 AUTHOR

 Jaideep Sundaram

 Copyright Jaideep Sundaram

=head1 METHODS

=over 4

=cut