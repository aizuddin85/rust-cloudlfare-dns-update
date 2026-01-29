# --- Stage 1: Build ---
# Updated to 1.82-slim to satisfy zerovec requirements
FROM docker.io/library/rust:latest AS builder

WORKDIR /usr/src/myapp

# Install build dependencies (openssl and pkg-config are often needed for Rust network crates)
RUN apt-get update && apt-get install -y pkg-config libssl-dev && rm -rf /var/lib/apt/lists/*

# Cache dependencies
COPY Cargo.toml Cargo.lock ./
RUN mkdir src && echo "fn main() {}" > src/main.rs && cargo build --release

# Build actual source
COPY src ./src
RUN touch src/main.rs && cargo build --release

# --- Stage 2: Runtime ---
# Using the 'cc' variant because most Rust networking crates link against glibc
FROM gcr.io/distroless/cc-debian13:latest

COPY --from=builder /usr/src/myapp/target/release/cloudflare_dns_updater /usr/local/bin/

USER nonroot:nonroot

ENTRYPOINT ["/usr/local/bin/cloudflare_dns_updater"]
