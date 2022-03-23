#!/bin/bash

# Never run pacman -Sy on your actual system
pacman -Sy dialog

# Ensure time is correct
timedatectl set-ntp true

dialog --defaultno --title "Are you sure?" --yesno \
    "This will install arch linux on your computer. \n\n\
    WARNING! It will DESTROY everything on the hd you choose. \n\n\
    Proceed with caution and Just Say NO if you're not sure what you're doing! \n\n\
    Do you really want to continue?" 15 60 || exit
