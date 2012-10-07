#!/usr/bin/perl

use strict;
use utf8;

BEGIN {
  use File::Spec::Functions qw(rel2abs);
  use File::Basename;
  unshift(@INC, dirname(rel2abs($0)).'/../lib');
}

die "Usage: $0 neat-config-file\n" unless $ARGV[0];

use Config::Neat::Inheritable;
use Config::Neat::Render;

my $cfg = Config::Neat::Inheritable->new();
my $data = $cfg->parse_file($ARGV[0]);

my $r = Config::Neat::Render->new();
print $r->render($data);
