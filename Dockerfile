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

FROM nginx:1.29-alpine AS site
COPY --from=web /bundle /usr/share/nginx/html

FROM gcr.io/distroless/static-debian12 AS relay
COPY --from=build /out/relay /relay
ENTRYPOINT ["/relay"]
