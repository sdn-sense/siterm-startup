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
import argparse
import subprocess
import shlex
import ipaddress

def normalizeIPAddress(ipInput):
    """Normalize IP Address"""
    tmpIP = ipInput.split('/')
    longIP = ipaddress.ip_address(tmpIP[0]).exploded
    if len(tmpIP) == 2:
        return "%s/%s" % (longIP, tmpIP[1])
    return longIP


def externalCommand(command, dryRun=False):
    """Execute External Commands and return stdout and stderr."""
    if not dryRun:
        command = shlex.split(command)
        proc = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        return proc.communicate()
    print('DRY_RUN: %s' % command)
    return ""

def sendviaStdIn(maincmd, commands, dryRun=False):
    """Send commands to maincmd stdin"""
    if not dryRun:
        mainProc = subprocess.Popen([maincmd], stdin=subprocess.PIPE, stdout=subprocess.PIPE)
        singlecmd = ""
        for cmd in commands:
            singlecmd += "%s\n" % cmd
        cmdOut = mainProc.communicate(input=singlecmd.encode())[0]
        print('This is what we get back from %s command' % maincmd)
        for out in cmdOut.split(b'\n'):
            print(out.decode('utf-8'))
    else:
        print('DRY_RUN: Comand to be sent to %s stdin' % maincmd)
        for cmd in commands:
            print(cmd)

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
    def __init__(self, args):
        self.config = {}
        self.args = args
        self.needRefresh = True

    def _dryRunLocalConfig(self):
        """Load config from local file - for debugging purposes"""
        if self.args.sonicconfig and os.path.isfile(self.args.sonicconfig):
            with open(self.args.sonicconfig, 'r', encoding='utf-8') as fd:
                return strtojson(fd.read())
        return {}

    def generateSonicDict(self):
        """Generate all Vlan Info for comparison with SENSE FE Entries"""
        if not self.args.dryrun:
            cmdout = externalCommand('show runningconfiguration all', self.args.dryrun)
            out = strtojson(cmdout[0])
        else:
            out = self._dryRunLocalConfig()
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
    """Vtysh running config parser"""
    def __init__(self, args):
        self.running_config = {}
        self.stdout = ""
        self.args = args
        self.totalLines = 0
        self.regexes = {'network': r'network ([0-9a-f.:]*)/([0-9]{1,3})',
                        'neighbor-route-map': r'neighbor ([a-zA-z_:.0-9-]*) route-map ([a-zA-z_:.0-9-]*) (in|out)',
                        'neighbor-remote-as': r'neighbor ([0-9a-f.:]*) remote-as ([0-9]*)',
                        'neighbor-act': r'neighbor ([a-zA-z_:.0-9-]*) activate',
                        'address-family': r'address-family (ipv[46]) ([a-z]*)',
                        'ipv4-prefix-list': r'ip prefix-list ([a-zA-Z0-9_-]*) seq ([0-9]*) permit ([0-9a-f.:]*/[0-9]{1,2})',
                        'ipv6-prefix-list': r'ipv6 prefix-list ([a-zA-Z0-9_-]*) seq ([0-9]*) permit ([0-9a-f.:]*/[0-9]{1,3})',
                        'route-map': r'route-map ([a-zA-Z0-9_-]*) permit ([0-9]*)',
                        'match-ipv4': r'match ip address prefix-list ([a-zA-Z0-9_-]*)',
                        'match-ipv6': r'match ipv6 address prefix-list ([a-zA-Z0-9_-]*)',
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
                normIP = normalizeIPAddress(match[1])
                networks[normIP] = {'ip': normIP, 'range': match[2]}
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
                normIP = normalizeIPAddress(match[1])
                neighbor[normIP] = {'ip': normIP, 'remote-as': match[2]}
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
            prefList['ipv4'].setdefault(match[1], {})[normalizeIPAddress(match[3])] = match[2]
            return incr
        match = re.search(self.regexes['ipv6-prefix-list'], self.stdout[incr].strip(), re.M)
        if match:
            prefList['ipv6'].setdefault(match[1], {})[normalizeIPAddress(match[3])] = match[2]
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
            match = re.search(self.regexes['match-ipv4'], self.stdout[i].strip(), re.M)
            if match:
                rMap[match[1]] = ""
            match = re.search(self.regexes['match-ipv6'], self.stdout[i].strip(), re.M)
            if match:
                rMap[match[1]] = ""
        return incr

    def _dryRunLocalConfig(self):
        """Load config from local file - for debugging purposes"""
        if self.args.vtyshoutput and os.path.isfile(self.args.vtyshoutput):
            with open(self.args.vtyshoutput, 'r', encoding='utf-8') as fd:
                self.stdout = fd.read().split('\n')

    def getConfig(self):
        """Get vtysh running config and parse it to dict format"""
        if not self.args.dryrun:
            vtyshProc = externalCommand("vtysh -c 'show running-config'")
            self.stdout = vtyshProc[0].decode('utf-8').split('\n')
        else:
            self._dryRunLocalConfig()
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
    def __init__(self, args):
        self.commands = []
        self.args = args

    def _genPrefixList(self, parser, newConf):
        """Generate Prefix lists"""
        def genCmd(pItem, noCmd=False):
            if noCmd:
                self.commands.append("no %(iptype)s prefix-list %(name)s permit %(iprange)s" % pItem)
            else:
                self.commands.append("%(iptype)s prefix-list %(name)s permit %(iprange)s" % pItem)
        if not newConf:
            return
        for iptype, pdict in newConf.get('prefix_list', {}).items():
            for iprange, prefDict in pdict.items():
                for prefName, prefState in prefDict.items():
                    normIP = normalizeIPAddress(iprange)
                    out = {'iptype': iptype, 'name': prefName, 'iprange': iprange}
                    if normIP in parser.running_config.get('prefix-list', {}).get(iptype, {}).get(prefName, {}):
                        if prefState == 'absent':
                            genCmd(out, noCmd=True)
                    elif prefState == 'present':
                        genCmd(out)

    def _genRouteMap(self, parser, newConf):
        """Generate Route-map commands."""
        def genCmd(pItem, noCmd=False):
            if noCmd:
                self.commands.append("no route-map %(name)s permit %(permit)s" % pItem)
            else:
                self.commands.append("route-map %(name)s permit %(permit)s" % pItem)
                self.commands.append(" match %(iptype)s address prefix-list %(match)s" % pItem)
        if not newConf:
            return
        for iptype, rdict in newConf.get('route_map', {}).items():
            for rMapName, rMapPrios in rdict.items():
                for prio, rNames in rMapPrios.items():
                    for rName, rState in rNames.items():
                        out = {'iptype': iptype, 'permit': str(prio), 'name': rMapName, 'match': rName}
                        if out['match'] in parser.running_config.get('route-map', {}).get(out['name'], {}).get(out['permit'], {}):
                            if rState == 'absent':
                                genCmd(out, True)
                        elif rState == 'present':
                            genCmd(out)

    def _genBGP(self, parser, newConf):
        if not newConf:
            return
        senseasn = newConf.get('asn', None)
        runnasn = parser.running_config.get('bgp', {}).get('asn', None)
        if runnasn and int(senseasn) != int(runnasn):
            msg = 'Running ASN != SENSE ASN (%s != %s)' % (runnasn, senseasn)
            print(msg)
            raise Exception(msg)
        # Append only if any new commands are added.
        self.commands.append("router bgp %s" % senseasn)
        for key in ['ipv6', 'ipv4']:
            for netw, netstate in newConf.get('%s_network' % key, {}).items():
                netwNorm = normalizeIPAddress(netw.split('/')[0])
                if netwNorm in parser.running_config.get('bgp', {}).get('address-family', {}).get(key, {}).get('network', {}) and netstate == 'present':
                    continue
                # At this point it is not defined
                if netstate == 'present':
                    # Add it
                    self.commands.append(' address-family %s unicast' % key)
                    self.commands.append('  network %s' % netw)
                    self.commands.append(' exit-address-family')
                if netstate == 'absent':
                    print('Not removing network as it might break things for normal routing')
                    # We need a way to allow sites to control this via simple flag.
                    # If site does not run bgp - then it is save to delete;
                    # If they do - then it is better to keep it as is
            for neighIP, neighDict in newConf.get('neighbor', {}).get(key, {}).items():
                ipNorm = normalizeIPAddress(neighIP.split('/')[0])
                if ipNorm in parser.running_config.get('bgp', {}).get('neighbor', {}):
                    if neighDict['state'] == 'absent':
                        # It is present on router, but new state is absent
                        # TODO removal
                        self.commands.append(' address-family %s unicast' % key)
                        self.commands.append('  no neighbor %s remote-as %s' % (ipNorm, neighDict['remote_asn']))
                        print('Remove %s. TODO' % neighDict)
                        continue
                elif neighDict['state'] == 'present':
                    # It is present in new config, but not present on router. Add it
                    self.commands.append(' address-family %s unicast' % key)
                    self.commands.append('  neighbor %s remote-as %s' % (ipNorm, neighDict['remote_asn']))
                    # Adding remote-as will exit address family. Need to enter it again
                    self.commands.append(' address-family %s unicast' % key)
                    self.commands.append('  neighbor %s activate' % ipNorm)
                    self.commands.append('  neighbor %s soft-reconfiguration inbound' % ipNorm)
                    for rtype in ['in', 'out']:
                        for rName, rState in neighDict.get('route_map', {}).get(rtype, {}).items():
                            if rState == 'present':
                                self.commands.append('  neighbor %s route-map %s %s' % (ipNorm, rName, rtype))
                            elif rState == 'absent':
                                self.commands.append('  no neighbor %s route-map %s %s' % (ipNorm, rName, rtype))
                    self.commands.append(' exit-address-family')
        if len(self.commands) == 1:
            # means only router to configure. Skip it.
            self.commands = []


    def generateCommands(self, parser, newConf):
        """Check new conf with running conf and generate commands
           for missing router config commands"""
        self._genPrefixList(parser, newConf)
        self._genRouteMap(parser, newConf)
        self._genBGP(parser, newConf)
        if self.commands:
            sendviaStdIn('vtysh', ['configure'] + self.commands, self.args.dryrun)

def applyVlanConfig(args, sensevlans):
    """Loop via sense vlans and check with sonic vlans config"""
    sonicAPI = SonicCmd(args)
    for key, val in sensevlans.items():
        tmpKey = key.split(' ')
        if len(tmpKey) == 1:
            tmpD = {'vlan': "".join(key), 'vlanid': key[-4:]}
        else:
            tmpD = {'vlan': "".join(tmpKey), 'vlanid': tmpKey[1]}
        # Vlan ADD/Remove
        if val['state'] == 'present':
            sonicAPI._addVlan(**tmpD)
        if val['state'] == 'absent':
            sonicAPI._delVlan(**tmpD)
            continue
        # IP ADD/Remove
        for ipkey in ['ipv6_address', 'ipv4_address']:
            for ipval, ipstate in val.get(ipkey, {}).items():
                tmpD['ip'] = normalizeIPAddress(ipval)
                if ipstate == 'present':
                    sonicAPI._addIP(**tmpD)
                if ipstate == 'absent':
                    sonicAPI._delIP(**tmpD)
        # Tagged Members Add/Remove
        for taggedName, taggedState in val.get('tagged_members', {}).items():
            tmpD['member'] = taggedName
            if taggedState == 'present':
                sonicAPI._addMember(**tmpD)
            if taggedState == 'absent':
                sonicAPI._delMember(**tmpD)


def applyBGPConfig(args, bgpconfig):
    """Generate BGP Commands and apply to Router (vtysh)"""
    parser = vtyshParser(args)
    parser.getConfig()
    vtyConf = vtyshConfigure(args)
    vtyConf.generateCommands(parser, bgpconfig)


def execute(args):
    """Main execute"""
    senseconfig = loadJson(args.config)
    applyVlanConfig(args, senseconfig.get('INTERFACE', {}))
    applyBGPConfig(args, senseconfig.get('BGP', {}))

if __name__ == "__main__":
    oparser = argparse.ArgumentParser(description="Azure Sonic SENSE Configuration apply script.",
                                      prog=os.path.basename(sys.argv[0]), add_help=True)
    oparser.add_argument('--debug', dest='debug', default=False, help="Debug mode", action='store_true')
    oparser.add_argument('--dryrun', dest='dryrun', default=False, help="Not apply any commands. Log to console.", action='store_true')
    oparser.add_argument('--vtyshoutput', dest='vtyshoutput', default=None, help="vtyshoutput. Only used if --nocmd specified. Otherwise will call vtysh")
    oparser.add_argument('--sonicconfig', dest='sonicconfig', default=None, help="sonicconfig. Only used if --nocmd specified. Otherwise will call show runningconfiguration all")
    oparser.add_argument('--config', dest='config', default=None, help="config file - provided by SiteRM.")
    if len(sys.argv) == 1:
        oparser.print_help()
    argsCmd = oparser.parse_args(sys.argv[1:])
    execute(argsCmd)
