#!/usr/bin/env python3
"""
SENSE Azure Sonic Module, which is copied and called via Ansible from
SENSE Site-RM Resource Manager.

Main reasons for this script are the following:
    1. Azure Sonic does not have Ansible module
    2. Dell Sonic module depends on sonic-cli - and currently (140422) -
       it is broken due to python2 removal. See https://github.com/Azure/SONiC/issues/781
    3. It is very diff from normal switch cli, like:
          If vlan present on Sonic, adding it again will raise Exception (on Dell/Arista Switches, it is not)
          If vlan not cleaned (has member, ip, or any param) Sonic does not allow to remove vlan. First need to
          clean all members, params, ips and only then remove vlan.
    4. For BGP - We cant use SONiC config_db.json - as it is not rich enough, and does not support all features
       (route-map, ip list). Because of this - we have to rely on vtysh

With this script - as input, it get's information from Site-RM for which vlan and routing to configure/unconfigure
It checks with local configuration and applies the configs on Sonic with config command or routing with vtysh

Authors:
  Justas Balcas jbalcas (at) caltech.edu

Date: 2022/04/14
"""
import os
import re
import ast
import sys
import json
import subprocess
import shlex
import ipaddress
import logging

def normalizeIPAddress(ipInput):
    """Normalize IP Address"""
    tmpIP = ipInput.split('/')
    longIP = ipaddress.ip_address(tmpIP[0]).exploded
    if len(tmpIP) == 2:
        return "%s/%s" % (longIP, tmpIP[1])
    return longIP


def externalCommand(command):
    """Execute External Commands and return stdout and stderr."""
    command = shlex.split(command)
    proc = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    return proc.communicate()

def strtojson(intxt):
    """str to json function"""
    out = {}
    try:
        out = ast.literal_eval(intxt)
    except ValueError:
        out = json.loads(intxt)
    except SyntaxError as ex:
        raise Exception("SyntaxError: Failed to literal eval dict. Err:%s " % ex) from ex
    return out

def loadJson(infile):
    """Load json file and return dictionary"""
    out = {}
    fout = ""
    if not os.path.isfile(infile):
        print('File does not exist %s. Exiting' % infile)
        sys.exit(2)
    with open(infile, 'r', encoding='utf-8') as fd:
        fout = fd.readlines()
    if fout:
        for line in fout:
            splline = line.split(': ', 1)
            if len(splline) == 2:
                out[splline[0]] = strtojson(splline[1])
    return out

class SonicCmd():
    """Sonic CMD Executor API"""
    def __init__(self):
        self.config = {}
        self.needRefresh = True

    def generateSonicDict(self):
        """Generate all Vlan Info for comparison with SENSE FE Entries"""
        cmdout = externalCommand('show runningconfiguration all')
        out = strtojson(cmdout[0])
        for key, _ in out.get('VLAN', {}).items():
            self.config.setdefault(key, {})
        for key, _ in out.get('VLAN_INTERFACE', {}).items():
            # Key can be
            # Vlan4070|2001:48d0:3001:11f::1/64
            # Vlan50
            # Vlan50|132.249.2.46/29
            tmpKey = key.split('|')
            intD = self.config.setdefault(tmpKey[0], {})
            if len(tmpKey) == 2:
                intD.setdefault('ips', [])
                intD['ips'].append(normalizeIPAddress(tmpKey[1]))
        for key, vals in out.get('VLAN_MEMBER', {}).items():
            #'Vlan3841|PortChannel501': {'tagging_mode': 'tagged'}
            #'Vlan3842|Ethernet100': {'tagging_mode': 'untagged'},
            # SENSE Works only with tagged mode.
            if vals['tagging_mode'] == 'tagged':
                tmpKey = key.split('|')
                intD = self.config.setdefault(tmpKey[0], {})
                intD.setdefault('tagged_members', [])
                intD['tagged_members'].append(tmpKey[1])

    def __executeCommand(self, cmd):
        """Execute command and set needRefresh to True"""
        print(cmd)
        externalCommand(cmd)
        self.needRefresh = True

    def __refreshConfig(self):
        """Refresh config from Switch"""
        if self.needRefresh:
            self.config = {}
            self.generateSonicDict()
            self.needRefresh = False

    def _addVlan(self, **kwargs):
        """Add Vlan if not present"""
        self.__refreshConfig()
        if kwargs['vlan'] not in self.config:
            cmd = "sudo config vlan add %(vlanid)s" % kwargs
            self.__executeCommand(cmd)

    def _delVlan(self, **kwargs):
        """Del Vlan if present. Del All Members, IPs too (required)"""
        # First we need to clean all IPs and tagged members from VLAN
        self._delMember(**kwargs)
        self._delIP(**kwargs)
        self.__refreshConfig()
        if kwargs['vlan'] in self.config:
            cmd = "sudo config vlan del %(vlanid)s" % kwargs
            self.__executeCommand(cmd)

    def _addMember(self, **kwargs):
        """Add Member if not present"""
        self._addVlan(**kwargs)
        self.__refreshConfig()
        if kwargs['member'] not in self.config.get(kwargs['vlan'], {}).get('tagged_members', []):
            cmd = "sudo config vlan member add %(vlanid)s %(member)s" % kwargs
            self.__executeCommand(cmd)

    def _delMember(self, **kwargs):
        """Del Member if not present"""
        self.__refreshConfig()
        if 'member' in kwargs:
            cmd = "sudo config vlan member del %(vlanid)s %(member)s" % kwargs
            self.__executeCommand(cmd)
        else:
            for member in self.config.get(kwargs['vlan'], {}).get('tagged_members', []):
                kwargs['member'] = member
                self._delMember(**kwargs)

    def _addIP(self, **kwargs):
        """Add IP if not present"""
        self._addVlan(**kwargs)
        self.__refreshConfig()
        if kwargs['ip'] not in self.config.get(kwargs['vlan'], {}).get('ips', []):
            cmd = "sudo config interface ip add %(vlan)s %(ip)s" % kwargs
            self.__executeCommand(cmd)

    def _delIP(self, **kwargs):
        """Del IP if not present"""
        self.__refreshConfig()
        if 'ip' in kwargs:
            cmd = "sudo config interface ip remove %(vlan)s %(ip)s" % kwargs
            self.__executeCommand(cmd)
        else:
            for delip in self.config.get(kwargs['vlan'], {}).get('ips', []):
                kwargs['ip'] = delip
                self._delIP(**kwargs)

class vtyshParser():
    def __init__(self):
        self.running_config = {}
        self.stdout = ""
        self.totalLines = 0
        self.regexes = {'network': r'network ([0-9a-f.:]*)/([0-9]{1,3})',
                        'neighbor-route-map': r'neighbor ([a-zA-z_:.0-9-]*) route-map ([a-zA-z_:.0-9-]*) (in|out)',
                        'neighbor-remote-as': r'neighbor ([0-9a-f.:]*) remote-as ([0-9]*)',
                        'neighbor-act': r'neighbor ([a-zA-z_:.0-9-]*) activate',
                        'address-family': r'address-family (ipv[46]) ([a-z]*)',
                        'ipv4-prefix-list': r'ip prefix-list ([a-zA-Z0-9_-]*) seq ([0-9]*) permit ([0-9a-f.:]*)/([0-9]{1,3})',
                        'ipv6-prefix-list': r'ipv6 prefix-list ([a-zA-Z0-9_-]*) seq ([0-9]*) permit ([0-9a-f.:]*)/([0-9]{1,3})',
                        'route-map': r'route-map ([a-zA-Z0-9_-]*) permit ([0-9]*)',
                        'match-ip': r'match ip route-source prefix-list ([a-zA-Z0-9_-]*)',
                        'router': r'^router bgp ([0-9]*)'}

    def _parseAddressFamily(self, incr, iptype='unset'):
        """Parse address family from running config"""
        addrFam = self.running_config.setdefault('bgp', {}).setdefault('address-family', {}).setdefault(iptype, {})
        networks = addrFam.setdefault('network', {})
        routeMap = addrFam.setdefault('route-map', {})
        for i in range(incr, self.totalLines):
            incr = i
            if self.stdout[incr].strip() == 'exit-address-family':
                return incr
            match = re.search(self.regexes['network'], self.stdout[incr].strip(), re.M)
            if match:
                networks[match[1]] = {'ip': match[1], 'range': match[2]}
                continue
            match = re.search(self.regexes['neighbor-route-map'], self.stdout[incr].strip(), re.M)
            if match:
                routeMap.setdefault(match[1], {}).setdefault(match[2], match[3])
                continue
            match = re.search(self.regexes['neighbor-act'], self.stdout[incr].strip(), re.M)
            if match:
                routeMap.setdefault(match[1], {}).setdefault('activate', True)
        return incr

    def parseRouterInfo(self, incr):
        """Parse Router info from running config"""
        bgp = self.running_config.setdefault('bgp', {})
        match = re.search(self.regexes['router'], self.stdout[incr], re.M)
        if match:
            bgp['asn'] = match.group(1)
        for i in range(incr, self.totalLines):
            incr = i
            if self.stdout[i] == '!':
                return i
            match = re.search(self.regexes['neighbor-remote-as'], self.stdout[i].strip(), re.M)
            if match:
                neighbor = bgp.setdefault('neighbor', {})
                neighbor[match[1]] = {'ip': match[1], 'remote-as': match[2]}
                continue
            match = re.search(self.regexes['address-family'], self.stdout[i].strip(), re.M)
            if match:
                bgp.setdefault('address-family', {}).setdefault(match[1], {'type': match[2]})
                i = self._parseAddressFamily(i, match[1])
        return incr

    def parserPrefixList(self, incr):
        """Parse Prefix List from running config"""
        prefList = self.running_config.setdefault('prefix-list', {'ipv4': {}, 'ipv6': {}})
        match = re.search(self.regexes['ipv4-prefix-list'], self.stdout[incr].strip(), re.M)
        if match:
            prefList['ipv4'].setdefault(match[1], {})[match[3]] = match[2]
            return incr
        match = re.search(self.regexes['ipv6-prefix-list'], self.stdout[incr].strip(), re.M)
        if match:
            prefList['ipv6'].setdefault(match[1], {})[match[3]] = match[2]
        return incr

    def parserRouteMap(self, incr):
        """Parse Route map info from running config"""
        routeMap = self.running_config.setdefault('route-map', {})
        match = re.search(self.regexes['route-map'], self.stdout[incr].strip(), re.M)
        if not match:
            return incr
        rMap = routeMap.setdefault(match[1], {}).setdefault(match[2], {})
        for i in range(incr, self.totalLines):
            incr = i
            if self.stdout[i] == '!':
                return i
            match = re.search(self.regexes['match-ip'], self.stdout[i].strip(), re.M)
            if match:
                rMap[match[1]] = ""
            # What about IPV6 route match?
        return incr

    def getConfig(self):
        """Get vtysh running config and parse it to dict format"""
        with open('vtysh-out', 'r', encoding='utf-8') as fd:
            self.stdout = fd.read().split('\n')
        self.totalLines = len(self.stdout)
        for i in range(self.totalLines):
            if self.stdout[i].startswith('router bgp'):
                i = self.parseRouterInfo(i)
            elif self.stdout[i].startswith('ip prefix-list') or self.stdout[i].startswith('ipv6 prefix-list'):
                i = self.parserPrefixList(i)
            elif self.stdout[i].startswith('route-map'):
                i = self.parserRouteMap(i)

class vtyshConfigure():
    """vtysh configure"""
    def __init__(self):
        self.commands = []

    def _genPrefixList(self, parser, newConf):
        def genCmd(pItem, noCmd=False):
            if noCmd:
                self.commands.append("no %s prefix-list %s permit %s" % ('ip' if pItem['iptype'] == 'ipv4' else pItem['iptype'],
                                                                      pItem['name'], pItem['iprange']))
            else:
                self.commands.append("%s prefix-list %s permit %s" % ('ip' if pItem['iptype'] == 'ipv4' else pItem['iptype'],
                                                                      pItem['name'], pItem['iprange']))
        for pItem in newConf.get('prefix_list'):
            if 'name' not in pItem or 'iprange' not in pItem or 'iptype' not in pItem or 'state' not in pItem:
                continue
            if pItem['iprange'] in parser.running_config.get('prefix-list', {}).get(pItem['iptype'], {}).get(pItem['name'], {}):
                if pItem['state'] == 'absent':
                    # It is present, but new state is absent. Remove
                    genCmd(pItem, noCmd=True)
            elif pItem['state'] == 'present':
                genCmd(pItem)

    def _genRouteMap(self, parser, newConf):
        def genCmd(pItem, noCmd=False):
            if noCmd:
                self.commands.append("no route-map %s permit 10" % pItem['name'])
            else:
                self.commands.append("route-map %s permit 10" % pItem['name'])
                self.commands.append(" match ip route-source prefix-list %s" % pItem['match'])
        for rItem in newConf.get('route_map'):
            if 'match' not in rItem or 'name' not in rItem \
            or 'state' not in rItem:
                continue
            if rItem['match'] in parser.running_config.get('route-map', {}).get(rItem['name'], {}).get('10', {}):
                if rItem['state'] == 'absent':
                    genCmd(rItem, noCmd=True)
            elif rItem['state'] == 'present':
                genCmd(rItem)

    def _genBGP(self, parser, newConf):
        senseasn = newConf.get('asn', None)
        runnasn = parser.running_config.get('bgp', {}).get('asn', None)
        if runnasn and senseasn != runnasn:
            print('bad')
            return
        # Append only if any new commands are added.
        self.commands.append("router bgp %s" % runnasn)
        for key in ['ipv6', 'ipv4']:
            for netw in newConf.get('%s_network' % key, []):
                if netw['address'].split('/')[0] in parser.running_config.get('bgp', {}).get('address-family', {}).get(key, {}).get('network', {}):
                    print("network already defined.")
                    # Todo check if range is equal and or state present/absent
                    # Not sure what we should do with absent? Remove? This might break normal routing, so we should leave it as is.
                    continue
                # At this point it is not defined
                if netw['state'] == 'present':
                    # Aadd it
                    self.commands.append(' address-family %s unicast' % key)
                    self.commands.append('  network %s' % netw['address'])
                    self.commands.append(' exit-address-family')
            for neigh in newConf.get('neighbor', {}).get(key, []):
                ip = neigh['ip'].split('/')[0]
                if ip in parser.running_config.get('bgp', {}).get('neighbor', {}):
                    if neigh['state'] == 'absent':
                        # It is present on router, but new state is absent
                        # TODO removal
                        print('Remove %s. TODO' % neigh)
                        continue
                elif neigh['state'] == 'present':
                    # It is present in new config, but not present on router. Add it
                    self.commands.append(' address-family %s unicast' % key)
                    self.commands.append('  neighbor %s remote-as %s' % (ip, neigh['remote_asn']))
                    # Adding remote-as will exit address family. Need to enter it again
                    self.commands.append(' address-family %s unicast' % key)
                    self.commands.append('  neighbor %s activate' % ip)
                    for rKey, rName in neigh.get('route_map', {}).items():
                        self.commands.append('  neighbor %s route-map %s %s' % (ip, rName, rKey))
                    self.commands.append(' exit-address-family')


    def generateCommands(self, parser, newConf):
        """Check new conf with running conf and generate commands
           for missing router config commands"""
        self._genPrefixList(parser, newConf)
        self._genRouteMap(parser, newConf)
        self._genBGP(parser, newConf)
        for command in self.commands:
            print(command)

def applyVlanConfig(sensevlans):
    """Loop via sense vlans and check with sonic vlans config"""
    sonicAPI = SonicCmd()
    for key, val in sensevlans.items():
        # Sonic key is without space
        tmpKey = key.split(' ')
        tmpD = {'vlan': "".join(tmpKey), 'vlanid': tmpKey[1]}
        # Vlan ADD/Remove
        if val['state'] == 'present':
            sonicAPI._addVlan(**tmpD)
        if val['state'] == 'absent':
            sonicAPI._delVlan(**tmpD)
            continue
        # IP ADD/Remove
        for ipkey in ['ip6_address', 'ip_address']:
            ipDict = val.get(ipkey, {})
            if not ipDict:
                continue
            tmpD['ip'] = normalizeIPAddress(ipDict['ip'])
            if ipDict['state'] == 'present':
                sonicAPI._addIP(**tmpD)
            if ipDict['state'] == 'absent':
                sonicAPI._delIP(**tmpD)
        # Tagged Members Add/Remove
        for tagged in val.get('tagged_members', []):
            tmpD['member'] = tagged['port']
            if tagged['state'] == 'present':
                sonicAPI._addMember(**tmpD)
            if tagged['state'] == 'absent':
                sonicAPI._delMember(**tmpD)


def applyBGPConfig(bgpconfig):
    """Generate BGP Commands and apply to Router (vtysh)"""
    parser = vtyshParser()
    parser.getConfig()
    vtyConf = vtyshConfigure()
    vtyConf.generateCommands(parser, bgpconfig)


def execute(args):
    """Main execute"""
    if len(args) == 1 or len(args) > 2:
        print('Too many or not enough args provided. Args: %s' % args)
        print('Please run ./sonic.py <json_file_config_location>')
        sys.exit(1)
    senseconfig = loadJson(args[1])
    #applyVlanConfig(senseconfig.get('INTERFACE', {}))
    applyBGPConfig(senseconfig.get('BGP', {}))

if __name__ == "__main__":
    execute(args=sys.argv)
