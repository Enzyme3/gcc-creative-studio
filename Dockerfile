# Stage 1: Build the Google Socket Factory shaded JAR
FROM maven:3.9-eclipse-temurin-17 AS builder
WORKDIR /build
RUN git clone https://github.com/GoogleCloudPlatform/cloud-sql-jdbc-socket-factory.git . \
    && git checkout v1.21.0 \
    && mvn -pl jdbc/postgres -P jar-with-dependencies clean package -DskipTests

# Stage 2: Keycloak pre-optimized image
FROM quay.io/keycloak/keycloak:latest
COPY --from=builder /build/jdbc/postgres/target/postgres-socket-factory-*-jar-with-dependencies.jar /opt/keycloak/providers/postgres-socket-factory.jar
ENV KC_DB=postgres
ENV KC_PROXY_HEADERS=xforwarded
RUN /opt/keycloak/bin/kc.sh build
