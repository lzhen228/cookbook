FROM eclipse-temurin:17.0.9-jdk-alpine AS builder

WORKDIR /build
COPY pom.xml .
COPY src ./src

RUN apk add --no-cache maven \
    && mvn clean package -DskipTests -q

FROM eclipse-temurin:17.0.9-jre-alpine

RUN addgroup -S app && adduser -S app -G app

WORKDIR /app
COPY --from=builder /build/target/*.jar app.jar

RUN chown -R app:app /app
USER app

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=10s --retries=3 --start-period=60s \
    CMD wget -q --spider http://localhost:8080/api/v1/actuator/health/liveness || exit 1

ENTRYPOINT ["java", "-jar", "app.jar"]
