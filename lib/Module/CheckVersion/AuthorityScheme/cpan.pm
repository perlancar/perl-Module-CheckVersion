package Module::CheckVersion::AuthorityScheme::cpan;

use 5.010001;
use strict;
use warnings;

use HTTP::Tiny;
use JSON::MaybeXS;

# AUTHORITY
# DATE
# DIST
# VERSION

sub check_latest_version {
    my ($mod, $authority_scheme, $authority_content) = @_;

    my $res = HTTP::Tiny->new->get("http://fastapi.metacpan.org/v1/module/$mod?fields=name,version");
    return [$res->{status}, "API request failed: $res->{reason}"] unless $res->{success};
    eval { $res = JSON::MaybeXS::decode_json($res->{content}) };
    return [500, "Can't decode JSON API response: $@"] if $@;
    return [500, "Error from API response: $res->{message}"] if $res->{message};
    [200, "OK", $res->{version}];
}

1;
# ABSTRACT: Handler for "cpan" authority scheme

=for Pod::Coverage .+

=head1 SYNOPSIS

In F<Some/Module.pm>:

 our $AUTHORITY = 'cpan:APAUSEID';


=head1 DESCRIPTION

This handler will check module version on MetaCPAN.
