#!/usr/bin/perl

use strict;

BEGIN {
    use File::Spec::Functions qw(rel2abs catfile);
    use File::Basename;
    unshift(@INC, catfile(dirname(rel2abs($0)), '../lib'));
}

$| = 1; # disable output buffering;

use Test::More;

use_ok('Config::Neat');

my $c = Config::Neat->new();
ok($c, '$c is defined');

my $data;

_load_conf('01');
ok($data->{test1}->as_string eq 'foo1');
ok($data->{test2}->as_string eq 'foo bar');
ok($data->{test3}->as_string eq 'foo  bar');
ok($data->{test4}->as_string eq '/* foo */');
ok($data->{test5}->as_string eq '\/');
ok($data->{test6}->as_string eq '`');
ok($data->{test7}->as_string eq '`');
ok($data->{test8}->as_string eq '\/x');

done_testing();

sub _load_conf {
    my $number = shift;
    ok($data = $c->parse_file(catfile(dirname(rel2abs($0)), "data/parse/$number.nconf")), "$number.nconf loaded successfully");
}
