FROM alpine:3.20 AS builder

RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories && \
    apk add --no-cache openjdk17 maven

WORKDIR /build
COPY pom.xml .
COPY maven-settings.xml .
COPY src ./src

RUN mvn clean package -DskipTests -q -s maven-settings.xml

FROM alpine:3.20

RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories && \
    apk add --no-cache openjdk17-jre-headless wget

RUN addgroup -S app && adduser -S app -G app

WORKDIR /app
COPY --from=builder /build/target/*.jar app.jar

RUN chown -R app:app /app
USER app

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=10s --retries=3 --start-period=60s \
    CMD wget -q --spider http://localhost:8080/api/v1/actuator/health/liveness || exit 1

ENTRYPOINT ["java", "-jar", "app.jar"]
