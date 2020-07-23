package Docker::Construct;

use 5.006;
use strict;
use warnings;

=head1 NAME

Docker::Construct - Construct the filesystem of an exported docker image.

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

This is the backend module for the L<docker-construct> command-line tool. For
basic usage, refer to its documentation instead.

    use Docker::Construct qw(construct);

    # Minimal usage
    construct('path/to/image.tar', 'path/to/output/dir');

    # With options
    construct(
        image           => 'path/to/image.tar',
        dir             => 'path/to/output.dir',
        quiet           => 1,
        include_config  => 1
    )

=cut

use Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(construct);

use Carp;
use JSON;
use Scalar::Util qw(openhandle);

=head1 construct()

Reconstruct the the filesystem of the specified tarball (output from
the C<docker save> command) inside the specified directory. If only two
arguments are given, they are interpreted as the paths to the input tarball
and output directory respectively. If more arguments are given, the arguments
are interpreted as a hash. A hash allows you specify additional options and the
input tarball and output directory are specified with the C<image> and C<dir>
keys respectively.

=head2 Options

=over 4

=item * image I<(required)>

Path to the input tarball

=item * dir I<(required)>

Path to the output directory (must exist already)

=item * quiet

If true, progress will not be reported on stderr.

=item * include_config

If true, include the image's config json file as F<config.json> in the
root of the extracted filesystem.

=cut
sub construct {
    my %params;
    if ( @_ == 2 ) {
        ( $params{image}, $params{dir} ) = @_;
    }
    else {
        %params = @_;
    }

    croak "must specify input image tarball 'image'"    unless $params{image};
    croak "must specify output directory 'dir'"         unless $params{dir};
    my $image   = $params{image};
    my $dir     = $params{dir};
    croak "file not found: $image"      unless -f $image;
    croak "directory not found: $dir"   unless -d $dir;

    my @imagefiles = _read_file_list($image);

    croak "this does not seem to be a docker image (missing manifest.json)"
        unless grep {$_ eq 'manifest.json'} @imagefiles;

    my %manifest = %{
        decode_json(
            _read_file_from_tar($image, 'manifest.json')
        )->[0]
    };

    for my $layer ( @{$manifest{Layers}} ) {
        print STDERR "reading layer: $layer...\n";
        my $layer       = _stream_file_from_tar($image, $layer);
        my $filelist    = _exec_tar($layer, '-t');

        my $numfiles = 0;
        while (<$filelist>) {
            $numfiles++;
        }
        print STDERR "($numfiles file(s))\n";

    }
}

sub _exec_tar {
    my $input   = shift;
    my @args    = @_;


    my @command = openhandle $input ? ('tar',               @args)
                                    : ('tar', '-f', $input, @args);

    my $read_fh;
    if (openhandle $input) {
        my $pid = open($read_fh, '-|');
        croak "could not fork" unless defined $pid;
        do { open(STDIN, '<&', $input); exec @command; } unless $pid;
    }
    else {
        open ($read_fh, '-|', @command)   or croak "could not exec tar";
    }
    return $read_fh;
}

sub _read_file_list {
    my $fh = _exec_tar(shift, '-t');

    my @filelist = <$fh>;
    chomp @filelist;

    close $fh       or croak $! ?   "could not close pipe: $!"
                                :   "exit code $? from tar";

    return @filelist;
}

sub _read_file_from_tar {
    my $fh = _stream_file_from_tar(@_);
    my $content;
    {
        local $/ = undef;
        $content = <$fh>;
    }
    close $fh
        or croak $! ?   "could not close pipe: $!"
                    :   "exit code $? from tar";
    return $content;
}

sub _stream_file_from_tar {
    my $input = shift;
    my $path    = shift;

    return _exec_tar($input, '-xO', $path);
}

=head1 AUTHOR

Cameron Tauxe, C<< <camerontauxe at gmail.com> >>

=head1 LICENSE AND COPYRIGHT

This software is copyright (c) 2020 by Cameron Tauxe.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

1;
