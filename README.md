# Demo of using HAProxy to terminate SSL connections to p4d

This is seems to have performance benefits over the p4d process itself doing the termination.

# Instructions for use

    docker-compose build
    docker-compose up

You can then connect as follows (in a different terminal), using ports:

* localhost:2199 -> p4d directly
* localhost:2188 -> via HA Proxy container with no SSL
* localhost:2189 -> via HA Proxy container and SSL
  
Note that we use a version of the (https://swarm.workshop.perforce.com/projects/perforce_software-helix-installer/)[SDP Helix Installer project] which installs the (https://community.perforce.com/s/article/2439)[sampledepot] for easy testing.

    p4 -p 2199 info
    p4 -p 2188 info
    p4 -p ssl:2189 trust -y
    p4 -p ssl:2189 info

