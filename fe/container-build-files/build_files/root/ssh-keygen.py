#!/usr/bin/env python3
"""
   Check that all ansible hosts have key inside ~/.ssh/known_hosts.
Authors:
  Justas Balcas jbalcas (at) caltech.edu
Date: 2022/11/22
"""
import subprocess
import yaml

def getInventory(inventoryFile="/opt/siterm/config/ansible/sense/inventory/inventory.yaml"):
    """Get inventory file"""
    with open(inventoryFile, 'r', encoding='utf-8') as fd:
        out = yaml.safe_load(fd.read())
    return out

def checkaddkeystore(hostname):
    """Check if hostname is in known hosts. If not, add it"""
    print(f'Checking if {hostname} is in ~/.ssh/known_hosts')
    cmdExit = subprocess.call(f'ssh-keygen -H -F {hostname}', shell=True)
    if cmdExit != 0:
        print(f'Host {hostname} not found in ~/.ssh/known_hosts. Running ssh-keyscan')
        subprocess.call(f'ssh-keyscan -H {hostname} 2>> error 1>> ~/.ssh/known_hosts', shell=True)

def generateKnownHosts():
    """Generate Known Hosts"""
    inventory = getInventory()
    for _key, vals in inventory.items():
        if 'hosts' not in vals:
            continue
        for hostkey, hostvals in vals['hosts'].items():
            if 'ansible_host' in hostvals:
                checkaddkeystore(hostvals["ansible_host"])
            # Check if ssh args defined
            hostVars = getInventory(f'/opt/siterm/config/ansible/sense/inventory/host_vars/{hostkey}.yaml')
            if 'ansible_ssh_common_args' in hostVars:
                for item in hostVars['ansible_ssh_common_args'].split(' '):
                    if '@' in item:  # This is dummy check, but works. Might need to improve in future.
                        checkaddkeystore(item.split('@')[1])

if __name__ == "__main__":
    generateKnownHosts()
