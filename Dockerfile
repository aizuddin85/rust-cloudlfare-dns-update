# Use the official Rust image as the base image
FROM docker.io/library/rust:latest as builder

# Set the working directory inside the container
WORKDIR /usr/src/myapp

# Copy the Cargo.toml and Cargo.lock files
COPY Cargo.toml ./

# Copy the source code
COPY src ./src

# Install dependencies and build the release binary
RUN cargo build --release

# Use the official Debian image for the final image
FROM registry.access.redhat.com/ubi9/ubi-minimal:latest

# Copy the release binary from the builder image
COPY --from=builder /usr/src/myapp/target/release/cloudflare_dns_updater /usr/local/bin/cloudflare_dns_updater

# Set the working directory
WORKDIR /usr/local/bin

USER 1001

# Set the entry point to the built binary
ENTRYPOINT ["./cloudflare_dns_updater"]

