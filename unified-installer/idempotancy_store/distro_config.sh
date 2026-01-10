#!/bin/bash

declare -A DISTRO_MAP
declare -A PACKAGE_MANAGER_MAP

DISTRO_MAP['arch']='arch'
DISTRO_MAP['fedora']='fedora'
DISTRO_MAP['debian']='debian'

PACKAGE_MANAGER_MAP['arch']='pacman|yay,paru|flatpak,tar'
PACKAGE_MANAGER_MAP['fedora']='dnf|yum,rpm|flatpak,tar'
PACKAGE_MANAGER_MAP['debian']='apt|apt-get,dpkg|flatpak,tar'

export DISTRO_MAP
