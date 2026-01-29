# --- Stage 1: Build ---
FROM docker.io/library/rust:1.82-slim AS builder

WORKDIR /usr/src/myapp

# 1. Install required build dependencies for Rust networking crates
RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# 2. Copy manifests (using wildcard to prevent crash if Cargo.lock is missing)
COPY Cargo.toml Cargo.lock* ./

# 3. Cache dependencies: Build a dummy binary to download/compile crates early
RUN mkdir src && \
    echo "fn main() {println!(\"dummy\")}" > src/main.rs && \
    cargo build --release && \
    rm -rf src/

# 4. Build the actual application
COPY src ./src
# We touch main.rs so cargo knows the source changed since the dummy build
RUN touch src/main.rs && cargo build --release

# --- Stage 2: Runtime (Sanitized) ---
# Distroless cc includes glibc and openssl but no shell/package manager
FROM gcr.io/distroless/cc-debian12:latest

# Copy the binary from the builder
# Ensure the name matches the [[bin]] name in your Cargo.toml
COPY --from=builder /usr/src/myapp/target/release/cloudflare_dns_updater /usr/local/bin/

# Use the non-privileged user provided by Distroless
USER nonroot:nonroot

ENTRYPOINT ["/usr/local/bin/cloudflare_dns_updater"]
