#!/usr/bin/env python3
"""Database starter to create and update database"""
import pkg_resources
import mariadb
from SiteRMLibs.DBBackend import dbinterface
from SiteRMLibs import __version__ as runningVersion
from SiteRMLibs.GitConfig import getGitConfig


class DBStarter:
    """Database starter class"""
    def __init__(self):
        self.config = getGitConfig()
        self.db = dbinterface('DBINIT', self.config, "MAIN")

    @staticmethod
    def _getversionfloat(valin):
        valspl = valin.split('.')
        if len(valspl) == 1:
            return float(valspl[0])
        intpart = valspl[0]
        fracpart = ''.join(valspl[1:])
        return float(f"{intpart}.{fracpart}")

    def _makesqlcall(self, sqlcall):
        try:
            self.db.db.execute(sqlcall)
        except mariadb.ProgrammingError as ex:
            print(f"Error executing SQL: {ex}")
            raise
        except mariadb.OperationalError as ex:
            print(f"Error executing SQL: {ex}")
            raise


    def _getversion(self):
        version = self.db.get("dbversion", limit=1)
        # If no version is found, write the current version
        if not version:
            vval = self._getversionfloat(runningVersion)
            self.db.insert("dbversion", [{"version": vval}])
            return vval
        return self._getversionfloat(version[0]["version"])

    def _getAllModFiles(self):
        """Get all the modification files"""
        moddir = pkg_resources.resource_listdir('SiteFE', 'release/release_mods')
        modfiles = {}
        for mod in moddir:
            modv = self._getversionfloat(mod)
            modfiles.setdefault(modv, {'dirname': mod, 'files': []})
            modfiles[modv]['files'] = pkg_resources.resource_listdir('SiteFE', f'release/release_mods/{mod}')
        return modfiles

    def upgradedb(self, version):
        """Update the database"""
        modfiles = self._getAllModFiles()
        sortedkeys = sorted(modfiles.keys())
        for key in sortedkeys:
            if key > version:
                for modfile in modfiles[key]['files']:
                    with pkg_resources.resource_stream('SiteFE', f'release/release_mods/{modfiles[key]["dirname"]}/{modfile}') as fd:
                        sql = fd.read().decode('utf-8')
                        sql_statements = [line.strip() for line in sql.split('\n') if line.strip()]
                    for sqlcall in sql_statements:
                        if sqlcall:
                            self._makesqlcall(sqlcall)
                self.db.update("dbversion", {"version": key})
                version = key

    def start(self):
        """Start the database creation"""
        self.db.createdb()
        version = self._getversion()
        if version == self._getversionfloat(runningVersion):
            self.upgradedb(version)


if __name__ == "__main__":
    dbclass = DBStarter()
    dbclass.start()
