# syntax=docker/dockerfile:1

# --- Build stage: uses the project's existing build scripts (no Maven/Gradle) ---
FROM eclipse-temurin:17-jdk-jammy AS build
RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /src
COPY build.sh ./
COPY tools/ tools/
RUN chmod +x tools/fetch-deps.sh
COPY src/ src/
RUN bash build.sh

# --- Runtime stage: one image, two roles selected by APP_ROLE ---
FROM eclipse-temurin:17-jre-jammy AS runtime
RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates bash \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd -g 10001 mstp \
    && useradd -u 10001 -g mstp -m -s /bin/bash mstp
WORKDIR /app
COPY --from=build /src/out/ out/
COPY --from=build /src/lib/ lib/
COPY web/ web/
COPY data/ data/
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY docker/healthcheck-gateway.sh /usr/local/bin/healthcheck-gateway.sh
COPY docker/healthcheck-rmi.sh /usr/local/bin/healthcheck-rmi.sh
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/healthcheck-gateway.sh /usr/local/bin/healthcheck-rmi.sh \
    && chown -R mstp:mstp /app
USER mstp
EXPOSE 8080 1099 1100
ENV APP_ROLE=gateway \
    JAVA_TOOL_OPTIONS="-Dfile.encoding=UTF-8" \
    MHT_DATA_DIR=/app/data \
    MHT_UPLOAD_DIR=/app/web/images/hotels \
    MHT_HTTP_PORT=8080 \
    MHT_RMI_HOST=mstp-rmi \
    MHT_RMI_HOSTNAME=mstp-rmi \
    MHT_RMI_REGISTRY_PORT=1099 \
    MHT_RMI_SERVICE_PORT=1100 \
    MHT_DEMO=false \
    MHT_TRUST_PROXY=false
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
