package inc::GenerateDocs;

use Moose;
with 'Dist::Zilla::Role::FileGatherer',
    'Dist::Zilla::Role::AfterBuild',
    'Dist::Zilla::Role::FileInjector';

use File::pushd;
use IPC::System::Simple qw(capturex);
use List::Util 'first';
use Path::Tiny;

my $filename = path(qw(lib Moose Manual Exceptions Manifest.pod));

sub gather_files {
    my ($self, $arg) = @_;

    $self->add_file(Dist::Zilla::File::InMemory->new(
        name    => $filename->stringify,
        # more to fill in later
        content => <<'END_POD',
# PODNAME: Moose::Manual::Exceptions::Manifest
# ABSTRACT: Moose's Exception Types
END_POD
        )
    );
}

sub after_build {
    my ($self, $opts) = @_;
    my $build_dir = $opts->{build_root};

    my $wd = pushd($build_dir);
    unless ( -d 'blib' ) {
        my @builders = @{ $self->zilla->plugins_with( -BuildRunner ) };
        die "no BuildRunner plugins specified" unless @builders;
        $_->build for @builders;
        die "no blib; failed to build properly?" unless -d 'blib';
    }

    # This must be run as a separate process because we need to use the new
    # Moose we just generated, in order to introspect all the exception classes
    $self->log('running author/doc-generator...');
    my $text = capturex($^X, 'author/doc-generator');

    my $file_obj = first { $_->name eq $filename } @{$self->zilla->files};

    $file_obj->content($text);

    $filename->spew_raw($file_obj->encoded_content);
}

1;
