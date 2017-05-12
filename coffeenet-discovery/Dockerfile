FROM java:8

ADD application.yml /application.yml

RUN curl  -n -sS -L "https://nexus.synyx.de/service/local/artifact/maven/redirect?g=coffee.synyx&a=discovery&v=LATEST&r=public-snapshots&p=jar" > /discovery.jar

EXPOSE 8761

CMD ["java", "-jar", "/discovery.jar"]