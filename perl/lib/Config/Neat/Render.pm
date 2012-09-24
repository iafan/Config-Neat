# Copyright (C) 2012 Igor Afanasyev, https://github.com/iafan/Config-Neat

package Config::Neat::Render;

my $VERSION = '0.1';

use strict;

use Tie::IxHash;

#
# Initialize object
#
sub new {
    my ($class, $options) = @_;

    my $default_options = {
        indentation     =>  4, # number of spaces to indent each nested block contents with
        key_spacing     =>  4, # number of spaces between a key and and a value

        wrap_width      => 60, # suggested maximum width of the multiline string or array

        brace_under     =>  1, # if true, put the opening brace under the key name, not on the same line
        separate_blocks =>  1, # if true, surrond blocks with empty lines for better readability

        sort            => undef, # can be a true value if you want to sort keys alphabetically
                                  # or a reference to an array with an ordered list of key names
    };

    $options = {} unless $options;
    %$options = (%$default_options, %$options);

    my $self = {
        _options => $options
    };

    bless $self, $class;
    return $self;
}

# Renders a nested tree structure into a Config::Neat-compatible text representaion.
# @@@@@@@@
# CAUTION: Config::Neat::Render->render() and Config::Neat->parse()
# are NOT SYMMETRICAL and should not be used for arbitrary data
# serialization/deserialization.
#
# In other words, when doing this:
#
#     my $c = Config::Neat->new();
#     my $r = Config::Neat::Render->new();
#     my $parsed_data = $c->parse($r->render($arbitrary_data));
#
# $parsed_data will almost always be different from $arbitrary_data.
# However, doing this immediately after:
#
#     my $parsed_data_2 = $c->parse($r->render($parsed_data));
#
# Should produce the same data structure again.
#
# See README for more information.
# @@@@@@@@
sub render {
    my ($self, $data, $options) = @_;

    $options = {} unless $options;
    %$options = (%{$self->{_options}}, %$options);

    my $indentation     =   $options->{indentation};
    my $key_spacing     =   $options->{key_spacing};
    my $wrap_width      =   $options->{wrap_width};
    my $brace_under     = !!$options->{brace_under};
    my $separate_blocks = !!$options->{separate_blocks};
    my $sort            =   $options->{sort};
    if (ref($sort) eq 'ARRAY') {
        # convert an array into a hash with 0..n values
        my %h;
        @h{@$sort} = (0 .. scalar(@$sort) - 1);
        $sort = \%h;
    }

    sub is_code {
        my $node = shift;
        return ref($node) eq 'CODE';
    }

    sub is_hash {
        my $node = shift;
        return ref($node) eq 'HASH';
    }

    sub is_array {
        my $node = shift;
        return ref($node) eq 'ARRAY';
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
                $contains_scalar |= is_simple_array($value);
            }
            die "Mixing hashes with simple arrays/scalars within one node is not supported" if $contains_hash and $contains_scalar;
        }
        return $contains_scalar;
    }

    sub max_key_length {
        my $node = shift;
        die "Not a hash" unless is_hash($node);

        my $len = 0;
        foreach my $key (keys %$node) {
            $len = length($key) if length($key) > $len;
        }
        return $len;
    }

    sub hash_with_array_like_keys {
        my $node = shift;
        die "Not a hash" unless is_hash($node);

        my $i = 0;
        # sort keys numerically
        foreach my $key (sort { $a <=> $b } keys %$node) {
            return undef if ($i++ != $key);
        }
        return 1;
    }

    sub convert_array_to_hash {
        my $node = shift;

        my $i = 0;

        my $h = {};
        tie(%$h, 'Tie::IxHash');

        foreach my $value (@$node) {
            $h->{$i++} = $value;
        }
        return $h;
    }

    sub render_wrapped_array {
        my ($array, $indent) = @_;

        my @a;
        my $line = '';
        foreach my $item (@$array) {
            my $l = $line ? length($line) + 1 : 0;

            if ($l + length($item) > $wrap_width) {
                push(@a, $line) if $line;
                $line = '';
            }

            if (length($item) >= $wrap_width) {
                push(@a, $item);
            } else {
                $line .= ' ' if $line;
                $line .= $item;
            }
        }
        push(@a, $line) if $line;

        return join("\n".(' ' x $indent), @a);
    }

    sub render_scalar {
        my ($scalar, $indent, $should_escape) = @_;

        # dereference scalar
        $scalar = $$scalar if ref($scalar) eq 'SCALAR';

        $scalar =~ s/`/\\`/g;

        if ($scalar =~ m/(\n|\s{2,})/) {
            $should_escape = 1;
        }

        if (!defined $scalar) {
            $scalar = 'NO';
        } elsif ($scalar eq '') {
            $scalar = '``';
        }

        if ($should_escape and $scalar =~ m/\s/) {
            $scalar = '`'.$scalar.'`';
        }

        if (!$should_escape and $scalar) {
            my @a = split(/\s+/, $scalar);
            return render_wrapped_array(\@a, $indent);
        }

        return $scalar;
    }

    sub pad {
        my ($s, $width) = @_;
        my $spaces = $width - length($s);
        return ($spaces <= 0) ? $s : $s . ' ' x $spaces;
    }

    sub render_node_recursively {
        my ($node, $indent) = @_;
        my $text = '';
        my $simple_array;
        my $key_length = 0;
        my $array_mode;

        my $space_indent = (' ' x $indent);

        if (is_array($node)) {
            $simple_array = is_simple_array($node);
            die "Can't render simple arrays as a main block content" if $simple_array;
            $array_mode = 1;
            $node = convert_array_to_hash($node);

        } elsif (is_hash($node)) {
            $array_mode = hash_with_array_like_keys($node);
            $key_length = max_key_length($node);

        } else {
            die "Unsupported data type: '".ref($node)."'";
        }

        my $was = undef;
        my $PARAM = 1;
        my $BLOCK = 2;

        my @keys = keys %$node;
        if (!$array_mode and scalar(@keys) > 1) {
            if (is_hash($sort)) {
                @keys = sort { $sort->{$a} <=> $sort->{$b} } @keys;
            } elsif ($sort) {
                @keys = sort @keys;
            }
        }

        foreach my $key (@keys) {
            my $val = $node->{$key};
            die "Keys should not conain whitespace" if ($key =~ m/\s/);

            if (is_scalar($val)) {
                $text .= "\n" if ($was == $BLOCK) and $separate_blocks;

                $text .= $space_indent .
                         pad($key, $key_length) .
                         (' ' x $key_spacing) .
                         render_scalar($val, $indent + $key_length + $key_spacing) .
                         "\n";

                $was = $PARAM;

            } elsif (is_simple_array($val)) {
                # escape individual array items
                my @a = map { render_scalar($_, undef, 1) } @$val;

                $text .= "\n" if ($was == $BLOCK) and $separate_blocks;

                $text .= $space_indent .
                         pad($key, $key_length) .
                         (' ' x $key_spacing) .
                         render_wrapped_array(\@a, $indent + $key_length + $key_spacing) .
                         "\n";

                $was = $PARAM;

            } else {
                $text .= "\n" if defined($was) and $separate_blocks;

                $text .= $space_indent;

                if (!$array_mode) {
                    $text .= $brace_under ? "$key\n$space_indent" : "$key ";
                }

                $text .= "{\n" .
                         render_node_recursively($val, $indent + $indentation) .
                         $space_indent .
                         "}\n";

                $was = $BLOCK;
            }
        }
        return $text;
    }

    return render_node_recursively($data, 0);
} # end sub

1; # return true