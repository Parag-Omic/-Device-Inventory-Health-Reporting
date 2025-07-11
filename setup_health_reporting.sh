#!/bin/bash

echo " Installing required tools..."
sudo apt update
sudo apt install -y sshpass mailutils

echo " Tools installed:"
echo " - sshpass (for SSH automation)"
echo " - mailutils (optional email support)"
