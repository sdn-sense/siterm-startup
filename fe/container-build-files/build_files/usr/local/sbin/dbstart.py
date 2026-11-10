#!/usr/bin/env python3
"""Database starter to create and update database"""
from time import sleep
import pymysql
import sqlalchemy.exc
from SiteRMLibs.DBBackend import dbinterface
from SiteRMLibs import __version__ as runningVersion


class DBStarter:
    """Database starter class"""
    def __init__(self):
        self.db = dbinterface('DBINIT', None, "MAIN")

    def dboptimize(self):
        """Optimize the database by rebuilding each table in place.

        Prepends DROP TABLE IF EXISTS for the _new/_old scratch tables so a
        table left over from a previous interrupted run doesn't wedge every
        future attempt with 'table already exists' forever. Each table's
        commands run in their own try/except so one table failing doesn't
        stop the rest from being optimized.

        Catches sqlalchemy.exc.OperationalError, not pymysql.OperationalError:
        executeRaw() runs through SQLAlchemy Core, which wraps every DBAPI
        error in its own exception hierarchy -- pymysql's own exception class
        is only reachable via the wrapped exception's `.orig` attribute, so
        `except pymysql.OperationalError` here never actually catches anything.
        """
        print("Optimizing database")
        try:
            out = self.db.executeRaw("""SELECT CONCAT('DROP TABLE IF EXISTS ', table_name, '_new; ',
                                                          'DROP TABLE IF EXISTS ', table_name, '_old; ',
                                                          'CREATE TABLE ', table_name, '_new LIKE ', table_name, '; ',
                                                          'INSERT INTO ', table_name, '_new SELECT * FROM ', table_name, '; ',
                                                          'RENAME TABLE ', table_name, ' TO ', table_name, '_old, ',
                                                                           table_name, '_new TO ', table_name, '; ',
                                                          'DROP TABLE ', table_name, '_old; '
                                                         ) AS migration_commands
                                            FROM information_schema.tables
                                            WHERE table_schema = 'sitefe';""")
        except sqlalchemy.exc.OperationalError as ex:
            print(f"Error listing tables to optimize: {ex}")
            return False
        allOK = True
        for row in out:
            cmd = row[0]
            print("Executing SQL Command:", cmd)
            try:
                for item in cmd.split(';'):
                    if item.strip():
                        self.db.executeRaw(item.strip())
            except sqlalchemy.exc.OperationalError as ex:
                print(f"Error optimizing one table, continuing with remaining tables: {ex}")
                allOK = False
        return allOK

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
        self.db.upgradedb("/usr/local/share/siterm/dbupgrade/")
        self._insupdversion(runningVersion)


if __name__ == "__main__":
    dbclass = DBStarter()
    dbclass.start()
