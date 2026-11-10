#!/usr/bin/env python3
"""
  Prepare the SiteRM site private directory /opt/siterm/config/{SITENAME} owned by apache:apache.
  Components share data through the database; this directory only holds local scratch
  (ansible run artifacts, background debug process output).
Authors:
  Justas Balcas jbalcas (at) caltech.edu
Date: 2022/11/22
"""
import os
import pwd
from pathlib import Path
from SiteRMLibs.GitConfig import GitConfig

def getusergroupuid(user, group):
    """Get user and group uid"""
    gid = pwd.getpwnam(user).pw_gid
    uid = pwd.getpwnam(group).pw_uid
    return uid, gid

def pathcreate(path, uid, gid):
    """Create path and own by uid,gid"""
    pathObj = Path(path)
    pathObj.mkdir(parents=True, exist_ok=True)
    os.chown(path, uid, gid)

def dircreate():
    """Create dir and own by apache user. This dir is dynaminc
       and can be changed to support multiple sites.
    """
    uid, gid = getusergroupuid('apache', 'apache')
    gitObj = GitConfig()
    gitObj.getLocalConfig()
    if gitObj.config.get('SITENAME', None):
        path = f'/opt/siterm/config/{gitObj.config["SITENAME"]}'
        pathcreate(path, uid, gid)

if __name__ == "__main__":
    dircreate()
