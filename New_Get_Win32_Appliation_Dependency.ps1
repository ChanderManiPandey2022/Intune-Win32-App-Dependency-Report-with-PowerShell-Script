
<#
.SYNOPSIS
    Find Win32 Application Dependencies in Intune and generate a CSV report using PowerShell.

.DESCRIPTION
    This script connects to Microsoft Graph, retrieves all Win32 applications from Intune,
    checks dependency relationships for each app, and exports a complete dependency report 
    including Parent App, Dependency App, Version, and Install Behavior.
    
    The script also includes DEBUG output so you can see real-time progress and dependency 
    discovery for each application.

.DEMO VIDEO
    https://www.youtube.com/@ChanderManiPandey

.INPUTS
    Provide all required information in the User Input section (line no. 42).

.OUTPUTS
    Generates a CSV file containing the full dependency mapping for all Win32 apps.

.VERSION
    1.0

.AUTHOR
    Chander Mani Pandey

.CREATION DATE
    18 Nov 2024

.FIND AUTHOR ON
    YouTube  : https://www.youtube.com/@chandermanipandey8763
    Twitter  : https://twitter.com/Mani_CMPandey
    LinkedIn : https://www.linkedin.com/in/chandermanipandey
#>


#--------------------------------  User Input Section Start -----------------------------------------------------------------#

$Pathfinalreport = "c:\windows\temp\Win32AppDependencyReport.csv"

#-------------------------------- User Input Section End---------------------------------------------------------------------#


###############################################
# Function: Ensure Module Installed + Imported
###############################################
function Ensure-Module {
    param (
        [string]$moduleToCheck
    )
    
    Write-Host "Checking if $moduleToCheck is installed..." -ForegroundColor Yellow
    $moduleStatus = Get-Module -Name $moduleToCheck -ListAvailable

    if (-not $moduleStatus) {
        Write-Host "$moduleToCheck not found. Installing..." -ForegroundColor Red
        Install-Module $moduleToCheck -Force -Scope CurrentUser
        Write-Host "$moduleToCheck installed successfully." -ForegroundColor Green
    }
    else {
        Write-Host "$moduleToCheck is already installed." -ForegroundColor Green
    }

    Write-Host "Importing $moduleToCheck module..." -ForegroundColor Yellow
    Import-Module $moduleToCheck -Force
    Write-Host "$moduleToCheck module imported successfully." -ForegroundColor Green
}

# Ensure Graph Module
Ensure-Module -moduleToCheck "Microsoft.Graph.Authentication"


###############################################
# Connect to Microsoft Graph
###############################################
Write-Host ""
Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Cyan
Connect-MgGraph -Scopes "DeviceManagementApps.ReadWrite.All" -NoWelcome -ErrorAction Stop



###############################################
# Function: Get All Mobile Apps (Pagination)
###############################################
function Get-AllApps {
    $uri = "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps"
    $allApps = @()

    do {
        $response = Invoke-MgGraphRequest -Method GET -Uri $uri
        $allApps += $response.value
        $uri = $response.'@odata.nextLink'
    } while ($uri)

    return $allApps
}



###############################################
# Get All Win32 Apps
###############################################
Write-Host ""
Write-Host "Downloading Application Inventory Dump..." -ForegroundColor Yellow

$Apps = Get-AllApps | Where-Object { $_.'@odata.type' -eq "#microsoft.graph.win32LobApp" }

Write-Host ""
Write-Host "Total Win32 Apps Found: $($Apps.Count)" -ForegroundColor Green



###############################################
# Prepare Dependency Report
###############################################
$reportData = @()
$totalApps = $Apps.Count
$currentAppIndex = 0


foreach ($App in $Apps) {

    # PROGRESS BAR
    $currentAppIndex++
    $progress = ($currentAppIndex / $totalApps) * 100
    Write-Progress -Activity "Generating Win32 Apps Dependency List..." -Status "Processing $currentAppIndex of $totalApps" -PercentComplete $progress


    ####################################################################
    # DEBUG BLOCK — PRINT APP DETAILS BEFORE QUERYING DEPENDENCIES
    ####################################################################
    Write-Host "========================================================================" -ForegroundColor DarkCyan
    Write-Host "Processing Application: $($App.displayName)" -ForegroundColor Yellow
    Write-Host "App ID: $($App.ID)" -ForegroundColor Cyan
    Write-Host "========================================================================" -ForegroundColor DarkCyan

    # Build dependency URL
    $depUri = "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/$($App.ID)/relationships"
    $DependencyInfo = @()

    do {
        #Write-Host "Calling Graph API → $depUri" -ForegroundColor DarkGray

        try {
            $depResponse = Invoke-MgGraphRequest -Method GET -Uri $depUri -ErrorAction Stop
        }
        catch {
            Write-Host "ERROR Calling Graph API for App: $($App.displayName)" -ForegroundColor Red
            Write-Host $_ -ForegroundColor Red
            break
        }

        if ($depResponse.value.Count -gt 0) {
            Write-Host "Graph returned $($depResponse.value.Count) dependency objects." -ForegroundColor Green
        }
        else {
            #Write-Host "Graph returned ZERO objects in this page." -ForegroundColor Red
        }

        # Debug raw items
        foreach ($d in $depResponse.value) {
            #Write-Host " → RAW: $($d.targetDisplayName) | Type: $($d.targetType) | DepType: $($d.dependencyType)" -ForegroundColor Magenta
        }

        $DependencyInfo += $depResponse.value
        $depUri = $depResponse.'@odata.nextLink'

    } while ($depUri)

    Write-Host "Total Collected Dependencies for This App: $($DependencyInfo.Count)" -ForegroundColor Green
    #Write-Host "========================================================================"



    ####################################################################
    # PROCESS ONLY CHILD DEPENDENCIES
    ####################################################################
    $ChildDeps = $DependencyInfo | Where-Object { $_.targetType -eq "Child" }

    foreach ($Dependency in $ChildDeps) {
        $reportData += [PSCustomObject]@{
            ApplicationName              = $App.displayName
            ApplicationID                = $App.ID
            DependencyApplicationName    = $Dependency.targetDisplayName
            DependencyApplicationVersion = $Dependency.targetDisplayVersion
            DependencyInstallType        = $Dependency.dependencyType
        }
    }
}



###############################################
# Export Report
###############################################
# Extract the folder path
$folderPath = Split-Path -Path $Pathfinalreport -Parent

# Check if folder exists, if not create it
if (!(Test-Path -Path $folderPath)) {
    Write-Host "Folder not found. Creating: $folderPath" -ForegroundColor Yellow
    New-Item -Path $folderPath -ItemType Directory -Force | Out-Null
} else {
    Write-Host "Folder already exists: $folderPath" -ForegroundColor Green
}

Write-Host ""
Write-Host "Saving report to: $Pathfinalreport" -ForegroundColor Yellow

$reportData | Export-Csv -Path $Pathfinalreport -NoTypeInformation

Write-Host ""
Write-Host "Report created successfully!" -ForegroundColor Green
Invoke-Item -Path $Pathfinalreport

Write-Host ""
Write-Host "====================== COMPLETED ======================" -ForegroundColor Magenta
