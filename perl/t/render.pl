#!/usr/bin/perl

use strict;
use utf8;

BEGIN {
  use File::Spec::Functions qw(rel2abs);
  use File::Basename;
  unshift(@INC, dirname(rel2abs($0)).'/../lib');
}

use Config::Neat;
use Config::Neat::Render;
use Data::Dumper;

my $c = Config::Neat->new();
my $r = Config::Neat::Render->new();

my $data = {
    'word' => 'Hello',
    'string_with_spaces' => 'Hello, world!',
    'simple_array' => [1, '2 3', '4 5', 6, 7],
    'wrappable_string' => 'Vestibulum ullamcorper leo quam, vel adipiscing tellus. '.
                          'Phasellus placerat dolor sit amet lorem mattis dictum. '.
                          'Vestibulum luctus malesuada risus, et porttitor lectus lobortis et.',
    'wrappable_array' => [
        'this particular array item will not wrap since it contains spaces and thus is enclosed in backticks',
        'Aa','Bb','Cc','Dd','Ee','Ff','Gg','Hh','Ii','Jj','Kk','Ll','Mm','Nn','Oo','Pp','Qq','Rr',
        'Ss','Tt','Uu','Vv','Ww','Xx','Yy','Zz',
    ],
    'subsection_1' => {
        'etc' => 'foo bar',
        'pwd' => ['foo', 'foo bar', 'ba``z', '`'],
    },
    'subsection_2' => {
        'true_parameter'  => 1,
        'false_parameter' => undef,
        'subtree' => {
            'empty_string' => '',
            'array_of_empty_strings' => ['', '', ''],
        },
    },
    'array_of_hashes' => [
        {
            'param1' => 'value1',
        },
        {
            'param2' => 'value2',
        },
        {
            'param3' => 'value3',
        },
    ],
};

my @order = qw(
    word string_with_spaces simple_array wrappable_string
    wrappable_array subsection_1 subsection_2 array_of_hashes

    etc pwd

    true_parameter false_parameter subtree

    empty_string array_of_empty_strings
);

#my $sort = undef; # unsorted
#my $sort = 1; # sorted alphabetically
my $sort = \@order; # sort in the order

my $options = {
    sort      => $sort,
    align_all => 1,
};

my $text1 = $r->render($data, $options);
my $data1 = $c->parse($text1);
my $text2 = $r->render($data1, $options);
if ($text1 ne $text2) {
    warn "WARNING: Text from two passes differs\n";

    print "# =[1]====\n";
    print $text1;
    print "# =[2]====\n";
    print $text2;
    print "# =[1:data]=====\n";
    print "/*\n";
    print Dumper($data1);
    print "*/";
} else {
    print $text1;
}
