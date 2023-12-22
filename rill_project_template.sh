#!/bin/bash

# error if no arg 
# $1 is project_name
# $2 is duckdb database
echo "getting tables from $2"
tables=$(duckdb -c .tables $2) 
for tbl in $tables
do
   echo exporting $tbl to parquet
   duckdb -s "copy $tbl to '$tbl.parquet' (format 'parquet');" $2
done
# i don't like rill dumping crap to the terminal.
# if there are issues, you might have to remove the redirections to see what's up 
echo starting rill server process
rill start --no-open $1 > /dev/null 2>&1 &
rill_pid=$!
echo rill pid $rill_pid
wait_secs=3
echo waiting $wait_secs seconds
sleep $wait_secs
echo curl endpoint to make empty project
curl -s -o /dev/null -X POST "http://localhost:9009/v1/instances/default/files/unpack-empty"
echo killing initial server process $rill_pid 
kill $rill_pid

for tbl in $tables
do
   echo making default data source/model for $tbl

cat << EOF > $1/sources/$tbl.yaml
type: "duckdb"
sql: "select * from read_parquet('../$tbl.parquet')"
EOF
model_sfx="_model.sql"
cat << EOF > $1/models/$tbl$model_sfx
select * from $tbl
EOF
done
echo "done generating rill project scaffold"
echo "use the command below to start the rill session"
echo "and create default dashboards or new models"
echo 
echo "rill start $1"