# One image per (debian, perl) cell.  The stages build on one another rather
# than copying between images, so the final image still has a compiler and
# headers; CI jobs need them to build XS.  Naming the stages lets a developer
# stop early with --target when only the perl build is in question.

ARG DEBIAN_RELEASE=trixie

FROM debian:${DEBIAN_RELEASE}-slim AS perl

ARG PERL_VERSION
ARG PERL_SHA256
ARG PERL_DEVEL=0

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# libdevel-patchperl-perl brings in Debian's perl, which stays at
# /usr/bin/perl; the perl we build goes to /usr/local/bin and wins in PATH.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        aspell aspell-en \
        build-essential \
        bzip2 \
        ca-certificates \
        curl \
        dpkg-dev \
        git \
        gpg \
        libdevel-patchperl-perl \
        libexpat1-dev \
        libssl-dev \
        netbase \
        patch \
        xz-utils \
        zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

COPY bin/build-perl /usr/local/src/perl-ci/

RUN /usr/bin/perl /usr/local/src/perl-ci/build-perl "$PERL_VERSION" "$PERL_SHA256" "$PERL_DEVEL"

# smoke is copied after the build so that editing it does not invalidate the
# (slow) perl layer above.
COPY bin/smoke /usr/local/src/perl-ci/

RUN perl /usr/local/src/perl-ci/smoke perl "$PERL_VERSION"

FROM perl AS toolchain

ARG PERL_VERSION

COPY bin/install-toolchain cpanfile.bootstrap /usr/local/src/perl-ci/

RUN perl /usr/local/src/perl-ci/install-toolchain \
    && rm -rf /root/.cpanm /root/.perl-cpm

RUN perl /usr/local/src/perl-ci/smoke toolchain "$PERL_VERSION"

FROM toolchain AS full

ARG PERL_VERSION
ARG DEBIAN_RELEASE
ARG HELPERS_REF=main

COPY cpanfile /usr/local/src/perl-ci/

RUN cpm install -g --show-build-log-on-failure --cpanfile /usr/local/src/perl-ci/cpanfile \
    && rm -rf /root/.perl-cpm

RUN git clone --depth 1 --branch "$HELPERS_REF" https://github.com/perl-actions/ci-perl-tester-helpers.git /tmp/helpers \
    && cp /tmp/helpers/bin/* /usr/local/bin/ \
    && rm -rf /tmp/helpers \
    && git config --system --add safe.directory '*'

RUN perl /usr/local/src/perl-ci/smoke full "$PERL_VERSION"

LABEL org.opencontainers.image.source="https://github.com/rjbs/perl-ci" \
      org.opencontainers.image.version="${PERL_VERSION}" \
      org.opencontainers.image.description="perl ${PERL_VERSION} on Debian ${DEBIAN_RELEASE} with CPAN testing tools" \
      org.perl-ci.debian="${DEBIAN_RELEASE}"

ENV PERL_CI_PERL_VERSION=${PERL_VERSION}

WORKDIR /work

CMD ["/bin/bash"]
