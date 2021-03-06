Alpine JasperReports Server CE (Oracle 11g) Docker image
========================================================

This image is based on Alpine tomcat image ([tomcat:8.5-jre8-alpine](https://hub.docker.com/_/tomcat/)), which is only a 75MB image, and provides a docker image for JasperReports Server CE with Oracle 11g as repository database.

Prerequisites
-------------

- If you want to build this image, you will need to download [Oracle Database 11g Release 2 JDBC Driver - ojdbc6.jar](http://www.oracle.com/technetwork/apps-tech/jdbc-112010-090769.html) and [Oracle SQLcl 18.1.1](http://www.oracle.com/technetwork/developer-tools/sqlcl/downloads/index.html).

Usage Example
-------------

This image is intended to be a base image for your projects, so you may use it like this:

```Dockerfile
FROM cosmomill/alpine-jasperserverce-oracle
```

```sh
$ docker build -t my_app . --build-arg ORACLE_JDBC_DRIVER="ojdbc6.jar" --build-arg SQLCL_FILE="sqlcl-18.1.1.zip"
```

```sh
$ docker run -d -P --link <your cosmomill/alpine-oracle-xe container>:db --volumes-from <your cosmomill/alpine-oracle-xe container> -v jasperserver_src:/usr/src/jasperserver -v jasperserver_webapps:/usr/local/tomcat/webapps -e DATABASE_HOSTNAME="db" -p 8080:8080 my_app
```

The default list of ENV variables is:

```
DATABASE_HOSTNAME=
ORACLE_SID=XE
DATABASE_PORT=1521
CATALINA_OPTS=-Doracle.jdbc.defaultNChar=true -Xms1024m -Xmx2048m -XX:PermSize=32m -XX:MaxPermSize=512m -Xss2m -XX:+UseConcMarkSweepGC -XX:+CMSClassUnloadingEnabled
```

Connect to database
-------------------

Auto generated passwords are stored in separate hidden files in ```/u01/app/oracle/oradata/dbconfig/XE``` with the naming system ```.username.passwd```.

Using wait-for-oracle.sh
------------------------

If you want bootstrap the entire application with a single command using Docker Compose you have to use ```wait-for-oracle.sh```. The problem is that Docker Compose does not wait for the Oracle Database container to become ready before starting the JasperReports container. When you start the application using ```docker-compose up``` Docker Compose does not ensure that the Oracle Database container is ready before the JasperReports Container is started. This means your application will fail to start. The ```depends_on``` only means that the Oracle Database container should be started first but Docker Compose does not ensure Oracle Database is full ready for connections.
Usage example:

```sh
jasperserver:
  depends_on:
    - oradb
  entrypoint: /usr/local/bin/wait-for-oracle.sh -- docker-entrypoint.sh
  command: run
  build:
    context: ./jasperserver
  ports:
    - "8080:8080"
  volumes:
    - jasperserver_src:/usr/src/jasperserver
    - jasperserver_webapps:/usr/local/tomcat/webapps
  volumes_from:
    - oradb
  environment:
    DATABASE_HOSTNAME: oradb
  restart: always
```