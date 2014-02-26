=head1 NAME

Config::Neat::Util - Common utility functions for other Config::Neat modules

=head1 COPYRIGHT

Copyright (C) 2012-2014 Igor Afanasyev <igor.afanasyev@gmail.com>

=head1 SEE ALSO

L<https://github.com/iafan/Config-Neat>

=cut

package Config::Neat::Util;

our $VERSION = '0.2';

use strict;

use Tie::IxHash;

our @ISA = qw(Exporter);

our @EXPORT_OK = qw(
    is_number
    is_code
    is_hash
    is_ixhash
    is_array
    is_neat_array
    is_scalar
    is_simple_array
    hash_has_sequential_keys
    get_next_auto_key
    offset_keys
    get_keys_ordered
    reorder_numerically
    read_file
);

sub is_number {
    my $n = shift;
    return ($n + 0) eq $n;
}

sub is_code {
    my $node = shift;
    return ref($node) eq 'CODE';
}

sub is_hash {
    my $node = shift;
    return ref($node) eq 'HASH';
}

sub is_ixhash {
    my $node = shift;
    return undef unless is_hash($node);
    return ref(tied(%$node)) eq 'Tie::IxHash';
}

sub is_array {
    my $node = shift;
    return ref($node) eq 'ARRAY';
}

sub is_neat_array {
    my $node = shift;
    return ref($node) eq 'Config::Neat::Array';
}

sub is_scalar {
    my $node = shift;
    return (ref(\$node) eq 'SCALAR') or (ref($node) eq 'SCALAR');
}

sub is_simple_array {
    my $node = shift;

    return 1 if is_scalar($node);
    return undef if is_hash($node);

    my $contains_hash = undef;
    my $contains_scalar = undef;

    foreach my $value (@$node) {
        if (is_hash($value)) {
            $contains_hash |= 1;
        } else {
            $contains_scalar |= is_scalar($value);
        }
        die "Mixing hashes with simple arrays/scalars within one node is not supported" if $contains_hash && $contains_scalar;
    }
    return $contains_scalar;
}

sub hash_has_sequential_keys {
    my $node = shift;
    die "Not a hash" unless is_hash($node);

    my $i = 0;
    # sort keys numerically
    foreach my $key (sort { $a <=> $b } keys %$node) {
        return undef if ($key + 0 ne $key) or ($i++ != $key);
    }
    return 1;
}

# supposed to be used against hash that matches the
# `hash_has_sequential_keys() == true` criterion
sub get_next_auto_key {
    my $node = shift;
    die "Not a hash" unless is_hash($node);

    # get max(key)
    my $i = -1; # so that next key will start with 0
    map {
        $i = $_ if $_ > $i && is_number($_);
    } keys %$node;

    # return max + 1
    return $i + 1;
}

# supposed to be used against hash that matches the
# `hash_has_sequential_keys() == true` criterion
sub offset_keys {
    my ($node, $offset) = @_;
    die "Not a hash" unless is_hash($node);
    die "Offset is a negative number" if $offset < 0;
    return if $offset == 0;

    # sort keys numerically in the reverse order
    my @a = sort {$b <=> $a} keys %$node;

    # remap keys
    map {
        if (is_number($_)) {
            $node->{$_ + $offset} = $node->{$_};
            delete $node->{$_};
        }
    } @a;
}

# accepts an array of hasrefs
sub get_keys_ordered {
    my %result;
    tie(%result, 'Tie::IxHash');

    map {
        map {
            $result{$_} = 1;
        } keys %$_;
    } @_;

    return keys %result;
}

sub reorder_numerically {
    my ($node) = @_;
    die "Not a Tie::IxHash" unless is_ixhash($node);

    # sort keys numerically
    my @a = sort {$a <=> $b} keys %$node;

    reorder($node, \@a);
}

sub reorder {
    my ($node, $aref) = @_;
    die "Not a Tie::IxHash" unless is_ixhash($node);

    # get values in the right order
    my @values = map { $node->{$_} } @$aref;

    # clear all the keys
    map { delete $node->{$_} } @$aref;

    # re-add the keys in the proper order
    for (my $i = 0; $i < scalar @$aref; $i++) {
        $node->{$aref->[$i]} = $values[$i];
    }
}

sub read_file {
    my ($filename, $binmode) = @_;

    open(CFG, $filename) or die "Can't open [$filename]: $!";
    binmode(CFG, $binmode || ':utf8');
    my $text = join('', <CFG>);
    close(CFG);

    return $text;
} # end sub


1;