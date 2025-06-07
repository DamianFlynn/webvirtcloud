[![Gitpod ready-to-code](https://img.shields.io/badge/Gitpod-ready--to--code-blue?logo=gitpod)](https://gitpod.io/#https://github.com/retspen/webvirtcloud)

# WebVirtCloud
###### Python >=3.11 & Django 4.2 LTS

## Features
* QEMU/KVM Hypervisor Management
* QEMU/KVM Instance Management - Create, Delete, Update
* Hypervisor & Instance web based stats
* Manage Multiple QEMU/KVM Hypervisor
* Manage Hypervisor Datastore pools
* Manage Hypervisor Networks
* Instance Console Access with Browsers
* Libvirt API based web management UI
* User Based Authorization and Authentication
* User can add SSH public key to root in Instance (Tested only Ubuntu)
* User can change root password in Instance (Tested only Ubuntu)
* Supports cloud-init datasource interface

## Running within a Container

I have packaged the image to a container, which I am hosting on Github Container services. 
Using the following we can run this container on our host.

> **Note:** If the host has a firewall running, you must ensure that the ports we are to listen on are open!

### Prerequisites

Before starting, ensure your host system has:
- KVM/libvirt properly configured
- Docker installed and running
- Firewall configured to allow the necessary ports

### Container Configuration

#### Environment Variables

The container uses several environment variables for configuration:

| Variable | Description | Example Value |
|----------|-------------|---------------|
| `CURRENT_IP` | Your host IP and WebVirtCloud port | `"192.168.1.100:8080"` |
| `DEBUG` | Enable debug logging | `True` |
| `KVM_HOST` | Your KVM host IP address | `"192.168.1.100"` |
| `KVM_HOSTNAME` | Your host's hostname | `"myhost"` |
| `WS_PUBLIC_HOST` | Host IP for WebSocket connections | `"192.168.1.100"` |
| `WS_PUBLIC_PORT` | External port for noVNC WebSocket | `"6080"` |
| `WS_PUBLIC_PATH` | WebSocket path | `"novncd/"` |

#### Port Mapping

| Internal Port | External Port | Purpose |
|---------------|---------------|---------|
| 80 | 8080 (configurable) | WebVirtCloud web interface |
| 6080 | 6080 (configurable) | noVNC WebSocket for console access |

### Start the Container

Replace the IP addresses and ports with your actual values:

```bash
# Set your configuration variables
HOST_IP="192.168.1.100"          # Replace with your host IP
WEB_PORT="8080"                  # Replace with desired web interface port
VNC_PORT="6080"                  # Replace with desired VNC console port
HOSTNAME="$(hostname)"           # Or set your hostname manually

# Stop and remove existing container if it exists
docker stop webvirtcloud 2>/dev/null && docker rm webvirtcloud 2>/dev/null

# Start the container with your configuration
docker run -dit \
  -e CURRENT_IP="${HOST_IP}:${WEB_PORT}" \
  -e DEBUG=True \
  -e KVM_HOST="${HOST_IP}" \
  -e KVM_HOSTNAME="${HOSTNAME}" \
  -e WS_PUBLIC_HOST="${HOST_IP}" \
  -e WS_PUBLIC_PORT="${VNC_PORT}" \
  -e WS_PUBLIC_PATH="novncd/" \
  -v /var/run/libvirt/:/var/run/libvirt/ \
  -v /dev/pts/:/dev/pts/ \
  -p ${WEB_PORT}:80 \
  -p ${VNC_PORT}:6080 \
  --name webvirtcloud \
  ghcr.io/damianflynn/webvirtcloud:20250606075619
```

### Security: Create a Dedicated User (Recommended)

For better security, create a dedicated user for WebVirtCloud connections instead of using your personal account.

#### For NixOS Users

Add this configuration to your NixOS system configuration:

```nix
# Add to your system configuration
users.users.webvirtcloud = {
  isNormalUser = true;
  description = "WebVirtCloud Service User";
  extraGroups = [ "libvirtd" "libvirt" "kvm" "qemu-libvirtd" ];
  openssh.authorizedKeys.keys = [
    # This will be filled with the container's public key
  ];
};

# Ensure polkit rules allow this user to manage VMs
security.polkit.extraConfig = ''
  polkit.addRule(function(action, subject) {
    if (action.id == "org.libvirt.unix.manage" &&
        subject.user == "webvirtcloud") {
        return polkit.Result.YES;
    }
  });
'';
```

Apply the configuration:
```bash
sudo nixos-rebuild switch
```

#### For Other Linux Distributions

```bash
# Create dedicated user
sudo useradd -m -s /bin/bash webvirtcloud
sudo usermod -a -G libvirt,kvm,qemu-libvirtd webvirtcloud

# Create SSH directory
sudo mkdir -p /home/webvirtcloud/.ssh
sudo chown webvirtcloud:webvirtcloud /home/webvirtcloud/.ssh
sudo chmod 700 /home/webvirtcloud/.ssh

# Configure polkit (create file /etc/polkit-1/rules.d/50-webvirtcloud.rules)
sudo tee /etc/polkit-1/rules.d/50-webvirtcloud.rules << 'EOF'
polkit.addRule(function(action, subject) {
  if (action.id == "org.libvirt.unix.manage" &&
      subject.user == "webvirtcloud") {
      return polkit.Result.YES;
  }
});
EOF

sudo systemctl restart polkit
```

### Set up SSH Access

#### Step 1: Get the Container's Public Key

```bash
# Get the container's SSH public key
docker exec -it webvirtcloud sudo -u www-data cat /var/www/.ssh/id_rsa.pub
```

Copy the output (it will look like `ssh-rsa AAAAB3Nza...` or `ssh-ed25519 AAAAC3Nza...`).

#### Step 2: Add Key to Host User

**For the dedicated webvirtcloud user (recommended):**
```bash
# Add the key to the webvirtcloud user
echo "PASTE_THE_PUBLIC_KEY_HERE" | sudo tee -a /home/webvirtcloud/.ssh/authorized_keys
sudo chmod 600 /home/webvirtcloud/.ssh/authorized_keys
sudo chown webvirtcloud:webvirtcloud /home/webvirtcloud/.ssh/authorized_keys
```

**For your personal user (less secure):**
```bash
# Add to your user's authorized_keys
echo "PASTE_THE_PUBLIC_KEY_HERE" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

### Test SSH Connection

Test the connection from the container to your host:

```bash
# Test with dedicated webvirtcloud user (recommended)
docker exec -it webvirtcloud sudo -u www-data ssh -o ConnectTimeout=5 webvirtcloud@YOUR_HOST_IP 'virsh -c qemu:///system list --all'

# Test with your personal user
docker exec -it webvirtcloud sudo -u www-data ssh -o ConnectTimeout=5 YOUR_USERNAME@YOUR_HOST_IP 'virsh -c qemu:///system list --all'
```

If successful, you should see a list of your virtual machines.

### Configure WebVirtCloud

1. **Access the web interface:** `http://YOUR_HOST_IP:YOUR_WEB_PORT`
2. **Login with default credentials:**
   - Username: `admin`
   - Password: `admin`
3. **Add your compute host:**
   - Go to **Computes** → **Add SSH Compute**
   - **Name:** `your-hostname`
   - **Hostname:** `YOUR_HOST_IP`
   - **Login:** `webvirtcloud` (or your username)
   - **Details:** Optional description

After saving, the status should show "Connected" if the SSH configuration is correct.

### Firewall Configuration

#### NixOS Firewall (using your KVM module)

Your KVM module already includes the necessary firewall rules. If you're using different ports, update your configuration:

```nix
# In your KVM module or system configuration
networking.firewall.allowedTCPPorts = [ 
  8080  # WebVirtCloud web interface (adjust to your WEB_PORT)
  6080  # noVNC console access (adjust to your VNC_PORT)
];

networking.firewall.allowedTCPPortRanges = [
  { from = 5900; to = 5910; }  # VNC ports for VM consoles
];
```

#### Other Linux Distributions

```bash
# UFW (Ubuntu/Debian)
sudo ufw allow 8080/tcp     # WebVirtCloud web interface
sudo ufw allow 6080/tcp     # noVNC console
sudo ufw allow 5900:5910/tcp # VNC range

# Firewalld (RHEL/CentOS/Fedora)
sudo firewall-cmd --permanent --add-port=8080/tcp
sudo firewall-cmd --permanent --add-port=6080/tcp
sudo firewall-cmd --permanent --add-port=5900-5910/tcp
sudo firewall-cmd --reload

# iptables (manual)
sudo iptables -A INPUT -p tcp --dport 8080 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 6080 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 5900:5910 -j ACCEPT
```

### Example: Complete Setup for NixOS

Here's a complete example for a NixOS system with IP `192.168.1.100`:

```bash
# 1. Set variables
HOST_IP="192.168.1.100"
WEB_PORT="8080"
VNC_PORT="6080"

# 2. Start container
docker run -dit \
  -e CURRENT_IP="${HOST_IP}:${WEB_PORT}" \
  -e DEBUG=True \
  -e KVM_HOST="${HOST_IP}" \
  -e KVM_HOSTNAME="$(hostname)" \
  -e WS_PUBLIC_HOST="${HOST_IP}" \
  -e WS_PUBLIC_PORT="${VNC_PORT}" \
  -e WS_PUBLIC_PATH="novncd/" \
  -v /var/run/libvirt/:/var/run/libvirt/ \
  -v /dev/pts/:/dev/pts/ \
  -p ${WEB_PORT}:80 \
  -p ${VNC_PORT}:6080 \
  --name webvirtcloud \
  ghcr.io/damianflynn/webvirtcloud:20250606075619

# 3. Get container's public key
CONTAINER_KEY=$(docker exec -it webvirtcloud sudo -u www-data cat /var/www/.ssh/id_rsa.pub)

# 4. Add key to webvirtcloud user
echo "${CONTAINER_KEY}" | sudo tee -a /home/webvirtcloud/.ssh/authorized_keys
sudo chmod 600 /home/webvirtcloud/.ssh/authorized_keys
sudo chown webvirtcloud:webvirtcloud /home/webvirtcloud/.ssh/authorized_keys

# 5. Test connection
docker exec -it webvirtcloud sudo -u www-data ssh -o ConnectTimeout=5 webvirtcloud@${HOST_IP} 'virsh -c qemu:///system list --all'

# 6. Access WebVirtCloud at http://192.168.1.100:8080
```

### Troubleshooting

If you encounter issues, check the [Troubleshooting section](#troubleshooting-websocket-connection) below for common problems and solutions.

### Docker Compose

A docker compose file is included in the repo, this is work in progress

```bash
#!/bin/bash

# Setup script for WebVirtCloud persistent data
DATA_DIR="/srv/appdata/webvirtcloud"

echo "Setting up WebVirtCloud persistent storage..."

# Create all required directories
sudo mkdir -p "${DATA_DIR}"/{database,static,ssh,logs}
sudo mkdir -p "${DATA_DIR}"/logs/nginx

# Set proper ownership (www-data UID:GID = 33:33)
sudo chown -R root:root "${DATA_DIR}"

# Set proper permissions
sudo chmod 755 "${DATA_DIR}"
sudo chmod 700 "${DATA_DIR}/ssh"

echo "Persistent storage setup complete!"
echo "Directory structure:"
ls -la "${DATA_DIR}/"
```

## Manual Installation

### Generate secret key

You should generate SECRET_KEY after cloning repository. Then put it into webvirtcloud/settings.py.

```python3
import random, string
haystack = string.ascii_letters + string.digits + string.punctuation
print(''.join([random.SystemRandom().choice(haystack) for _ in range(50)]))
```

### Install WebVirtCloud panel (Ubuntu 18.04+ LTS)

```bash
sudo apt-get -y install git virtualenv python3-virtualenv python3-dev python3-lxml libvirt-dev zlib1g-dev libxslt1-dev nginx supervisor libsasl2-modules gcc pkg-config python3-guestfs libsasl2-dev libldap2-dev libssl-dev
git clone https://github.com/retspen/webvirtcloud
cd webvirtcloud
cp webvirtcloud/settings.py.template webvirtcloud/settings.py
# now put secret key to webvirtcloud/settings.py
sudo cp conf/supervisor/webvirtcloud.conf /etc/supervisor/conf.d
sudo cp conf/nginx/webvirtcloud.conf /etc/nginx/conf.d
cd ..
sudo mv webvirtcloud /srv
sudo chown -R www-data:www-data /srv/webvirtcloud
cd /srv/webvirtcloud
virtualenv -p python3 venv
source venv/bin/activate
pip install -r conf/requirements.txt
python3 manage.py migrate
python3 manage.py collectstatic --noinput
sudo chown -R www-data:www-data /srv/webvirtcloud
sudo rm /etc/nginx/sites-enabled/default
```

Restart services for running WebVirtCloud:

```bash
sudo service nginx restart
sudo service supervisor restart
```

Setup libvirt and KVM on server

```bash
wget -O - https://bit.ly/36baWUu | sudo sh
```

Done!!

Go to http://serverip and you should see the login screen.

### Install WebVirtCloud panel (CentOS8/OEL8)

```bash
sudo yum -y install epel-release
sudo yum -y install python3-virtualenv python3-devel libvirt-devel glibc gcc nginx supervisor python3-lxml git python3-libguestfs iproute-tc cyrus-sasl-md5 python3-libguestfs libsasl2-dev libldap2-dev libssl-dev
```

#### Creating directories and cloning repository

```bash
sudo mkdir /srv && cd /srv
sudo git clone https://github.com/retspen/webvirtcloud && cd webvirtcloud
cp webvirtcloud/settings.py.template webvirtcloud/settings.py
# now put secret key to webvirtcloud/settings.py
# create secret key manually or use that command
sudo sed -r "s/SECRET_KEY = ''/SECRET_KEY = '"`python3 /srv/webvirtcloud/conf/runit/secret_generator.py`"'/" -i /srv/webvirtcloud/webvirtcloud/settings.py
```

#### Start installation webvirtcloud

```bash
virtualenv-3 venv
source venv/bin/activate
pip3 install -r conf/requirements.txt
cp conf/nginx/webvirtcloud.conf /etc/nginx/conf.d/
python3 manage.py migrate
python3 manage.py collectstatic --noinput
```

#### Configure the supervisor for CentOS

Add the following after the [include] line (after **files = ...** actually):
```bash
sudo vim /etc/supervisord.conf

[program:webvirtcloud]
command=/srv/webvirtcloud/venv/bin/gunicorn webvirtcloud.wsgi:application -c /srv/webvirtcloud/gunicorn.conf.py
directory=/srv/webvirtcloud
user=nginx
autostart=true
autorestart=true
redirect_stderr=true

[program:novncd]
command=/srv/webvirtcloud/venv/bin/python3 /srv/webvirtcloud/console/novncd
directory=/srv/webvirtcloud
user=nginx
autostart=true
autorestart=true
redirect_stderr=true
```

#### Edit the nginx.conf file

You will need to edit the main nginx.conf file as the one that comes from the rpm's will not work. Comment the following lines:

```bash
#    server {
#        listen       80 default_server;
#        listen       [::]:80 default_server;
#        server_name  _;
#        root         /usr/share/nginx/html;
#
#        # Load configuration files for the default server block.
#        include /etc/nginx/default.d/*.conf;
#
#        location / {
#        }
#
#        error_page 404 /404.html;
#            location = /40x.html {
#        }
#
#        error_page 500 502 503 504 /50x.html;
#            location = /50x.html {
#        }
#    }
}
```

Also make sure file in **/etc/nginx/conf.d/webvirtcloud.conf** has the proper paths:

```bash
upstream gunicorn_server {
    #server unix:/srv/webvirtcloud/venv/wvcloud.socket fail_timeout=0;
    server 127.0.0.1:8000 fail_timeout=0;
}
server {
    listen 80;

    server_name servername.domain.com;
    access_log /var/log/nginx/webvirtcloud-access_log; 

    location /static/ {
        root /srv/webvirtcloud;
        expires max;
    }

    location / {
        proxy_pass http://gunicorn_server;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-for $proxy_add_x_forwarded_for;
        proxy_set_header Host $host:$server_port;
        proxy_set_header X-Forwarded-Proto $remote_addr;
        proxy_connect_timeout 1800;
        proxy_read_timeout 1800;
        proxy_send_timeout 1800;
        client_max_body_size 1024M;
    }
}
```

Change permissions so nginx can read the webvirtcloud folder:

```bash
sudo chown -R nginx:nginx /srv/webvirtcloud
```

Change permission for selinux:

```bash
sudo semanage fcontext -a -t httpd_sys_content_t "/srv/webvirtcloud(/.*)"
sudo setsebool -P httpd_can_network_connect on -P
```

Add required user to the kvm group(if you not install with root):

```bash
sudo usermod -G kvm -a <username>
```

Allow http ports on firewall:

```bash
sudo firewall-cmd --add-service=http
sudo firewall-cmd --add-service=http --permanent
sudo firewall-cmd --add-port=6080/tcp
sudo firewall-cmd --add-port=6080/tcp --permanent
```

Let's restart nginx and the supervisord services:

```bash
sudo systemctl restart nginx && systemctl restart supervisord
```

And finally, check everything is running:

```bash
sudo supervisorctl status
gstfsd             RUNNING   pid 24662, uptime 6:01:40
novncd             RUNNING   pid 24661, uptime 6:01:40
webvirtcloud       RUNNING   pid 24660, uptime 6:01:40
```

#### Apache mod_wsgi configuration

```bash
WSGIDaemonProcess webvirtcloud threads=2 maximum-requests=1000 display-name=webvirtcloud
WSGIScriptAlias / /srv/webvirtcloud/webvirtcloud/wsgi_custom.py
```

#### Install final required packages for libvirtd and others on Host Server

```bash
wget -O - https://clck.ru/9V9fH | sudo sh
```

Done!!

Go to http://serverip and you should see the login screen.

### Alternative running novncd via runit(Debian)

Alternative to running nonvcd via supervisor is runit.

On Debian systems install runit and configure novncd service:

```bash
apt install runit runit-systemd
mkdir /etc/service/novncd/
ln -s /srv/webvirtcloud/conf/runit/novncd.sh /etc/service/novncd/run
systemctl start runit.service
```

### Default credentials

```html
login: admin
password: admin
```

### Configuring Compute SSH connection

This is a short example of configuring cloud and compute side of the ssh connection.

On the webvirtcloud machine you need to generate ssh keys and optionally disable StrictHostKeyChecking.

```bash
chown www-data -R ~www-data
sudo -u www-data ssh-keygen
cat > ~www-data/.ssh/config << EOF
Host *
StrictHostKeyChecking no
EOF
chown www-data -R ~www-data/.ssh/config
```

You need to put cloud public key into authorized keys on the compute node. Simpliest way of doing this is to use ssh tool from the webvirtcloud server.

```bash
sudo -u www-data ssh-copy-id root@compute1
```

### Host SMBIOS information is not available

If you see warning

```bash
Unsupported configuration: Host SMBIOS information is not available
```

Then you need to install `dmidecode` package on your host using your package manager and restart libvirt daemon.

Debian/Ubuntu like:

```bash
sudo apt-get install dmidecode
sudo service libvirt-bin restart
```

Arch Linux

```bash
sudo pacman -S dmidecode
systemctl restart libvirtd
```

### Cloud-init

Currently supports only root ssh authorized keys and hostname. Example configuration of the cloud-init client follows.

```bash
datasource:
  OpenStack:
      metadata_urls: [ "http://webvirtcloud.domain.com/datasource" ]
```

### Reverse-Proxy

Edit WS_PUBLIC_PORT at settings.py file to expose redirect to 80 or 443. Default: 6080

```bash
WS_PUBLIC_PORT = 80
```

## How To Update

```bash
# Go to Installation Directory
cd /srv/webvirtcloud
source venv/bin/activate
git pull
pip3 install -U -r conf/requirements.txt 
python3 manage.py migrate
python3 manage.py collectstatic --noinput
sudo service supervisor restart
```

### Running tests

Server on which tests will be performed must have libvirt up and running.
It must not contain vms.
It must have `default` storage which not contain any disk images.
It must have `default` network which must be on.
Setup venv

```bash
python -m venv venv
source venv/bin/activate
pip install -r conf/requirements.txt
```

Run tests

```bash
python manage.py test
```

## LDAP Configuration

The config options below can be changed in `webvirtcloud/settings.py` file. Variants for Active Directory and OpenLDAP are shown. This is a minimal config to get LDAP running, for further info read the [django-auth-ldap documentation](https://django-auth-ldap.readthedocs.io).

Enable LDAP

```bash
sudo sed -i "s~#\"django_auth_ldap.backend.LDAPBackend\",~\"django_auth_ldap.backend.LDAPBackend\",~g" /srv/webvirtcloud/webvirtcloud/settings.py
```

Set the LDAP server name and bind DN

```python
# Active Directory
AUTH_LDAP_SERVER_URI = "ldap://example.com"
AUTH_LDAP_BIND_DN = "username@example.com"
AUTH_LDAP_BIND_PASSWORD = "password"

# OpenLDAP
AUTH_LDAP_SERVER_URI = "ldap://example.com"
AUTH_LDAP_BIND_DN = "CN=username,CN=Users,OU=example,OU=com"
AUTH_LDAP_BIND_PASSWORD = "password"
```

Set the user filter and user and group search base and filter

```python
# Active Directory
AUTH_LDAP_USER_SEARCH = LDAPSearch(
    "CN=Users,DC=example,DC=com", ldap.SCOPE_SUBTREE, "(sAMAccountName=%(user)s)"
)
AUTH_LDAP_GROUP_SEARCH = LDAPSearch(
    "CN=Users,DC=example,DC=com", ldap.SCOPE_SUBTREE, "(objectClass=group)"
)
AUTH_LDAP_GROUP_TYPE = NestedActiveDirectoryGroupType()

# OpenLDAP
AUTH_LDAP_USER_SEARCH = LDAPSearch(
    "CN=Users,DC=example,DC=com", ldap.SCOPE_SUBTREE, "(cn=%(user)s)"
)
AUTH_LDAP_GROUP_SEARCH = LDAPSearch(
    "CN=Users,DC=example,DC=com", ldap.SCOPE_SUBTREE, "(objectClass=groupOfUniqueNames)"
)
AUTH_LDAP_GROUP_TYPE = GroupOfUniqueNamesType()  # import needs to be changed at the top of settings.py
```

Set group which is required to access WebVirtCloud. You may set this to `False` to disable this filter.

```python
AUTH_LDAP_REQUIRE_GROUP = "CN=WebVirtCloud Access,CN=Users,DC=example,DC=com"
```

Populate user fields with values from LDAP

```python
AUTH_LDAP_USER_FLAGS_BY_GROUP = {
    "is_staff": "CN=WebVirtCloud Staff,CN=Users,DC=example,DC=com",
    "is_superuser": "CN=WebVirtCloud Admins,CN=Users,DC=example,DC=com",
}
AUTH_LDAP_USER_ATTR_MAP = {
    "first_name": "givenName",
    "last_name": "sn",
    "email": "mail",
}
```

Now when you login with an LDAP user it will be assigned the rights defined. The user will be authenticated then with LDAP and authorized through the WebVirtCloud permissions.

If you'd like to move a user from ldap to WebVirtCloud, just change its password from the UI and (eventually) remove from the group in LDAP.


## REST API / BETA
Webvirtcloud provides a REST API for programmatic access.
To access API methods open your browser and check them with Swagger interface
```bash
http://<webvirtloud-address:port>/swagger
```
```bash
http://<webvirtloud-address:port>/redoc
```

## Screenshots

Instance Detail:
<img src="doc/images/instance.PNG" width="96%" align="center"/>
Instance List:</br>
<img src="doc/images/grouped.PNG" width="43%"/>
<img src="doc/images/nongrouped.PNG" width="53%"/>
Other: </br>
<img src="doc/images/hosts.PNG" width="47%"/>
<img src="doc/images/log.PNG" width="49%"/>

## License

WebVirtCloud is licensed under the [Apache Licence, Version 2.0](http://www.apache.org/licenses/LICENSE-2.0.html).
