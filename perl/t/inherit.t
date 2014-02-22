#!/usr/bin/perl

use strict;

BEGIN {
    use File::Spec::Functions qw(rel2abs catfile);
    use File::Basename;
    unshift(@INC, catfile(dirname(rel2abs($0)), '../lib'));
}

$| = 1; # disable output buffering;

use File::Find;
use File::Slurp;
use Getopt::Long;
use Test::More;

my ($init);

GetOptions("init" => \$init);

use_ok('Config::Neat::Inheritable');
use_ok('Config::Neat::Render');

my $c = Config::Neat::Inheritable->new();
ok($c, '$cfg is defined');

my $r = Config::Neat::Render->new();
ok($r, '$r is defined');

eval {
    $c->parse_file(catfile(dirname(rel2abs($0)), '../../sample/readme.nconf'));
};
like($@, qr/^Can't open \[C:\\path\\to\\file\]: No such file or directory/, 'readme.nconf parsing should fail because of unresolved inheritance path');

my @nconf_files;

find(sub {
    push @nconf_files, $File::Find::name if (-f $_ && /\.nconf$/);
}, catfile(dirname(rel2abs($0)), 'data/inherit/tests'));

foreach my $test_filename (@nconf_files) {
    $test_filename =~ s|\\|/|g;
    subtest "$test_filename", sub {
        my $reference_filename = $test_filename;
        $reference_filename =~ s|/inherit/tests/|/inherit/reference/|;

        if ($init) {
            # init mode: create reference file
            my $data1 = $c->parse_file($test_filename);
            ok($data1, '$data1 is defined');

            my $text1 = $r->render($data1);
            ok($text1, '$text1 is defined');

            write_file($reference_filename, {binmode => ':utf8'}, $text1);
            ok(-f $reference_filename, "$reference_filename file should exist");
        } else {
            # test mode: read and compare reference file
            BAIL_OUT("$reference_filename file should exist; can't continue") unless -f $reference_filename;

            my $data1 = $c->parse_file($test_filename);
            ok($data1, '$data1 is defined');

            my $text1 = $r->render($data1);
            ok($text1, '$text1 is defined');

            my $reference_text = read_file($reference_filename, {binmode => ':utf8'});
            is($text1, $reference_text, 'Text should be equal to reference file contents: '.$reference_filename);
        }
    }
}

done_testing();