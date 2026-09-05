# perl-ci

Docker images for testing Perl code in CI: one image for every cell of a
small matrix of Debian releases and perl versions, each with a perl built from
source, `cpanm`, `cpm`, and the same collection of testing modules and helper
scripts that `perldocker/perl-tester` provides.

Images are published at `ghcr.io/rjbs/perl-ci`.

## Why not docker-perl-tester?

`perldocker/perl-tester` layers its cpanfile on top of the official `perl:*`
images from `Perl/docker-perl`.  Those are only rebuilt for the four current
perl releases; everything older is a frozen image on an end-of-life Debian,
and it keeps breaking as CPAN moves on.  perl-ci builds every perl itself, on
a current Debian, so 5.8 gets the same treatment as 5.44.

## What's in an image

- perl, non-threaded, built with `-Duseshrplib` into `/usr/local`
  (Debian's own perl is still at `/usr/bin/perl`; ours comes first in `PATH`)
- `cpanm` (App::cpanminus 1.7049) and `cpm` (1.1.5, or 0.998003 on perls
  before 5.24), both pinned and checksummed
- everything in [`cpanfile`](cpanfile), which is a copy of docker-perl-tester's,
  including its `requires_by_perl` helper for "this version on that perl"
- the scripts from
  [perl-actions/ci-perl-tester-helpers](https://github.com/perl-actions/ci-perl-tester-helpers)
  in `/usr/local/bin`
- `build-essential`, `git`, `gpg`, `aspell`, `libssl-dev`, `zlib1g-dev`,
  `libexpat1-dev`

A perl 5.8.8 linked against a 2025 glibc is a fine thing to run tests on, but
it is not the same artifact as a 2006 perl on a 2006 libc.  If you need to
reproduce a genuinely old deployment, this is not the image for that.

## The matrix

Debian: `trixie` (owns the unversioned tags) and `forky`.

Perl: 5.8.8, then the newest release of every even-numbered branch from 5.10
on, then the newest development release.  The exact versions are in
[`perls.json`](perls.json).

## Tags

For perl 5.36 on `trixie`:

    5.36-trixie
    5.36            (only on the default debian)

The point release (5.36.3) is not part of any tag; it is an implementation
detail, and tagging it would leave stale tags behind every time a branch
moved on.  The exact version inside an image is in `perls.json`, and in the
`PERL_CI_PERL_VERSION` environment variable.

The newest stable perl also gets `latest-trixie` and `latest`; the development
release gets `devel-trixie` and `devel` in place of a `5.x` alias.  Exactly one
cell owns each bare tag.

Images are multi-arch: `linux/amd64` and `linux/arm64`.

## Using it in GitHub Actions

If you use `perldocker/perl-tester` today, change the image name:

```yaml
    container:
      image: ghcr.io/rjbs/perl-ci:${{ matrix.perl-version }}
```

## Building locally

    bin/build --debian trixie --perl 5.36           # one cell, host arch
    bin/build --debian trixie --stable              # every non-devel perl
    bin/build --debian trixie --perl 5.8 --target perl   # just build perl

Each build logs to `logs/VERSION-DEBIAN.log`.  A native build takes a minute
or so for perl and much longer for the cpanfile.

## Building and publishing in CI

`.github/workflows/build.yml` is run by hand (`workflow_dispatch`).  Pick a
Debian release, a perl (or `all`, or `stable`), and whether to push.  Each
architecture is built on its own runner and pushed by digest; a final job
merges the two into one manifest and applies the cell's tags.

## Maintaining

- **A new perl came out.**  Run `bin/refresh-manifest`; it updates
  `perls.json` (and moves `latest` if needed).  Commit, then build.
- **A module stopped installing on some perl.**  Pin it in `cpanfile` with
  `requires_by_perl`, with a comment saying why.  If it's a build-time module
  that has to be in place before cpm reads the cpanfile at all, pin it in
  `cpanfile.bootstrap` instead.
- **Adding a module.**  Add it to `cpanfile`.  Try it on the oldest perl you
  care about first; `bin/build --perl 5.8 --target toolchain` then
  `docker run --rm -it ghcr.io/rjbs/perl-ci:5.8 cpm install -g Some::Module`
  is a quick way to find out where it stops working.
