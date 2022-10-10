FROM rockylinux:8 as build

# Install Build Dependencies
RUN yum install -y java-1.8.0-openjdk-devel maven git

ARG METASTORE_VERSION=3.1.3
ARG HADOOP_VERSION=3.3.4

ENV METASTORE_HOME /opt/metastore
ENV HADOOP_HOME /opt/hadoop

RUN git clone --depth 1 --branch rel/release-${METASTORE_VERSION} https://github.com/apache/hive.git && \
    cd hive/standalone-metastore && \
    mvn clean package -DskipTests && \
    mkdir -p ${METASTORE_HOME}/{tmp,logs,init} && \
    tar -xf target/apache-hive-metastore-${METASTORE_VERSION}-bin.tar.gz -C ${METASTORE_HOME} --strip-components=1  && \
    mkdir -p ${HADOOP_HOME} && \
    curl https://archive.apache.org/dist/hadoop/common/current/hadoop-${HADOOP_VERSION}.tar.gz | tar -xz -C ${HADOOP_HOME} --strip-components=1

# Install JDBC Drivers
RUN curl https://jdbc.postgresql.org/download/postgresql-42.5.0.jar -o ${METASTORE_HOME}/lib/postgresql.jar

###############################################################################
FROM rockylinux:8

ENV METASTORE_USER metastore
ENV METASTORE_GROUP metastore
ENV METASTORE_UID 2001
ENV METASTORE_GID 2001

ENV METASTORE_HOME /opt/metastore
ENV HADOOP_HOME /opt/hadoop

RUN yum install -y java-1.8.0-openjdk-devel openssl && \
    yum clean all && \
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