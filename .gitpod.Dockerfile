FROM gitpod/workspace-postgres
                    
USER root

# Install custom tools, runtime, etc. using apt-get
# For example, the command below would install "bastet" - a command line tetris clone:
#
# RUN sudo apt-get -q update && #     sudo apt-get install -yq bastet && #     sudo rm -rf /var/lib/apt/lists/*
#
# More information: https://www.gitpod.io/docs/config-docker/

ARG GEOIP_UPDATER_VERSION=4.1.5
ARG MQT=https://github.com/OCA/maintainer-quality-tools.git
ARG WKHTMLTOPDF_VERSION=0.12.5
ARG WKHTMLTOPDF_CHECKSUM='1140b0ab02aa6e17346af2f14ed0de807376de475ba90e1db3975f112fbd20bb'
ENV DB_FILTER=.* \
    DEPTH_DEFAULT=1 \
    DEPTH_MERGE=100 \
    EMAIL=https://hub.docker.com/r/tecnativa/odoo \
    GEOIP_ACCOUNT_ID="" \
    GEOIP_LICENSE_KEY="" \
    GIT_AUTHOR_NAME=docker-odoo \
    INITIAL_LANG="" \
    LC_ALL=C.UTF-8 \
    LIST_DB=false \
    NODE_PATH=/usr/local/lib/node_modules:/usr/lib/node_modules \
    OPENERP_SERVER=/opt/odoo/auto/odoo.conf \
    PATH="/home/odoo/.local/bin:$PATH" \
    PIP_NO_CACHE_DIR=0 \
    PTVSD_ARGS="--host 0.0.0.0 --port 6899 --wait --multiprocess" \
    PTVSD_ENABLE=0 \
    PUDB_RDB_HOST=0.0.0.0 \
    PUDB_RDB_PORT=6899 \
    PYTHONOPTIMIZE=1 \
    UNACCENT=true \
    WAIT_DB=true \
    WDB_NO_BROWSER_AUTO_OPEN=True \
    WDB_SOCKET_SERVER=wdb \
    WDB_WEB_PORT=1984 \
    WDB_WEB_SERVER=localhost

# Other requirements and recommendations
# See https://github.com/$ODOO_SOURCE/blob/$ODOO_VERSION/debian/control
RUN apt-get -qq update \
    && apt-get install -yqq --no-install-recommends \
        curl \
    && curl -SLo wkhtmltox.deb https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/${WKHTMLTOPDF_VERSION}/wkhtmltox_${WKHTMLTOPDF_VERSION}-1.stretch_amd64.deb \
    && echo "${WKHTMLTOPDF_CHECKSUM}  wkhtmltox.deb" | sha256sum -c - \
    && apt-get install -yqq --no-install-recommends \
        ./wkhtmltox.deb \
    && curl --silent -L --output geoipupdate_${GEOIP_UPDATER_VERSION}_linux_amd64.deb https://github.com/maxmind/geoipupdate/releases/download/v${GEOIP_UPDATER_VERSION}/geoipupdate_${GEOIP_UPDATER_VERSION}_linux_amd64.deb \
    && dpkg -i geoipupdate_${GEOIP_UPDATER_VERSION}_linux_amd64.deb \
    && rm geoipupdate_${GEOIP_UPDATER_VERSION}_linux_amd64.deb \
    && apt-get autopurge -yqq \
    && rm -Rf wkhtmltox.deb /var/lib/apt/lists/* /tmp/* \
    && sync

# Doodba-QA dependencies in a separate virtualenv
COPY qa /qa
RUN python -m venv --system-site-packages /qa/venv \
    && . /qa/venv/bin/activate \
    && pip install \
        click \
        coverage \
        flake8 \
        pylint-odoo \
        six \
    && npm install --loglevel error --prefix /qa eslint \
    && deactivate \
    && mkdir -p /qa/artifacts \
    && git clone --depth 1 $MQT /qa/mqt

ARG ODOO_SOURCE=ODOO/ODOO
ARG ODOO_VERSION=13.0
ENV ODOO_VERSION="$ODOO_VERSION"

# Install Odoo hard & soft dependencies, and Doodba utilities
RUN build_deps=" \
        build-essential \
        libfreetype6-dev \
        libfribidi-dev \
        libghc-zlib-dev \
        libharfbuzz-dev \
        libjpeg-dev \
        liblcms2-dev \
        libldap2-dev \
        libopenjp2-7-dev \
        libpq-dev \
        libsasl2-dev \
        libtiff5-dev \
        libwebp-dev \
        libxml2-dev \
        libxslt-dev \
        tcl-dev \
        tk-dev \
        zlib1g-dev \
    " \
    && apt-get update \
    && apt-get install -yqq --no-install-recommends $build_deps \
    && pip install \
        -r https://raw.githubusercontent.com/$ODOO_SOURCE/$ODOO_VERSION/requirements.txt \
        'websocket-client~=0.56' \
        astor \
        git-aggregator \
        click-odoo-contrib \
        pg_activity \
        phonenumbers \
        plumbum \
        ptvsd \
        pudb \
        watchdog \
        wdb \
        geoip2 \
        inotify \
    && (python3 -m compileall -q /usr/local/lib/python3.6/ || true) \
    && apt-get purge -yqq $build_deps \
    && apt-get autopurge -yqq \
    && rm -Rf /var/lib/apt/lists/* /tmp/*

USER gitpod

RUN git clone https://github.com/odoo/odoo.git -b$ODOO_VERSION

USER gitpod
