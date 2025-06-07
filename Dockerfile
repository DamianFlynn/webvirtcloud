FROM phusion/baseimage:noble-1.0.2

EXPOSE 80 6080

# Use baseimage-docker's init system.
CMD ["/sbin/my_init"]

COPY . /srv/webvirtcloud

RUN echo 'APT::Get::Clean=always;' >> /etc/apt/apt.conf.d/99AutomaticClean && \
    apt-get update -qqy && \
    DEBIAN_FRONTEND=noninteractive apt-get -qyy install --no-install-recommends \
        git sudo vim nano python3-venv python3-dev python3-lxml libvirt-dev \
        zlib1g-dev nginx pkg-config gcc libldap2-dev libssl-dev \
        libsasl2-dev libsasl2-modules net-tools lsof procps && \
        apt-get clean && \
        rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    mkdir /etc/service/nginx && \
       mkdir /etc/service/nginx-log-forwarder && \
       mkdir /etc/service/webvirtcloud && \
       mkdir /etc/service/novnc && \
       mkdir -p /etc/my_init.d && \
       cp /srv/webvirtcloud/conf/runit/nginx /etc/service/nginx/run && \
       cp /srv/webvirtcloud/conf/runit/nginx-log-forwarder /etc/service/nginx-log-forwarder/run && \
       cp /srv/webvirtcloud/conf/runit/webvirtcloud.sh /etc/service/webvirtcloud/run && \
       cp /srv/webvirtcloud/conf/runit/novncd.sh /etc/service/novnc/run && \
       cp /srv/webvirtcloud/conf/runit/entrypoint.sh /etc/my_init.d/entrypoint.sh && \
       chmod +x /etc/my_init.d/entrypoint.sh && \
       chmod +x /etc/service/nginx/run && \
       chmod +x /etc/service/nginx-log-forwarder/run && \
       chmod +x /etc/service/webvirtcloud/run && \
       chmod +x /etc/service/novnc/run && \
       cp /srv/webvirtcloud/webvirtcloud/settings.py.template /srv/webvirtcloud/webvirtcloud/settings.py && \
       SECRET=$(python3 /srv/webvirtcloud/conf/runit/secret_generator.py) && \
       sed -i "s|SECRET_KEY = \"\"|SECRET_KEY = \"$SECRET\"|" /srv/webvirtcloud/webvirtcloud/settings.py && \
       cp /srv/webvirtcloud/conf/nginx/webvirtcloud.conf /etc/nginx/conf.d

# Setup webvirtcloud - Install dependencies only, don't initialize data
WORKDIR /srv/webvirtcloud
RUN python3 -m venv venv && \
    . venv/bin/activate && \
    pip3 install -U pip && \
    pip3 install wheel && \
    pip3 install -r conf/requirements.txt && \
    pip3 cache purge && \
    # Create directory structures but don't initialize data
    mkdir -p ~www-data/.ssh && \
    mkdir -p /srv/webvirtcloud/static && \
    # Ensure novncd script is executable
    chmod +x /srv/webvirtcloud/console/novncd && \
    chown -R www-data:www-data /srv/webvirtcloud && \
    rm /etc/nginx/sites-enabled/default && \
    chown -R www-data:www-data /var/lib/nginx && \
    chown -R www-data:www-data ~www-data && \
    chown -R www-data:www-data /srv/webvirtcloud/static
    # Database migrations, static files, and SSH keys will be handled at runtime
