package Umlet::Perl::ClassDiagram::File::XML::Parser;

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

        $instance = new Umlet::Perl::ClassDiagram::File::XML::Parser(@_);

        if (!defined($instance)){

            confess "Could not instantiate Umlet::Perl::ClassDiagram::File::XML::Parser";
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

    my $lineCtr = 0;

    my $currentModule;
    my $sectionCtr = 0;

    my $processingFactoryModule = FALSE;

    foreach my $line (@lines){

        $lineCtr++;

        if ($line =~ /^\s*$/){
            next;  ## skip blank lines
        }

        $line =~ s/^\s+//; ## leading white space
        $line =~ s/\s+$//; ## trailing white space
        
        if ($line =~ m|^\-\-\s*$|){
            $sectionCtr++;
            next;
        }

        if ($lineCtr == 1){
            
            $line =~ s/\s//g; ## Remove all whitespace

            if ($line =~ /^lt\=\</){
                ## This is a Umlet dependency arrow object that we can ignore.
                return;
            }

            $currentModule = $line;

            if (! exists $self->{_module_lookup}->{$currentModule}){

                if ($currentModule =~ /Factory/){
                    $processingFactoryModule = TRUE;
                }

                $self->{_module_lookup}->{$currentModule} = {};
                $self->{_module_ctr}++;
            }
            else {
                $self->{_logger}->logconfess("Already processed a module called '$currentModule'");
            }
        }
        else {

            ## Not processing the first line

            if (!defined($currentModule)){
                $self->{_logger}->logconfess("module name was not determined when processing data line '$lineCtr' with data content:\n$data");
            }

            if ($sectionCtr == HEADER_SECTION){

                if ($line =~ /^bg\=(\S+)/){

                    if ($1 eq 'green'){
                        $self->{_module_lookup}->{$currentModule}->{already_implemented} = TRUE;
                    }
                    ## encountered the background color directive
                    next;
                }
                elsif ($line =~ m|^//|){

                    ## In the top section where the module is named and all dependencies and constants are cited

                    if ($line =~ m|^//skip|){
                        $self->{_module_lookup}->{$currentModule}->{already_implemented} = TRUE;
                    }
                    elsif ($line =~ m|^//singleton|){
                        if ($self->getVerbose()){
                            print "currentModule '$currentModule' is a singleton\n";
                        }

                        $self->{_module_lookup}->{$currentModule}->{singleton}++;
                    }
                    elsif (($line =~ m|^//extends (\S+)|) || ($line =~ m|^//inherits (\S+)|)){
                        if ($self->getVerbose()){
                            print "module '$currentModule' extends '$1'\n";
                        }

                        push(@{$self->{_module_lookup}->{$currentModule}->{extends_list}}, $1);
                    }
                    elsif ($line =~ m|^//use (\S+)|){

                        push(@{$self->{_module_lookup}->{$currentModule}->{uses_list}}, $1);                        
                    }
                    elsif ( (($line =~ m|^//depends on (\S+) type\=(\S+)|) || ($line =~ m|^//depends (\S+) type\=(\S+)|)) && ($processingFactoryModule)){

                        push(@{$self->{_module_lookup}->{$currentModule}->{depends_on_list}}, $1);
                        $self->{_module_lookup}->{$currentModule}->{factory_types_lookup}->{$1} = $2;
                    }
                    elsif (($line =~ m|^//depends on (\S+)|) || ($line =~ m|^//depends (\S+)|)){
                        push(@{$self->{_module_lookup}->{$currentModule}->{depends_on_list}}, $1);
                    }
                    elsif ($line =~ m|^//constant (\S+)\s*=\s*(\S+)|){
                        push(@{$self->{_module_lookup}->{$currentModule}->{constant_list}}, [$1, $2]);
                        ## $1 is the name of the constant
                        ## $2 is the value assigned to the constant
                    }
                    elsif ($line =~ m|^//constant (\S+) (\S+)|){
                        push(@{$self->{_module_lookup}->{$currentModule}->{constant_list}}, [$1, $2]);
                        ## $1 is the name of the constant
                        ## $2 is the value assigned to the constant
                    }
                    else {
                        $self->{_logger}->warn("Don't know what to do with commented line '$line' ".
                                      "in header section of module '$currentModule'.  ".
                                      "Ignoring this line.");
                        next;
                    }
                }
                else {
                    $self->{_logger}->logconfess("Don't know what to do with line '$line' in header section of module '$currentModule'");
                }
            }
            elsif ($sectionCtr == PRIVATE_MEMBERS_SECTION){

                if ($line =~ /^bg\=(\S+)/){

                    my $color = $1;

                    if ($color eq 'green'){
                        $self->{_module_lookup}->{$currentModule}->{already_implemented} = TRUE;
                    }
                    else {
                        $self->{_logger}->info("Encountered the background color directive '$color'.");
                    }
                    next;
                }
                elsif ($line =~ m|^constant (\S+)\s*=\s*(\S+)|){
                    push(@{$self->{_module_lookup}->{$currentModule}->{constant_list}}, [$1, $2]);
                    ## $1 is the name of the constant
                    ## $2 is the value assigned to the constant
                }
                elsif ($line =~ m|^constant (\S+) (\S+)|){
                    push(@{$self->{_module_lookup}->{$currentModule}->{constant_list}}, [$1, $2]);
                    ## $1 is the name of the constant
                    ## $2 is the value assigned to the constant
                }
                elsif ($line =~ m|//(.+)|){
                    $self->{_logger}->info("Going to ignore comment '$1' in private members section");
                    next;
                }             
                elsif ($line =~ m|^\-(\S+):\s*(\S+)\s*$|){
                    push(@{$self->{_module_lookup}->{$currentModule}->{private_data_members_list}}, [$1, $2]);
                    ## $1 is the name of the variable
                    ## $2 is the data type
                }
                elsif ($line =~ m|^[\-\_]{0,1}(\S+)\(\)\s*:\s*(\S+)\s*$|){
                    push(@{$self->{_module_lookup}->{$currentModule}->{private_methods_list}}, [$1, undef, $2]);
                    ## $1 is the name of the private method
                    ## undef indicates that there are no arguments passed to the method
                    ## $2 is the returned data type
                }
                elsif ($line =~ m|^[\-\_]{0,1}(\S+)\(([\S\s\,]+)\)\s*:\s*(\S+)\s*$|){
                    push(@{$self->{_module_lookup}->{$currentModule}->{private_methods_list}}, [$1, $2, $3]);
                    ## $1 is the name of the private method
                    ## $2 the argument list passed to the method (need to refine this so that can handle more than one argument i.e.: comma-separated list
                    ## $3 is the returned data type
                }
                elsif ($line =~ m|^[\-\_]{0,1}(\S+)\(([\S\s\,]+)\)\s*$|){
                    push(@{$self->{_module_lookup}->{$currentModule}->{private_methods_list}}, [$1, $2, undef]);
                    ## $1 is the name of the private method
                    ## $2 the argument list passed to the method (need to refine this so that can handle more than one argument i.e.: comma-separated list
                    ## undef indicates the method does not return anything
                }
                elsif ($line =~ m|^[\-\_]{0,1}(\S+)\(\)\s*$|){
                    push(@{$self->{_module_lookup}->{$currentModule}->{private_methods_list}}, [$1, undef, undef]);
                    ## $1 is the name of the private method
                    ## first undef indicates that there is not argument
                    ## second undef indicates the method does not return anything
                }

                else {
                    $self->{_logger}->logconfess("Don't know how to process this line '$line' in private members section of module '$currentModule'");
                }
            }
            elsif ($sectionCtr == PUBLIC_MEMBERS_SECTION){

                if ($line =~ m|//(.+)|){
                    $self->{_logger}->info("Going to ignore comment '$1' in public members section");
                    next;
                }                          
                elsif ($line =~ m|^(\S+)\(\)\s*:\s*(\S+)\s*$|){
                    push(@{$self->{_module_lookup}->{$currentModule}->{public_methods_list}}, [$1, undef, $2]);
                    ## $1 is the name of the public method
                    ## undef indicates that there are no arguments passed to the method
                    ## $2 is the returned data type
                }
                elsif ($line =~ m|^(\S+)\((\S+[\S\s\,]*)\)\s*:\s*(\S+)\s*$|){
                    push(@{$self->{_module_lookup}->{$currentModule}->{public_methods_list}}, [$1, $2, $3]);
                    ## $1 is the name of the public method
                    ## $2 the argument list passed to the method (need to refine this so that can handle more than one argument i.e.: comma-separated list
                    ## $3 is the returned data type
                }
                elsif ($line =~ m|^(\S+)\((\S+[\S\s\,]*)\)\s*$|){
                    push(@{$self->{_module_lookup}->{$currentModule}->{public_methods_list}}, [$1, $2, undef]);
                    ## $1 is the name of the public method
                    ## $2 the argument list passed to the method (need to refine this so that can handle more than one argument i.e.: comma-separated list
                    ## undef indicates the method does not return anything
                }
                elsif ($line =~ m|^(\S+)\(\)\s*$|){
                    push(@{$self->{_module_lookup}->{$currentModule}->{public_methods_list}}, [$1, undef, undef]);
                    ## $1 is the name of the public method
                    ## first undef indicates that there is not argument
                    ## second undef indicates the method does not return anything
                }
                else {
                    $self->{_logger}->logconfess("Don't know how to parse '$line' in public members section of module '$currentModule'");
                }
            }
            else {
                $self->{_logger}->logconfess("Did not expect section '$sectionCtr'");
            }
        }
    }
}


no Moose;
__PACKAGE__->meta->make_immutable;

__END__


=head1 NAME

 Umlet::Perl::ClassDiagram::File::XML::Parser
 

=head1 VERSION

 1.0

=head1 SYNOPSIS

 use Umlet::Perl::ClassDiagram::File::XML::Parser;
 my $parser = new Umlet::Perl::ClassDiagram::File::XML::Parser(infile => $infile);
 my $class_record_list = $parser->getClassList();

=head1 AUTHOR

 Jaideep Sundaram

 Copyright Jaideep Sundaram

=head1 METHODS

=over 4

=cut
