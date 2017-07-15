package Umlet::Python::Module::File::Parser;

use Moose;
use Cwd;
use Term::ANSIColor;
use File::Slurp;

use Umlet::Config::Manager;

use constant TRUE  => 1;

use constant FALSE => 0;

use constant DEFAULT_VERBOSE => TRUE;

use constant DEFAULT_TEST_MODE => TRUE;

use constant DEFAULT_USERNAME => getlogin || getpwuid($<) || $ENV{USER} || "sundaramj";

use constant DEFAULT_OUTDIR => '/tmp/' . DEFAULT_USERNAME . '/' . File::Basename::basename($0) . '/' . time();

use constant DEFAULT_INDIR => File::Spec->rel2abs(cwd());

## Singleton support
my $instance;

has 'test_mode' => (
    is       => 'rw',
    isa      => 'Bool',
    writer   => 'setTestMode',
    reader   => 'getTestMode',
    required => FALSE,
    default  => DEFAULT_TEST_MODE
    );

has 'config_file' => (
    is       => 'rw',
    isa      => 'Str',
    writer   => 'setConfigfile',
    reader   => 'getConfigfile',
    required => FALSE,
    );

has 'outdir' => (
    is       => 'rw',
    isa      => 'Str',
    writer   => 'setOutdir',
    reader   => 'getOutdir',
    required => FALSE,
    default  => DEFAULT_OUTDIR
    );

has 'infile' => (
    is       => 'rw',
    isa      => 'Str',
    writer   => 'setInfile',
    reader   => 'getInfile',
    required => FALSE
    );

has 'verbose' => (
    is       => 'rw',
    isa      => 'Bool',
    writer   => 'setVerbose',
    reader   => 'getVerbose',
    required => FALSE,
    default  => DEFAULT_VERBOSE
    );


sub getInstance {

    if (!defined($instance)){

        $instance = new Umlet::Python::Module::File::Parser(@_);

        if (!defined($instance)){

            confess "Could not instantiate Umlet::Python::Module::File::Parser";
        }
    }
    return $instance;
}

sub BUILD {

    my $self = shift;

    $self->_initLogger(@_);

    $self->_initConfigManager(@_);

    $self->{_is_parsed} = FALSE;

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


sub printBoldRed {

    my ($msg) = @_;
    print color 'bold red';
    print $msg . "\n";
    print color 'reset';
}

sub printYellow {

    my ($msg) = @_;
    print color 'yellow';
    print $msg . "\n";
    print color 'reset';
}

sub printGreen {

    my ($msg) = @_;
    print color 'green';
    print $msg . "\n";
    print color 'reset';
}

sub getLookup {

    my $self = shift;

    if (! $self->{_is_parsed}){
        $self->_parse_file(@_);
    }

    return $self->{_lookup};
}

sub _parse_file {

    my $self = shift;
    my ($infile) = @_;

    if (!defined($infile)){

        $infile = $self->getInfile();

        if (!defined($infile)){

            $self->{_logger}->logconfess("infile was not defined");
        }
    }

    if ($self->getVerbose()){
        print "About to parse '$infile'\n";
    }

    my @lines = read_file($infile);

    my $line_ctr = 0;

    foreach my $line (@lines){
    
        chomp $line;
    
        $line_ctr++;
    
        if ($line =~ m|^\s*$|){
            next;
        }
        elsif ($line =~ m|^package\s+(\S+)\s*;\s*$|){
            $self->{_lookup}->{package_name} = $1;
        }
        elsif ($line =~ m|^sub (\S+)\s*\{\s*$|){
            push(@{$self->{_lookup}->{sub_list}}, $1);
        }
        elsif ($line =~ m|^use constant (\S+)\s*=>\s*(\S+)$|){
            push(@{$self->{_lookup}->{constant_list}}, [$1, $2]);
        }
        elsif ($line =~ m|^extends \'(\S+)\';\s*$|){
            push(@{$self->{_lookup}->{extends_list}}, $1);
        }
        elsif ($line =~ m|^use (\S+);\s*$|){
            push(@{$self->{_lookup}->{use_list}}, $1);
        }
        elsif ($line =~ m|^has \'(\S+)\'|){
            push(@{$self->{_lookup}->{has_list}}, $1);
        }
    }

    $self->{_is_parsed} = TRUE;
}



no Moose;
__PACKAGE__->meta->make_immutable;

__END__


=head1 NAME

 Umlet::Python::Module::File::Parser
 

=head1 VERSION

 1.0

=head1 SYNOPSIS

 use Umlet::Python::Module::File::Parser;
 my $parser = new Umlet::Python::Module::File::Parser(infile=>$infile);
 $parser->getLookup();

=head1 AUTHOR

 Jaideep Sundaram

 Copyright Jaideep Sundaram

=head1 METHODS

=over 4

=cut