use 5.012;
use strict;
use warnings;
use Module::Build;
Module::Build->VERSION('0.4004');

my $builder = Module::Build->new(
    module_name         => 'Docker::Construct',
    license             => 'perl_5',
    dist_author         => q{Cameron Tauxe <camerontauxe@gmail.com>},
    dist_version_from   => 'lib/Docker/Construct.pm',
    release_status      => 'stable',
    configure_requires => {
        'Module::Build' => '0.4004',
    },
    test_requires => {
        'Test::More' => '0',
    },
    requires => {
        #'ABC'              => '1.6',
        #'Foo::Bar::Module' => '5.0401',
    },
    add_to_cleanup     => [ 'Docker-Construct-*' ],
);

$builder->create_build_script();
