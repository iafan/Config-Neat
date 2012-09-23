# Copyright (C) 2012 Igor Afanasyev, https://github.com/iafan/Config-Neat

package Config::Neat;

my $VERSION = '0.1';

use strict;

use Tie::IxHash;

#
# Initialize object
#
sub new {
    my ($class) = @_;

    my $self = {
      'cfg' => {}
    };

    bless $self, $class;
    return $self;
}

# Given a string representation of the config, returns a parsed tree
sub parse {
    my ($self, $nconf) = @_;

    my $new = {};
    tie(%$new, 'Tie::IxHash');

    my @context = ($new);

    my $LINE_START    = 0;
    my $KEY           = 1;
    my $WHITESPACE    = 2;
    my $VALUE         = 3;
    my $LINE_COMMENT  = 4;
    my $BLOCK_COMMENT = 5;

    my $c;

    my $line = 1;
    my $pos  = 0;

    my $key             = '';
    my $values          = [];
    my $value           = undef;
    my $auto_key        = 0;
    my $mode            = $LINE_START;
    my $previous_mode   = $LINE_START;
    my $in_raw_mode     = undef;
    my $was_backslash   = undef;
    my $was_slash       = undef;
    my $was_asterisk    = undef;
    my $first_value_pos = 0;

    sub end_of_param {
        if ($key ne '') {
            push @$values, 'YES' if scalar(@$values) == 0;
            $context[$#context]->{$key} = $values;
            $values = [];
            $key = '';
        }
    }

    sub process_char {
        #print "$mode:$first_value_pos:$pos $c\n";

        if ($was_slash) {
            $c = '/'.$c; # emit with the slash prepended
        }

        if ($was_backslash) {
            $c = '\\'.$c; # emit with the backslash prepended
        }

        if ($mode == $LINE_START) {
            if (($first_value_pos > 0) and ($pos >= $first_value_pos)) {
                $mode = $VALUE;
            } else {
                end_of_param;
                $mode = $KEY;
                $first_value_pos = 0;
            }
        } elsif ($mode == $WHITESPACE) {
            $mode = $VALUE;
            if ($first_value_pos == 0) {
                $first_value_pos = $pos - 1; # -1 to allow for quote before the first value
            }
        }

        if ($mode == $KEY) {
            $key .= $c;
        } elsif ($mode == $VALUE) {
            $value .= $c;
        }
    }

    sub end_of_value {
        if ($was_slash or $was_backslash) {
            $c = '';
            process_char;
        }

        if (defined $value) {
            push @$values, $value;
            $value = undef;
        }
    }

    for (my $i = 0, my $l = length($nconf); $i < $l; $i++) {
        $c = substr($nconf, $i, 1);
        $pos++;

        if ($c eq '{') {
            next if ($mode == $LINE_COMMENT) or ($mode == $BLOCK_COMMENT);

            if ($in_raw_mode) {
                process_char;
                next;
            }

            end_of_value;

            if (!$key) {
                while (exists $context[$#context]->{$auto_key}) {
                    $auto_key++;
                }
                $key = $auto_key++;
            }
             
            my $new = {};
            tie(%$new, 'Tie::IxHash');
            
            $context[$#context]->{$key} = $new;
            push @context, $new;

            # any values preceding the block will be added into it with an empty key value
            if (scalar(@$values) > 0) {
                $new->{''} = $values;
            }

            $values = [];
            $key = '';
            $value = undef;
            $auto_key = 0;
            $mode = $LINE_START;
            $first_value_pos = 0;

        } elsif ($c eq '}') {
            next if ($mode == $LINE_COMMENT) or ($mode == $BLOCK_COMMENT);

            if ($in_raw_mode) {
                process_char;
                next;
            }

            end_of_value;
            end_of_param;

            if (scalar(@context) == 0) {
                die "Unmatched closing bracket at config line $line position $pos";
            }
            pop @context;
            $mode = $WHITESPACE;
            $key = '';
            $values = [];

        } elsif ($c eq '\\') {
            next if ($mode == $LINE_COMMENT) or ($mode == $BLOCK_COMMENT);

            if ($was_backslash) {
                $was_backslash = undef;
                process_char; # print previous backslash, if any
            }

            $was_backslash = 1; # do not print current slash, but wait for the next char
            next;

        } elsif ($c eq '/') {
            next if ($mode == $LINE_COMMENT);

            if ($was_asterisk and ($mode == $BLOCK_COMMENT)) {
                $mode = $previous_mode;
                next;
            }

            if ($was_slash) {
                $was_slash = undef;
                process_char; # print previous slash, if any
            }

            $was_slash = 1; # do not print current slash, but wait for the next char
            next;

        } elsif ($c eq '*') {
            next if ($mode == $LINE_COMMENT);

            if ($mode == $BLOCK_COMMENT) {
                $was_asterisk = 1;
                next;
            } else {
                if ($was_slash) {
                    $was_slash = undef;
                    $previous_mode = $mode;
                    $mode = $BLOCK_COMMENT;
                    next;
                }

                process_char;
            }

        } elsif ($c eq '`') {
            next if ($mode == $LINE_COMMENT) or ($mode == $BLOCK_COMMENT);

            if ($was_backslash) {
                $was_backslash = undef;
                process_char;
                next;
            }

            $c = '';
            process_char;

            $in_raw_mode = !$in_raw_mode;

        } elsif (($c eq ' ') or ($c eq "\t")) {
            if ($c eq "\t") {
                warn "Tab symbol at config line $line position $pos (replace tabs with spaces to ensure proper parsing of multiline parameters)";
            }

            next if ($mode == $LINE_COMMENT) or ($mode == $BLOCK_COMMENT);

            if ($in_raw_mode) {
                process_char;
                next;
            }

            if ($mode == $KEY) {
                $mode = $WHITESPACE;
            } elsif ($mode == $VALUE) {
                end_of_value;
                $mode = $WHITESPACE;
            }

        } elsif ($c eq "\r") {
            next;

        } elsif ($c eq "\n") {
            $line++;
            $pos = 0;

            next if ($mode == $BLOCK_COMMENT);

            if ($in_raw_mode) {
                process_char;
                next;
            }

            end_of_value;
            $mode = $LINE_START;

        } elsif ($c eq "#") {
            next if ($mode == $LINE_COMMENT) or ($mode == $BLOCK_COMMENT);

            if ($in_raw_mode) {
                process_char;
                next;
            }

            if (($mode == $LINE_START) or ($mode == $WHITESPACE)) {
                $mode = $LINE_COMMENT;
            } else {
                process_char;
            }

        } else {
            next if ($mode == $LINE_COMMENT) or ($mode == $BLOCK_COMMENT);

            process_char;
        }

        $was_slash = undef;
        $was_backslash = undef;
        $was_asterisk = undef;
    }

    die "Unmatched backtick at config line $line position $pos" if $in_raw_mode;

    end_of_value;
    end_of_param;

    return $self->{'cfg'} = $context[0];
} # end sub

# Given file name, will read this file in the specified mode (defaults to UTF-8) and parse it
sub parse_file {
    my ($self, $filename, $binmode) = @_;

    open(CFG, $filename) or die "Can't open [$filename]: $!";
    binmode(CFG, $binmode || ':utf8');
    my $text = join('', <CFG>);
    close(CFG);

    return $self->parse($text);
} # end sub

# Given ['foo', 'bar', 'baz'] array reference, returns 'foo bar baz' string.
# If string starts from a newline and the next line is indented, remove that amount of spaces
# from each line and trim leading and trailing newline
sub as_string {
    my ($self, $node) = @_;

    my $val = join(' ', @$node);
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

# Returns true if the string representation of a given array
# evaluates case-insensitively to a known list of strings: YES, Y, ON, TRUE or 1;
# otherwise, returns false
sub as_boolean {
    my ($self, $node) = @_;

    my $val = uc(as_string($node));
    return ($val eq 'YES') or ($val eq 'Y') or ($val eq 'ON') or ($val eq 'TRUE') or ($val eq '1');
} # end sub

# Given ['foo', 'bar', 'baz'] array and property name 'x', returns the following hash reference:
#   {
#       0 => {'x' => 'foo'},
#       1 => {'x' => 'bar'},
#       2 => {'x' => 'baz'}
#   }
sub as_hash {
    my ($self, $arr, $name) = @_;
    
    die "Second parameter (name) not provided" unless defined $name;

    # if the provided value is a hash, return it as is
    return $arr if ref($arr) eq 'HASH';

    die "First parameter must be an array" unless ref($arr) eq 'ARRAY';

    my $result = {};
    tie(%$result, 'Tie::IxHash');

    my $n = 0;
    foreach my $val (@$arr) {
        $result->{$n++} = { $name => $val };
    }

    return $result;
} # end sub

1; # return true