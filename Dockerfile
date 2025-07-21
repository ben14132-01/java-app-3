FROM openjdk:17-jdk-slim

WORKDIR /app

COPY src/SpringAPI/target/SpringAPI-0.0.1-SNAPSHOT.jar /app/my-spring-boot-app.jar

EXPOSE 8081

CMD ["java", "-jar", "/app/my-spring-boot-app.jar"]

