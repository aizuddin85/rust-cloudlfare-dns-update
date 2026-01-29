# --- Stage 1: Build ---
FROM docker.io/library/rust:latest AS builder

WORKDIR /usr/src/myapp

# 1. Install system dependencies (essential for networking crates)
RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# 2. Copy ALL metadata files first. 
# This prevents 'Cargo' from panicking if it looks for README/LICENSE/Lock.
COPY Cargo.toml Cargo.lock* README.md* LICENSE* ./

# 3. Create dummy source and build dependencies
# We use a real file name instead of just 'main.rs' in case you have a library
RUN mkdir src && \
    echo "fn main() {}" > src/main.rs && \
    cargo build --release && \
    rm -rf src/

# 4. Copy actual source and build
COPY src ./src
RUN touch src/main.rs && cargo build --release

# --- Stage 2: Runtime (Sanitized & Secure) ---
FROM gcr.io/distroless/cc-debian13:latest

# Ensure this name matches the 'name' in your Cargo.toml [package] section
COPY --from=builder /usr/src/myapp/target/release/cloudflare_dns_updater /usr/local/bin/

USER nonroot:nonroot

ENTRYPOINT ["/usr/local/bin/cloudflare_dns_updater"]
