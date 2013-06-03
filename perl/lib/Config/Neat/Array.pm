package Config::Neat::Array;

use strict;

our $VERSION = '0.1';

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
# evaluates case-insensitively to a known list of strings: YES, Y, ON, TRUE or 1
sub as_boolean {
    my ($self) = @_;

    my $val = uc($self->as_string);
    return ($val eq 'YES') or ($val eq 'Y') or ($val eq 'ON') or ($val eq 'TRUE') or ($val eq '1');
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

1; # return true
