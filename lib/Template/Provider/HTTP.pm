package Template::Provider::HTTP;
use base qw( Template::Provider );

use strict;
use warnings;

use LWP::UserAgent;

our $VERSION = 0.02;

=head1 NAME

Template::Provider::HTTP - fetch templates from a webserver

=head1 SYNOPSIS

    use Template;
    use Template::Provider::HTTP;

    my %provider_config = (
        INCLUDE_PATH => [
            "/some/local/path",                        # file
            "http://svn.example.com/svn/templates/",    # url
        ],
    );

    my $tt = Template->new(
        {   LOAD_TEMPLATES => [
                Template::Provider::HTTP->new( \%provider_config ),
                Template::Provider->new( \%provider_config ),
            ],
        }
    );

    # now use $tt as normal
    $tt->process( 'my_template.html', \%vars );

=head1 DESCRIPTION

Templates usually live on disk, but this is not always ideal. This module lets
you serve your templates over HTTP from a webserver.

For our purposes we wanted to access the latest templates from a Subversion
repository and have them update immediately.

=head1 NOTE

Currently there is NO caching, so the webserver will get multiple hits every
time that a template is requested. Patches welcome.

=head1 METHODS

This module is a very thin layer on top of L<Template::Provider> - please see the documentation there for full details.

=head1 PRIVATE METHODS

=head2 _init

Does some setup. Notably goes through the C<INCLUDE_PATH> and removes anything
that does not start with C<http>.

=cut

sub _init {
    my ( $self, $params ) = @_;

    $self->SUPER::_init($params);

    my @path
        = grep {m{ \A http s? :// \w }xi} @{ $self->{INCLUDE_PATH} || [] };
    $self->{INCLUDE_PATH} = \@path;

    $self->{UA} = $params->{UA};

    return $self;

}

=head2 _ua

Returns a L<LWP::UserAgent> object, or a cached one if it has already been
called.

=cut

sub _ua {
    my $self = shift;
    return $self->{UA} ||= LWP::UserAgent->new;
}

=head2 _template_modified

Returns the current time if the request is a success, otherwise undef. Could be
smartened up with a bt of local caching.

=cut

#------------------------------------------------------------------------
# _template_modified($path)
#
# Returns the last modified time of the $path.
# Returns undef if the path does not exist.
# Override if templates are not on disk, for example
#------------------------------------------------------------------------

sub _template_modified {
    my $self = shift;

    my $template = shift || return;
    $template =~ s{http:/}{http://};

    $self->debug("_template_modified( '$template' )") if $self->{DEBUG};

    return $self->_ua->get($template)->is_success ? time : undef;
}

=head2 _template_content

Returns the content from the request, or an error.

=cut

#------------------------------------------------------------------------
# _template_content($path)
#
# Fetches content pointed to by $path.
# Returns the content in scalar context.
# Returns ($data, $error, $mtime) in list context where
#   $data       - content
#   $error      - error string if there was an error, otherwise undef
#   $mtime      - last modified time from calling stat() on the path
#------------------------------------------------------------------------

sub _template_content {
    my $self = shift;

    my $path = shift;
    $path =~ s{http:/}{http://};
    $self->debug("_template_content( '$path' )") if $self->{DEBUG};

    return ( undef, "No path specified to fetch content from " )
        unless $path;

    my $data;
    my $mod_date;
    my $error;

    if ( $path =~ m{ \A http s? :// \w }xi ) {
        my $res = $self->_ua->get($path);

        if ( $res->is_success ) {
            $data     = $res->decoded_content;
            $mod_date = time;
        } else {
            $error = "error with request: " . $res->status_line;
        }
    } else {
        $error = 'NOT A URL';
    }

    return wantarray
        ? ( $data, $error, $mod_date )
        : $data;
}

=head1 SEE ALSO

L<Template::Provider> - which this module inherits from.

=head1 AUTHOR

Edmund von der Burg C<<evdb@ecclestoad.co.uk>>

=head1 THANKS

Developed whilst working at Foxtons for an internal system there and released
with their blessing.

=head1 GOD SPEED

TT3 - there has to be a better way than this :)

=head1 LICENSE

Sam as Perl.

=cut

1;
