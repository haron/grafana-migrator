#! /bin/sh

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

echo ; echo 'Done.'; echo
echo 'Please find the psql dumps at '$3