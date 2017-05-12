FROM java:8

ADD application.yml /application.yml

RUN curl  -n -sS -L "https://nexus.synyx.de/service/local/artifact/maven/redirect?g=coffee.synyx&a=auth&v=LATEST&r=public-snapshots&p=jar" > /auth.jar

EXPOSE 9999

CMD ["java", "-jar", "/auth.jar"]