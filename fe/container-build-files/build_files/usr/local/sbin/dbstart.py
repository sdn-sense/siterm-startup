#!/usr/bin/env python3
"""Database starter to create and update database"""
from time import sleep
import pymysql
from SiteRMLibs.DBBackend import dbinterface
from SiteRMLibs import __version__ as runningVersion


class DBStarter:
    """Database starter class"""
    def __init__(self):
        self.db = dbinterface('DBINIT', None, "MAIN")

    def dboptimize(self):
        """Optimize the database"""
        print("Optimizing database")
        try:
            out = self.db.executeRaw("""SELECT CONCAT('CREATE TABLE ', table_name, '_new LIKE ', table_name, '; ',
                                                          'INSERT INTO ', table_name, '_new SELECT * FROM ', table_name, '; ',
                                                          'RENAME TABLE ', table_name, ' TO ', table_name, '_old, ',
                                                                           table_name, '_new TO ', table_name, '; ',
                                                          'DROP TABLE ', table_name, '_old; '
                                                         ) AS migration_commands
                                            FROM information_schema.tables
                                            WHERE table_schema = 'sitefe';""")
            for row in out:
                cmd = row[0]
                print("Executing SQL Command:", cmd)
                for item in cmd.split(';'):
                    if item.strip():
                        self.db.executeRaw(item.strip())
        except pymysql.OperationalError as ex:
            print(f"Error executing SQL: {ex}")
            return False
        return True

    def _insupdversion(self, vval):
        version = self.db.get("dbversion", limit=1)
        # If no version is found, write the current version
        if not version:
            self.db.insert("dbversion", [{"version": vval}])
        else:
            self.db.update("dbversion", [{"version": vval, "id": version[0]["id"]}])

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
            self.db.executeRaw(sqlcall)
        except pymysql.ProgrammingError as ex:
            print(f"Error executing SQL: {ex}")
            raise
        except pymysql.OperationalError as ex:
            print(f"Error executing SQL: {ex}")
            raise

    def start(self):
        """Start the database creation"""
        while not self.db.isDBReady():
            print("Database not ready, waiting for 1 second. See error above. If continous, check the mariadb process.")
            sleep(1)
        self.db.createdb()
        self.dboptimize()
        self._insupdversion(runningVersion)


if __name__ == "__main__":
    dbclass = DBStarter()
    dbclass.start()
