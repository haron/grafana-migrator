#!/bin/env bash

usage_error () {
    echo 'Usage: sh migrator.sh <path to sqlite_to_postgres.py> <path to sqlite db file> <an empty dir to output dump files>'
    echo
    echo 'Example:'
    echo '>sh migrator.sh sqlite_to_postgres.py ~/reviewboard.db /tmp/dumps'
    echo
    echo 'Tested on:'
    echo 'Python 2.7.3'
    echo 'SQLite 3.7.9'
}
if [ ! $# -eq 3 ]
then
  usage_error
  exit 1
fi

if [ ! -r $1 ]
then
  echo $1' is not readable.'
  echo 'Please give the correct path to sqlite_to_postgres.py'
  exit 1
fi

if [ ! -r $2 ]
then
  echo $2' is not readable'
  exit 1
fi

if [ ! -d $3 ]
then
  echo $3' is not a valid directory'
  exit 1
fi


#Get the list of tables
echo .tables | sqlite3 $2 > $3/lsoftbls

#Get dumps from sqlite
for i in `cat $3/lsoftbls`
do
  echo 'Generating sqlite dumps for '$i
  echo '.output '$3'/'$i'.dump' > $3/dumper
  echo 'pragma table_info('$i');' >> $3/dumper
  echo '.dump '$i >> $3/dumper
  echo '.quit'  >> $3/dumper
  cat $3/dumper | sqlite3 $2
done

#Fix dumps
echo
echo 'Remove unneeded dumps'
rm $3/migration_log.dump
rm $3/org.dump
rm $3/plugin_setting.dump
echo 'Replacing ` with "'
sed -i s/\`/\"/g $3/*.dump;
echo 'Removing index statements'
sed -i '/^CREATE/ d' $3/*.dump;

#Use the python script to convert the sqlite dumps to psql dumps
echo
echo 'Now converting the sqlite dumps into psql format...'
echo
for i in `ls -1 $3/*.dump`
do
  python $1 $i
done

#Remove the sqlite3 dumps and the file 'lsoftbls'
echo
echo 'Removing temporary files..'
rm $3/*.dump
rm $3/lsoftbls
rm $3/dumper

echo 'Removing empty dump files..'
wc -l $3/*.psql | grep -w 0 | awk '{ print $NF }' | xargs rm

#Use the python script to convert hex sequences into printable characters
echo
echo 'Now converting hex sequences in dumps to printable characters...'
echo
for i in `ls -1 $3/*.dump.psql`
do
  python hex_to_str.py $i
  sed -i '/^\s*$/d' $i
done

#Workaround for PostgreSQL Grafana DB boolean columns
psql grafana <<SQL
ALTER TABLE alert ALTER COLUMN silenced TYPE integer USING silenced::integer;
ALTER TABLE alert_notification ALTER COLUMN is_default DROP DEFAULT;
ALTER TABLE alert_notification ALTER COLUMN is_default TYPE integer USING is_default::integer;
ALTER TABLE dashboard_snapshot ALTER COLUMN external TYPE integer USING external::integer;
ALTER TABLE data_source ALTER COLUMN basic_auth TYPE integer USING basic_auth::integer;
ALTER TABLE data_source ALTER COLUMN is_default TYPE integer USING is_default::integer;
ALTER TABLE data_source ALTER COLUMN with_credentials DROP DEFAULT;
ALTER TABLE data_source ALTER COLUMN with_credentials TYPE integer USING with_credentials::integer;
ALTER TABLE migration_log ALTER COLUMN success TYPE integer USING success::integer;
ALTER TABLE plugin_setting ALTER COLUMN enabled TYPE integer USING enabled::integer;
ALTER TABLE plugin_setting ALTER COLUMN pinned TYPE integer USING pinned::integer;
ALTER TABLE temp_user ALTER COLUMN email_sent TYPE integer USING email_sent::integer;
ALTER TABLE "user" ALTER COLUMN is_admin TYPE integer USING is_admin::integer;
ALTER TABLE "user" ALTER COLUMN email_verified TYPE integer USING email_verified::integer;
SQL

#Import PostgreSQL dumps into Grafana DB
for f in $3/*.dump.psql
do
  psql grafana < "$f";
done

#Undo workaround for PostgreSQL Grafana DB boolean columns
psql grafana <<SQL
ALTER TABLE alert
  ALTER COLUMN silenced TYPE boolean
    USING CASE WHEN silenced = 0 THEN FALSE
      WHEN silenced = 1 THEN TRUE
      ELSE NULL
      END;
ALTER TABLE alert_notification
  ALTER COLUMN is_default TYPE boolean
    USING CASE WHEN is_default = 0 THEN FALSE
      WHEN is_default = 1 THEN TRUE
      ELSE NULL
      END;
ALTER TABLE alert_notification ALTER COLUMN is_default SET DEFAULT false;
ALTER TABLE dashboard_snapshot
  ALTER COLUMN external TYPE boolean
    USING CASE WHEN external = 0 THEN FALSE
      WHEN external = 1 THEN TRUE
      ELSE NULL
      END;
ALTER TABLE data_source
  ALTER COLUMN basic_auth TYPE boolean
    USING CASE WHEN basic_auth = 0 THEN FALSE
      WHEN basic_auth = 1 THEN TRUE
      ELSE NULL
      END;
ALTER TABLE data_source
  ALTER COLUMN is_default TYPE boolean
    USING CASE WHEN is_default = 0 THEN FALSE
      WHEN is_default = 1 THEN TRUE
      ELSE NULL
      END;
ALTER TABLE data_source
  ALTER COLUMN with_credentials TYPE boolean
    USING CASE WHEN with_credentials = 0 THEN FALSE
      WHEN with_credentials = 1 THEN TRUE
      ELSE NULL
      END;
ALTER TABLE data_source ALTER COLUMN with_credentials SET DEFAULT false;
ALTER TABLE migration_log
  ALTER COLUMN success TYPE boolean
    USING CASE WHEN success = 0 THEN FALSE
      WHEN success = 1 THEN TRUE
      ELSE NULL
      END;
ALTER TABLE plugin_setting
  ALTER COLUMN enabled TYPE boolean
    USING CASE WHEN enabled = 0 THEN FALSE
      WHEN enabled = 1 THEN TRUE
      ELSE NULL
      END;
ALTER TABLE plugin_setting
  ALTER COLUMN pinned TYPE boolean
    USING CASE WHEN pinned = 0 THEN FALSE
      WHEN pinned = 1 THEN TRUE
      ELSE NULL
      END;
ALTER TABLE temp_user
  ALTER COLUMN email_sent TYPE boolean
    USING CASE WHEN email_sent = 0 THEN FALSE
      WHEN email_sent = 1 THEN TRUE
      ELSE NULL
      END;
ALTER TABLE "user"
  ALTER COLUMN is_admin TYPE boolean
    USING CASE WHEN is_admin = 0 THEN FALSE
      WHEN is_admin = 1 THEN TRUE
      ELSE NULL
      END;
ALTER TABLE "user"
  ALTER COLUMN email_verified TYPE boolean
    USING CASE WHEN email_verified = 0 THEN FALSE
      WHEN email_verified = 1 THEN TRUE
      ELSE NULL
      END;
SQL

echo ; echo 'Done.'; echo