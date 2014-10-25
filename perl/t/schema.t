#!/usr/bin/perl

use strict;

BEGIN {
    use File::Spec::Functions qw(rel2abs catfile);
    use File::Basename;
    unshift(@INC, catfile(dirname(rel2abs($0)), '../lib'));
}

$| = 1; # disable output buffering;

use Test::More 0.94;

use_ok('Config::Neat');
use_ok('Config::Neat::Inheritable');
use_ok('Config::Neat::Schema');

use Config::Neat::Util qw(is_any_array is_any_hash);

my $c = Config::Neat->new();
ok($c, '$c is defined');

my $s = Config::Neat::Schema->new();
ok($s, '$s is defined');

ok($s->load(catfile(dirname(rel2abs($0)), 'data/schema/schema.nconf')), 'Schema loaded successfully');

my $data;

_load_conf('01');
eval { $s->validate($data) };
like($@, qr|^Node '/abc' is not defined in the schema |, '01.nconf validation should fail because of "/abc" node not having been defined in the schema');

_load_conf('02');
eval { $s->validate($data) };
like($@, qr|^Can't validate '/foo/bar/baz', because schema contains no definition for it |, '02.nconf validation should fail because of "/foo/bar/baz" node not having been defined in the schema');

_load_conf('03');
$s->validate($data);
ok(ref($data->{foo}->{etc}->{some_key}) eq 'ARRAY', '03.nconf: /foo/etc/some_key is now an array');

_load_conf('04');
_validate_conf('04');
ok($data->{path}->{some_key} eq 'foo bar baz', '04.nconf: /path/some_key is now a string casted from array');
ok($data->{path}->{some_key_2} eq 'foo  bar  baz', '04.nconf: /path/some_key_2 is remaining a string');

ok($data->{path2}->{some_key}->as_string eq 'foo bar baz', '04.nconf: /path2/some_key is an array');
ok($data->{path2}->{some_key_2}->as_string eq 'foo  bar  baz', '04.nconf: /path2/some_key_2 is an array');

_load_conf('05');
_validate_conf('05');
ok($data->{path} eq 'foo bar baz', '05.nconf: /path is now a string casted from array');
ok($data->{path2}->as_string eq 'foo bar baz', '05.nconf: /path2 is an array');

_load_conf('06');
_validate_conf('06');

_load_conf('07');
_validate_conf('07');

_load_conf('08');
_validate_conf('08');
ok(
    $data->{options}->{opt1} &&
    $data->{options}->{opt2} &&
    $data->{options}->{opt3} &&
    $data->{options}->{opt4} &&
    $data->{options}->{opt5}, '08.nconf: all true boolean values are true');

ok(
    !$data->{options}->{opt6} &&
    !$data->{options}->{opt7} &&
    !$data->{options}->{opt8} &&
    !$data->{options}->{opt9} &&
    !$data->{options}->{opt10}, '08.nconf: all false boolean values are false');

ok(
    !$data->{options}->{opt11} &&
    !$data->{options}->{opt12}, '08.nconf: all garbage boolean values are false');

_load_conf('09');
_validate_conf('09');
ok(ref($data->{jobs}) eq 'ARRAY', '09.nconf: /jobs is now an array of objects');

_load_conf('10');
_validate_conf('10');
ok(ref($data->{jobs}) eq 'ARRAY', '10.nconf: /jobs is now an array of objects');

_load_conf('11');
eval { $s->validate($data) };
like($@, qr|^Can't cast '/foo/bar' to ARRAY, since it is a HASH containing non-sequential keys |, '11.nconf validation should fail because of "/foo/bar" node containing non-sequential keys');

_load_conf('12');
_validate_conf('12');

_load_conf('13');
_validate_conf('13');

ok(is_any_array($data->{single_node})
   && scalar(@{$data->{single_node}}) == 1
   && is_any_array($data->{single_node}->[0])
   && scalar(@{$data->{single_node}->[0]}) == 3,
    '13.nconf: single_node is now an array containing one element: an array of scalars');

_load_conf('14');
_validate_conf('14');

ok(is_any_array($data->{single_hash_node})
   && scalar(@{$data->{single_hash_node}}) == 1
   && is_any_hash($data->{single_hash_node}->[0])
   && $data->{single_hash_node}->[0]->{foo} == 'bar baz',
    '14.nconf: single_hash_node is now an array containing one element: a hash');

ok(is_any_array($data->{repeating_hash_node})
   && scalar(@{$data->{repeating_hash_node}}) == 2
   && is_any_hash($data->{repeating_hash_node}->[0])
   && $data->{repeating_hash_node}->[0]->{foo} == 'bar',
    '14.nconf: repeating_hash_node remains intact');

done_testing();

sub _load_conf {
    my $number = shift;
    ok($data = $c->parse_file(catfile(dirname(rel2abs($0)), "data/schema/$number.nconf")), "$number.nconf loaded successfully");
}

sub _validate_conf {
    my $number = shift;
    ok($s->validate($data), "$number.nconf passed validation");
}
