FROM redhat/ubi8-minimal as build

# Install Build Dependencies
RUN microdnf install -y java-1.8.0-openjdk-devel maven git tar

ARG HADOOP_VERSION=3.3.4

ENV METASTORE_HOME /opt/metastore
ENV HADOOP_HOME /opt/hadoop

COPY hive/standalone-metastore/ /tmp/standalone-metastore/

RUN cd /tmp/standalone-metastore && \
    mvn clean package -DskipTests && \
    mkdir -p ${METASTORE_HOME}/{tmp,logs,init} && \
    tar -xf target/apache-hive-metastore-*-bin.tar.gz -C ${METASTORE_HOME} --strip-components=1  && \
    mkdir -p ${HADOOP_HOME} && \
    curl https://archive.apache.org/dist/hadoop/common/current/hadoop-${HADOOP_VERSION}.tar.gz | tar -xz -C ${HADOOP_HOME} --strip-components=1

# Removing some parts of Hadoop that aren't needed.
RUN rm -rf ${HADOOP_HOME}/share/doc && \
    rm -rf ${HADOOP_HOME}/share/hadoop/tools && \
    rm -rf ${HADOOP_HOME}/share/hadoop/client

# Install JDBC Drivers
RUN curl https://jdbc.postgresql.org/download/postgresql-42.5.0.jar -o ${METASTORE_HOME}/lib/postgresql.jar

###############################################################################
FROM redhat/ubi8-minimal

ENV METASTORE_USER metastore
ENV METASTORE_GROUP metastore
ENV METASTORE_UID 2001
ENV METASTORE_GID 2001

ENV METASTORE_HOME /opt/metastore
ENV HADOOP_HOME /opt/hadoop

RUN microdnf install -y java-1.8.0-openjdk-devel shadow-utils openssl && \
    mkdir -p ${METASTORE_HOME} && \
    mkdir -p ${HADOOP_HOME} && \
    groupadd -r -g ${METASTORE_GID} ${METASTORE_GROUP} && \
    useradd -r -u ${METASTORE_UID} -g ${METASTORE_GROUP} -M -d ${METASTORE_HOME} ${METASTORE_USER} && \
    chown ${METASTORE_USER}:${METASTORE_GROUP} ${METASTORE_HOME} -R

COPY --from=build --chown=${METASTORE_USER}:${METASTORE_GROUP} [ "${METASTORE_HOME}", "${METASTORE_HOME}/" ]
COPY --from=build --chown=${METASTORE_USER}:${METASTORE_GROUP} [ "${HADOOP_HOME}", "${HADOOP_HOME}/" ]
COPY --chown=${METASTORE_USER}:${METASTORE_GROUP} [ "templates/", "/opt/templates/" ]
COPY --chown=${METASTORE_USER}:${METASTORE_GROUP} --chmod=755 [ "entrypoint*.sh", "${METASTORE_HOME}/" ]

USER ${METASTORE_USER}
ENV JAVA_HOME=/usr/lib/jvm/java-1.8.0
ENV PATH=${PATH}:${METASTORE_HOME}
WORKDIR ${METASTORE_HOME}