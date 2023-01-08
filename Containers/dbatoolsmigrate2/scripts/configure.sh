# loop until sql server is up and ready
for i in {1..50};
do
    sqlcmd -S localhost -d master -Q "SELECT @@VERSION"
    if [ $? -ne 0 ];then
        sleep 2
    fi
done

# create sqladmin with dbatools.IO password and disable sa
sqlcmd -S localhost -d master -i /tmp/create-admin.sql

# change the default login to sqladmin instead of sa
export SQLCMDUSER=sqladmin

# prep to rename the server to be mssql1 or mssql2
sqlcmd -d master -Q "EXEC sp_dropserver @@SERVERNAME"

# if it's the primary server, restore pubs and northwind and create a bunch of objects
sqlcmd -S localhost -d master -Q "EXEC sp_addserver 'mssql2', local"
