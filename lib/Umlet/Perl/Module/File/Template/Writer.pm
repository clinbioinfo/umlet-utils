package Umlet::Perl::Module::File::Template::Writer;

use Moose;
use Cwd;
use String::CamelCase qw(decamelize);
use Data::Dumper;
use File::Path;
use FindBin;
use Term::ANSIColor;
use Template;
use File::Slurp;


use Umlet::Config::Manager;

extends 'Umlet::Perl::Module::File::Writer';

use constant TRUE  => 1;

use constant FALSE => 0;

use constant DEFAULT_SINGLETON_MODULE_TEMPLATE_FILE => "$FindBin::Bin/../template/perl_singleton_module_file_tmpl.tt";

use constant DEFAULT_MODULE_TEMPLATE_FILE => "$FindBin::Bin/../template/perl_module_file_tmpl.tt";

use constant DEFAULT_MOOSE_ATTRIBUTE_TEMPLATE_FILE => "$FindBin::Bin/../template/perl_moose_attribute_tmpl.tt";

use constant DEFAULT_INIT_METHOD_DEFINITION_TEMPLATE_FILE => "$FindBin::Bin/../template/perl_init_method_definition_tmpl.tt";

use constant DEFAULT_METHOD_DEFINITION_TEMPLATE_FILE => "$FindBin::Bin/../template/perl_method_definition_tmpl.tt";

use constant DEFAULT_TEST_SCRIPT_TEMPLATE_FILE => "$FindBin::Bin/../template/perl_module_test_script_file_tmpl.tt";


## Singleton support
my $instance;

has 'singleton_module_template_file' => (
    is       => 'rw',
    isa      => 'Str',
    writer   => 'setSingletonModuleTemplateFile',
    reader   => 'getSingletonModuleTemplateFile',
    required => FALSE,
    default  => DEFAULT_SINGLETON_MODULE_TEMPLATE_FILE
    );

has 'module_template_file' => (
    is       => 'rw',
    isa      => 'Str',
    writer   => 'setModuleTemplateFile',
    reader   => 'getModuleTemplateFile',
    required => FALSE,
    default  => DEFAULT_MODULE_TEMPLATE_FILE
    );

has 'moose_attribute_template_file' => (
    is       => 'rw',
    isa      => 'Str',
    writer   => 'setMooseAttributeTemplateFile',
    reader   => 'getMooseAttributeTemplateFile',
    required => FALSE,
    default  => DEFAULT_MOOSE_ATTRIBUTE_TEMPLATE_FILE
    );

has 'init_method_definition_template_file' => (
    is       => 'rw',
    isa      => 'Str',
    writer   => 'setInitMethodDefinitionTemplateFile',
    reader   => 'getInitMethodDefinitionTemplateFile',
    required => FALSE,
    default  => DEFAULT_INIT_METHOD_DEFINITION_TEMPLATE_FILE
    );

has 'method_definition_template_file' => (
    is       => 'rw',
    isa      => 'Str',
    writer   => 'setMethodDefinitionTemplateFile',
    reader   => 'getMethodDefinitionTemplateFile',
    required => FALSE,
    default  => DEFAULT_METHOD_DEFINITION_TEMPLATE_FILE
    );

has 'test_script_template_file' => (
    is       => 'rw',
    isa      => 'Str',
    writer   => 'setTestScriptTemplateFile',
    reader   => 'getTestScriptTemplateFile',
    required => FALSE,
    default  => DEFAULT_TEST_SCRIPT_TEMPLATE_FILE
    );

sub getInstance {

    if (!defined($instance)){

        $instance = new Umlet::Perl::Module::File::Template::Writer(@_);

        if (!defined($instance)){

            confess "Could not instantiate Umlet::Perl::Module::File::Template::Writer";
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

    $self->{_module_lookup} = $master_lookup;

    my $outdir = $self->getOutdir();

    if ($self->getVerbose()){
        print "About to create the API in directory '$outdir'\n";
    }

    $self->{_logger}->info("About to create the API in directory '$outdir'");

    foreach my $module_name (sort keys %{$master_lookup}){

        $self->{_current_module_name} = undef;
        $self->{_current_module_details} = {};

        my $module_lookup = $master_lookup->{$module_name};

        if ((exists $master_lookup->{$module_name}->{already_implemented}) && 
            ($master_lookup->{$module_name}->{already_implemented} ==  TRUE)){

            if ($self->getSkipGreenModules()){

                $self->{_logger}->info("Will skip creation of module '$module_name' since UXF indicates the module has already been implemented");
                next;
            }
        }

        $self->{_current_module_name} = $module_name;

        my $template_file;

        if (( exists $module_lookup->{singleton}) &&
            ( defined $module_lookup->{singleton})){

            $self->{_current_module_details}->{is_singleton} = $module_lookup->{singleton};

            $template_file = $self->getSingletonModuleTemplateFile();
        }
        else {
            $template_file = $self->getSingletonModuleTemplateFile();
        }     
       
        $self->_add_dependencies($module_lookup);
        
        $self->_add_extends($module_lookup);
        
        $self->_add_constants($module_lookup);
                
        $self->_add_private_data_members($module_lookup);
        
        $self->{_current_module_details}->{method_definition_list} = [];

        $self->_add_private_methods($module_lookup);
        
        $self->_add_public_methods($module_lookup);

        $self->_create_test_script($module_name, $outdir);

        my $lookup = {
            software_version    => $self->getSoftwareVersion(),
            author              => $self->getSoftwareAuthor(),
            copyright           => $self->getCopyright(),
            package_name        => $self->{_current_module_name},
            use_module_list     => $self->{_current_module_details}->{use_module_list},
            extends_module_list => $self->{_current_module_details}->{extends_module_list},
            constants_list      => $self->{_current_module_details}->{constants_list},
            private_data_member_definition_list => $self->{_current_module_details}->{private_data_member_definition_list},
            init_method_statement_list  => $self->{_current_module_details}->{init_method_statement_list},
            init_method_definition_list => $self->{_current_module_details}->{init_method_definition_list},
            method_definition_list      => $self->{_current_module_details}->{method_definition_list}            
        };

        my $outfile = $self->_get_outfile($self->{_current_module_name});

        $self->_write_module_file($template_file, $lookup, $outfile);
    }

    if ($self->getVerbose()){
        print "Have created the API in the directory '$outdir'\n";
    }

    $self->{_logger}->info("Have created the API in the directory '$outdir'");
}


sub _write_module_file {

    my $self = shift;
    my ($template_file, $lookup, $outfile) = @_;

    my $tt = new Template({ABSOLUTE => 1});
    if (!defined($tt)){
        $self->{_logger}->logconfess("Could not instantiate TT");
    }

    $tt->process($template_file, $lookup, $outfile) || $self->{_logger}->logconfess("Encountered the following Template::process error:" . $tt->error());
    
    if ($self->getVerbose()){
        print "Wrote module file '$outfile' for module '$self->{_current_module_name}'\n";
    }

    $self->{_logger}->info("Wrote module file '$outfile' for module '$self->{_current_module_name}'");

    push(@{$self->{_module_file_list}}, $outfile);
}

sub _get_outfile {

    my $self = shift;
    my ($namespace) = @_;

    my $outdir = $self->getOutdir() . '/lib/';

    my $outfile = $outdir . $namespace;

    $outfile =~ s|::|/|g;

    my $dirname = File::Basename::dirname($outfile);

    if (!-e $dirname){

        mkpath($dirname) || $self->{_logger}->logconfess("Could not create directory '$dirname' : $!");
        
        $self->{_logger}->info("Created output directory '$dirname'");
    }


    $outfile .= '.pm';

    return $outfile;
}


sub _print_summary {

    my $self = shift;
    
    print "Created the following test scripts:\n";
    print join("\n", @{$self->{_test_script_file_list}}) . "\n";

    print "\nCreated the following test scripts:\n";
    print join("\n", @{$self->{_module_file_list}}) . "\n";
}


sub _add_dependencies {

    my $self = shift;

    my ($module_lookup) = @_;

    if (( exists $module_lookup->{depends_on_list}) && 
        ( defined $module_lookup->{depends_on_list})){

        my $ctr = 0;
        my $list = [];

        foreach my $dependency (@{$module_lookup->{depends_on_list}}){
            
            push(@{$list}, $dependency);

            my $init_method_name = $dependency;

            $init_method_name =~ s|::||g;
            
            push(@{$self->{_current_module_details}->{init_method_statement_list}}, $init_method_name);            
            
            $self->_derive_init_method_definition_content($init_method_name, $dependency);

            $ctr++;
        }

        $self->{_current_module_details}->{use_module_list} = $list;

        if ($self->getVerbose()){
            print "Added '$ctr' dependencies\n";
        }

        $self->{_logger}->info("Added '$ctr' dependencies");
    }
    else {
        $self->{_logger}->info("Looks like there are not dependencies for module '$self->{_current_module_name}'");
    }
}

sub _derive_init_method_definition_content {

    my $self = shift;
    my ($init_method_name, $dependency) = @_;

    my $template_file = $self->getInitMethodDefinitionTemplateFile();

    my $variable_name = $dependency;

    $variable_name =~ s|::||g;

    $variable_name = lcfirst($variable_name);

    my $lookup = {
        init_method_name => $init_method_name,
        dependency       => $dependency,
        variable_name    => $variable_name
    };

    my $content = $self->_generate_content_from_template($template_file, $lookup);

    push(@{$self->{_current_module_details}->{init_method_definition_list}}, $content);            
}

sub _add_extends {

    my $self = shift;

    my ($module_lookup) = @_;

    if (( exists $module_lookup->{extends_list}) && 
        ( defined $module_lookup->{extends_list})){

        my $ctr = 0;

        my $list = [];

        foreach my $extends (@{$module_lookup->{extends_list}}){
            
            push(@{$list}, $extends);
            
            $ctr++;
        }

        $self->{_current_module_details}->{extends_module_list} = $list;

        if ($self->getVerbose()){
            print "Added '$ctr' extends clauses\n";
        }

        $self->{_logger}->info("Added '$ctr' extends clauses");
    }
    else {
        $self->{_logger}->info("Looks like this module '$self->{_current_module_name}' does not inherit from any other module");
    }
}
sub _add_constants {

    my $self = shift;

    my ($module_lookup) = @_;

    if (( exists $module_lookup->{constant_list}) &&
        ( defined $module_lookup->{constant_list})){


        my $ctr = 0 ;
        my $list = [];
       
        foreach my $constantArrayRef (@{$module_lookup->{constant_list}}){
            
            push(@{$list}, [uc($constantArrayRef->[0]), $constantArrayRef->[1]]);

            $ctr++;
        }

        $self->{_current_module_details}->{constants_list} = $list;

        if ($self->getVerbose()){
            print "Added '$ctr' constants\n";
        }

        $self->{_logger}->info("Added '$ctr' constants for module '$self->{_current_module_name}'");
    }
    else {
        $self->{_logger}->info("Looks like module '$self->{_current_module_name}' does not have any constants");
    }
}


sub _add_private_data_members {

    my $self = shift;

    my ($module_lookup) = @_;
  
    if (( exists $module_lookup->{private_data_members_list}) &&
        ( defined $module_lookup->{private_data_members_list})){

        my $ctr = 0 ;

        my $list = [];

        my $template_file = $self->getMooseAttributeTemplateFile();

        foreach my $arrayRef (@{$module_lookup->{private_data_members_list}}){
        
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

            my $lookup = {
                attribute_name => lc($name),
                access_type    => 'rw',
                data_type      => $isa,
                method_name    => $mooseMethodName,
                is_required    => TRUE,
                default        => 'N/A' 
            };

            my $content = $self->_generate_content_from_template($template_file, $lookup);

            push(@{$list}, $content);

            $ctr++;
        }

        $self->{_current_module_details}->{private_data_member_definition_list} = $list;

        if ($self->getVerbose()){
            print "Added '$ctr' private data members\n";
        }
    }
    else {
        $self->{_logger}->info("Looks like module '$self->{_current_module_name}' does not have any private data members");    
    }
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

sub _add_public_methods {

    my $self = shift;
    my ($module_lookup) = @_;

    if (( exists $module_lookup->{public_methods_list}) && 
        ( defined $module_lookup->{public_methods_list})){
        
        $self->_add_methods($module_lookup, 'public');
    }
    else {
        $self->{_logger}->info("Looks like module '$self->{_current_module_name}' does not have any public methods");
    }
}

sub _add_private_methods {

    my $self = shift;
    my ($module_lookup) = @_;

    if (( exists $module_lookup->{private_methods_list}) && 
        ( defined $module_lookup->{private_methods_list})){
        
        $self->_add_methods($module_lookup, 'private');
    }
    else {
        $self->{_logger}->info("Looks like module '$self->{_current_module_name}' does not have any private methods");
    }
}
            
sub _add_methods {

    my $self = shift;
    my ($module_lookup, $methodType) = @_;

    my $methodTypeKey = 'public_methods_list';

    if ($methodType eq 'private'){
        $methodTypeKey = 'private_methods_list';
    }

    my $template_file = $self->getMethodDefinitionTemplateFile();

    my $ctr = 0;

    foreach my $arrayRef (@{$module_lookup->{$methodTypeKey}}){

        my $method_name = $arrayRef->[0];

        if ($methodType eq 'private'){
            $method_name = '_' . $method_name->[0];
        }

        if ($method_name =~ m|^\+|){
            $method_name =~ s|^\+||;
        }

        if ($method_name =~ m|^\-|){
            $method_name =~ s|^\-|_|;
        }


        my $lookup = {method_name => $method_name};
              
        my $parameterList = $arrayRef->[1];

        if (defined($parameterList)){

            $parameterList =~ s/\s//g; ## Remove all whitespaces 

            my @paramList = split(',', $parameterList);

            my @argumentList;

            foreach my $param (@paramList){
                
                push(@argumentList, '$'. $param);
            }

            $lookup->{parameter_name_list_content} = join(', ', @argumentList);

            $lookup->{has_parameter_list} = TRUE;

            $lookup->{parameter_name_list} = \@paramList;

        }
        else {
            $self->{_logger}->info("There were no parameters for method '$method_name' in module '$self->{_current_module_name}'");
        }


        my $returnDataType = $arrayRef->[2];

        if (defined($returnDataType)){

            $lookup->{has_return_datatype} = TRUE;

            $lookup->{return_datatype} = $returnDataType;
        }
        else {
            $self->{_logger}->info("There was no return data type for method '$method_name' in module '$self->{_current_module_name}'");
        }           

        my $content = $self->_generate_content_from_template($template_file, $lookup);

        push(@{$self->{_current_module_details}->{method_definition_list}}, $content);
        
        $ctr++;
    }

    if ($self->getVerbose()){
        print "Added '$ctr' $methodType method definitions to module '$self->{_current_module_name}'\n";
    }

    $self->{_logger}->info("Added '$ctr' $methodType method definitions to module '$self->{_current_module_name}'");
}

sub _create_test_script {

    my $self = shift;  
    my ($module, $outdir) = @_;

    my $script_name = $outdir . '/test/test_' . $module;

    $script_name =~ s|::|_|g;

    if (-e $script_name){

        my $bakfile = $script_name . '.bak';

        copy ($script_name, $bakfile) || $self->{_logger}->logconfess("Could not copy '$script_name' to '$bakfile' : $!");

        $self->{_logger}->info("Copied '$script_name' to '$bakfile'");
    }

    my $lookup = {module_name => $module};

    my $template_file = $self->getTestScriptTemplateFile();

    $self->_write_test_script_file($template_file, $lookup, $script_name);
}

sub _write_test_script_file {

    my $self = shift;
    my ($template_file, $lookup, $outfile) = @_;

    my $tt = new Template({ABSOLUTE => 1});
    if (!defined($tt)){
        $self->{_logger}->logconfess("Could not instantiate TT");
    }

    $tt->process($template_file, $lookup, $outfile) || $self->{_logger}->logconfess("Encountered the following Template::process error:" . $tt->error());
    
    if ($self->getVerbose()){
        print "Wrote test script file '$outfile' for module '$self->{_current_module_name}'\n";
    }

    $self->{_logger}->info("Wrote test script file '$outfile' for module '$self->{_current_module_name}'");

    push(@{$self->{_test_script_file_list}}, $outfile);
}

no Moose;
__PACKAGE__->meta->make_immutable;

__END__


=head1 NAME

 Umlet::Perl::Module::File::Template::Writer
 

=head1 VERSION

 1.0

=head1 SYNOPSIS

 use Umlet::Perl::Module::File::Template::Writer;
 my $manager = Umlet::Perl::Module::File::Template::Writer::getInstance();
 $manager->commitCodeAndPush($comment);

=head1 AUTHOR

 Jaideep Sundaram

 Copyright Jaideep Sundaram

=head1 METHODS

=over 4

=cut