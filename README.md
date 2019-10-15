# Migrating Grafana from SQLite to PostgreSQL

## Credits

This code is an adaption of [this gist](https://gist.github.com/pizjix/158e632495f67b3bda52b41b14ec600d) to the newer Grafana version (namely 5.1.3), so all credit goes to the author. Many thanks for the blog post [Migrating Grafana from SQLite to PostgreSQL](https://pizjix.com/migrating-grafana-from-sqlite-to-postgresql/). Also `migrator.sh` is largely based on [SQLite to PostgreSQL dump convertor script](https://gist.github.com/vigneshwaranr/3454093).

## Tested Versions of Grafana

This code has been explicity tested with databases from Grafana 6.3.5. Other versions may or may not work without modification.

## Prerequisites

All commands are executed on PostgreSQL server. I assume that Grafana is running on the same server as PostgreSQL, otherwise, commands related to Grafana should be corrected accordingly. This README covers Ubuntu 16.04 only.

    sudo apt-get install sqlite3 libsqlite3-dev

## Migration

### Create DB and environment

Create `grafana` database and PostgreSQL user. Store username and password in `~/.pgpass` file, it should look like this:

    > cat ~/.pgpass
    *:*:*:grafana:XXXXXXXX

and make sure that file permissions are `0600`. Copy Grafana DB file to the current directory:

    cp /var/lib/grafana/grafana.db .

[Configure Grafana to use PostgreSQL database](http://docs.grafana.org/installation/configuration/#database), then start Grafana and stop it immediately:

    sudo service grafana-server start && sleep 15 && sudo service grafana-server stop

The goal of this step is to make Grafana create DB schema - tables, sequences, etc,
make sure that the database is fully created.

### Migration itself

Run migration script:

    ./migrator.sh sqlite_to_postgres.py ./grafana.db . 2>&1 | tee migrator.log

You can change the default `python` and `psql` commands using environment
variables.

Eg: if you want run it using `python2` and a remote postgres database:

    PYTHON_CMD=python2 \
    PSQL_CMD='psql -h PG_HOST -U PG_USER' \
    ./migrator.sh sqlite_to_postgres.py ./grafana.db . 2>&1 | tee migration.log
    
or use `sudo`:

    PSQL_CMD='sudo -u postgres psql grafana' \
      ./migrator.sh sqlite_to_postgres.py ./grafana.db . 2>&1 | tee migration.log

And check `migrator.log` for errors. If none found, then the migration was successful - start Grafana and enjoy your new database experience. If you see any errors other than listed below, then most likely you were trying to upgrade newer Grafana version.

Errors like this one can be safely ignored:

    ERROR:  23505: duplicate key value violates unique constraint "dashboard_acl_pkey"
    DETAIL:  Key (id)=(1) already exists.
    SCHEMA NAME:  public
    TABLE NAME:  dashboard_acl
    CONSTRAINT NAME:  dashboard_acl_pkey
    LOCATION:  _bt_check_unique, nbtinsert.c:434
