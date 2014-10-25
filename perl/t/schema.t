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

#use Data::Dumper; print Dumper($s->{schema}); exit;

my $data;

subtest '01.nconf' => sub {
    _load_conf('01');
    eval { $s->validate($data) };
    like($@, qr|^Node '/abc' is not defined in the schema |, '01.nconf validation should fail because of "/abc" node not having been defined in the schema');
};

subtest '02.nconf' => sub {
    _load_conf('02');
    eval { $s->validate($data) };
    like($@, qr|^Can't validate '/foo/bar/baz', because schema contains no definition for it |, '02.nconf validation should fail because of "/foo/bar/baz" node not having been defined in the schema');
};

subtest '03.nconf' => sub {
    _load_conf('03');
    $s->validate($data);
    ok(ref($data->{foo}->{etc}->{some_key}) eq 'ARRAY', '03.nconf: /foo/etc/some_key is now an array');
};

subtest '04.nconf' => sub {
    _load_conf('04');
    _validate_conf('04');
    ok($data->{path}->{some_key} eq 'foo bar baz', '04.nconf: /path/some_key is now a string casted from array');
    ok($data->{path}->{some_key_2} eq 'foo  bar  baz', '04.nconf: /path/some_key_2 is remaining a string');

    ok($data->{path2}->{some_key}->as_string eq 'foo bar baz', '04.nconf: /path2/some_key is an array');
    ok($data->{path2}->{some_key_2}->as_string eq 'foo  bar  baz', '04.nconf: /path2/some_key_2 is an array');
};

subtest '05.nconf' => sub {
    _load_conf('05');
    _validate_conf('05');
    ok($data->{path} eq 'foo bar baz', '05.nconf: /path is now a string casted from array');
    ok($data->{path2}->as_string eq 'foo bar baz', '05.nconf: /path2 is an array');
};

subtest '06.nconf' => sub {
    _load_conf('06');
    _validate_conf('06');
};

subtest '07.nconf' => sub {
    _load_conf('07');
    _validate_conf('07');
};

subtest '08.nconf' => sub {
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
};

subtest '09.nconf' => sub {
    _load_conf('09');
    _validate_conf('09');
    ok(ref($data->{jobs}) eq 'ARRAY', '09.nconf: /jobs is now an array of objects');
};

subtest '10.nconf' => sub {
    _load_conf('10');
    _validate_conf('10');
    ok(ref($data->{jobs}) eq 'ARRAY', '10.nconf: /jobs is now an array of objects');
};

subtest '11.nconf' => sub {
    _load_conf('11');
    eval { $s->validate($data) };
    like($@, qr|^Can't cast '/foo/bar' to ARRAY, since it is a HASH containing non-sequential keys |, '11.nconf validation should fail because of "/foo/bar" node containing non-sequential keys');
};

subtest '12.nconf' => sub {
    _load_conf('12');
    _validate_conf('12');
};

subtest '13.nconf' => sub {
    _load_conf('13');
    _validate_conf('13');

    subtest '13.nconf: single_node' => sub {
        ok(is_any_array($data->{single_node}));
        ok(scalar(@{$data->{single_node}}) == 1);
        ok(is_any_array($data->{single_node}->[0]));
        ok(scalar(@{$data->{single_node}->[0]}) == 3);
    };

    subtest '13.nconf: repeating_node' => sub {
        ok(is_any_array($data->{repeating_node}));
        ok(scalar(@{$data->{repeating_node}}) == 3);

        ok(is_any_array($data->{repeating_node}->[0]));
        ok($data->{repeating_node}->[0]->as_string eq 'foo bar');

        ok(is_any_array($data->{repeating_node}->[1]));
        ok($data->{repeating_node}->[1]->as_string eq 'baz etc');

        ok(is_any_hash($data->{repeating_node}->[2]));
        ok($data->{repeating_node}->[2]->{123}->as_string eq '456');
    };
};

subtest '14.nconf' => sub {
    _load_conf('14');
    _validate_conf('14');

    subtest '14.nconf: single_hash_node' => sub {
        ok(is_any_array($data->{single_hash_node}));
        ok(scalar(@{$data->{single_hash_node}}) == 1);
        ok(is_any_hash($data->{single_hash_node}->[0]));
        ok($data->{single_hash_node}->[0]->{foo} eq 'bar baz');
    };

    subtest '14.nconf: repeating_hash_node' => sub {
        ok(is_any_array($data->{repeating_hash_node}));
        ok(scalar(@{$data->{repeating_hash_node}}) == 2);

        ok(is_any_hash($data->{repeating_hash_node}->[0]));
        ok($data->{repeating_hash_node}->[0]->{foo} eq 'bar');

        ok(is_any_hash($data->{repeating_hash_node}->[1]));
        ok($data->{repeating_hash_node}->[1]->{baz} eq 'etc');
    };
};

done_testing();

sub _load_conf {
    my $number = shift;
    ok($data = $c->parse_file(catfile(dirname(rel2abs($0)), "data/schema/$number.nconf")), "$number.nconf loaded successfully");
}

sub _validate_conf {
    my $number = shift;
    ok($s->validate($data), "$number.nconf passed validation");
}
