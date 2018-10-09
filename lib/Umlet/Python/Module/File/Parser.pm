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

has 'indir' => (
    is       => 'rw',
    isa      => 'Str',
    writer   => 'setIndir',
    reader   => 'getIndir',
    required => FALSE
    );

has 'namespace' => (
    is       => 'rw',
    isa      => 'Str',
    writer   => 'setNamespace',
    reader   => 'getNamespace',
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

    my $current_class;

    foreach my $line (@lines){

        chomp $line;

        $line_ctr++;

        if ($line =~ m/__name__ == '__main__':/){
            $self->{_lookup} = {};
            return;
        }

        if ($line =~ m|^\s*$|){
            next;
        }
        elsif ($line =~ m|^class\s+(\S+)\(\S*\)\s*:\s*$|){

            $current_class = $self->_get_class_with_namespace($1, $infile);

            my $inherits_from = $2;

            $self->{_lookup}->{$current_class}->{inherits_from} = $inherits_from;
        }
        elsif ($line =~ m|^\s+def (\S+)\(.+\):\s*$|){
            push(@{$self->{_lookup}->{$current_class}->{method_list}}, $1);
        }
        # elsif ($line =~ m|^from|){
        #     push(@{$self->{_lookup}->{$current_class}->{import_list}}, $1);
        # }
        # elsif ($line =~ m|^import|){
        #     push(@{$self->{_lookup}->{$current_class}->{import_list}}, $1);
        # }
    }

    $self->{_is_parsed} = TRUE;
}

sub _get_class_with_namespace {

    my $self = shift;
    my ($class, $infile) = @_;

    my $namespace = $self->_get_namespace($infile);

    my $current_class = $namespace . '.' . $class;

    $current_class =~ s|/|\.|g;

    $current_class =~ s/^\.//;

    return $current_class;
}

sub _get_namespace {

    my $self = shift;
    my ($infile) = @_;

    my $namespace = $self->getNamespace();

    if (!defined($namespace)){

        my $indir = $self->getIndir();

        $namespace = $infile;

        $namespace =~ s/$indir//;

        $self->setNamespace($namespace);
    }

    return $namespace;
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