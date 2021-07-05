# Demo of using HAProxy to terminate SSL connections to p4d

This is seems to have performance benefits over the p4d process itself doing the termination.

# Instructions for use

    docker-compose build
    docker-compose up

You can then connect as follows (in a different terminal), using ports:

* localhost:2199 -> p4d directly
* localhost:2188 -> via HA Proxy container with no SSL
* localhost:2189 -> via HA Proxy container and SSL
  
Note that we use a version of the [SDP Helix Installer project](https://swarm.workshop.perforce.com/projects/perforce_software-helix-installer/) which installs the [sampledepot](https://community.perforce.com/s/article/2439) for easy testing.

See the ports defined/forwarded in [docker-compose.yml](docker-compose.yml).

First you can connect direct to p4d (no SSL):

    p4 -p 2199 info

Then via HAPRoxy with no SSL:

    p4 -p 2188 info

Then via HAProxy with SSL:

    p4 -p ssl:2189 trust -y
    p4 -p ssl:2189 info

Please note user `perforce` and password `F@stSCM!` if you want to look around in the repo.
