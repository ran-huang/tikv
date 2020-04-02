# We need to use CentOS 7 because many of our users choose this as their deploy machine.
# Since the glibc it uses (2.17) is from 2012 (https://sourceware.org/glibc/wiki/Glibc%20Timeline)
# it is our lowest common denominator in terms of distro support.
FROM centos:7.6.1810 as builder

# We require epel packages, so enable the fedora EPEL repo then install dependencies.
# Install the system dependencies
RUN yum install -y epel-release && \
    yum clean all && \
    yum makecache

RUN yum install -y \
        perl \
        make cmake3 pkg-config dwz \
        gcc gcc-c++ libstdc++-static && \
    yum clean all

# CentOS gives cmake 3 a weird binary name, so we link it to something more normal
# This is required by many build scripts, including ours.
RUN ln -s /usr/bin/cmake3 /usr/bin/cmake
ENV LIBRARY_PATH /usr/local/lib:$LIBRARY_PATH
ENV LD_LIBRARY_PATH /usr/local/lib:$LD_LIBRARY_PATH

# Install Rustup.
RUN curl https://sh.rustup.rs -sSf | sh -s -- --no-modify-path --default-toolchain none -y
ENV PATH /root/.cargo/bin/:$PATH

# Install the Rust toolchain.
WORKDIR /tikv
COPY rust-toolchain rust-toolchain
RUN rustup self update
RUN rustup set profile minimal
RUN rustup default $(cat "rust-toolchain")

# Build!
ARG GIT_FULLBACK="Unknown (no git or not git repo)"
ARG GIT_HASH=${GIT_FULLBACK}
ARG GIT_TAG=${GIT_FULLBACK}
ARG GIT_BRANCH=${GIT_FULLBACK}
ENV TIKV_BUILD_GIT_HASH=${GIT_HASH}
ENV TIKV_BUILD_GIT_TAG=${GIT_TAG}
ENV TIKV_BUILD_GIT_BRANCH=${GIT_BRANCH}
COPY ./ /tikv
RUN make build_dist_release

FROM pingcap/alpine-glibc
COPY --from=builder /tikv/target/release/tikv-server /tikv-server
COPY --from=builder /tikv/target/release/tikv-ctl /tikv-ctl

EXPOSE 20160 20180

ENTRYPOINT ["/tikv-server"]
