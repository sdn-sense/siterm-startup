#!/usr/bin/env python3
"""
   Prepare ansible config files based on configuration inside /etc/ansible-conf.yaml
Authors:
  Justas Balcas jbalcas (at) caltech.edu
Date: 2022/11/22
"""
import os
import os.path
import traceback
import json
import yaml

ROOTPATH = "/opt/siterm/config/ansible/sense/inventory"


def template_mapping(network_os, subitem=""):
    """Template mappings for OS"""
    mappings = {
        "sense.dellos9.dellos9": {"main": "dellos9.j2",
                                  "before": "dellos9_before.j2",
                                  "ping": "dellos9_ping.j2",
                                  "traceroute": "dellos9_traceroute.j2"},
        "sense.dellos10.dellos10": {"main": "dellos10.j2",
                                    "before": "dellos10_before.j2",
                                    "ping": "dellos10_ping.j2",
                                    "traceroute": "dellos10_traceroute.j2"},
        "sense.aristaeos.aristaeos": {"main": "aristaeos.j2",
                                      "before": "aristaeos_before.j2",
                                      "ping": "aristaeos_ping.j2",
                                      "traceroute": "aristaeos_traceroute.j2"},
        "sense.freertr.freertr": {"main": "freertr.j2",
                                  "before": "freertr_before.j2",
                                  "ping": "freertr_ping.j2",
                                  "traceroute": "freertr_traceroute.j2"},
        "sense.sonic.sonic": {"main": "sonic.j2",
                              "before": "sonic_before.j2",
                              "ping": "sonic_ping.j2",
                              "traceroute": "sonic_traceroute.j2"},
        "sense.frr.frr": {"main": "frr.j2",
                              "before": "frr_before.j2",
                              "ping": "frr_ping.j2",
                              "traceroute": "frr_traceroute.j2"},
        "sense.cisconx9.cisconx9": {"main": "cisconx9.j2",
                                    "before": "cisconx9_before.j2",
                                    "ping": "cisconx9_ping.j2",
                                    "traceroute": "cisconx9_traceroute.j2"},
        "sense.junos.junos": {"main": "junos.j2",
                             "before": "junos_before.j2",
                             "ping": "junos_ping.j2",
                             "traceroute": "junos_traceroute.j2"},
    }
    if network_os in mappings:
        if subitem:
            return mappings[network_os].get(subitem, "")
        return mappings[network_os]["main"]
    return ""


def special_params(network_os):
    """Add Special ansible params based on network os"""
    mappings = {"sense.sonic.sonic": {"ansible_connection": "ansible.netcommon.libssh"},
                "sense.frr.frr": {"ansible_connection": "ansible.netcommon.libssh"}}
    if network_os in mappings:
        return mappings[network_os]
    return {}


def key_mac_mappings(network_os):
    """Key/Mac mapping for MAC monitoring"""
    default = {"oid": "1.3.6.1.2.1.17.7.1.2.2.1.3", "mib": "mib-2.17.7.1.2.2.1.3."}
    mappings = {
        "sense.sonic.sonic": {
            "oid": "1.3.6.1.2.1.17.7.1.2.2.1.2",
            "mib": "mib-2.17.7.1.2.2.1.2.",
        }
    }
    if network_os in mappings:
        return mappings[network_os]
    return default


def getYamlContent(filename, raiseError=False):
    """Get inventory file"""
    out = {}
    if not os.path.isfile(filename):
        if raiseError:
            raise Exception(f"ERROR! File {filename} not available.")
        return out
    with open(filename, "r", encoding="utf-8") as fd:
        out = yaml.safe_load(fd.read())
    return out


def dumpYamlContent(filename, outContent):
    """Dump outContent in Yaml format to filename"""
    with open(filename, "w", encoding="utf-8") as fd:
        yaml.dump(
            outContent,
            fd,
            allow_unicode=True,
            default_flow_style=False,
            explicit_start=True,
            width=1000,
        )

def dumpJsonContent(filename, outContent):
    """Dump outcontent in Json format to filename"""
    with open(filename, "w", encoding="utf-8") as fd:
        json.dump(outContent, fd)

def prepareNewInventoryFile(inventory):
    """Prepare and write new inventory file"""
    out = {"sense": {"hosts": {}}}
    for name, params in inventory.get("inventory", {}).items():
        out["sense"]["hosts"][name] = {"ansible_host": params["host"]}
        # port is optional parameter
        if "port" in params:
            out["sense"]["hosts"][name]["ansible_port"] = params["port"]
        prepareNewHostFiles(name, params)
    dumpYamlContent(f"{ROOTPATH}/inventory.yaml", out)


def prepareNewHostFiles(name, params):
    """Prepare and write new host file"""
    hostinfo = getYamlContent(f"{ROOTPATH}/host_vars/{name}.yaml")
    if not hostinfo:
        hostinfo = {
            "ansible_become": "",
            "ansible_network_os": "",
            "ansible_ssh_pass": "",
            "ansible_ssh_user": "",
            "ansible_ssh_private_key_file": "",
            "ansible_ssh_common_args": "",
            "hostname": "",
            "template_name": "",
            "snmp_monitoring": {},
            "interface": {},
            "sense_bgp": {},
        }
    # Loop via each parameter and add it to correct location;
    # 1. Add Hostname parameter (same as name)
    hostinfo["hostname"] = name
    # 2. Add network OS
    if "network_os" in params:
        hostinfo["ansible_network_os"] = params["network_os"]
    else:
        print(f"ERROR! {name} does not have network_os parameter defined!")
    # 3. Add username
    if "user" in params:
        hostinfo["ansible_ssh_user"] = params["user"]
    else:
        print(f"ERROR! {name} does not have user parameter defined!")
    # 4. Add pass or sshkey parameter
    if "pass" in params and "sshkey" in params:
        print(
            f"ERROR! {name} has pass and sshkey parameter defined! Unpredicted behaviour"
        )
    elif "pass" in params:
        hostinfo["ansible_ssh_pass"] = params["pass"]
        try:
            del hostinfo["ansible_ssh_private_key_file"]
        except KeyError:
            pass
    else:
        hostinfo["ansible_ssh_private_key_file"] = params["sshkey"]
        try:
            del hostinfo["ansible_ssh_pass"]
        except KeyError:
            pass
        # Check that key is present, if not print WARNING!
        if not os.path.isfile(params["sshkey"]):
            print(f"ERROR! SSH Key {params['sshkey']} not available on the host")
    # 5. Add ansible_ssh_common_args
    if "ssh_common_args" in params:
        hostinfo["ansible_ssh_common_args"] = params["ssh_common_args"]
    elif 'ansible_ssh_common_args' in hostinfo:
        del hostinfo["ansible_ssh_common_args"]
    # 6. Add become flag
    if "become" in params:
        hostinfo["ansible_become"] = params["become"]
    else:
        print(
            f"ERROR! {name} does not have become parameter defined! Will set default to False"
        )
        hostinfo["ansible_become"] = False
    # 7. Add SNMP Parameters
    if "session_vars" in params.get("snmp_params", {}):
        hostinfo.setdefault("snmp_monitoring", {})
        hostinfo["snmp_monitoring"]["session_vars"] = params["snmp_params"][
            "session_vars"
        ]
        macparse = key_mac_mappings(params["network_os"])
        if macparse:
            hostinfo["snmp_monitoring"]["mac_parser"] = macparse
    # 8. Add template parameter
    for key, anskey in {"main": "template_name", "before": "template_before_name",
                        "ping": "template_name_ping", "traceroute": "template_name_traceroute"}.items():
        template = template_mapping(params["network_os"], key)
        if template:
            hostinfo[anskey] = template
        else:
            print(f"ERROR! {name} does not availabe template for {key}. Unsupported Device?!")
    # 9. Add special Ansible params (known as needed)
    specParams = special_params(params["network_os"])
    if specParams:
        hostinfo.update(specParams)
    dumpYamlContent(f"{ROOTPATH}/host_vars/{name}.yaml", hostinfo)

def writeState(state):
    """Write state file"""
    stdict = {"state": state, "sitename": "General", "runtime": 0, "version": "General"}
    try:
        os.mkdir('/tmp/siterm-states/')
    except FileExistsError:
        pass
    dumpJsonContent("/tmp/siterm-states/ansible-prepare.yaml", stdict)

def generateAnsible():
    """Generate Ansible configuration files"""
    try:
        inventory = getYamlContent("/etc/ansible-conf.yaml", True)
        prepareNewInventoryFile(inventory)
    except Exception as ex:
        print(f"ERROR! Got Exception: {ex}")
        print("Full traceback below:")
        print(traceback.print_exc())
        writeState("ERROR")
        raise
    writeState("OK")


if __name__ == "__main__":
    generateAnsible()
