################################################################################
# Build stage 0 `prep_es_files`:
# Extract elasticsearch artifact
# Install required plugins
# Set gid=0 and make group perms==owner perms
################################################################################

FROM centos:7

ARG ELASTIC_VERSION=6.2.3
ARG ELASTIC_TAR_URL=https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-${ELASTIC_VERSION}.tar.gz

ENV ELASTIC_CONTAINER true
ENV PATH /usr/share/elasticsearch/bin:$PATH
ENV JAVA_HOME /usr/lib/jvm/jre-1.8.0-openjdk

RUN yum update -y && \
    yum install -y nc java-1.8.0-openjdk-headless unzip wget which && \
    yum clean all

RUN groupadd -g 1000 elasticsearch && \
    adduser -u 1000 -g 1000 -d /usr/share/elasticsearch elasticsearch

WORKDIR /usr/share/elasticsearch

USER 1000

# Download and extract defined ES version.
RUN curl -fsSL ${ELASTIC_TAR_URL} | \
    tar zx --strip-components=1

RUN set -ex && for esdirs in config data logs; do \
    mkdir -p "$esdirs"; \
    done

# Install x-pack and also the ingest-{agent,geoip} modules required for Filebeat
RUN for PLUGIN in x-pack ingest-user-agent ingest-geoip; do \
    elasticsearch-plugin install --batch "$PLUGIN"; done

COPY --chown=1000:0 elasticsearch.yml log4j2.properties config/

RUN echo 'xpack.license.self_generated.type: basic' >>config/elasticsearch.yml

USER 0

# Set gid to 0 for elasticsearch and make group permission similar to that of user
# This is needed, for example, for Openshift Open: https://docs.openshift.org/latest/creating_images/guidelines.html
# and allows ES to run with an uid
RUN chown -R elasticsearch:0 . && \
    chmod -R g=u /usr/share/elasticsearch && \
    chmod 0775 /usr/share/elasticsearch && \
    chgrp 0 /usr/share/elasticsearch

WORKDIR /usr/share/elasticsearch

RUN chown -R 1000:0 /usr/share/elasticsearch

COPY --chown=1000:0 bin/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
    
# Openshift overrides USER and uses ones with randomly uid>1024 and gid=0
# Allow ENTRYPOINT (and ES) to run even with a different user
RUN chgrp 0 /usr/local/bin/docker-entrypoint.sh && \
    chmod g=u /etc/passwd && \
    chmod 0775 /usr/local/bin/docker-entrypoint.sh

EXPOSE 9200 9300

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
# Dummy overridable parameter parsed by entrypoint
CMD ["eswrapper"]