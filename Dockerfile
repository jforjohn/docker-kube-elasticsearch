# This Dockerfile was generated from templates/Dockerfile.j2

#FROM centos:7
FROM openjdk:8-jre-alpine
LABEL maintainer "Elastic Docker Team <docker@elastic.co>"

ENV ELASTIC_CONTAINER true
ENV PATH /usr/share/elasticsearch/bin:$PATH
#ENV JAVA_HOME /usr/lib/jvm/jre-1.8.0-openjdk
ENV ELASTICSEARCH_VERSION 5.3.1

#RUN yum update -y && yum install -y java-1.8.0-openjdk-headless wget which && yum clean all
RUN apk add --no-cache --update bash ca-certificates su-exec util-linux; \
    apk add --no-cache -t .build-deps wget gnupg openssl; \
    addgroup -g 1000 elasticsearch && adduser -SD -u 1000 -G elasticsearch -h /usr/share/elasticsearch elasticsearch

WORKDIR /usr/share/elasticsearch

# Download/extract defined ES version. busybox tar can't strip leading dir.
RUN wget --progress=bar:force https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-$ELASTICSEARCH_VERSION.tar.gz && \
    EXPECTED_SHA=$(wget -O - https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-$ELASTICSEARCH_VERSION.tar.gz.sha1) && \
    REAL_SHA=$(sha1sum elasticsearch-$ELASTICSEARCH_VERSION.tar.gz | awk '{print $1}') && \
    test $EXPECTED_SHA==$REAL_SHA && \
    tar zxf elasticsearch-$ELASTICSEARCH_VERSION.tar.gz && \
    chown -R elasticsearch:elasticsearch elasticsearch-$ELASTICSEARCH_VERSION && \
    mv elasticsearch-$ELASTICSEARCH_VERSION/* . && \
    rmdir elasticsearch-$ELASTICSEARCH_VERSION && \
    rm elasticsearch-$ELASTICSEARCH_VERSION.tar.gz

RUN set -ex && for esdirs in config data logs; do \
        mkdir -p "$esdirs"; \
        chown -R elasticsearch:elasticsearch "$esdirs"; \
    done

USER elasticsearch
# Install x-pack and also the ingest-{agent,geoip} modules required for Filebeat
# ingest-user-agent ingest-geoip
RUN for PLUGIN_TO_INST in x-pack io.fabric8:elasticsearch-cloud-kubernetes:$ELASTICSEARCH_VERSION; do elasticsearch-plugin install --batch "$PLUGIN_TO_INST"; done
COPY elasticsearch.yml config/
COPY log4j2.properties config/
COPY bin/es-docker bin/es-docker

USER root
RUN chown elasticsearch:elasticsearch config/elasticsearch.yml config/log4j2.properties bin/es-docker && \
    chmod 0750 bin/es-docker

EXPOSE 9200 9300
VOLUME ['/usr/share/elasticsearch/data','/usr/share/elasticsearch/logs']

# Set environment variables defaults
ENV ES_JAVA_OPTS "-Xms512m -Xmx512m"
ENV CLUSTER_NAME SMONNET
ENV NODE_MASTER true
ENV NODE_DATA true
ENV NODE_INGEST true
ENV HTTP_ENABLE true
ENV NETWORK_HOST _site_
ENV HTTP_CORS_ENABLE true
ENV HTTP_CORS_ALLOW_ORIGIN *
ENV NUMBER_OF_MASTERS 1
ENV MAX_LOCAL_STORAGE_NODES 1
ENV SHARD_ALLOCATION_AWARENESS ""
ENV SHARD_ALLOCATION_AWARENESS_ATTR ""
ENV DISCOVERY_SERVICE elasticsearch-discovery

#USER elasticsearch
CMD ["/bin/bash", "bin/es-docker"]
