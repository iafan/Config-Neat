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
use_ok('Config::Neat::Schema');

my $c = Config::Neat->new();
ok($c, '$c is defined');

my $s = Config::Neat::Schema->new();
ok($s, '$s is defined');

ok($s->load(catfile(dirname(rel2abs($0)), 'data/schema/schema.nconf')), 'Schema loaded successfully');

my $data;

_load_conf('01');
eval { $s->validate($data) };
like($@, qr|^Node '/abc' is not defined in the schema |, '01.nconf validation should fail because of "/abc" node');

_load_conf('02');
eval { $s->validate($data) };
like($@, qr|^'/foo/bar' is HASH, while it is expected to be ARRAY |, '02.nconf validation should fail because of "/foo/bar" node');

_load_conf('03');
eval { $s->validate($data) };
like($@, qr|^'/foo/etc/some_key' is HASH, while it is expected to be ARRAY |, '03.nconf validation should fail because of "/foo/bar/some_key" node');

_load_conf('04');
ok($s->validate($data), '04.nconf passed validation');
ok($data->{path}->{some_key} eq 'foo bar baz', '04.nconf: /path/some_key is now a string casted from array');
ok($data->{path}->{some_key_2} eq 'foo  bar  baz', '04.nconf: /path/some_key_2 is remaining a string');

ok($data->{path2}->{some_key}->as_string eq 'foo bar baz', '04.nconf: /path2/some_key is an array');
ok($data->{path2}->{some_key_2}->as_string eq 'foo  bar  baz', '04.nconf: /path2/some_key_2 is an array');

_load_conf('05');
ok($s->validate($data), '05.nconf passed validation');
ok($data->{path} eq 'foo bar baz', '05.nconf: /path is now a string casted from array');
ok($data->{path2}->as_string eq 'foo bar baz', '05.nconf: /path2 is an array');

_load_conf('06');
_load_conf('07');

done_testing();

sub _load_conf {
    my $number = shift;
    ok($data = $c->parse_file(catfile(dirname(rel2abs($0)), "data/schema/$number.nconf")), "$number.nconf loaded successfully");
}
