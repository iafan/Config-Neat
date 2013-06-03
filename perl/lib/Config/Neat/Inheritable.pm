# Copyright (C) 2012 Igor Afanasyev, https://github.com/iafan/Config-Neat

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

our $VERSION = '0.1';

use strict;

use Config::Neat;
use File::Spec::Functions qw(rel2abs);
use File::Basename qw(dirname);
use Tie::IxHash;

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
    return $self->expand_data($self->{orig_data}, dirname(rel2abs($filename)));
}

# Given a string representation of the config, returns a parsed tree
# with expanded '@inherit' blocks
sub parse {
    my ($self, $nconf, $dir) = @_;
    $self->{cache} = {};
    $dir = dirname(rel2abs($0)) unless $dir;
    return $self->expand_data($nconf, $dir);
}

sub expand_data {
    my ($self, $node, $dir) = @_;
    my $result = {};
    tie(%$result, 'Tie::IxHash');

    if (ref($node) eq 'HASH' and exists $node->{'@inherit'}) {
        die "The value of '\@inherit' must be a string or array" unless ref($node->{'@inherit'}) eq 'Config::Neat::Array';

        foreach my $from (@{$node->{'@inherit'}}) {
            my ($filename, $selector) = split('#', $from, 2);
            die "Neither filename nor selector are specified" unless $filename or $selector;

            my $merge_node;
            if (exists $self->{cache}->{$from}) {
                $merge_node = $self->{cache}->{$from};
            } else {
                my $merge_cfg;
                if ($filename) {
                    my $fullpath = rel2abs($filename, $dir);

                    if (exists $self->{cache}->{$fullpath}) {
                        $merge_cfg = $self->{cache}->{$fullpath};
                    } else {
                        #print "load file:[$fullpath]\n";

                        $merge_cfg = $self->expand_data($self->{cfg}->parse_file($fullpath, $self->{binmode}), dirname($fullpath));
                        $self->{cache}->{$fullpath} = $merge_cfg;
                    }
                } else {
                    $merge_cfg = $self->{orig_data};
                }
                $merge_node = $self->select_subnode($merge_cfg, $selector);
                $self->{cache}->{$from} = $merge_node;
            }
            $result = $self->merge_data($result, $merge_node, $dir);
        }
        delete $node->{'@inherit'};
    }

    $result = $self->merge_data($result, $node, $dir);
    
    return $result;
}

sub select_subnode {
    my ($self, $node, $selector) = @_;
    
    die "Bad selector syntax (double slash) in '$selector'" if $selector =~ m/\/{2,}/;
    $selector =~ s/^\///; # remove leading slash, if any
    
    return $node if $selector eq '';

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
    return $result;
}

sub merge_data {
    my ($self, $data1, $data2, $dir) = @_;

    if (ref($data1) eq 'HASH' and ref($data2) eq 'HASH') {
        foreach my $key (keys %$data2) {
            if ($key =~ m/^-(.*)$/) {
                die "Key '$key' contains bogus data; expected an empty or true value" unless $data2->{$key}->as_boolean;
                delete $data1->{$1};
            } elsif ($key =~ m/^\+(.*)$/) {
                my $merge_key = $1;
                $data1->{$merge_key} = $self->merge_data($data1->{$merge_key}, $data2->{$key}, $dir);
                $data1->{$merge_key} = $self->expand_data($data1->{$merge_key}, $dir);
            } else {
                $data1->{$key} = $data2->{$key};
                $data1->{$key} = $self->expand_data($data1->{$key}, $dir);
            }
        }
    } elsif (ref($data1) eq 'Config::Neat::Array' and ref($data2) eq 'Config::Neat::Array') {
        push(@$data1, @$data2);
    } else {
        $data1 = $data2;
    }

    return $data1;
}
