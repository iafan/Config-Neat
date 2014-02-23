# Copyright (C) 2012-2014 Igor Afanasyev, https://github.com/iafan/Config-Neat

=head1 NAME

Config::Neat::Inheritable - Config::Neat files with inheritance

=head1 SYNOPSIS

File 01.nconf:

    foo {
        bar         baz

        etc {
            pwd     1
        }
    }
    abc             def

File 02.nconf:

    @inherit        01.nconf

    +foo {
        bar         replace
    }

    -abc

Resulting data structure will be equivalent to:

    foo {
        bar         replace

        etc {
            pwd     1
        }
    }

Within C<@inherit>, you can use selectors as slash-delimited paths to the node
within a target file, for example:

    whatever {
        @inherit    01.nconf#foo/etc
        bar         replace
    }

Resulting data structure will be equivalent to:

    whatever {
        pwd         1
        bar         replace
    }

=cut

package Config::Neat::Inheritable;

our $VERSION = '0.2';

use strict;

use Config::Neat;
use File::Spec::Functions qw(rel2abs);
use File::Basename qw(dirname);
use Storable qw(dclone);

#
# Initialize object
#
sub new {
    my ($class) = @_;

    my $self = {
      'cfg' => Config::Neat->new(),
      'cache' => {}
    };

    bless $self, $class;
    return $self;
}

# Given file name, will read this file in the specified mode (defaults to UTF-8), parse it
# and expand '@inherit' blocks
sub parse_file {
    my ($self, $filename, $binmode) = @_;
    $self->{cache} = {};
    $self->{binmode} = $binmode;
    $self->{orig_data} = $self->{cfg}->parse_file($filename, $binmode);
    my $data = _clone($self->{orig_data});
    $self->expand_data(\$data, dirname(rel2abs($filename)));
    return $data;
}

# Given a string representation of the config, returns a parsed tree
# with expanded '@inherit' blocks
sub parse {
    my ($self, $nconf, $dir) = @_;
    $self->{cache} = {};
    $dir = dirname(rel2abs($0)) unless $dir;
    $self->{orig_data} = $self->{cfg}->parse($nconf);
    my $data = _clone($self->{orig_data});
    $self->expand_data(\$data, $dir);
    return $data;
}

sub expand_data {
    my ($self, $noderef, $dir) = @_;

    if (ref($$noderef) eq 'HASH') {
        # expand child nodes
        map {
            $self->expand_data(\$$noderef->{$_}, $dir);
        } keys %$$noderef;

        if (exists $$noderef->{'@inherit'}) {
            die "The value of '\@inherit' must be a string or array" unless ref($$noderef->{'@inherit'}) eq 'Config::Neat::Array';

            my @a = @{$$noderef->{'@inherit'}};
            delete $$noderef->{'@inherit'};

            foreach my $from (@a) {
                my ($filename, $selector) = split('#', $from, 2);
                $filename = '' if $filename eq '.'; # allow .#selector style to indicate the current file
                die "Neither filename nor selector are specified" unless $filename or $selector;

                my $merge_node;
                if (exists $self->{cache}->{$from}) {
                    $merge_node = $self->{cache}->{$from};
                } else {
                    my $merge_cfg;
                    my $merge_dir = $dir;
                    if ($filename) {
                        my $fullpath = rel2abs($filename, $dir);
                        $merge_dir = dirname($fullpath);

                        if (exists $self->{cache}->{$fullpath}) {
                            $merge_cfg = $self->{cache}->{$fullpath};
                        } else {
                            $merge_cfg = $self->{cache}->{$fullpath} = $self->parse_file($fullpath, $self->{binmode});
                        }
                    } else {
                        $merge_cfg = _clone($self->{orig_data});
                    }
                    $merge_node = $self->select_subnode($merge_cfg, $selector, $dir);

                    $self->expand_data(\$merge_node, $merge_dir);

                    $self->{cache}->{$from} = $merge_node;
                }
                $self->merge_data($noderef, $merge_node, $dir);
            }
        }
    }
}

sub select_subnode {
    my ($self, $node, $selector, $dir) = @_;

    die "Bad selector syntax (double slash) in '$selector'" if $selector =~ m/\/{2,}/;
    $selector =~ s/^\///; # remove leading slash, if any

    return _clone($node) if $selector eq '';

    my @a = split('/', $selector);

    my $result = $node;
    foreach (@a) {
        next if ($_ eq '');
        if (ref($result) eq 'HASH' and exists $result->{$_}) {
            $result = $result->{$_};
        } else {
            die "Can't find key '$_' in node (selector: '$selector')";
        }
    }
    return _clone($result);
}

sub _clone {
	my $data = shift;
	return ref($data) ? dclone($data) : $data;
}

# merge into data1ref tree structure from data2
# data1ref is the one that may contain `-key` and `+key` entries
sub merge_data {
    my ($self, $data1ref, $data2, $dir) = @_;

    if (ref($$data1ref) eq 'HASH') {
        my $data2_is_hash = ref($data2) eq 'HASH';
        foreach my $key (keys %$$data1ref) {
            if ($key =~ m/^-(.*)$/) {
                my $merge_key = $1;
                die "Key '$key' contains bogus data; expected an empty or true value" unless $$data1ref->{$key}->as_boolean;
                delete $$data1ref->{$key};
                delete $data2->{$merge_key} if $data2_is_hash;
            } elsif ($key =~ m/^\+(.*)$/) {
                my $merge_key = $1;
                $$data1ref->{$merge_key} = $$data1ref->{$key};
                delete $$data1ref->{$key};
                $self->merge_data(\$$data1ref->{$merge_key}, $data2->{$merge_key}, $dir);
                delete $data2->{$merge_key} if $data2_is_hash;
            } else {
                $self->merge_data(\$$data1ref->{$key}, undef, $dir);
            }
        }
        if ($data2_is_hash) {
            foreach my $key (keys %$data2) {
                if (exists $data2->{$key} && !exists $$data1ref->{$key}) {
                    $$data1ref->{$key} = $data2->{$key};
                }
            }
        }
    } elsif (ref($$data1ref) eq 'Config::Neat::Array') {
        if (ref($data2) eq 'Config::Neat::Array') {
            unshift(@$$data1ref, @$data2);
        }
    } else {
        die "Unknown data type to merge";
    }
}
