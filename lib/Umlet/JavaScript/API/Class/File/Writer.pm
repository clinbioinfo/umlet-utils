package Umlet::JavaScript::API::Class::File::Writer;

use Moose;

use Umlet::Config::Manager;
use Umlet::JavaScript::Class::Regular::File::Writer;
use Umlet::JavaScript::Class::Singleton::File::Writer;

extends 'Umlet::API::Class::File::Writer';

use constant TRUE  => 1;

use constant FALSE => 0;

## Singleton support
my $instance;

sub getInstance {

    if (!defined($instance)){

        $instance = new Umlet::JavaScript::API::Class::File::Writer(@_);

        if (!defined($instance)){

            confess "Could not instantiate Umlet::JavaScript::API::Class::File::Writer";
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
    
    my $writer = new Umlet::JavaScript::Class::Singleton::File::Writer(
        class_lookup         => $class_lookup,
        namespace            => $current_namespace,
        javascript_namespace => $language_namespace,
        outdir               => $outdir
        );

    if (!defined($writer)){
        $self->{_logger}->logconfess("Could not instantiate Umlet::JavaScript::Class::Singleton::File::Writer");
    }

    return $writer;
}

sub _initClassRegularFileWriter {

    my $self = shift;
    my ($class_lookup, $current_namespace, $language_namespace, $outdir) = @_;

    my $writer = new Umlet::JavaScript::Class::Regular::File::Writer(
        class_lookup         => $class_lookup,
        namespace            => $current_namespace,
        javascript_namespace => $language_namespace,
        outdir               => $outdir
        );

    if (!defined($writer)){
        $self->{_logger}->logconfess("Could not instantiate Umlet::JavaScript::Class::Regular::File::Writer");
    }

    return $writer;
}

no Moose;
__PACKAGE__->meta->make_immutable;

__END__


=head1 NAME

 Umlet::JavaScript::API::Class::File::Writer
 

=head1 VERSION

 1.0

=head1 SYNOPSIS

 use Umlet::JavaScript::API::Class::File::Writer;
 my $manager = Umlet::JavaScript::API::Class::File::Writer::getInstance();
 $manager->commitCodeAndPush($comment);

=head1 AUTHOR

 Jaideep Sundaram

 Copyright Jaideep Sundaram

=head1 METHODS

=over 4

=cut