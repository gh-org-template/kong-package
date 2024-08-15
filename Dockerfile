ARG OSTYPE=linux-gnu
ARG ARCHITECTURE
ARG DOCKER_REGISTRY=ghcr.io
ARG DOCKER_IMAGE_NAME
ARG DOCKER_ARCHITECTURE
ARG DOCKER_ARCHITECTURE
ARG OPERATING_SYSTEM
ARG VERSION=1.1.2

FROM --platform=linux/${DOCKER_ARCHITECTURE} ghcr.io/gh-org-template/kong-build-images:${OPERATING_SYSTEM}-${VERSION} AS build

COPY . /src
RUN /src/build.sh && /src/test.sh


# Copy the build result to scratch so we can export the result
FROM scratch AS package

COPY --from=build /tmp/build /
