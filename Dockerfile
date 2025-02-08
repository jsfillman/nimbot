# Build Stage (Compiling & Stripping Binary)
FROM debian:stable-slim AS builder

WORKDIR /app

# Install Dependencies (SSL, glibc, OpenSSL, CA Certs)
RUN apt-get update && apt-get install -y \
    openssl \
    ca-certificates \
    libc6 \
    && apt-get clean && rm -rf /var/lib/apt/lists/* /usr/share/doc /usr/share/man /usr/share/locale

# Copy prebuilt binary
COPY nimbot /app/nimbot
COPY gpt_instructions.md /app/gpt_instructions.md

# Strip & Compress
# RUN strip --strip-all /app/nimbot && upx --best --lzma /app/nimbot

# Final Stage (Minimal Runtime)
FROM gcr.io/distroless/base

WORKDIR /app

# Copy files from builder stage
COPY --from=builder /app/nimbot /app/nimbot
COPY --from=builder /app/gpt_instructions.md /app/gpt_instructions.md

# ✅ Copy CA Certificates from Builder (Fixes Missing SSL Certs)
COPY --from=builder /etc/ssl/certs /etc/ssl/certs

# ✅ Copy Required Libraries (for Dynamic Linking)
COPY --from=builder /lib/aarch64-linux-gnu/libc.so.6 /lib/aarch64-linux-gnu/libc.so.6
COPY --from=builder /lib/ld-linux-aarch64.so.1 /lib/ld-linux-aarch64.so.1

# ✅ Copy OpenSSL if Needed (`libcrypto.so`)
COPY --from=builder /usr/lib/aarch64-linux-gnu/libcrypto.so* /usr/lib/aarch64-linux-gnu/

# Set environment variable for API key (must be provided at runtime)
ENV OPENAI_API_KEY=""

# Set Dynamic Loader Path
ENV LD_LIBRARY_PATH="/lib/aarch64-linux-gnu:/usr/lib/aarch64-linux-gnu"

# Run the chatbot
ENTRYPOINT ["/app/nimbot"]

