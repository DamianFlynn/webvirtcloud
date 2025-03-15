FROM phusion/baseimage:jammy-1.0.1

EXPOSE 80 6080
CMD ["/sbin/my_init"]

# 合并所有 apt 操作到单层，并彻底清理缓存
RUN echo 'APT::Get::Clean=always;' >> /etc/apt/apt.conf.d/99AutomaticClean && \
    apt-get update -qqy && \
    DEBIAN_FRONTEND=noninteractive apt-get -qyy install --no-install-recommends \
        git sudo vim nano python3-venv python3-dev python3-lxml libvirt-dev \
        zlib1g-dev nginx pkg-config gcc libldap2-dev libssl-dev \
        libsasl2-dev libsasl2-modules && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY . /srv/webvirtcloud

# 合并 Python 虚拟环境构建和依赖安装
RUN cp /srv/webvirtcloud/webvirtcloud/settings.py.template /srv/webvirtcloud/webvirtcloud/settings.py && \
    SECRET=$(python3 /srv/webvirtcloud/conf/runit/secret_generator.py) && \
    sed -i "s|SECRET_KEY = \"\"|SECRET_KEY = \"$SECRET\"|" /srv/webvirtcloud/webvirtcloud/settings.py && \
    cp /srv/webvirtcloud/conf/nginx/webvirtcloud.conf /etc/nginx/conf.d && \
    python3 -m venv venv && \
    . venv/bin/activate && \
    pip3 install -U pip wheel -r conf/requirements.txt && \
    pip3 cache purge && \
    python3 manage.py makemigrations && \
    python3 manage.py migrate && \
    python3 manage.py collectstatic --noinput && \
    chown -R www-data:www-data /srv/webvirtcloud /var/lib/nginx && \
    mkdir -p /home/www-data/.ssh && \
    chown www-data:www-data /home/www-data /home/www-data/.ssh && \
    setuser www-data ssh-keygen -f /home/www-data/.ssh/id_rsa -q -N ""

# 合并 Nginx 配置和 SSH 配置
RUN printf "\n%s" "daemon off;" >> /etc/nginx/nginx.conf && \
    rm /etc/nginx/sites-enabled/default && \
    echo -e "Host *\nStrictHostKeyChecking no" > /home/www-data/.ssh/config && \
    chown www-data /srv/webvirtcloud/db.sqlite3

# 合并服务注册和初始化脚本
RUN mkdir -p /etc/service/{nginx,nginx-log-forwarder,webvirtcloud,novnc} && \
    cp conf/runit/{nginx,nginx-log-forwarder/run,novncd.sh,webvirtcloud.sh} /etc/service/ && \
    mkdir -p /etc/my_init.d && \
    cp conf/runit/entrypoint.sh /etc/my_init.d/ && \
    chmod +x /etc/my_init.d/entrypoint.sh

WORKDIR /srv/webvirtcloud
