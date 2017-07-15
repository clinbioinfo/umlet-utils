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


sub _process_private_member {

    my $self = shift;
    my ($line) = @_;

    if ($line =~ m|^[\-\_]{1}(\S+):\s*(\S+)\s*$|){

        ## $1 is the name of the variable
        ## $2 is the data type
        
        my $record = $self->_init_data_member_record($1, $2);

        push(@{$self->{_module_lookup}->{$self->{_current_class}}->{private_data_members_list}}, $record);
    }
    elsif ($line =~ m|^[\-\_]{1}(\S+)\(\)\s*:\s*(\S+)\s*$|){

        ## $1 is the name of the private method
        ## undef indicates that there are no arguments passed to the method
        ## $2 is the returned data type
        my $record = $self->_init_method_record($1, $2, undef);

        push(@{$self->{_module_lookup}->{$self->{_current_class}}->{private_methods_list}}, $record);

    }
    elsif ($line =~ m|^[\-\_]{1}(\S+)\(([\S\s\,]+)\)\s*:\s*(\S+)\s*$|){

        ## $1 is the name of the private method
        ## $2 the argument list passed to the method (need to refine this so that can handle more than one argument i.e.: comma-separated list
        ## $3 is the returned data type

        my $record = $self->_init_method_record($1, $2, $3);

        push(@{$self->{_module_lookup}->{$self->{_current_class}}->{private_methods_list}}, $record);
    }
    elsif ($line =~ m|^[\-\_]{1}(\S+)\(([\S\s\,]+)\)\s*$|){
        
        ## $1 is the name of the private method
        ## $2 the argument list passed to the method (need to refine this so that can handle more than one argument i.e.: comma-separated list
        ## undef indicates the method does not return anything

        my $record = $self->_init_method_record($1, undef, $2);

        push(@{$self->{_module_lookup}->{$self->{_current_class}}->{private_methods_list}}, $record);
    }
    elsif ($line =~ m|^[\-\_]{1}(\S+)\(\)\s*$|){
        
        ## $1 is the name of the private method
        ## first undef indicates that there is not argument
        ## second undef indicates the method does not return anything

        my $record = $self->_init_method_record($1, undef, undef);

        push(@{$self->{_module_lookup}->{$self->{_current_class}}->{private_methods_list}}, $record);
    }
    elsif ($line =~ m|^[\-\_]{1}(\S+)\s*:\s*(\S+)\s*$|){

        ## $1 is the name of the public data member
        ## $2 is the data type

        my $record = $self->_init_data_member_record($1, $2);

        push(@{$self->{_module_lookup}->{$self->{_current_class}}->{private_data_members_list}}, $record);
    }
    elsif ($line =~ m|^[\-\_]{1}(\S+)\s*:?\s*$|){

        ## $1 is the name of the public data member
        ## No data type specified

        my $record = $self->_init_data_member_record($1, undef);

        push(@{$self->{_module_lookup}->{$self->{_current_class}}->{private_data_members_list}}, [$1, undef]);
    }
    else {
        $self->{_logger}->logconfess("Don't know how to process this line '$line' in private members section of module '$self->{_current_class}'");
    }
}

sub _process_public_member {

    my $self = shift;
    my ($line) = @_;

    if ($line =~ m|^\+|){
        $line =~ s|^\+||;  ## remove leading plus sign        
    }


    if ($line =~ m|^(\S+)\(\)\s*:\s*(\S+)\s*$|){

        ## $1 is the name of the public method
        ## undef indicates that there are no arguments passed to the method
        ## $2 is the returned data type

        my $record = $self->_init_method_record($1, $2, undef);

        push(@{$self->{_module_lookup}->{$self->{_current_class}}->{public_methods_list}}, $record);
    }
    elsif ($line =~ m|^(\S+)\((\S+[\S\s\,]*)\)\s*:\s*(\S+)\s*$|){
        
        ## $1 is the name of the public method
        ## $2 the argument list passed to the method (need to refine this so that can handle more than one argument i.e.: comma-separated list
        ## $3 is the returned data type

        my $record = $self->_init_method_record($1, $2, $3);

        push(@{$self->{_module_lookup}->{$self->{_current_class}}->{public_methods_list}}, $record);
    }
    elsif ($line =~ m|^(\S+)\((\S+[\S\s\,]*)\)\s*$|){

        ## $1 is the name of the public method
        ## $2 the argument list passed to the method (need to refine this so that can handle more than one argument i.e.: comma-separated list
        ## undef indicates the method does not return anything

        my $record = $self->_init_method_record($1, $2, undef);

        push(@{$self->{_module_lookup}->{$self->{_current_class}}->{public_methods_list}}, $record);
    }
    elsif ($line =~ m|^(\S+)\(\)\s*$|){

        ## $1 is the name of the public method
        ## first undef indicates that there is not argument
        ## second undef indicates the method does not return anything

        my $record = $self->_init_method_record($1, undef, undef);

        push(@{$self->{_module_lookup}->{$self->{_current_class}}->{public_methods_list}}, $record);
    }
    elsif ($line =~ m|^(\S+)\s*:\s*(\S+)\s*$|){
        
        ## $1 is the name of the public data member
        ## $2 is the data type

        my $record = $self->_init_method_record($1, $2);

        push(@{$self->{_module_lookup}->{$self->{_current_class}}->{public_data_members_list}}, $record);
    }
    elsif ($line =~ m|^(\S+)\s*:?\s*$|){

        ## $1 is the name of the public data member
        ## No data type specified

        my $record = $self->_init_method_record($1, undef);

        push(@{$self->{_module_lookup}->{$self->{_current_class}}->{public_data_members_list}}, $record);

    }
    else {
        $self->{_logger}->logconfess("Don't know how to parse '$line' in public members section of module '$self->{_current_class}'");
    }
}


sub _process_comment_line {

    my $self = shift;
    my ($line)     = @_;

    if ($line =~ m|^//skip|){

        $self->{_module_lookup}->{$self->{_current_class}}->{already_implemented} = TRUE;
    }
    elsif ($line =~ m|^//singleton|i){

        if ($self->getVerbose()){
            print "currentModule '$self->{_current_class}' is a singleton\n";
        }

        $self->{_module_lookup}->{$self->{_current_class}}->{singleton} = TRUE;
    }
    elsif (($line =~ m|^//extends (\S+)|) || ($line =~ m|^//inherits (\S+)|)){

        if ($self->getVerbose()){
            print "module '$self->{_current_class}' extends '$1'\n";
        }

        push(@{$self->{_module_lookup}->{$self->{_current_class}}->{extends_list}}, $1);
    }
    elsif (($line =~ m|^//depends on (\S+)|) || ($line =~ m|^//depends (\S+)|)){

        push(@{$self->{_module_lookup}->{$self->{_current_class}}->{depends_on_list}}, $1);
    }
    elsif ($line =~ m|^//constant|){

        $self->_process_constant_line($line);
    }
    elsif ($line =~ m|//(.+)|){

        $self->{_logger}->warn("Going to ignore comment '$1'");

    }             
    else {
        $self->{_logger}->warn("Don't know what to do with commented line '$line' ".
                      "in header section of module '$self->{_current_class}'.  ".
                      "Ignoring this line.");
        next;
    }
}


sub _process_constant_line {

    my $self = shift;
    my ($line) = @_;


    if ($line =~ m|^constant (\S+)\s*=\s*(\S+)|){

        ## $1 is the name of the constant
        ## $2 is the value assigned to the constant

        my $record = $self->_init_constant_record($1, $2);

        push(@{$self->{_module_lookup}->{$self->{_current_class}}->{constant_list}}, $record);
        
    }
    elsif ($line =~ m|^constant (\S+) (\S+)|){
        
        ## $1 is the name of the constant
        ## $2 is the value assigned to the constant

        my $record = $self->_init_constant_record($1, $2);

        push(@{$self->{_module_lookup}->{$self->{_current_class}}->{constant_list}}, $record);
    }
    elsif ($line =~ m|^//constant (\S+)\s*=\s*(\S+)|){

        ## $1 is the name of the constant
        ## $2 is the value assigned to the constant

        my $record = $self->_init_constant_record($1, $2);

        push(@{$self->{_module_lookup}->{$self->{_current_class}}->{constant_list}}, $record);

    }
    elsif ($line =~ m|^//constant (\S+) (\S+)|){

        ## $1 is the name of the constant
        ## $2 is the value assigned to the constant

        my $record = $self->_init_constant_record($1, $2);

        push(@{$self->{_module_lookup}->{$self->{_current_class}}->{constant_list}}, $record);
    }
    else {
        $self->{_logger}->logconfess("Unexpected line '$line' in constant processing section");
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
