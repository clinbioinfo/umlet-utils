package Umlet::JavaScript::Class::File::Writer;

use Moose;
use Cwd;
use String::CamelCase qw(decamelize);
use Data::Dumper;
use File::Path;
use FindBin;
use Term::ANSIColor;

use Umlet::Config::Manager;

extends 'Umlet::File::Writer';

use constant TRUE  => 1;

use constant FALSE => 0;

use constant DEFAULT_JAVASCRIPT_SINGLETON_CLASS_FILE => "$FindBin::Bin/../template/javascript_singleton_class_tmpl.tt";

use constant DEFAULT_JAVASCRIPT_CLASS_FILE => "$FindBin::Bin/../template/javascript_class_tmpl.tt";

## Singleton support
my $instance;

has 'singleton_class_template_file' => (
    is       => 'rw',
    isa      => 'Str',
    writer   => 'setSingletonClassTemplateFile',
    reader   => 'getSingletonClassTemplateFile',
    required => FALSE,
    default  => DEFAULT_JAVASCRIPT_SINGLETON_CLASS_FILE
    );

has 'class_template_file' => (
    is       => 'rw',
    isa      => 'Str',
    writer   => 'setClassTemplateFile',
    reader   => 'getClassTemplateFile',
    required => FALSE,
    default  => DEFAULT_JAVASCRIPT_CLASS_FILE
    );

sub getInstance {

    if (!defined($instance)){

        $instance = new Umlet::JavaScript::Class::File::Writer(@_);

        if (!defined($instance)){

            confess "Could not instantiate Umlet::JavaScript::Class::File::Writer";
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
    my ($class_lookup) = @_;

    $self->{_class_lookup} = $class_lookup;

    my $outdir = $self->getOutdir();

    if ($self->getVerbose()){
        print "About to create the API in directory '$outdir'\n";
    }

    $self->{_logger}->info("About to create the JavaScript API in directory '$outdir'");

    foreach my $namespace (sort keys %{$class_lookup}){

        my $lookup = $class_lookup->{$namespace};

        if ($self->getSkipGreenModules()){

            if ((exists $class_lookup->{$namespace}->{already_implemented}) && 
                ($class_lookup->{$namespace}->{already_implemented} ==  TRUE)){

                $self->{_logger}->info("Will skip creation of module '$namespace' since UXF indicates the module has already been implemented");
                
                next;
            }
        }


        $self->_add_package_name($namespace, $lookup);
        
        $self->_add_provenance_info($outfile);
        
        $self->_add_package_pod($namespace, $lookup);
        
        $self->_add_dependencies($namespace, $lookup);
        
        $self->_add_extends($namespace, $lookup);
        
        $self->_add_constants($namespace, $lookup);
        
        $self->_add_instance_private_member($namespace, $lookup);
        
        $self->_add_private_data_members($namespace, $lookup);
        
        $self->_add_get_instance_method($namespace, $lookup);
        
        $self->_add_build_method($namespace, $lookup);
        
        $self->_add_private_methods($namespace, $lookup);
        
        $self->_add_public_methods($namespace, $lookup);

        if ($namespace =~ /Factory/){
            $self->_add_factory_module_specific_methods($namespace, $lookup);
        }

        
        $self->_write_file($namespace);
    }

    if ($self->getVerbose()){
        print "Have created the API in the directory '$outdir'\n";
    }

    $self->{_logger}->info("Have created the API in the directory '$outdir'");
}


sub _print_summary {

    my $self = shift;
    
    print "Created the following test scripts:\n";
    print join("\n", @{$self->{_test_script_file_list}}) . "\n";

    print "\nCreated the following test scripts:\n";
    print join("\n", @{$self->{_module_file_list}}) . "\n";
}

sub _add_package_name {

    my $self = shift;
    
    my ($namespace, $lookup) = @_;
    
    print OUTFILE "package $namespace;\n\n";
}

sub _add_provenance_info {

    my $self = shift;

    my ($outfile) = @_;

    print OUTFILE "## [RCS_TRIPWIRE] After this module has been reviewed, the following lines can be deleted:\n";
    print OUTFILE "## [RCS_TRIPWIRE] method-created: " . File::Spec->rel2abs($0) . "\n";
    print OUTFILE "## [RCS_TRIPWIRE] date-created: " . localtime() . "\n";
    print OUTFILE "## [RCS_TRIPWIRE] created-by: " . getlogin . "\n";
    print OUTFILE "## [RCS_TRIPWIRE] input-umlet-file: " . File::Spec->rel2abs($self->getInfile()) . "\n";
    print OUTFILE "## [RCS_TRIPWIRE] output-directory: " . File::Spec->rel2abs($self->getOutdir()) . "\n";

}

sub _add_package_pod {

    my $self = shift;

    my ($namespace, $lookup) = @_;

    print OUTFILE "\n\n";
    print OUTFILE '=head1 NAME' . "\n\n";
    print OUTFILE ' ' . $namespace . "\n\n";
    print OUTFILE ' [RCS_TRIPWIRE] INSERT ONE LINE DESCRIPTION HERE.' . "\n\n";
    print OUTFILE '=head1 VERSION' . "\n\n";
    print OUTFILE ' ' . $self->getSoftwareVersion() . "\n\n";
    print OUTFILE '=head1 SYNOPSIS' . "\n\n";
    print OUTFILE ' use ' . $namespace . ';' . "\n";
    print OUTFILE ' [RCS_TRIPWIRE] INSERT SHORT SYNOPSIS HERE.'. "\n\n";
    print OUTFILE '=head1 AUTHOR' . "\n\n";
    print OUTFILE ' ' . $self->getSoftwareAuthor()  . "\n\n";
    print OUTFILE ' ' . $self->getAuthorEmailAddress() . "\n\n";
    print OUTFILE '=head1 METHODS' . "\n\n";
    print OUTFILE '=over 4' . "\n\n";
    print OUTFILE '=cut' . "\n\n";
}

sub _add_dependencies {

    my $self = shift;

    my ($namespace, $lookup) = @_;

    print OUTFILE "\n";
    print OUTFILE "use Moose;\n";

    my $ctr = 0 ;

    if (( exists $lookup->{depends_on_list}) && 
        ( defined $lookup->{depends_on_list})){

        foreach my $dependency (@{$lookup->{depends_on_list}}){
            
            print OUTFILE "use $dependency;\n";
            
            $ctr++;
        }
    }

    if ($self->getVerbose()){
        print "Added '$ctr' dependencies\n";
    }

    $self->{_logger}->info("Added '$ctr' dependencies");
}

sub _add_extends {

    my $self = shift;

    my ($namespace, $lookup) = @_;

    print OUTFILE "\n";

    my $ctr = 0 ;

    if (( exists $lookup->{extends_list}) && 
        ( defined $lookup->{extends_list})){

        foreach my $extends (@{$lookup->{extends_list}}){
            
            print OUTFILE "extends '$extends';\n";
            
            $ctr++;
        }
    }

    if ($self->getVerbose()){
        print "Added '$ctr' extends clauses\n";
    }

    $self->{_logger}->info("Added '$ctr' extends clauses");
}

sub _add_constants {

    my $self = shift;

    my ($namespace, $lookup) = @_;

    my $ctr = 0 ;

    ## Always add the TRUE, FALSE constants to the top of each module
    print OUTFILE "\nuse constant TRUE  => 1;\n";
    print OUTFILE "use constant FALSE => 0;\n";

    if (( exists $lookup->{constant_list}) &&
        ( defined $lookup->{constant_list})){

        print OUTFILE "\n";
        
        foreach my $constantArrayRef (@{$lookup->{constant_list}}){
            
            my $name = $constantArrayRef->[0];
            
            if ((lc($name) eq 'true') || (lc($name) eq 'false')){
                next;
            }

            my $val = $constantArrayRef->[1];
            
            if (!defined($val)){
                $val = undef;
            }

            ## Automatically convert all uppercase
            $name = uc($name);

            print OUTFILE "use constant $name => $val;\n";
            $ctr++;
        }
    }

    if ($self->getVerbose()){
        print "Added '$ctr' constants\n";
    }

    $self->{_logger}->info("Added '$ctr' constants");
}

sub _add_instance_private_member {

    my $self = shift;

    my ($namespace, $lookup) = @_;

    if (( exists $lookup->{singleton}) &&
        ( defined $lookup->{singleton})){
        
        print OUTFILE "\n";
        print OUTFILE "## Singleton support\n";
        print OUTFILE 'my $instance;' . "\n\n";

        if ($self->getVerbose()){
            print "Adding Singleton support for module '$namespace'\n";
        }

        $self->{_logger}->info("Adding Singleton support for module '$namespace'");
        
    }
    else {
        if ($self->getVerbose()){
            print "module '$namespace' is not a singleton\n";
        }
    }       

    $self->{_logger}->info("module '$namespace' is not a singleton");
    
}

sub _add_get_instance_method {

    my $self = shift;

    my ($namespace, $lookup) = @_;

    if (( exists $lookup->{singleton}) &&
        ( defined $lookup->{singleton})){

        print OUTFILE 'sub getInstance {' . "\n\n";


        if (! $self->getSuppressCheckpoints()){
            print OUTFILE '    confess "CHECKPOINT"; ## [RCS_TRIPWIRE] Remove this line of code after reviewing this method.' . "\n\n";
        }

        print OUTFILE '    if (!defined($instance)){' . "\n";
        print OUTFILE '        $instance = new ' . $namespace . '(@_);' . "\n";
        print OUTFILE '        if (!defined($instance)){' . "\n";
        print OUTFILE '            confess "Could not instantiate ' . $namespace . "\";\n";
        print OUTFILE '        }' . "\n";
        print OUTFILE '    }' . "\n";
        print OUTFILE '    return $instance;' . "\n";
        print OUTFILE '}' . "\n";
        
        if ($self->getVerbose()){
            print "Added getInstance method\n";
        }

        $self->{_logger}->info("Added getInstance method");
    }
    else {
        if ($self->getVerbose()){
            print "module '$namespace' is not a singleton\n";
        }

        $self->{_logger}->info("module '$namespace' is not a singleton");
    }        
}

sub _add_private_data_members {

    my $self = shift;

    my ($namespace, $lookup) = @_;

    my $ctr = 0 ;

    if (( exists $lookup->{private_data_members_list}) &&
        ( defined $lookup->{private_data_members_list})){

        print OUTFILE "\n";
    
        foreach my $arrayRef (@{$lookup->{private_data_members_list}}){
            
            my $name = $arrayRef->[0];
            
            my $datatype = lc($arrayRef->[1]);

            my $isa;

            my $mooseMethodName = ucfirst(lc($name));

            if (($datatype eq 'string') || ($datatype eq 'str')){
                $isa = 'Str';
            }
            elsif (($datatype eq 'int') || ($datatype eq 'integer')){
                $isa = 'Int';
            }
            elsif ($datatype eq 'float'){
                $self->{_logger}->info("Will convert the float data type into Moose Num");
                $isa = 'Num';
            }
            elsif ($datatype eq 'number'){
                $self->{_logger}->info("Will convert the number data type into Moose Num");
                $isa = 'Num';
            }                
            elsif ($datatype =~ /::/){
                $isa = $datatype;
            }
            else {
                $self->{_logger}->logconfess("Unrecognized data type '$datatype'");
            }

            print OUTFILE "has '$name' => (\n";
            print OUTFILE "    is => 'rw',\n";
            print OUTFILE "    isa => '$isa',\n";
            print OUTFILE "    writer => 'set$mooseMethodName',\n";
            print OUTFILE "    reader => 'get$mooseMethodName'";

            if ($name ne lc($name)){

                my $init_arg = decamelize($name);

                print OUTFILE ",\n";
                print OUTFILE "    init_arg => '$init_arg'";
            }

            print OUTFILE "    );\n\n";
            $ctr++;
        }
    }

    if ($self->getVerbose()){
        print "Added '$ctr' private data members\n";
    }
}

sub _add_build_method {

    my $self = shift;
    my ($namespace, $lookup) = @_;

    print OUTFILE "\n";
    print OUTFILE "sub BUILD {\n\n";

    if (! $self->getSuppressCheckpoints()){
        print OUTFILE '    confess "CHECKPOINT"; ## [RCS_TRIPWIRE] Remove this line of code after reviewing this method.' . "\n\n";
    }

    print OUTFILE '    my $self' ." = shift;\n\n";

    my $initMethodLookup = {};
    my $methodToModuleLookup = {};

    my $ctr = 0;

    print OUTFILE '    $self->_initLogger(@_);' . "\n";


    if (( exists $lookup->{depends_on_list}) &&
        ( defined $lookup->{depends_on_list})){

        foreach my $dependency (@{$lookup->{depends_on_list}}){

            my @parts = split(/::/, $dependency);
            
            my $dep = pop(@parts);

            if (lc($dep) eq 'logger'){
                next;
            }

            my $initMethodName = "_init". $dep;
 
            if (exists $methodToModuleLookup->{$initMethodName}){
                my $namespace = pop(@parts);
                $initMethodName = "_init". $namespace. $dep; 
            }

            $methodToModuleLookup->{$initMethodName} = $dependency;

 #           $initMethodLookup->{$initMethodName} = $dependency;
           $initMethodLookup->{$dependency} = $initMethodName;
            
            print OUTFILE '    $self->' . $initMethodName ."(" .'@_' .");\n";
            
            $ctr++;
        }

    }

    print OUTFILE "}\n\n";

    if ($self->getVerbose()){
        print "Added '$ctr' init methods to the BUILD method\n";
    }

    $self->{_logger}->info("Added '$ctr' init methods to the BUILD method");

    $self->_add_init_logger_method();

    if ($ctr > 0){

        $self->_add_init_methods($initMethodLookup, $namespace);

#        print "module '$namespace' initMethodLookup: " . Dumper $initMethodLookup;
    }
}
    
sub _add_init_logger_method {

    my $self = shift;
    
    print OUTFILE "sub _initLogger {\n\n";
    print OUTFILE '    my $self = shift;' . "\n\n";
    print OUTFILE '    my $self->{_logger} = Log::Log4perl->get_logger(__PACKAGE__);' . "\n";
    print OUTFILE '    if (!defined($self->{_logger})){' . "\n";
    print OUTFILE '        confess "logger was not defined";' . "\n";
    print OUTFILE "    }\n\n";
    print OUTFILE '    $self->{_logger} = $self->{_logger};' . "\n";
    print OUTFILE "}\n";
}

sub _add_init_methods {

    my $self = shift;
    my ($initMethodLookup, $namespace) = @_;

    print OUTFILE "\n";

    my $ctr = 0;

    foreach my $module (sort {$a <=> $b } keys %{$initMethodLookup}){

        if (exists $self->{_class_lookup}->{$namespace}->{factory_types_lookup}->{$module}){
            next;
        }

        my $method = $initMethodLookup->{$module};

        if ($method eq '_initLogger'){
            next;
        }

#        my $module = $initMethodLookup->{$method};

        my @parts = split(/::/, $module);

        my $moduleBasename = pop(@parts);
        
        my $moduleVar = lc($moduleBasename);

        print OUTFILE "sub $method {\n\n";

        if (! $self->getSuppressCheckpoints()){
            print OUTFILE '    confess "CHECKPOINT"; ## [RCS_TRIPWIRE] Remove this line of code after reviewing this method.' . "\n\n";
        }
        
        print OUTFILE '    my $self = shift;'."\n\n";

        if (( exists $self->{_class_lookup}->{$module}->{singleton}) && 
            ( defined $self->{_class_lookup}->{$module}->{singleton})){
            print OUTFILE '    my $' . $moduleVar . ' = ' . $module . '::getInstance(@_);' . "\n";
        }
        else {
            print OUTFILE '    my $' . $moduleVar . ' = new ' . $module . '(@_);' . "\n";
        }
        print OUTFILE '    if (!defined($' . $moduleVar. ')){' . "\n";
        print OUTFILE '        $self->{_logger}->logconfess("Could not instantiate ' . $module .'");' ."\n";
        print OUTFILE "    }\n\n";
        print OUTFILE '    $self->{_' .$moduleVar . '} = $'. $moduleVar . ";\n";
        print OUTFILE "}\n\n";
        
        
        $ctr++;
    }

    if ($self->getVerbose()){
        print "Added '$ctr' init methods\n";
    }

    $self->{_logger}->info("Added '$ctr' init methods");
}

sub _add_public_methods {

    my $self = shift;
    my ($namespace, $lookup) = @_;

    my $ctr = 0;

    if (( exists $lookup->{public_methods_list}) && 
        ( defined $lookup->{public_methods_list})){
        
        $self->_add_methods($namespace, $lookup, 'public');
    }
}

sub _add_private_methods {

    my $self = shift;
    my ($namespace, $lookup) = @_;

    if (( exists $lookup->{private_methods_list}) && 
        ( defined $lookup->{private_methods_list})){
        
        $self->_add_methods($namespace, $lookup, 'private');
    }
}
            
sub _add_methods {

    my $self = shift;
    my ($namespace, $lookup, $methodType) = @_;

    my $methodTypeKey = 'public_methods_list';

    if ($methodType eq 'private'){
        $methodTypeKey = 'private_methods_list';
    }

    my $ctr = 0;

    foreach my $arrayRef (@{$lookup->{$methodTypeKey}}){

        my $methodName = $arrayRef->[0];

        if ($methodType eq 'private'){
            $methodName = '_' . $arrayRef->[0];
        }

        ## Add the POD first
        print OUTFILE '=item ' . $methodName . '()' . "\n\n";
        print OUTFILE 'B<Description:> INSERT BRIEF DESCRIPTION HERE' . "\n\n";
        print OUTFILE 'B<Parameters:> INSERT PARAMETERS HERE' . "\n\n";
        print OUTFILE 'B<Returns:> INSERT RETURNS HERE' . "\n\n";
        print OUTFILE '=cut' . "\n\n";

        ## Add the method definition
        print OUTFILE 'sub ' . $methodName . " {\n\n";

        print OUTFILE '    my $self = shift;'."\n";
        
        
        my $parameterList = $arrayRef->[1];

        if (defined($parameterList)){

            $self->{_logger}->info("Will add parameters '$parameterList' to method '$methodName'");

            $parameterList =~ s/\s//g; ## Remove all whitespaces 

            my @paramList = split(',', $parameterList);


            my @argumentList;

            foreach my $param (@paramList){
                
                push(@argumentList, '$'. $param);
            }

            my $argList = '    my (' . join(', ', @argumentList) . ') = @_;';                

            print OUTFILE $argList . "\n\n";
            
            foreach my $param (@paramList){

                print OUTFILE '    if (!defined($' . $param . ')){' . "\n";
                print OUTFILE '        $self->{_logger}->logconfess("' . $param . ' was not defined");' . "\n";
                print OUTFILE '    }' . "\n\n";
            }


        }
        else {
            $self->{_logger}->info("There were no parameters for method '$methodName'");
        }


        print OUTFILE "\n    confess \"NOT YET IMPLEMENTED\"; ## [RCS_TRIPWIRE]\n\n";

        my $returnDataType = $arrayRef->[2];

        if (defined($returnDataType)){
            print OUTFILE '    my $returnVal; ## [RCS_TRIPWIRE] Should be defined as data type ' . $returnDataType . "\n\n";
            print OUTFILE '    return $returnVal;' . "\n";
        }
        else {
            $self->{_logger}->info("There was no return data type for method '$methodName'");
        }           

        print OUTFILE "}\n\n";

        $ctr++;
    }


    if ($self->getVerbose()){
        print "Added '$ctr' $methodType methods\n";
    }

    $self->{_logger}->info("Added '$ctr' $methodType methods");
}


sub _derive_script_name {

    my $self = shift;
    my ($namespace, $outdir) = @_;


    if ($namespace =~ /::/){

    my @parts = split(/::/, $namespace);

    my $name = pop(@parts);

    my $testScriptName = 'test' . $name . '.pl';

    my $subdirName = join('::', @parts);

    $subdirName =~ s/::/\//g;

    my $dir = $outdir . '/test/' . $subdirName;

    if (!-e $dir){

        mkpath($dir) || $self->{_logger}->logconfess("Could not create directory '$dir' : $!");

        $self->{_logger}->info("Created directory '$dir'");
    }
    
    my $fqdName = $dir . '/' . $testScriptName;

    return $fqdName;
    }
    else {
        $self->{_logger}->logconfess("Don't know how to process module '$namespace'");
    }
}

sub _create_test_script {

    my $self = shift;  
    my ($module, $outdir) = @_;

    my $scriptName = $self->_derive_script_name($module, $outdir);


    if (-e $scriptName){

        my $bakfile = $scriptName . '.bak';

        copy ($scriptName, $bakfile) || $self->{_logger}->logconfess("Could not copy '$scriptName' to '$bakfile' : $!");
    }

    open (TOUTFILE, ">$scriptName") || $self->{_logger}->logconfess("Could not open file '$scriptName' in write mode : $!");


    print TOUTFILE '#!/usr/bin/env perl' . "\n";

    print TOUTFILE 'use strict;' . "\n";
    print TOUTFILE 'use ' . $module . ';' . "\n\n";


    print TOUTFILE "## method-created: " . File::Spec->rel2abs($0) . "\n";
    print TOUTFILE "## date-created: " . localtime() . "\n";
    print TOUTFILE "## created-by: " . getlogin . "\n";
    print TOUTFILE "## input-umlet-file: " . File::Spec->rel2abs($self->getInfile()) . "\n";
    print TOUTFILE "## output-directory: " . File::Spec->rel2abs($self->getOutdir()) . "\n\n";

    print TOUTFILE 'my $var = new ' . $module . '();' ."\n";
    print TOUTFILE 'if (!defined($var)){' . "\n";
    print TOUTFILE '    die "Could not instantiate '. $module . "\";\n";
    print TOUTFILE '}' . "\n\n";

    print TOUTFILE 'print "$0 execution completed\n";' ."\n";
    print TOUTFILE 'exit(0);' . "\n\n";

    print TOUTFILE '##---------------------------------------------------' ."\n";
    print TOUTFILE '##' . "\n";
    print TOUTFILE '##  END OF MAIN -- SUBROUTINES FOLLOW' . "\n";
    print TOUTFILE '##' . "\n";
    print TOUTFILE '##---------------------------------------------------' ."\n";
    
    close TOUTFILE;

    $self->{_logger}->info("Wrote '$scriptName'");

    push(@{$self->{_test_script_file_list}}, $scriptName);
}


sub _add_factory_module_specific_methods {

    my $self = shift;
    
    my ($namespace, $lookup) = @_;

    $self->_add_factory_get_type_method($namespace, $lookup);
    $self->_add_factory_create_method($namespace, $lookup);
}

sub _add_factory_get_type_method {

    my $self = shift;
    
    my ($namespace, $lookup) = @_;

    if (! $self->getSuppressCheckpoints()){
        print OUTFILE '    confess "CHECKPOINT"; ## [RCS_TRIPWIRE] Remove this line '.
            'of code after reviewing this method.' . "\n\n";
    }

    print OUTFILE 'sub _getType {' . "\n\n";
    print OUTFILE '    my $self = shift;' . "\n";
    print OUTFILE '    my (%args) = @_;' . "\n\n";
    print OUTFILE '    my $type = $self->getType();' . "\n\n";
    print OUTFILE '    if (!defined($type)){' . "\n\n";
    print OUTFILE '        if (( exists $args{system_type}) && ( defined $args{system_type})){' . "\n";
    print OUTFILE '            $type = $args{system_type};' . "\n";
    print OUTFILE '        }' . "\n";
    print OUTFILE '        elsif (( exists $self->{_system_type}) && ( defined $self->{_system_type})){' . "\n";
    print OUTFILE '            $type = $self->{_system_type};' . "\n";
    print OUTFILE '        }' . "\n";
    print OUTFILE '        else {' . "\n";
    print OUTFILE '            $self->{_logger}->logconfess("type was not defined");' . "\n";
    print OUTFILE '        }' . "\n\n";
    print OUTFILE '        $self->setType($type);' . "\n";
    print OUTFILE '    }' . "\n\n";
    print OUTFILE '    return $type;' . "\n";
    print OUTFILE '}' . "\n\n";

    $self->{_logger}->info("Added _getType method for module '$namespace'");
}

   
sub _add_factory_create_method {

    my $self = shift;
    
    my ($namespace, $lookup) = @_;

    print OUTFILE 'sub create {' . "\n\n";


    if (! $self->getSuppressCheckpoints()){
        print OUTFILE '    confess "CHECKPOINT"; ## [RCS_TRIPWIRE] Remove this '.
            'line of code after reviewing this method.' . "\n\n";
    }

    print OUTFILE '    my $type  = $self->_getType(@_);' . "\n\n";
    
    my $typeCtr = 0;

    foreach my $depmod (sort {$a <=> $b } keys %{$lookup->{factory_types_lookup}}){

        $typeCtr++;

        my $type = $lookup->{factory_types_lookup}->{$depmod};

        my $lctype = lc($type);
        my @parts = split('::', $depmod);
        my $varname = lc(pop@parts);

        if ($typeCtr == 1){
            print OUTFILE '    if (lc($type) eq \'' . $lctype . "'){" . "\n\n";
        }
        else {
            print OUTFILE '    elsif (lc($type) eq \'' . $lctype . "'){" . "\n\n";
        }

        print OUTFILE '        my $' . $varname . ' = new ' . $depmod . '(@_);' . "\n";
        print OUTFILE '        if (!defined($' . $varname . ')){' . "\n";
        print OUTFILE '            confess "Could not instantiate ' . $depmod . "\";\n";
        print OUTFILE '        }' . "\n\n";
        print OUTFILE '        return $' . $varname . ';' . "\n";
        print OUTFILE '    }' . "\n";
    }
    
    print OUTFILE '    else {' . "\n";
    print OUTFILE '        confess "type \'$type\' is not currently supported";' . "\n";
    print OUTFILE '    }' . "\n";
    print OUTFILE '}' . "\n\n";
    
    if ($self->getVerbose()){
        print "Wrote create method for module '$namespace'\n";
    }
    
    $self->{_logger}->info("Wrote create method for module '$namespace'");
}

sub _get_app_method_content {

    my $self = shift;
    my ($method_name, $url, $desc, $route_parameters_list, $body_parameters_list) = @_;
    
    my $template_file = $self->getAppMethodTemplateFile();
    if (!defined($template_file)){
        $self->{_logger}->logconfess("template_file was not defined");
    }

    my $route_parameters_list_content = $self->_get_route_parameters_list_content($route_parameters_list);

    my $body_parameters_list_content = $self->_get_body_parameters_list_content($body_parameters_list);

    my $argument_list_content = $self->_get_argument_list_content($route_parameters_list, $body_parameters_list);

    my $lookup = {
        url => $url,
        desc => $desc,
        method_name => $method_name,
        route_parameters_list_content => $route_parameters_list_content,
        body_parameters_list_content => $body_parameters_list_content,
        argument_list_content => $argument_list_content
    };

    my $content = $self->_generate_content_from_template($template_file, $lookup);

    push(@{$self->{_app_method_content_list}}, $content);
}

sub _generate_content_from_template {

    my $self = shift;
    my ($template_file, $lookup) = @_;

    my $tt = new Template({ABSOLUTE => 1});
    if (!defined($tt)){
        $self->{_logger}->logconfess("Could not instantiate TT");
    }

    my $tmp_outfile = $self->getOutdir() . '/out.pm';

    $tt->process($template_file, $lookup, $tmp_outfile) || $self->{_logger}->logconfess("Encountered the following Template::process error:" . $tt->error());
    
    $self->{_logger}->info("Wrote temporary output file '$tmp_outfile'");

    my @lines = read_file($tmp_outfile);

    my $content = join("", @lines);

    unlink($tmp_outfile) || $self->{_logger}->logconfess("Could not unlink temporary output file '$tmp_outfile' : $!");

    $self->{_logger}->info("temporary output file '$tmp_outfile' was removed");

    return $content;
}

sub _write_file {

    my $self = shift;
    my ($namespace) = @_;

    my $outfile = $self->_get_outfile($namespace);


    if ($self->getVerbose()){
        print "Wrote module file '$outfile'\n";
    }

    $self->{_logger}->info("Wrote module file '$outfile'");

    push(@{$self->{_module_file_list}}, $outfile);
}

sub _get_outfile {

    my $self = shift;
    my ($namespace) = @_;

    my $outfile = $self->getOutdir() . '/javascript/model/' . $namespace . '.js';

    $outfile =~ s|\:\:|/|g;

    my $dirname = File::Basename::dirname($outfile);

    if (!-e $dirname){

        mkpath($dirname) || $self->{_logger}->logconfess("Could not create directory '$dirname' : $!");
        
        $self->{_logger}->info("Created output directory '$dirname'");
    }

    return $outfile;
}

no Moose;
__PACKAGE__->meta->make_immutable;

__END__


=head1 NAME

 Umlet::JavaScript::Class::File::Writer
 

=head1 VERSION

 1.0

=head1 SYNOPSIS

 use Umlet::JavaScript::Class::File::Writer;
 my $manager = Umlet::JavaScript::Class::File::Writer::getInstance();
 $manager->commitCodeAndPush($comment);

=head1 AUTHOR

 Jaideep Sundaram

 Copyright Jaideep Sundaram

=head1 METHODS

=over 4

=cut