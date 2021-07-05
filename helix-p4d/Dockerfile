FROM ubuntu:20.04
MAINTAINER Robert Cowham "rcowham@perforce.com"

RUN apt-get -y update; \
    echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections; \
    apt-get install -y apt-utils; \
    apt-get install -y mailutils; \
    apt-get install -y openssh-server; \
    apt-get install -y wget; \
    apt-get install -y curl; \
    apt-get install -y sudo; \
    apt-get autoremove; \
    apt-get clean

# Replace systemctl for use within docker
RUN cd /usr/local/bin; \
  wget https://raw.githubusercontent.com/gdraheim/docker-systemctl-replacement/master/files/docker/systemctl3.py; \
  chmod 755 systemctl3.py; \
  cd /usr/local/bin; \
  mv systemctl systemctl.old; \
  ln -s /usr/local/bin/systemctl3.py systemctl

# Create perforce user with UID to 1000 before p4d installation
RUN useradd --home-dir /p4 --create-home --uid 1000 perforce
RUN echo perforce:perforce | /usr/sbin/chpasswd

RUN mkdir /hxdepots /hxlogs /hxmetadata && \
   mkdir -p /hxdepots/reset && \
   chown -R perforce:perforce /hx*

RUN cd /hxdepots/reset && \
    curl -k -s -O https://swarm.workshop.perforce.com/download/guest/perforce_software/helix-installer/main/src/reset_sdp.sh && \
    chmod +x /hxdepots/reset/reset_sdp.sh && \
    /hxdepots/reset/reset_sdp.sh -fast -no_tweaks -no_cron

RUN mv /p4/common/config/p4_1.vars /tmp && \
  cat /tmp/p4_1.vars | sed -e 's/SSL_PREFIX=ssl:/SSL_PREFIX=/' > /p4/common/config/p4_1.vars

RUN cp -r /hxdepots/downloads/PerforceSample/* /p4/1/depots/
