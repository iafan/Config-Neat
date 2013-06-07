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

ok($data = $c->parse_file(catfile(dirname(rel2abs($0)), 'data/schema/01.nconf')), '01.nconf loaded successfully');
eval { $s->validate($data) };
like($@, qr|^Node '/abc' is not defined in the schema |, '01.nconf validation should fail because of "/abc" node');

ok($data = $c->parse_file(catfile(dirname(rel2abs($0)), 'data/schema/02.nconf')), '02.nconf loaded successfully');
eval { $s->validate($data) };
like($@, qr|^'/foo/bar' is HASH, while it is expected to be ARRAY |, '02.nconf validation should fail because of "/foo/bar" node');

ok($data = $c->parse_file(catfile(dirname(rel2abs($0)), 'data/schema/03.nconf')), '03.nconf loaded successfully');
eval { $s->validate($data) };
like($@, qr|^'/foo/etc/some_key' is HASH, while it is expected to be ARRAY |, '03.nconf validation should fail because of "/foo/bar/some_key" node');

ok($data = $c->parse_file(catfile(dirname(rel2abs($0)), 'data/schema/04.nconf')), '04.nconf loaded successfully');
ok($s->validate($data), '04.nconf passed validation');
ok($data->{path}->{some_key} eq 'foo bar baz', '04.nconf: /path/some_key is now a string casted from array');
ok($data->{path}->{some_key_2} eq 'foo  bar  baz', '04.nconf: /path/some_key is remaining a string');

done_testing();
