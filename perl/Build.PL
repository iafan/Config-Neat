use 5.006;
use strict;
use warnings FATAL => 'all';
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'Config::Neat',
    license             => 'perl',
    dist_author         => 'Igor Afanasyev <igor.afanasyev@gmail.com>',
    dist_version_from   => 'lib/Config/Neat.pm',
    release_status      => 'testing',
    configure_requires  => {
        'Module::Build' => 0,
    },
    build_requires      => {
        'Test::More'    => 0,
    },
    requires => {
        'Tie::IxHash'   => '1.22',
    },
    add_to_cleanup      => ['Config-Neat-*', 'Makefile.PL', 'MYMETA.*', 'META.*'],
    create_makefile_pl  => 'traditional',
);

$builder->create_build_script();
