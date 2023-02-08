##################################
#                                #
#  SQL Server 2022 - Migrations  #
#            Advanced            #
##################################

# What if our databases are big
# Pre-Stage most of the data
# Downtime window for final cutover

# Get Processes
$processSplat = @{
    SqlInstance = $SQLInstances
    Database    = "pubs", "Northwind"
}
Get-DbaProcess @processSplat |
    Select-Object Host, login, Program

# Remove database on destination
$dbSplat = @{
    SqlInstance   = $dbatools2
    ExcludeSystem = $true
}
Get-DbaDatabase @dbSplat | Remove-DbaDatabase -Confirm:$false

# Bring databases on source back online
$onlineSplat = @{
    SqlInstance   = $dbatools1
    Online        = $true
    AllDatabases  = $true
}
Set-DbaDbState @onlineSplat

################################################
# JESS GO OPEN ANOTHER PWSH AND START THE APP! #
################################################

# before downtime - stage most of the data
$copySplat = @{
    Source          = $dbatools1
    Destination     = $dbatools2
    Database        = 'pubs'
    SharedPath      = '/shared'
    BackupRestore   = $true
    NoRecovery      = $true # leave the database ready to receive more restores
    NoCopyOnly      = $true # this will break our backup chain!
    OutVariable     = 'CopyResults'
}
Copy-DbaDatabase @copySplat

# This DateTime is going to be important...
$CopyResults | Select-Object *

#################################
## DOWNTIME WINDOWS STARTS NOW ##
#################################
# App team will stop the app running...

# Activity hasn't stopped from our application
# Get Processes
$processSplat = @{
    SqlInstance = $dbatools1, $dbatools2
    Database    = 'Pubs'
}
Get-DbaProcess @processSplat |
    Select-Object Host, login, Program

# Kill any left over processes
Get-DbaProcess @processSplat | Stop-DbaProcess

# What's our newest order?
Invoke-DbaQuery -SqlInstance $dbatools1 -Database Pubs -Query 'select @@servername AS [SqlInstance], count(*)NumberOfOrders, max(ord_date) as NewestOrder from pubs.dbo.sales' -OutVariable 'sourceSales'

# Remember when we took our last backup?
$CopyResults | Select-Object *

# Let's take a differential to get any changes
$diffSplat = @{
    SqlInstance = $dbatools1
    Database    = 'pubs'
    Path        = '/shared'
    Type        = 'Differential'
}
$diff = Backup-DbaDatabase @diffSplat

# Set the source database offline
$offlineSplat = @{
    SqlInstance = $dbatools1
    Database    = 'pubs'
    Offline     = $true
    Force       = $true
}
Set-DbaDbState @offlineSplat

# Let's check on our databases
Get-DbaDatabase -SqlInstance $dbatools1, $dbatools2 -ExcludeSystem | Select-Object SqlInstance, Name, Status, SizeMB

# restore the differential and bring the destination online
$restoreSplat = @{
    SqlInstance = $dbatools2
    Database    = 'pubs'
    Path        = $diff.Path
    Continue    = $true
}
Restore-DbaDatabase @restoreSplat

# Let's check on our databases
Get-DbaDatabase -SqlInstance $dbatools1, $dbatools2 -ExcludeSystem | Select-Object SqlInstance, Name, Status, SizeMB

# Let's check our data
Invoke-DbaQuery -SqlInstance $dbatools2 -Database Pubs -Query 'select @@servername AS [SqlInstance], count(*)NumberOfOrders, max(ord_date) as NewestOrder from pubs.dbo.sales' -OutVariable 'destSales'

# Compare these dates and orders
$sourceSales, $destSales
