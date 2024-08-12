ARG OSTYPE=linux-gnu
ARG ARCHITECTURE=x86_64
ARG DOCKER_REGISTRY=ghcr.io
ARG DOCKER_IMAGE_NAME

# List out all image permutations to trick dependabot
FROM --platform=linux/amd64 ghcr.io/gh-org-template/kong-development:1.0.0-x86_64-linux-musl AS x86_64-linux-musl
FROM --platform=linux/amd64 ghcr.io/gh-org-template/kong-development:1.0.0-x86_64-linux-gnu AS x86_64-linux-gnu
FROM --platform=linux/arm64 ghcr.io/gh-org-template/kong-development:1.0.0-x86_64-linux-musl AS aarch64-linux-musl
FROM --platform=linux/arm64 ghcr.io/gh-org-template/kong-development:1.0.0-x86_64-linux-gnu AS aarch64-linux-gnu

# Run the build script
FROM $ARCHITECTURE-$OSTYPE AS build
RUN ./grep-kong-version.sh > /tmp/kong-version

FROM --platform=linux/amd64 ghcr.io/gh-org-template/multi-arch-fpm:1.0.1 AS x86_64-fpm
FROM --platform=linux/arm64 ghcr.io/gh-org-template/multi-arch-fpm:1.0.1 AS aarch64-fpm

FROM $ARCHITECTURE-fpm AS fpm

COPY --from=build /tmp/kong-version /tmp/kong-version
COPY --from=build /tmp/build /tmp/build
COPY /fpm /fpm

# Keep sync'd with the fpm/package.sh variables
ARG PACKAGE_TYPE=deb
ENV PACKAGE_TYPE=${PACKAGE_TYPE}

ARG ARCHITECTURE=x86_64
ENV ARCHITECTURE=${ARCHITECTURE}

ARG OPERATING_SYSTEM=ubuntu
ENV OPERATING_SYSTEM=${OPERATING_SYSTEM}

ARG OPERATING_SYSTEM_VERSION="22.04"
ENV OPERATING_SYSTEM_VERSION=${OPERATING_SYSTEM_VERSION}

WORKDIR /fpm
RUN ./package.sh


# Copy the build result to scratch so we can export the result
FROM scratch AS package
COPY --from=fpm /output/* /
