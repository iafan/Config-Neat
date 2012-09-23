About Config::Neat
==================

Configuration files don't have to be ugly. Inspired by [nginx configuration files](http://wiki.nginx.org/FullExample)
I decided to go a bit further and implement a format which is highly readable,
less error prone, requires little to no special markup, and yet is robust
to allow nested blocks for the projects that require more than just a plain
key-value list.

Currently Config::Neat is implemented as a Perl module.

### Simple Syntax Example
In its simplest form, the configuration file can look like this:

    # Server configuration
    server    Some string
    port      8080
    use_ssl   YES    

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
                root      /var/www/domain
                ...
            }

            www.otherdomain.com {
                root      /var/www/otherdomain
                ...
            }
        }
    }

### Full Syntax Example
See `sample/readme.nconf` file, which gives a full overview
of the supported syntax.

Perl Module
-----------

Perl module is located in `perl/lib` subdirectory.
It depends on [Tie::IxHash](http://search.cpan.org/~chorny/Tie-IxHash/) module available from CPAN.

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

    my $log_format = $cfg->as_string($data->{'server'}->{'log_format'});
    #
    # $log_format now is a scalar:
    #     '$remote_addr - $remote_user [$time] $status $size $request'

Tools
-----

### /perl/bin/dump_nconf.pl

This script will read the configuration file from a pipe (or STDIN)
and emit the parsed data structure created by Data::Dumper.
This script can be used to validate the syntax of the configuration file
and understand its internal tree representation.

#### Usage:

    perl dump_nconf.pl < config.nconf

