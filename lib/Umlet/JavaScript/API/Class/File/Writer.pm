package Umlet::JavaScript::API::Class::File::Writer;

use Moose;

use Umlet::Config::Manager;
use Umlet::JavaScript::Class::Regular::File::Writer;
use Umlet::JavaScript::Class::Singleton::File::Writer;

extends 'Umlet::File::Writer';

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

sub _create_api {

    my $self = shift;
    my ($master_lookup) = @_;

    my $outdir = $self->getOutdir();

    if ($self->getVerbose()){
        print "About to create the API in directory '$outdir'\n";
    }

    $self->{_logger}->info("About to create the JavaScript API in directory '$outdir'");

    foreach my $namespace (sort keys %{$master_lookup}){

        print "Processing JavaScript class '$namespace'\n";

        $self->{_logger}->info("Processing JavaScript class '$namespace'");        


        if ((exists $master_lookup->{$namespace}->{already_implemented}) && 
            ($master_lookup->{$namespace}->{already_implemented} ==  TRUE)){

            if ($self->getSkipGreenModules()){

                $self->{_logger}->info("Will skip creation of module '$namespace' since UXF indicates the module has already been implemented");
                
                next;
            }
        }

        $self->{_current_namespace} = $namespace;

        $self->{_current_javascript_namespace} = $self->_derive_javascript_namespace();

        if ((exists $master_lookup->{$namespace}->{singleton}) && 
            ($master_lookup->{$namespace}->{singleton} == TRUE)){
    
            my $writer = new Umlet::JavaScript::Class::Singleton::File::Writer(
                class_lookup         => $master_lookup->{$namespace},
                namespace            => $self->{_current_namespace},
                javascript_namespace => $self->{_current_javascript_namespace},
                outdir               => $outdir
                );

            if (!defined($writer)){
                $self->{_logger}->logconfess("Could not instantiate Umlet::JavaScript::Class::Singleton::File::Writer");
            }

            $writer->writeFile();
        }
        else {

            my $writer = new Umlet::JavaScript::Class::Regular::File::Writer(
                class_lookup         => $master_lookup->{$namespace},
                namespace            => $self->{_current_namespace},
                javascript_namespace => $self->{_current_javascript_namespace},
                outdir               => $outdir
                );

            if (!defined($writer)){
                $self->{_logger}->logconfess("Could not instantiate Umlet::JavaScript::Class::Regular::File::Writer");
            }

            $writer->writeFile();
        }
    }

    if ($self->getVerbose()){
        print "Have created the API in the directory '$outdir'\n";
    }

    $self->{_logger}->info("Have created the API in the directory '$outdir'");
}


sub _derive_javascript_namespace {

    my $self = shift;

    my $namespace = $self->{_current_namespace};

    if ($namespace =~ m|::|){

        my $original = $namespace;
        
        $namespace =~ s|::|\.|g;
        
        $self->{_logger}->info("Changed the namespace from '$original' to '$namespace'");
    }

    return $namespace;    
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