package Module::CheckVersion::cpan;

# DATE
# VERSION

use 5.010;
use strict;
use warnings;

use HTTP::Tiny;
use JSON;

sub check_latest_version {
    my ($mod, $installed_version, $chkres) = @_;

    my $res = HTTP::Tiny->new->get("http://api.metacpan.org/v0/module/$mod?fields=name,version");
    return [$res->{status}, "API request failed: $res->{reason}"] unless $res->{success};
    eval { $res = JSON::decode_json($res->{content}) };
    return [500, "Can't decode JSON API response: $@"] if $@;
    return [500, "Error from API response: $res->{message}"] if $res->{message};
    my $latest_version = $res->{version};

    $chkres->{installed_version} = $installed_version;
    $chkres->{latest_version} = $latest_version;
    if (defined $installed_version) {
        my $cmp = eval {
            version->parse($installed_version) <=>
                version->parse($latest_version);
        };
        if ($@) {
            $chkres->{compare_version_err} = @_;
            $chkres->{is_latest_version} = undef;
        } else {
            $chkres->{is_latest_version} = $cmp >= 0 ? 1:0;
        }
    } else {
        $chkres->{is_latest_version} = 0;
    }
    [200];
}

1;
# ABSTRACT: Handler for cpan

=for Pod::Coverage .+
