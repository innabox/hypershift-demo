#!/bin/bash

clustername=$1

set -x

openstack router remove subnet "${clustername}-router" "${clustername}-subnet"
openstack router delete "${clustername}-router"
openstack subnet delete "${clustername}-subnet"
openstack network delete "${clustername}-network"
