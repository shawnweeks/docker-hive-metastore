function initialize_metastore() {
    log "Validating Metastore"
    ( ${METASTORE_HOME}/bin/schematool \
        -validate \
        -dbType ${METASTORE_TYPE} \
        -url ${METASTORE_URL} \
        -userName ${METASTORE_USERNAME} \
        -passWord ${METASTORE_PASSWORD} ) && true
    if (( "$?" != "0" ))
    then
        log "Initializing Metastore"
        ${METASTORE_HOME}/bin/schematool \
            -initSchema \
            -dbType ${METASTORE_TYPE} \
            -url ${METASTORE_URL} \
            -userName ${METASTORE_USERNAME} \
            -passWord ${METASTORE_PASSWORD}
        touch init/SUCCESS
        log "Metastore Initialized"
    fi
}

function configure_metastore_site() {
    log "Configuring Metastore Site XML"
    render_template /opt/templates/metastore-site.xml.template > ${METASTORE_HOME}/conf/metastore-site.xml
}

function configure() {
    log "Configuring Metastore"
    initialize_metastore
    configure_metastore_site
}