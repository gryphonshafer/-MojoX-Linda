package MojoX::Linda;
# ABSTRACT: Plausibly helpful (and probably drunk) wrapper around morbo

use 5.022;
use exact;

use Class::Method::Modifiers 'install_modifier';
use Config::App ();
use File::Find 'find';
use Mojo::Server::Morbo;
use Mojo::File 'path';

# VERSION

sub conf ($conf) {
    my $conf_app   = Config::App->find;
    my $mojo_linda = ($conf_app) ? $conf_app->get( qw( mojolicious linda ) ) : {};

    $conf->{$_}  //= $mojo_linda->{$_} for ( qw( silent app mode backend ) );
    $conf->{app} //= $ARGV[0] || do {
        my $match;
        for my $file ( path('.')->list_tree->to_array->@* ) {
            next unless -x $file;
            if ( $file->slurp =~ /\b(
                Mojolicious::Commands\s*\-\s*>\s*start_app|
                MojoX::ConfigAppStart\s*\-\s*>\s*start
            )\b/x ) {
                $match = $file->to_string;
                last;
            }
        }
        $match;
    };

    for my $name ( qw( listen watch ) ) {
        my %hash = map { $_ => 1 } $conf->{$name}->@*, $mojo_linda->{$name}->@*;
        $conf->{$name} = [ keys %hash ];
    }

    unless ( $conf->{listen}->@* ) {
        for ( 3000 .. 3999 ) {
            unless (
                IO::Socket::INET->new(
                    PeerAddr => 'localhost',
                    Proto    => 'tcp',
                    PeerPort => $_,
                )
            ) {
                $conf->{listen} = [ 'http://*:' . $_ ];
                last;
            }
        }
    }

    return $conf;
}

sub run ($conf) {
    $ENV{MOJO_MODE}          = $conf->{mode}    if $conf->{mode};
    $ENV{MOJO_MORBO_BACKEND} = $conf->{backend} if $conf->{backend};

    install_modifier( 'Mojo::Server::Morbo', 'after', '_spawn', sub {
        say '  Silent  : ', ( ( $conf->{silent} ) ? 'Yes' : 'No' );
        say '  App     : ', $conf->{app};
        say '  Mode    : ', $ENV{MOJO_MODE}                  // '>Undefined<';
        say '  Backend : ', $ENV{MOJO_MORBO_BACKEND}         // '>Undefined<';
        say '  Listen  : ', join( ', ', $conf->{listen}->@* ) || '>Unspecified<';
        say '  Watch   : ', join( ', ', $conf->{watch}->@*  ) || '>Unspecified<';
    } ) if ( not $conf->{silent} );

    my $morbo = Mojo::Server::Morbo->new( silent => $conf->{silent} );

    $morbo->daemon->listen( $conf->{listen} ) if @{ $conf->{listen} };
    $morbo->backend->watch( $conf->{watch}  ) if @{ $conf->{watch}  };

    $morbo->run( $conf->{app} );

    return 0;
}

1;
__END__

=pod

=begin :badges

=for markdown
[![test](https://github.com/gryphonshafer/MojoX-Linda/workflows/test/badge.svg)](https://github.com/gryphonshafer/MojoX-Linda/actions?query=workflow%3Atest)
[![codecov](https://codecov.io/gh/gryphonshafer/MojoX-Linda/graph/badge.svg)](https://codecov.io/gh/gryphonshafer/MojoX-Linda)

=end :badges

=begin :prelude

=for test_synopsis BEGIN { die "SKIP: skip synopsis check because it's non-Perl\n"; }

=end :prelude

=head1 SYNOPSIS

    linda [OPTIONS]
        -s, --silent
        -a, --app     APPLICATION
        -m, --mode    MOJO_MODE
        -b, --backend MOJO_MORBO_BACKEND
        -l, --listen  LISTEN_PATTERN    # can be repeated
        -w, --watch   DIRECTORY_OR_FILE # can be repeated
        -h, --help
        -m, --man

=head1 DESCRIPTION

C<linda> is a plausibly helpful (and probably drunk) wrapper around C<morbo>,
provided by L<Mojo::Server::Morbo>. Like C<morbo>, C<linda> will accept various
configuration settings for server operation; but unlike C<morbo>, C<linda> will
hallucinate settings that aren't set explicitly.

In theory, if you just call C<linda> without any settings, C<linda> will call
C<morbo> in the way you want. In practice, C<linda> will probably act inebriated.

=head2 -s, --silent

This is the inverse of the C<morbo> "verbose" flag. If not set, C<linda> assumes
you want verbose.

=head2 -a, --app

This is the Mojolicious application you'd like to startup. If not set explicitly,
C<linda> will look around (from your current working directory) for an
executable file that has code in it that looks like it's probably a
Mojolicious application.

C<linda>'s judgement here should not be trusted.

=head2 -m, --mode

See L<Mojo::Server::Morbo>.

=head2 -b, --backend

See L<Mojo::Server::Morbo>.

=head2 -l, --listen

One or more locations you want to listen on. If not set explicitly, C<linda>
will look for open ports starting with 3000 and going up to 3999. The first
open port will be used.

=head2 -w, --watch

See L<Mojo::Server::Morbo>.

=head1 CONFIGURATION

C<linda> will initially try to find and load a configuration file via a call to
L<Config::App>'s C<find>. If C<find> returns a configuration, C<linda> will
look in that configuration under C<mojolicious/linda> for settings. Any settings
will be overwritten by any explicit command-line settings.

=head1 SEE ALSO

You can also look for additional information at:

=for :list
* L<GitHub|https://github.com/gryphonshafer/MojoX-Linda>
* L<MetaCPAN|https://metacpan.org/pod/MojoX::Linda>
* L<GitHub Actions|https://github.com/gryphonshafer/MojoX-Linda/actions>
* L<Codecov|https://codecov.io/gh/gryphonshafer/MojoX-Linda>
* L<CPANTS|http://cpants.cpanauthors.org/dist/MojoX-Linda>
* L<CPAN Testers|http://www.cpantesters.org/distro/M/MojoX-Linda.html>

=for Pod::Coverage conf run

=cut
