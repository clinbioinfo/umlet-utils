package Umlet::JavaScript::ClassDiagram::File::XML::Parser;

use Moose;

use XML::Twig;

extends 'Umlet::File::XML::Parser';

use constant TRUE  => 1;

use constant FALSE => 0;


use constant HEADER_SECTION => 0;

use constant PRIVATE_MEMBERS_SECTION => 1;

use constant PUBLIC_MEMBERS_SECTION => 2;


## Singleton support
my $instance;

my $this;


sub getInstance {

    if (!defined($instance)){

        $instance = new Umlet::JavaScript::ClassDiagram::File::XML::Parser(@_);

        if (!defined($instance)){

            confess "Could not instantiate Umlet::JavaScript::ClassDiagram::File::XML::Parser";
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


sub _parse_file {

    my $self = shift;
    my ($infile) = @_;

    if (!defined($infile)){

        $infile = $self->getInfile();

        if (!defined($infile)){
            $self->{_logger}->logconfess("infile was not defined");
        }
    }
    else {
        $self->setInfile($infile);
    }

    $this = $self;

    $self->{_module_lookup} = {};
    $self->{_module_ctr} = 0;

        my $twig = new XML::Twig(
        twig_handlers =>  { 
            panel_attributes => \&panelAttributesHandler 
        }
    );

    if (!defined($twig)){
        $self->{_logger}->logconfess("Could not instantiate XML::Twig");
    }

    if ($self->getVerbose()){
        print "About to parse input file '$infile'\n";
    }

    $self->{_logger}->info("About to parse input file '$infile'");

    $twig->parsefile($infile);


    $self->_summarize_parsing_activity();
}


sub panelAttributesHandler {

    my $self = $this;
    my ($twig, $elem) = @_;

    my $data = $elem->text;

    my @lines = split("\n", $data);

    my $line_ctr = 0;

    my $section_ctr = 0;

    my $processingFactoryModule = FALSE;

    foreach my $line (@lines){

        $line_ctr++;

        if ($line =~ /^\s*$/){
            next;  ## skip blank lines
        }

        $line =~ s/^\s+//; ## leading white space
        $line =~ s/\s+$//; ## trailing white space
        
        if ($line =~ m|^\-\-\s*$|){
            $section_ctr++;
            next;
        }

        if ($line_ctr == 1){
            
            $line =~ s/\s//g; ## Remove all whitespace

            if ($line =~ /^lt\=\</){
                ## This is a Umlet dependency arrow object that we can ignore.
                return;
            }

            if ($line =~ m|::|){
                $line =~ s|::|\.|g;
            }
            
            $self->{_current_class} = $line;

            if (! exists $self->{_module_lookup}->{$self->{_current_class}}){

                if ($self->{_current_class} =~ /Factory/){
                    $processingFactoryModule = TRUE;
                }

                $self->{_module_lookup}->{$self->{_current_class}} = {};
                $self->{_module_ctr}++;
            }
            else {
                $self->{_logger}->logconfess("Already processed a module called '$self->{_current_class}'");
            }

            next;
        }
 
        ## Past the first line at this point

        if (!defined($self->{_current_class})){
            $self->{_logger}->logconfess("module name was not determined when processing data line '$line_ctr' with data content:\n$data");
        }


        if ($line =~ /^bg\=(\S+)/){

            my $color = $1;

            if ($color eq 'green'){
                $self->{_module_lookup}->{$self->{_current_class}}->{already_implemented} = TRUE;
            }
            else {
                $self->{_logger}->info("Encountered the background color directive '$color'.");
            }

            next;
        }
        elsif ($line =~ m|^//|){

            $self->_process_comment_line($line);
        }
        elsif ($line =~ m|^constant|){

            $self->_process_constant_line($line);
        }
        elsif (($line =~ m|^\-{1}|) || ($line =~ m|^\_{1}|)){

            $self->_process_private_member($line);
        }
        elsif ($line =~ m|^\+{1}|){

            $self->_process_public_member($line);
        }
        else{

            $self->_process_public_member($line);
        }
    }
}




no Moose;
__PACKAGE__->meta->make_immutable;

__END__


=head1 NAME

 Umlet::JavaScript::ClassDiagram::File::XML::Parser
 

=head1 VERSION

 1.0

=head1 SYNOPSIS

 use Umlet::JavaScript::ClassDiagram::File::XML::Parser;
 my $parser = new Umlet::JavaScript::ClassDiagram::File::XML::Parser(infile => $infile);
 my $class_record_list = $parser->getClassList();

=head1 AUTHOR

 Jaideep Sundaram

 Copyright Jaideep Sundaram

=head1 METHODS

=over 4

=cut
