package Module::CheckVersion::darkpan;

use 5.010001;
use strict;
use warnings;

use File::Temp 'tempfile';
use File::Slurper 'write_binary';
use HTTP::Tiny;
use JSON::MaybeXS;

# AUTHORITY
# DATE
# DIST
# VERSION

sub check_latest_version {
    my ($mod, $installed_version, $chkres, $auth_scheme, $auth_content) = @_;

    my $url = "$auth_content/modules/02packages.details.txt.gz";
    my $res = HTTP::Tiny->new->get($url);
    #use DD; dd $res;
    return [$res->{status}, "Retrieving $url failed: $res->{reason}"] unless $res->{success};

    my ($tempfh, $tempfilename) = tempfile('XXXXXXXX', SUFFIX => '.gz', TMPDIR => 1);
    #print "D:tempfilename=$tempfilename\n";
    write_binary($tempfilename, $res->{content});

    require Parse::CPAN::Packages;
    my $pcp = Parse::CPAN::Packages->new($tempfilename);
    my $m = $pcp->package($mod);
    unless ($m) {
        return [404, "No such module '$mod' in $url"];
    }

    my $latest_version = $m->version;

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
# ABSTRACT: Handler for the "darkpan" authority scheme

=for Pod::Coverage .+

=head1 SYNOPSIS

In F<Some/Module.pm>:

 our $AUTHORITY = 'darkpan:https://github.com/mycompany/my-darkpan/raw/refs/heads/master';

or perhaps:

 our $AUTHORITY = 'file:/my/darkpan';


=head1 DESCRIPTION

This module will parse the authority as:

 darkpan:<URL>

and retrieve:

 <URL>/modules/02packages.details.txt.gz

using L<HTTP::Tiny>, then parse the downloaded file using
L<Parse::CPAN::Packages>, then check module version from the parsed information.
