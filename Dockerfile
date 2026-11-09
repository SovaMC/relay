FROM golang:1.26-bookworm AS go

FROM rust:1-bookworm AS web
COPY --from=go /usr/local/go /usr/local/go
ENV PATH=/usr/local/go/bin:$PATH
WORKDIR /src
COPY rust-toolchain.toml ./
RUN rustup toolchain install
COPY . .
RUN --mount=type=cache,target=/usr/local/cargo/registry \
    --mount=type=cache,target=/src/target \
    cargo run --release --locked -p asset-compiler --bin assetc -- prepare --accept-eula \
    && cargo run --release --locked -p devtool -- build-web --assets .local/assets/compiled --out /bundle --release

FROM go AS build
WORKDIR /src
COPY . .
RUN --mount=type=cache,target=/go/pkg/mod \
    CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/relay ./core/cmd/bedrock-web-relay

FROM debian:bookworm-slim AS pack
ARG BINARYEN=version_133
ADD https://github.com/WebAssembly/binaryen/releases/download/${BINARYEN}/binaryen-${BINARYEN}-x86_64-linux.tar.gz /tmp/binaryen.tar.gz
RUN tar -xzf /tmp/binaryen.tar.gz -C /opt && mv /opt/binaryen-${BINARYEN} /opt/binaryen
COPY --from=web /bundle /bundle
RUN /opt/binaryen/bin/wasm-opt -Oz --strip-debug --strip-producers \
        /bundle/pkg/web_client_bg.wasm -o /bundle/pkg/web_client_bg.wasm \
    && rm /bundle/index.html /bundle/launcher.mjs \
    && find /bundle -type f -size +1k ! -name '*.mcbesnd' -exec gzip -9 -k {} + \
    && for gz in $(find /bundle -name '*.gz'); do \
        [ $(stat -c %s "$gz") -lt $(( $(stat -c %s "${gz%.gz}") * 9 / 10 )) ] || rm "$gz"; \
    done

FROM nginx:1.29-alpine AS site
COPY packaging/web/site.conf /etc/nginx/conf.d/default.conf
COPY --from=pack /bundle /usr/share/nginx/html

FROM gcr.io/distroless/static-debian12 AS relay
COPY --from=build /out/relay /relay
ENTRYPOINT ["/relay"]
