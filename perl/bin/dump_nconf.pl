#!/usr/bin/perl

use strict;
use utf8;

BEGIN {
  use File::Spec::Functions qw(rel2abs);
  use File::Basename;
  unshift(@INC, dirname(rel2abs($0)).'/../lib');
}

use Config::Neat;
use Data::Dumper;

my $cfg = Config::Neat->new();
my $data = $cfg->parse(join('', <>)); # Read data from STDIN

print Dumper($data);