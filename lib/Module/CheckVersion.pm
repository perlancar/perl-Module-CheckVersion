package Module::CheckVersion;

# AUTHORITY
# DATE
# DIST
# VERSION

use 5.010001;
use strict;
use warnings;

use Exporter ();
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(check_module_version);

our %SPEC;

$SPEC{check_module_version} = {
    v => 1.1,
    summary => 'Check module (e.g. check latest version) with CPAN '.
        '(or equivalent repo)',
    description => <<'_',

Designed to be more general and able to provide more information in the future
in addition to mere checking of latest version, but checking latest version is
currently the only implemented feature.

Can handle non-CPAN modules, as long as you put the appropriate `$AUTHORITY` in
your modules and create the `Module::CheckVersion::<scheme>` to handle your
authority scheme.

_
    args => {
        module => {
            schema => ['str*', match=>qr/\A\w+(::\w+)*\z/],
            description => <<'_',

This routine will try to load the module, and retrieve its `$VERSION`. If
loading fails will assume module's installed version is undef.

_
            req => 1,
            pos => 0,
        },
        check_latest_version => {
            schema => 'bool',
            default => 1,
        },
        default_authority_scheme => {
            schema  => 'str',
            default => 'cpan',
            description => <<'_',

If a module does not set `$AUTHORITY` (which contains string like
`<scheme>:<extra>` like `cpan:PERLANCAR`), the default authority scheme will be
determined from this setting. The module `Module::CheckVersion::<scheme>` module
is used to implement actual checking.

Can also be set to undef, in which case when module's `$AUTHORITY` is not
available, will return 412 status.

_
        },
    },
};
sub check_module_version {
    no strict 'refs';

    my %args = @_;

    my $mod = $args{module} or return [400, "Please specify module"];
    my $defscheme = $args{default_authority_scheme} // 'cpan';

    my $scheme_mod;

    my $chkres = {};

    my $code_load_scheme_mod = sub {
        return [200] if $scheme_mod;

        # GET AUTHORITY
        my $auth;
        {
            $auth = ${"$mod\::AUTHORITY"};
            last if $auth;
            my $mod_pm = $mod; $mod_pm =~ s!::!/!g; $mod_pm .= ".pm";
            eval { require $mod_pm; 1 };
            if ($@) {
                $chkres->{load_module_error} = $@;
            } else {
                $auth = ${"$mod\::AUTHORITY"};
                last if $auth;
            }
            $auth = "$defscheme:" if $defscheme;
            last if $auth;
            return [412, "Can't determine AUTHORITY for $mod"];
        }

        return [412, "AUTHORITY in $mod does not contain scheme"]
            unless $auth =~ /^(\w+):/;
        my $auth_scheme = $1;

        $scheme_mod = "Module::CheckVersion::$auth_scheme";
        my $mod_pm = $scheme_mod; $mod_pm =~ s!::!/!g; $mod_pm .= ".pm";
        require $mod_pm;
        [200];
    };

    if ($args{check_latest_version} // 1) {
        my $loadres = $code_load_scheme_mod->();
        return $loadres unless $loadres->[0] == 200;
        my $ver = ${"$mod\::VERSION"};
        my $chkres = &{"$scheme_mod\::check_latest_version"}($mod,$ver,$chkres);
        return $chkres unless $chkres->[0] == 200;
    }

    [200, "OK", $chkres];
}

1;
# ABSTRACT:

=head1 SYNOPSIS

Check latest version of modules:

 use Module::CheckVersion qw(check_module_version);

 my $res = check_module_version(module => 'Clone');
 # sample result: [200, "OK", {latest_version=>'0.38', installed_version=>'0.37', is_latest_version=>0}]

 say "Module Clone is the latest version ($res->[2]{latest_version})"
     if $res->[2]{is_latest_version};


=head1 SEE ALSO

L<check-module-version> (from L<App::CheckModuleVersion>) for the CLI.
