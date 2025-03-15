FROM phusion/baseimage:jammy-1.0.1

EXPOSE 80
EXPOSE 6080

# Use baseimage-docker's init system.
CMD ["/sbin/my_init"]


RUN echo 'APT::Get::Clean=always;' >> /etc/apt/apt.conf.d/99AutomaticClean

RUN apt-get update -qqy \
    && DEBIAN_FRONTEND=noninteractive apt-get -qyy install \
	--no-install-recommends \
	git \
        sudo \
	vim \ 
        nano \
	python3-venv \
	python3-dev \
	python3-lxml \
	libvirt-dev \
	zlib1g-dev \
	nginx \
	pkg-config \
	gcc \
	libldap2-dev \
	libssl-dev \
	libsasl2-dev \
	libsasl2-modules \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY . /srv/webvirtcloud
RUN cp /srv/webvirtcloud/webvirtcloud/settings.py.template /srv/webvirtcloud/webvirtcloud/settings.py && \
       SECRET=$(python3 /srv/webvirtcloud/conf/runit/secret_generator.py) && \
       sed -i "s|SECRET_KEY = \"\"|SECRET_KEY = \"$SECRET\"|" /srv/webvirtcloud/webvirtcloud/settings.py && \
       cp /srv/webvirtcloud/conf/nginx/webvirtcloud.conf /etc/nginx/conf.d && \
       chown -R www-data:www-data /srv/webvirtcloud

# Setup webvirtcloud
WORKDIR /srv/webvirtcloud
RUN python3 -m venv venv && \
	. venv/bin/activate && \
	pip3 install -U pip && \
	pip3 install wheel && \
	pip3 install -r conf/requirements.txt && \
	pip3 cache purge && \
	chown -R www-data:www-data /srv/webvirtcloud

RUN . venv/bin/activate && \
	python3 manage.py makemigrations && \
        python3 manage.py migrate && \
	python3 manage.py collectstatic --noinput && \
	chown -R www-data:www-data /srv/webvirtcloud

# Setup Nginx
RUN printf "\n%s" "daemon off;" >> /etc/nginx/nginx.conf && \
	rm /etc/nginx/sites-enabled/default && \
	chown -R www-data:www-data /var/lib/nginx && \
        mkdir -p /home/www-data/.ssh && \
        chown www-data:www-data /home/www-data && \
	chown www-data:www-data /home/www-data/.ssh && \
	chown www-data /srv/webvirtcloud/db.sqlite3 && \
        setuser www-data ssh-keygen -f /home/www-data/.ssh/id_rsa -q -N ""
	
RUN <<EOF
        echo "Host *" >> /home/www-data/.ssh/config
        echo "StrictHostKeyChecking no" >> /home/www-data/.ssh/config
EOF

RUN    chown www-data -R /home/www-data/.ssh/config
COPY conf/nginx/webvirtcloud.conf /etc/nginx/conf.d/

# Register services to runit
RUN	mkdir /etc/service/nginx && \
	mkdir /etc/service/nginx-log-forwarder && \
	mkdir /etc/service/webvirtcloud && \
	mkdir /etc/service/novnc

COPY conf/runit/nginx				/etc/service/nginx/run
COPY conf/runit/nginx-log-forwarder	/etc/service/nginx-log-forwarder/run
COPY conf/runit/novncd.sh			/etc/service/novnc/run
COPY conf/runit/webvirtcloud.sh		/etc/service/webvirtcloud/run

ENTRYPOINT ["sh conf/runit/entrypoint.shh"]

# Define mountable directories.
#VOLUME []

WORKDIR /srv/webvirtcloud
