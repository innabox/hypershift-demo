#!/bin/bash

clustername=$1

set -ex

openstack router show "${clustername}-router" > /dev/null && {
  openstack router remove subnet "${clustername}-router" "${clustername}-subnet"
  openstack router delete "${clustername}-router"
}
openstack port list --network "${clustername}-network" -f value -c ID | xargs -n1 -r openstack port delete
openstack subnet show "${clustername}-subnet" > /dev/null && openstack subnet delete "${clustername}-subnet"
openstack network show "${clustername}-network" > /dev/null && openstack network delete "${clustername}-network"
