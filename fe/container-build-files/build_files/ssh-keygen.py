#!/usr/bin/env python3
"""
   Check that all ansible hosts have key inside ~/.ssh/known_hosts.
Authors:
  Justas Balcas jbalcas (at) caltech.edu
Date: 2022/11/22
"""
import subprocess
import yaml

def getInventory():
    """Get inventory file"""
    inventoryFile = "/opt/siterm/config/ansible/sense/inventory/inventory.yaml"
    with open(inventoryFile, 'r', encoding='utf-8') as fd:
        out = yaml.safe_load(fd.read())
    return out

def generateKnownHosts():
    """Generate Known Hosts"""
    inventory = getInventory()
    for _key, vals in inventory.items():
        if 'hosts' in vals:
            for _hostkey, hostvals in vals['hosts'].items():
                if 'ansible_host' in hostvals:
                    print(f'Checking if {hostvals["ansible_host"]} is in ~/.ssh/known_hosts')
                    cmdExit = subprocess.call(f'ssh-keygen -H -F {hostvals["ansible_host"]}', shell=True)
                    if cmdExit != 0:
                        print(f'Host {hostvals["ansible_host"]} not found in ~/.ssh/known_hosts. Running ssh-keyscan')
                        subprocess.call(f'ssh-keyscan -H {hostvals["ansible_host"]} >> ~/.ssh/known_hosts 2>&1', shell=True)

if __name__ == "__main__":
    generateKnownHosts()
