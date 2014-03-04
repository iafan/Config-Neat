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

    foo {
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

Multiple inheritance is supported; use '.' do denote the the current file:

    @inherit    01.nconf#foo 02.nconf#bar .#baz

=cut

package Config::Neat::Inheritable;

our $VERSION = '0.5';

use strict;

use Config::Neat;
use Config::Neat::Util qw(new_ixhash is_hash is_neat_array get_next_auto_key offset_keys
                          get_keys_in_order reorder_ixhash rename_ixhash_key read_file);
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

            my $intermediate = new_ixhash;

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

                $intermediate = $self->merge_data($merge_node, $intermediate, $dir);
                pop @{$self->{include_stack}};
            }

            $node = $self->merge_data($node, $intermediate, $dir);
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

    if (is_hash($data1) && is_hash($data2)) {
        my @keys = get_keys_in_order($data2, $data1);

        foreach my $key (keys %$data1) {
            if ($key =~ m/^-(.*)$/) {
                die "Key '$key' contains bogus data; expected an empty or true value" unless $data1->{$key}->as_boolean;
                delete $data1->{$key};
                delete $data2->{$1};
                next;
            }

            # arrays are NOT merged by default; use `+key` will merge arrays
            if (is_neat_array($data1->{$key})) {
                if ($key =~ m/^\+(.*)$/) {
                    if ((!exists $data2->{$1} || is_neat_array($data2->{$1}))) {
                        $data1 = rename_ixhash_key($data1, $key, $1);
                        $key = $1;
                    }
                } else {
                    delete $data2->{$key};
                }
            }

            # hashes are merged by default; `+key { }` is the same as `key { }`
            if (is_hash($data1->{$key}) && ($key =~ m/^\+(.*)$/)) {
                $data1 = rename_ixhash_key($data1, $key, $1);
                $key = $1;
            }

            if (is_hash($data1->{$key}) && is_hash($data2->{$key})) {
                my $offset = get_next_auto_key($data2->{$key});
                $data1->{$key} = offset_keys($data1->{$key}, $offset);
            }
            $data1->{$key} = $self->merge_data($data1->{$key}, $data2->{$key}, $dir);
        }

        foreach my $key (keys %$data2) {
            if (exists $data2->{$key} && !exists $data1->{$key}) {
                $data1->{$key} = $data2->{$key};
            }
        }

        $data1 = reorder_ixhash($data1, \@keys);
    } elsif (is_neat_array($data1) && is_neat_array($data2)) {
        unshift(@$data1, @$data2);
    }

    return $data1;
}

1;