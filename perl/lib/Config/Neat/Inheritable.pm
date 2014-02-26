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
use Config::Neat::Util qw(is_hash get_next_auto_key
                          offset_keys reorder_numerically read_file);
use File::Spec::Functions qw(rel2abs);
use File::Basename qw(dirname);
use Storable qw(dclone);
use Tie::IxHash;

#
# Initialize object
#
sub new {
    my ($class) = @_;

    my $self = {
        cfg => Config::Neat->new(),
    };

    bless $self, $class;
    return $self;
}

# Given file name, will read this file in the specified mode (defaults to UTF-8), parse it
# and expand '@inherit' blocks
sub parse_file {
    my ($self, $filename, $binmode) = @_;

    $self->{binmode} = $binmode;

    return $self->_parse_file($filename, 1); # init
}

# Given a string representation of the config, returns a parsed tree
# with expanded '@inherit' blocks
sub parse {
    my ($self, $nconf, $dir) = @_;
    return $self->_parse($nconf, $dir, 1); # init
}

sub _parse_file {
    my ($self, $filename, $init) = @_;

    my $dir = dirname(rel2abs($filename));
    return $self->_parse(read_file($filename, $self->{binmode}), $dir, $init);
}

sub _parse {
    my ($self, $nconf, $dir, $init) = @_;

    if ($init) {
        $self->{cache} = {};
        $self->{saved_context} = [];
        $self->{include_stack} = [];
    }

    $dir = dirname(rel2abs($0)) unless $dir;

    # we need to preserve $self->{orig_data} and then restore it, so that
    # we will always have the current context file data for in-file @inherit rules
    push @{$self->{saved_context}}, $self->{orig_data};

    # parse the file
    my $data = $self->{cfg}->parse($nconf);

    # preserve the data in the current context
    $self->{orig_data} = _clone($data);

    # process @inherit rules
    $data = $self->expand_data($data, $dir);

    # restore the context
    $self->{orig_data} = pop @{$self->{saved_context}};

    return $data;
}

sub expand_data {
    my ($self, $node, $dir) = @_;

    if (ref($node) eq 'HASH') {
        # expand child nodes
        map {
            $node->{$_} = $self->expand_data($node->{$_}, $dir);
        } keys %$node;

        if (exists $node->{'@inherit'}) {
            die "The value of '\@inherit' must be a string or array" unless ref($node->{'@inherit'}) eq 'Config::Neat::Array';

            my @a = @{$node->{'@inherit'}};
            delete $node->{'@inherit'};

            my $final_node = {};
            tie(%$final_node, 'Tie::IxHash');

            foreach my $from (@a) {
                my ($filename, $selector) = split('#', $from, 2);
                # allow .#selector style to indicate the current file, since #selector
                # without the leading symbol will be treated as a comment line
                $filename = '' if $filename eq '.';
                die "Neither filename nor selector are specified" unless $filename or $selector;

                # normalize path and selector
                my $fullpath = rel2abs($filename, $dir); # make path absolute based on current context dir
                $selector =~ s/^\///; # remove leading slash, if any

                # make sure we don't have any infinite loops
                my $key = $fullpath.'#'.$selector;
                map {
                    die "Infinite loop detected at `\@inherit $key`" if $key eq $_;
                } @{$self->{include_stack}};

                push @{$self->{include_stack}}, $key;

                my $merge_node;
                if (exists $self->{cache}->{$from}) {
                    $merge_node = _clone($self->{cache}->{$from});
                } else {
                    my $merge_cfg;
                    my $merge_dir = $dir;
                    if ($filename) {
                        $merge_dir = dirname($fullpath);

                        if (exists $self->{cache}->{$fullpath}) {
                            $merge_cfg = $self->{cache}->{$fullpath};
                        } else {
                            $merge_cfg = $self->{cache}->{$fullpath} = $self->_parse_file($fullpath);
                        }
                    } else {
                        $merge_cfg = _clone($self->{orig_data});
                    }
                    $merge_node = $self->select_subnode($merge_cfg, $selector, $dir);

                    $merge_node = $self->expand_data($merge_node, $merge_dir);

                    $self->{cache}->{$from} = $merge_node;
                }
                $node = $self->merge_data($node, $merge_node, $dir);

                pop @{$self->{include_stack}};
            }
        }
    }

    return $node;
}

sub select_subnode {
    my ($self, $node, $selector, $dir) = @_;

    die "Bad selector syntax (double slash) in '$selector'" if $selector =~ m/\/{2,}/;
    die "Bad selector syntax (leading slash) in '$selector'" if $selector =~ m/^\//;

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

# merge into data1 tree structure from data2
# data1 is the one that may contain `-key` and `+key` entries
sub merge_data {
    my ($self, $data1, $data2, $dir) = @_;

    if (ref($data1) eq 'HASH') {
        my $data2_is_hash = ref($data2) eq 'HASH';
        foreach my $key (keys %$data1) {
            if ($key =~ m/^-(.*)$/) {
                my $merge_key = $1;
                die "Key '$key' contains bogus data; expected an empty or true value" unless $data1->{$key}->as_boolean;
                delete $data1->{$key};
                delete $data2->{$merge_key} if $data2_is_hash;
            } elsif ($key =~ m/^\+(.*)$/) {
                my $merge_key = $1;
                $data1->{$merge_key} = $data1->{$key};
                delete $data1->{$key};

                my $hash_array_merge_mode =
                    is_hash($data1->{$merge_key}) &&
                    is_hash($data2->{$merge_key});

                if ($hash_array_merge_mode) {
                    my $offset = get_next_auto_key($data2->{$merge_key});
                    offset_keys($data1->{$merge_key}, $offset);
                }

                $data1->{$merge_key} = $self->merge_data($data1->{$merge_key}, $data2->{$merge_key}, $dir);
                delete $data2->{$merge_key} if $data2_is_hash;

                if ($hash_array_merge_mode) {
                    reorder_numerically($data1->{$merge_key});
                }
            } else {
                $data1->{$key} = $self->merge_data($data1->{$key}, undef, $dir);
            }
        }
        if ($data2_is_hash) {
            foreach my $key (keys %$data2) {
                if (exists $data2->{$key} && !exists $data1->{$key}) {
                    $data1->{$key} = $data2->{$key};
                }
            }
        }
    } elsif (ref($data1) eq 'Config::Neat::Array') {
        if (ref($data2) eq 'Config::Neat::Array') {
            unshift(@$data1, @$data2);
        }
    } else {
        die "Unknown data type to merge";
    }

    return $data1;
}

1;