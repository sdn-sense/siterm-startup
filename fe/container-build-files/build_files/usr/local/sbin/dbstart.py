#!/usr/bin/env python3
"""Database starter to create and update database"""
import pkg_resources
from SiteRMLibs.DBBackend import dbinterface
from SiteRMLibs import __version__ as runningVersion
from SiteRMLibs.GitConfig import getGitConfig


class DBStarter:
    """Database starter class"""
    def __init__(self):
        self.config = getGitConfig()
        self.db = dbinterface('DBINIT', self.config, "MAIN")

    def _getversion(self):
        version = self.db.get("dbversion", limit=1)
        # If no version is found, write the current version
        if not version:
            self.db.insert("dbversion", [{"version": runningVersion}])
            return runningVersion
        return version[0]["version"]

    def _getAllModFiles(self):
        """Get all the modification files"""
        moddir = pkg_resources.resource_listdir('SiteFE', 'packaging/release_mods')
        modfiles = {}
        for mod in moddir:
            modv = mod.replace(".", "")
            modfiles.setdefault(modv, {'dirname': mod, 'files': []})
            modfiles[modv]['files'] = pkg_resources.resource_listdir('SiteFE', f'packaging/release_mods/{mod}')
        return modfiles

    def upgradedb(self, version):
        """Update the database"""
        modfiles = self._getAllModFiles()
        sortedkeys = sorted(modfiles.keys())
        for key in sortedkeys:
            if key > version:
                for modfile in modfiles[key]['files']:
                    with pkg_resources.resource_stream('SiteFE', f'packaging/release_mods/{modfiles[key]["dirname"]}/{modfile}') as fd:
                        sql = fd.read().decode('utf-8')
                    self.db.db.execute(sql)
                self.db.update("dbversion", {"version": key})
                version = key

    def start(self):
        """Start the database creation"""
        self.db.createdb()
        version = self._getversion()
        if version != runningVersion:
            self.upgradedb(version)


if __name__ == "__main__":
    dbclass = DBStarter()
    dbclass.start()
