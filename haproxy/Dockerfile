# FROM ubuntu:16.04
FROM eeacms/haproxy

RUN apt-get -y update; \
    echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections; \
    apt-get install -y openssh-client; \
    apt-get install -y wget; \
    apt-get install -y curl; \
    apt-get install -y sudo; \
    apt-get autoremove; \
    apt-get clean

# Generate a unique private key (KEY)
RUN openssl genrsa -out server.key 2048

# Generating a Certificate Signing Request (CSR)
RUN openssl req -new -key server.key -out server.csr \
        -subj "/C=UK/ST=LONDON/L=LONDON/O=OrgName/OU=IT Department/CN=example.com"

# Creating a Self-Signed Certificate (CRT)
RUN openssl x509 -req -days 365 -in server.csr -signkey server.key -out server.crt

# Append KEY and CRT to mydomain.pem
RUN bash -c 'cat server.key server.crt >> /etc/ssl/private/server.pem'

COPY haproxy.cfg /usr/local/etc/haproxy/haproxy.cfg
