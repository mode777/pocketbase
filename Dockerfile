ARG POCKETBASE_VERSION=0.39.10
ARG ALPINE_VERSION=3.24.1
ARG BUILD_DIR=/pb_build
ARG BUILD_TAG

FROM golang:1.26-alpine AS build

ARG POCKETBASE_VERSION
ARG BUILD_DIR

WORKDIR /build

COPY go.mod go.sum ./
RUN go mod download

COPY . .

ARG TARGETOS
ARG TARGETARCH
ARG TARGETVARIANT
RUN set -eux; \
    GOARM="${TARGETVARIANT#v}"; \
    CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} GOARM=${GOARM} \
    go build -trimpath \
      -ldflags "-s -w -X github.com/pocketbase/pocketbase.Version=${POCKETBASE_VERSION}" \
      -o ${BUILD_DIR}/pocketbase \
      ./examples/base

FROM alpine:${ALPINE_VERSION} AS base

RUN apk add --no-cache ca-certificates curl


FROM base AS final

ARG uid=1001
ARG gid=1001
ARG user=pocketbase
ARG group=pocketbase
ARG POCKETBASE_WORKDIR=/pocketbase
ARG POCKETBASE_PORT_NUMBER=8090

ARG POCKETBASE_VERSION
ARG BUILD_DIR

ENV POCKETBASE_VERSION=$POCKETBASE_VERSION \
    POCKETBASE_PORT_NUMBER=$POCKETBASE_PORT_NUMBER \
    POCKETBASE_WORKDIR=$POCKETBASE_WORKDIR \
    POCKETBASE_HOME=/opt/pocketbase

EXPOSE $POCKETBASE_PORT_NUMBER

RUN mkdir -p $POCKETBASE_HOME  \
    && mkdir -p -m 777 "$POCKETBASE_WORKDIR" \
    && addgroup -g ${gid} ${group} \
    && adduser -u ${uid} -G ${group} -s /bin/sh -D ${user}

COPY --from=build $BUILD_DIR/pocketbase $POCKETBASE_HOME/pocketbase
COPY scripts $POCKETBASE_HOME/scripts
RUN chmod -R 755 $POCKETBASE_HOME \
    && ln -s $POCKETBASE_HOME/pocketbase /usr/local/bin/pocketbase

USER $uid
WORKDIR "$POCKETBASE_WORKDIR"

ARG BUILD_TAG
ENV BUILD_TAG="$BUILD_TAG"

ENTRYPOINT ["/opt/pocketbase/scripts/entrypoint.sh"]
