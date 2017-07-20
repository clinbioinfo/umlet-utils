package Umlet::Datatype::Helper;

use Moose;

use Umlet::Config::Manager;

use constant TRUE  => 1;

use constant FALSE => 0;


## Singleton support
my $instance;


sub getInstance {

    if (!defined($instance)){

        $instance = new Umlet::Datatype::Helper(@_);

        if (!defined($instance)){

            confess "Could not instantiate Umlet::Datatype::Helper";
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

sub _initLogger {

    my $self = shift;

    my $logger = Log::Log4perl->get_logger(__PACKAGE__);

    if (!defined($logger)){
        confess "logger was not defined";
    }

    $self->{_logger} = $logger;
}

sub _initConfigManager {

    my $self = shift;

    my $manager = Umlet::Config::Manager::getInstance(@_);
    if (!defined($manager)){
        $self->{_logger}->logconfess("Could not instantiate Umlet::Config::Manager");
    }

    $self->{_config_manager} = $manager;
}

sub getDatatype {

    my $self = shift;
    my ($list) = @_;

    my $unique_lookup = {};
    my $datatype;

    my $ctr = 0;
    my $unique_ctr  = 0;
    my $int_ctr     = 0;
    my $float_ctr   = 0;
    my $bool_ctr    = 0;
    my $string_ctr  = 0;

    foreach my $val (@{$list}){

        $ctr++;

        if (! exists $unique_lookup->{$val}){
            
            $unique_ctr++;
            
            $unique_lookup->{$val}++;
            
            if ($val =~ m|^\d+$|){
                $int_ctr++;
            }
            elsif ($val =~ m|^\d+\.\d+$|){
                $float_ctr++;
            }
            elsif (($val =~ m|^t$|i) || ($val =~ m|^f$|i) || ($val =~ m|^true$|i)|| ($val =~ m|^false$|i)){
                $bool_ctr++;
            }
            else {
                $string_ctr++;
            }
        }
    }

    if ($unique_ctr == $int_ctr){
        $datatype =  'int';
    }
    elsif ($unique_ctr == $float_ctr){
        $datatype =  'float';
    }
    elsif ($unique_ctr == $string_ctr){
        $datatype =  'string';
    }
    elsif ($unique_ctr == $bool_ctr){
        $datatype =  'bool';
    }
    else {
        $datatype =  'string';   
    }

    $self->{_logger}->info("Processed '$ctr' values, '$unique_ctr' unique values and determined the datatype to be '$datatype'");

    return $datatype;
}


no Moose;
__PACKAGE__->meta->make_immutable;

__END__


=head1 NAME

 Umlet::Datatype::Helper
 

=head1 VERSION

 1.0

=head1 SYNOPSIS

 use Umlet::Datatype::Helper;
 my $converter = Umlet::Datatype::Helper::getInstance();
 $converter->runConversion();

=head1 AUTHOR

 Jaideep Sundaram

 Copyright Jaideep Sundaram

=head1 METHODS

=over 4

=cut
