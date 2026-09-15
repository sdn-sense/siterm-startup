#!/usr/bin/env python3
"""
   Prepare ansible config files based on configuration inside /etc/ansible-conf.yaml
Authors:
  Justas Balcas jbalcas (at) caltech.edu
Date: 2022/11/22
"""
import argparse
import json
import os
import os.path
import sys
import traceback

import yaml
from SiteRMLibs.GitConfig import GitConfig

ROOTPATH = "/opt/siterm/config/ansible/sense/inventory"


def _osTemplateMappings():
    """Supported network_os values and their template mappings"""
    return {
        "sense.dellos9.dellos9": {
            "main": "dellos9.j2",
            "before": "dellos9_before.j2",
            "ping": "dellos9_ping.j2",
            "traceroute": "dellos9_traceroute.j2",
        },
        "sense.dellos10.dellos10": {
            "main": "dellos10.j2",
            "before": "dellos10_before.j2",
            "ping": "dellos10_ping.j2",
            "traceroute": "dellos10_traceroute.j2",
        },
        "sense.aristaeos.aristaeos": {
            "main": "aristaeos.j2",
            "before": "aristaeos_before.j2",
            "ping": "aristaeos_ping.j2",
            "traceroute": "aristaeos_traceroute.j2",
        },
        "sense.freertr.freertr": {
            "main": "freertr.j2",
            "before": "freertr_before.j2",
            "ping": "freertr_ping.j2",
            "traceroute": "freertr_traceroute.j2",
        },
        "sense.sonic.sonic": {
            "main": "sonic.j2",
            "before": "sonic_before.j2",
            "ping": "sonic_ping.j2",
            "traceroute": "sonic_traceroute.j2",
            "bgpsummary": "sonic_bgpsummary.j2",
        },
        "sense.frr.frr": {
            "main": "frr.j2",
            "before": "frr_before.j2",
            "ping": "frr_ping.j2",
            "traceroute": "frr_traceroute.j2",
            "bgpsummary": "frr_bgpsummary.j2",
        },
        "sense.cisconx9.cisconx9": {
            "main": "cisconx9.j2",
            "before": "cisconx9_before.j2",
            "ping": "cisconx9_ping.j2",
            "traceroute": "cisconx9_traceroute.j2",
        },
        "sense.junos.junos": {
            "main": "junos.j2",
            "before": "junos_before.j2",
            "ping": "junos_ping.j2",
            "traceroute": "junos_traceroute.j2",
        },
    }


SUPPORTED_NETWORK_OS = sorted(_osTemplateMappings().keys())


def template_mapping(network_os, subitem=""):
    """Template mappings for OS"""
    mappings = _osTemplateMappings()
    if network_os in mappings:
        if subitem:
            return mappings[network_os].get(subitem, "")
        return mappings[network_os]["main"]
    return ""


def special_params(network_os):
    """Add Special ansible params based on network os"""
    mappings = {
        "sense.sonic.sonic": {"ansible_connection": "ansible.netcommon.libssh"},
        "sense.frr.frr": {"ansible_connection": "ansible.netcommon.libssh"},
    }
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
        content = fd.read()
    try:
        out = yaml.safe_load(content)
    except yaml.YAMLError as ex:
        location = ""
        mark = getattr(ex, "problem_mark", None)
        if mark is not None:
            location = f" (line {mark.line + 1}, column {mark.column + 1})"
        problem = getattr(ex, "problem", None) or str(ex)
        raise Exception(
            f"ERROR! File {filename} is not valid YAML{location}: {problem}"
        ) from ex
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
    netos = params.get("network_os")
    if not netos:
        raise Exception(
            f"ERROR! Host '{name}' has no network_os defined. Supported: {SUPPORTED_NETWORK_OS}"
        )
    if netos not in SUPPORTED_NETWORK_OS:
        raise Exception(
            f"ERROR! Host '{name}' has unsupported network_os '{netos}'. Supported: {SUPPORTED_NETWORK_OS}"
        )
    hostinfo["ansible_network_os"] = netos
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
    elif "ansible_ssh_common_args" in hostinfo:
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
    # 8. Add template parameter (required -- every supported network_os
    # must have one, so absence here is a real misconfiguration)
    for key, anskey in {
        "main": "template_name",
        "before": "template_before_name",
        "ping": "template_name_ping",
        "traceroute": "template_name_traceroute",
    }.items():
        template = template_mapping(params["network_os"], key)
        if template:
            hostinfo[anskey] = template
        else:
            print(
                f"ERROR! {name} does not availabe template for {key}. Unsupported Device?!"
            )
    # 8b. Add optional per-capability templates -- present only for the
    # network_os values that actually use a template for that capability
    # (e.g. BGP summary only applies to FRR/SONiC, which run it via an
    # on-device script + template; other supported NOS's get it through a
    # dedicated Ansible module instead and have no template at all).
    # Absence is expected here, unlike the required templates above, so it
    # is not treated as an error -- and any stale value from a previous
    # mapping is cleared rather than left behind.
    for key, anskey in {
        "bgpsummary": "template_name_bgpsummary",
    }.items():
        template = template_mapping(params["network_os"], key)
        if template:
            hostinfo[anskey] = template
        else:
            hostinfo.pop(anskey, None)
    # 9. Add special Ansible params (known as needed)
    specParams = special_params(params["network_os"])
    if specParams:
        hostinfo.update(specParams)
    # 10. Add per-host ansible params (e.g. vlanmode, vlanip, routing_instance,
    #     subset_config). Copied through verbatim - the getfacts playbook and
    #     test-runner read these straight from host_vars, so any new ansparams
    #     key is available to them without changes here.
    if "ansparams" in params:
        hostinfo["ansparams"] = params["ansparams"]
    dumpYamlContent(f"{ROOTPATH}/host_vars/{name}.yaml", hostinfo)


def validateInventory(inventory):
    """Validate inventory entries (network_os, credentials) without writing any files"""
    errors = []
    for name, params in inventory.get("inventory", {}).items():
        if "network_os" not in params:
            errors.append(
                f"Host '{name}' does not have network_os parameter defined! Supported: {SUPPORTED_NETWORK_OS}"
            )
        elif params["network_os"] not in SUPPORTED_NETWORK_OS:
            errors.append(
                f"Host '{name}' has unsupported network_os '{params['network_os']}'. Supported: {SUPPORTED_NETWORK_OS}"
            )
        user = params.get("user")
        passwd = params.get("pass")
        sshkey = params.get("sshkey")
        if not user:
            errors.append(
                f"Host '{name}' does not have a non-empty 'user' parameter defined!"
            )
        if not passwd and not sshkey:
            errors.append(
                f"Host '{name}' must have either a non-empty 'pass' or 'sshkey' parameter defined!"
            )
        if sshkey and not os.path.isfile(sshkey):
            errors.append(
                f"Host '{name}' has 'sshkey' set to '{sshkey}' but that file does not exist!"
            )
    if errors:
        details = "\n".join(f"  - {err}" for err in errors)
        raise Exception(f"ERROR! Ansible configuration validation failed:\n{details}")


def getSiteDeviceConfig():
    """Fetch the site's Git-managed configuration (rm-configs) and return its
    (sitename, ansible control plugin, switch/device name list)."""
    gitObj = GitConfig()
    if not gitObj.manualConfigEnabled():
        gitObj.getGitRepo()
    gitObj.getGitConfig()
    sitename = gitObj.config["MAIN"]["general"]["sitename"]
    siteConfig = gitObj.config["MAIN"].get(sitename, {})
    plugin = siteConfig.get("plugin", "ansible")
    switchNames = siteConfig.get("switch", [])
    return sitename, plugin, switchNames


def validateDeviceNames(inventory):
    """Cross-check device names between the Git-managed site configuration
    (rm-configs FE main.yaml 'switch' list) and /etc/ansible-conf.yaml.
    Skipped entirely when the site's ansible control 'plugin' is 'raw'."""
    try:
        sitename, plugin, switchNames = getSiteDeviceConfig()
    except Exception as ex:
        raise Exception(
            f"ERROR! Could not fetch Git site configuration to validate device names: {ex}"
        ) from ex
    if plugin == "raw":
        print(f"OK! Site '{sitename}' ansible control is 'raw', skipping device name cross-check.")
        return
    switchNames = set(switchNames)
    ansibleNames = set(inventory.get("inventory", {}).keys())
    errors = []
    for name in sorted(switchNames - ansibleNames):
        errors.append(
            f"Device '{name}' is listed in rm-configs (site '{sitename}') but missing from /etc/ansible-conf.yaml inventory!"
        )
    for name in sorted(ansibleNames - switchNames):
        errors.append(
            f"Device '{name}' is defined in /etc/ansible-conf.yaml but missing from rm-configs (site '{sitename}') switch list!"
        )
    if errors:
        details = "\n".join(f"  - {err}" for err in errors)
        raise Exception(f"ERROR! Device name validation failed:\n{details}")


def checkConfig():
    """Validate /etc/ansible-conf.yaml without writing any files. Returns True if valid."""
    try:
        inventory = getYamlContent("/etc/ansible-conf.yaml", True)
        validateInventory(inventory)
        validateDeviceNames(inventory)
    except Exception as ex:
        print(f"{ex}")
        return False
    print("OK! /etc/ansible-conf.yaml is valid.")
    return True


def writeState(state):
    """Write state file"""
    stdict = {"state": state, "sitename": "General", "runtime": 0, "version": "General"}
    try:
        os.mkdir("/tmp/siterm-states/")
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
    argparser = argparse.ArgumentParser(
        description="Prepare/validate Ansible configuration files"
    )
    argparser.add_argument(
        "--check",
        action="store_true",
        help="Validate /etc/ansible-conf.yaml only (no files written) and exit. "
        "Safe to run before the Ansible git repo/inventory directories exist.",
    )
    cliArgs = argparser.parse_args()
    if cliArgs.check:
        sys.exit(0 if checkConfig() else 1)
    generateAnsible()
