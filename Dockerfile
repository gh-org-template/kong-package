ARG OSTYPE=linux-gnu
ARG ARCHITECTURE=x86_64
ARG DOCKER_REGISTRY=ghcr.io
ARG DOCKER_IMAGE_NAME

# List out all image permutations to trick dependabot
FROM --platform=linux/amd64 ghcr.io/gh-org-template/kong-build-images:apk AS x86_64-linux-musl
FROM --platform=linux/amd64 ghcr.io/gh-org-template/kong-build-images:rpm AS x86_64-linux-gnu
FROM --platform=linux/arm64 ghcr.io/gh-org-template/kong-build-images:apk AS aarch64-linux-musl
FROM --platform=linux/arm64 ghcr.io/gh-org-template/kong-build-images:rpm AS aarch64-linux-gnu

# Run the build script
FROM $ARCHITECTURE-$OSTYPE AS build

COPY . /src
RUN /src/build.sh && /src/test.sh


# Copy the build result to scratch so we can export the result
FROM scratch AS package

COPY --from=build /tmp/build /
