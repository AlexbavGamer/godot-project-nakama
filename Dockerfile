## Copyright 2018 The Nakama Authors
##
## Licensed under the Apache License, Version 2.0 (the "License");
## you may not use this file except in compliance with the License.
## You may obtain a copy of the License at
##
## http://www.apache.org/licenses/LICENSE-2.0
##
## Unless required by applicable law or agreed to in writing, software
## distributed under the License is distributed on an "AS IS" BASIS,
## WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
## See the License for the specific language governing permissions and
## limitations under the License.

# docker build "$PWD" --build-arg commit="$(git rev-parse --short HEAD)" --build-arg version=v2.1.1 -t heroiclabs/nakama:2.1.1
# docker build "$PWD" --build-arg commit="$(git rev-parse --short HEAD)" --build-arg version="$(git rev-parse --short HEAD)" -t heroiclabs/nakama-prerelease:"$(git rev-parse --short HEAD)"

FROM golang:1.16.4-buster as builder

ARG commit
ARG version

ENV GOOS linux
ENV GOARCH amd64
ENV CGO_ENABLED 1

RUN apt-get update && \
    apt-get -y upgrade && \
    apt-get install -y --no-install-recommends ca-certificates gcc libc6-dev git && \
    git config --global advice.detachedHead false && \
    git clone --quiet --no-checkout https://github.com/heroiclabs/nakama /go/build/nakama

WORKDIR /go/build/nakama
RUN git checkout --quiet "$commit" && \
    go build -o /go/build-out/nakama -trimpath -mod=vendor -gcflags "-trimpath $PWD" -asmflags "-trimpath $PWD" -ldflags "-s -w -X main.version=$version -X main.commitID=$commit"

FROM debian:buster-slim

MAINTAINER Heroic Labs <support@heroiclabs.com>

ARG version

LABEL version=$version
LABEL variant=nakama
LABEL description="Distributed server for social and realtime games and apps."

RUN mkdir -p /nakama/data/modules && \
    apt-get update && \
    apt-get -y upgrade && \
    apt-get install -y --no-install-recommends ca-certificates=20200601~deb10u2 tzdata curl iproute2 unzip rsync git tini schroot && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /nakama/
COPY --from=builder "/go/build-out/nakama" /nakama/
EXPOSE 7349 7350 7351

ENTRYPOINT ["tini", "--", "/nakama/nakama"]

HEALTHCHECK --interval=5m --timeout=10s \
  CMD curl -f http://localhost:7350/ || exit 1
