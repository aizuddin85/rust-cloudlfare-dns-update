# --- Stage 1: Build ---
FROM docker.io/library/rust:1.82-slim AS builder
WORKDIR /usr/src/myapp

# Install system dependencies for OpenSSL/Networking
RUN apt-get update && apt-get install -y pkg-config libssl-dev && rm -rf /var/lib/apt/lists/*

# The '*' makes Cargo.lock optional!
COPY Cargo.toml Cargo.lock* ./

RUN mkdir src && echo "fn main() {}" > src/main.rs && cargo build --release
COPY src ./src
RUN touch src/main.rs && cargo build --release

# --- Stage 2: Runtime (Secure & Sanitized) ---
FROM gcr.io/distroless/cc-debian12:latest
COPY --from=builder /usr/src/myapp/target/release/cloudflare_dns_updater /usr/local/bin/
USER nonroot:nonroot
ENTRYPOINT ["/usr/local/bin/cloudflare_dns_updater"]
