############################
#                          #
#  Migrate.... Everything  #
#                          #
############################

# Explore available copy commands
# Get Databases & Logins
# Migrate Databases
# Migrate Logins
# Upgrade databases


# migrating application databases with dbatools
# https://dbatools.io/migrating-application-dbs/

# Copy commands available in dbatools
Get-Command -Module dbatools -Verb Copy

## Get databases
$datatbaseSplat = @{
    SqlInstance   = $dbatools1
    ExcludeSystem = $true
    OutVariable   = "dbs"        # OutVariable to also capture this to use later
}
Get-DbaDatabase @datatbaseSplat |
Select-Object Name, Status, RecoveryModel, Owner, Compatibility |
Format-Table

# Get Logins
$loginSplat = @{
    SqlInstance = $dbatools1
}
Get-DbaLogin @loginSplat |
Select-Object SqlInstance, Name, LoginType

# Get Processes
$processSplat = @{
    SqlInstance = $dbatools1
    Database    = "DatabaseAdmin"
}
Get-DbaProcess @processSplat |
Select-Object Host, login, Program

# Kill Processes
Get-DbaProcess @processSplat | Stop-DbaProcess

## Migrate the databases
$migrateDbSplat = @{
    Source        = $dbatools1
    Destination   = $dbatools2
    Database      = $dbs.name
    BackupRestore = $true
    SharedPath    = '/shared'
    #SetSourceOffline        = $true
    Verbose       = $true
}
Copy-DbaDatabase @migrateDbSplat

## Migrate login
$migrateLoginSplat = @{
    Source      = $dbatools1
    Destination = $dbatools2
    Login       = "JessP"
    Verbose     = $true
}
Copy-DbaLogin @migrateLoginSplat

## Set source dbs offline
$offlineSplat = @{
    SqlInstance = $dbatools1
    Database    = "Northwind", "DatabaseAdmin"
    Offline     = $true
    Force       = $true
}
Set-DbaDbState @offlineSplat

## upgrade compat level & check all is ok
$compatSplat = @{
    SqlInstance = $dbatools2
}
Get-DbaDbCompatibility @compatSplat |
Select-Object SqlInstance, Database, Compatibility

$compatSplat.Add('Database', 'Northwind')
$compatSplat.Add('Compatibility', '150')

Set-DbaDbCompatibility @compatSplat -Verbose

## Upgrade database - https://thomaslarock.com/2014/06/upgrading-to-sql-server-2014-a-dozen-things-to-check/
# Updates compatibility level
# runs CHECKDB with data_purity - make sure column values are in range, e.g. datetime
# DBCC updateusage
# sp_updatestats
# sp_refreshview against all user views
$upgradeSplat = @{
    SqlInstance = $dbatools2
    Database    = "Pubs"
}
Invoke-DbaDbUpgrade @upgradeSplat -Force