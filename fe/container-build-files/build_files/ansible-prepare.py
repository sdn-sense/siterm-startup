#!/usr/bin/env python3
"""
   Prepare ansible config files based on configuration inside /etc/ansible-conf.yaml
Authors:
  Justas Balcas jbalcas (at) caltech.edu
Date: 2022/11/22
"""
import os.path
import yaml

ROOTPATH = '/opt/siterm/config/ansible/sense/inventory'


def template_mapping(network_os):
    """Template mappings for OS"""
    mappings = {'sense.dellos9.dellos9': 'dellos9.j2',
                'sense.dellos10.dellos10': 'dellos10.j2',
                'sense.aristaeos.aristaeos': 'aristaeos.j2',
                'sense.freertr.freertr': 'freertr.j2',
                'sense.sonic.sonic': 'sonic.j2',
                'sense.cisconx9.cisconx9': 'cisconx9.j2'
                }
    if network_os in mappings:
        return mappings[network_os]
    return ""


def key_mac_mappings(network_os):
    """Key/Mac mapping for MAC monitoring"""
    default = {'oid': '1.3.6.1.2.1.17.7.1.2.2.1.3', 'mib': 'mib-2.17.7.1.2.2.1.3.'}
    mappings = {'sense.sonic.sonic': {'oid': '1.3.6.1.2.1.17.7.1.2.2.1.2', 'mib': 'mib-2.17.7.1.2.2.1.2.'}}
    if network_os in mappings:
        return mappings[network_os]
    return default


def getYamlContent(filename, raiseError=False):
    """Get inventory file"""
    out = {}
    if not os.path.isfile(filename):
        if raiseError:
            raise Exception(f'ERROR! File {filename} not available.')
        return out
    with open(filename, 'r', encoding='utf-8') as fd:
        out = yaml.safe_load(fd.read())
    return out


def dumpYamlContent(filename, outContent):
    """Dump outContent in Yaml format to filename"""
    with open(filename, 'w', encoding='utf-8') as fd:
        yaml.dump(outContent, fd, allow_unicode=True,
                  default_flow_style=False, explicit_start=True,
                  width=1000)


def prepareNewInventoryFile(inventory):
    """Prepare and write new inventory file"""
    out = {'sense': {'hosts': {}}}
    for name, params in inventory.get('inventory', {}).items():
        out['sense']['hosts'][name] = {'ansible_host': params['host']}
        prepareNewHostFiles(name, params)
    dumpYamlContent(f'{ROOTPATH}/inventory.yaml', out)


def prepareNewHostFiles(name, params):
    """Prepare and write new host file"""
    hostinfo = getYamlContent(f'{ROOTPATH}/host_vars/{name}.yaml')
    if not hostinfo:
        hostinfo = {'ansible_become': '',
                    'ansible_network_os': '',
                    'ansible_ssh_pass': '',
                    'ansible_ssh_user': '',
                    'ansible_ssh_private_key_file': '',
                    'hostname': '',
                    'template_name': '',
                    'snmp_monitoring': {},
                    'interface': {},
                    'sense_bgp': {}}
    # Loop via each parameter and add it to correct location;
    # 1. Add Hostname parameter (same as name)
    hostinfo['hostname'] = name
    # 2. Add network OS
    if 'network_os' in params:
        hostinfo['ansible_network_os'] = params['network_os']
    else:
        print(f'ERROR! {name} does not have network_os parameter defined!')
    # 3. Add username
    if 'user' in params:
        hostinfo['ansible_ssh_user'] = params['user']
    else:
        print(f'ERROR! {name} does not have user parameter defined!')
    # 4. Add pass or sshkey parameter
    if 'pass' in params and 'sshkey' in params:
        print(f'ERROR! {name} has pass and sshkey parameter defined! Unpredicted behaviour')
    elif 'pass' in params:
        hostinfo['ansible_ssh_pass'] = params['pass']
        try:
            del hostinfo['ansible_ssh_private_key_file']
        except KeyError:
            pass
    else:
        hostinfo['ansible_ssh_private_key_file'] = params['sshkey']
        try:
            del hostinfo['ansible_ssh_pass']
        except KeyError:
            pass
        # Check that key is present, if not print WARNING!
        if not os.path.isfile(params['sshkey']):
            print(f"ERROR! SSH Key {params['sshkey']} not available on the host")
    # 5. Add become flag
    if 'become' in params:
        hostinfo['ansible_become'] = params['become']
    else:
        print(f'ERROR! {name} does not have become parameter defined!')
    # 6. Add SNMP Parameters
    if 'session_vars' in params.get('snmp_params', {}):
        hostinfo.setdefault('snmp_monitoring', {})
        hostinfo['snmp_monitoring']['session_vars'] = params['snmp_params']['session_vars']
        macparse = key_mac_mappings(params['network_os'])
        if macparse:
            hostinfo['snmp_monitoring']['mac_parser'] = macparse
    # 7. Add template parameter
    template = template_mapping(params['network_os'])
    if template:
        hostinfo['template_name'] = template
    else:
        print(f'ERROR! {name} does not availabe template for control. Unsupported Device?!')
    dumpYamlContent(f'{ROOTPATH}/host_vars/{name}.yaml', hostinfo)


def generateAnsible():
    """Generate Ansible configuration files"""
    inventory = getYamlContent('/etc/ansible-conf.yaml', True)
    prepareNewInventoryFile(inventory)


if __name__ == "__main__":
    generateAnsible()
