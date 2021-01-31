# About Config::Neat

Configuration files don't have to be ugly. Inspired by
[nginx configuration files](http://wiki.nginx.org/FullExample)
I decided to go a bit further and implement a format which is highly readable,
less error prone, requires little to no special markup, and yet is robust
to allow nested blocks for the projects that require more than just a plain
key-value list.

Currently Config::Neat is implemented as a suite of Perl modules
which, in addition to parsing and rendering configuration files,
implement automatic configuration file inheritance (aka includes)
and validation against schema (see below).

### Simple Syntax Example

In its simplest form, the configuration file can look like this:

    # Server configuration
    server     Some string
    port       8080
    port       8081
    use_ssl    YES

You are not forced to enclose strings in quotes, or specify delimiters
at the end of each line; you will never need to escape single or double quotes.

### Robust Syntax Example

When it comes to having different (even nested) sections,
multiline lists or strings, block comments, Config::Neat will
offer you such an opportunity:

    /*
        Global server configuration
    */
    server {
        listen                  8080
        use_ssl                 YES
        debug                   NO
        log_format              $remote_addr - $remote_user [$time]
                                $status $size $request

        supported_mime_types    text/html text/css text/xml text/plain
                                image/gif image/jpeg image/png image/x-icon
                                application/x-javascript

        /*
            My virtual hosts
        */
        virtual_hosts {

            www.domain.com {
                root            /var/www/domain
                ...
            }

            www.otherdomain.com {
                root            /var/www/otherdomain
                ...
            }
        }
    }

### Full Syntax Example

See `sample/readme.nconf` file, which gives a full overview
of the supported syntax.

## Perl Module

Perl module is located in `perl/lib` subdirectory.
It depends on [Tie::IxHash](http://search.cpan.org/~chorny/Tie-IxHash/)
module available from CPAN.

### Synopsis

    use Config::Neat;

    my $cfg = Config::Neat->new();
    my $data = $cfg->parse_file('/path/to/myconfig.nconf');

    # now $data contains a parsed hash tree which you can examine

    # consider the example config above

    my $list = $data->{'server'}->{'supported_mime_types'};
    #
    # $list now is an array reference:
    #     ['text/html', 'text/css', ..., 'application/x-javascript']

    my $log_format = $data->{'server'}->{'log_format'}->as_string;
    #
    # $log_format now is a scalar:
    #     '$remote_addr - $remote_user [$time] $status $size $request'

## Config::Neat::Inheritable

This module adds config inheritance to Config::Neat files by automatically
processing `@inherit file#subnode`, `-somekey` and `+otherkey` keys.
See [Config::Neat::Inheritable source code](perl/lib/Config/Neat/Inheritable.pm)
for further explanation.

## Config::Neat::Schema

This module adds config validation against provided schema (schema itself
can be defined using Config::Neat format). See
[Config::Neat::Schema source code](perl/lib/Config/Neat/Schema.pm)
for further explanation.

## Config::Neat::Render

This module allows you render Config::Neat-compatible structures from your data
(but read below for limitations).

### When shoud I use it?

1. When you need to convert your old configuration files to a new format
   (and then manually tweak the output).
2. When you want to dump some data for diff purposes or just for reading.
3. When readability of your output is more important than knowing original
   data types of each node in your data output.

### When shoud I NOT use it?

Do not use it for arbitrary data serialization/deserialization.
JSON and YAML will work better for this kind of task.

Why? Because Config::Neat was primarily designed to allow easier configuration
file authoring and reading, and uses relaxed syntax where strings are treated like
space-separated arrays (and vice versa), and where there's no strict definition
for boolean types, no null values, etc.

It's the developer's responsibility to treat any given parameter as a boolean,
or string, or an array. This means that once you serialize your string into
Config::Neat format and parse it back, it will be converted to an array,
and you will need to use `->as_string` method to get the value as string.

In other words, when doing this:

    my $c = Config::Neat->new();
    my $r = Config::Neat::Render->new();
    my $parsed_data = $c->parse($r->render($arbitrary_data));

$parsed_data will almost always be different from $arbitrary_data.

However, doing this immediately after:

    my $parsed_data_2 = $c->parse($r->render($parsed_data));

Should produce the same data structure again.

### Synopsis

    use Config::Neat::Render;

    my $r = Config::Neat::Render->new();

    my $data = {
        'foo' => 'Hello, World!',
        'bar' => [1, 2, 3],
        'baz' => {
            'etc' => ['foo bar', 'baz', '', 1]
        }
    };

    print $r->render($data);

The output will be:

    bar    1 2 3

    baz
    {
        etc    `foo bar` baz `` 1
    }

    foo    Hello, World!

Note that hashes in Perl do not guarantee the correct order, so blocks may have
individual parameters shuffled randomly. To sort the keys, you can provide a reference
to an ordered list of key names in the `sort` option:

    ...

    my @order = qw(foo bar baz);

    print $r->render($data, {sort => \@order});

And now the output will be:

    foo    Hello, World!
    bar    1 2 3

    baz
    {
        etc    `foo bar` baz `` 1
    }

Alternatively, setting `sort` to a true value will just sort keys alphabetically.

## Tools

### [dump-nconf](perl/bin/dump-nconf)

This script will read the configuration file
and emit the parsed data structure in either Config::Neat::Render, Data::Dumper
or JSON format. This script can be used to validate the syntax of the
configuration file and understand its internal tree representation.

## Syntax Highlighters

There are a few syntax highlighters available (see the `highlighters` folder):

1. for [Sublime Text](http://www.sublimetext.com/) desktop editor
   (also compatible with [TextMate](http://macromates.com/))
2. for [Visual Studio Code](https://code.visualstudio.com)
3. for JavaScript-based editor called [CodeMirror](http://codemirror.net/).

You can also use CodeMirror with Config::Neat highlighter to
[statically highlight](http://codemirror.net/demo/runmode.html)
configuration snippets/examples within web pages.
