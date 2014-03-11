=head1 NAME

Config::Neat::Array - Class for array-like config nodes

=head1 COPYRIGHT

Copyright (C) 2012-2014 Igor Afanasyev <igor.afanasyev@gmail.com>

=head1 SEE ALSO

L<https://github.com/iafan/Config-Neat>

=cut

package Config::Neat::Array;

our $VERSION = '0.6';

use strict;

sub new {
    my ($class, $self) = @_;
    $self = [] unless defined $self && ref($self) eq 'ARRAY';
    bless $self, $class;
    return $self;
}

sub push {
    my $self = shift;
    push @$self, @_;
}

# Given ['foo', 'bar', 'baz'] as the contents of the array, returns 'foo bar baz' string.
# If string starts from a newline and the next line is indented, remove that amount of spaces
# from each line and trim leading and trailing newline
sub as_string {
    my ($self) = @_;

    my $val = join(' ', @$self);
    my $indent = undef;
    while ($val =~ m/\n(\s+)/g) {
        my $len = length($1);
        $indent = $len unless defined $indent and $len > 0;
        $indent = $len if $len > 0 and $indent > $len;
    }
    if ($indent > 0) {
        $indent = ' ' x $indent;
        $val =~ s/\n$indent/\n/sg;
        $val =~ s/^\s*\n//s; # remove first single newline and preceeding whitespace
        $val =~ s/\n\s*$//s; # remove last single newline and whitespace after it
    }
    return $val;
} # end sub

# Returns true if the string representation of the array
# evaluates case-insensitively to a known list of positive boolean strings
sub as_boolean {
    my ($self) = @_;

    return ($self->as_string =~ m/^(YES|Y|ON|TRUE|1)$/i);
} # end sub

# Returns true if the string representation of the array
# evaluates case-insensitively to a known list of positive or negative boolean strings
sub is_boolean {
    my ($self) = @_;

    return ($self->as_string =~ m/^(YES|NO|Y|N|ON|OFF|TRUE|FALSE|1|0)$/i);
} # end sub

# Given ['foo', 'bar', 'baz'] as the contents of the array,
# and property name 'x', returns the following hash reference:
#   {
#       0 => {'x' => 'foo'},
#       1 => {'x' => 'bar'},
#       2 => {'x' => 'baz'}
#   }
sub as_hash {
    my ($self, $propname) = @_;

    die "Second parameter (propname) not provided" unless defined $propname;

    my $result = {};
    tie(%$result, 'Tie::IxHash');

    my $n = 0;
    foreach my $val (@$self) {
        $result->{$n++} = {$propname => $val};
    }

    return $result;
} # end sub

1;
