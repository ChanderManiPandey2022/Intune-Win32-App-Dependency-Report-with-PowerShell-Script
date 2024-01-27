<# 
SYNOPSIS        = Find Win32 Application Dependency and create csv report Using PowerShell>
DESCRIPTION     = Find Win32 Application Dependency and create csv report Using PowerShell>
Demo Video link =  https://www.youtube.com/@ChanderManiPandey
INPUTS          = Provide all required inforamtion in User Input Section-line No 35 & 36 >
OUTPUTS         = You will get report in CSV>
Version:        = 1.0
Author:         = Chander Mani Pandey
Creation Date:  = 21 Jan 2024
Find Author on 
Youtube:-        https://www.youtube.com/@chandermanipandey8763
Twitter:-        https://twitter.com/Mani_CMPandey
LinkedIn:-       https://www.linkedin.com/in/chandermanipandey
#>


#--------------------------------  User Input Section Start -----------------------------------------------------------------#

$WorkingFolder = "C:\TEMP\Intune_App_Dependency"
$Pathfinalreport = "$WorkingFolder\Dependency\Intune_App_Dependency_Report.csv"

#-------------------------------- User Input Section End---------------------------------------------------------------------#
Write-Host "=============================== Find Win32 Application Dependency  ======================================================(Started)" -ForegroundColor  Magenta
Write-Host ""
Set-ExecutionPolicy -ExecutionPolicy 'ByPass' -Scope 'Process' -Force -ErrorAction 'Stop' 

$error.clear() ## this is the clear error history 
New-Item -ItemType Directory -Path $WorkingFolder -Force | Out-Null
$MGIModule = Get-module -Name "Microsoft.Graph.Intune" -ListAvailable

Write-Host "Checking Microsoft.Graph.Intune is Installed or Not" -ForegroundColor Yellow
If ($MGIModule -eq $null) 
{
    Write-Host "Microsoft.Graph.Intune module is not Installed" -ForegroundColor Yellow
    Write-Host "Installing Microsoft.Graph.Intune module" -ForegroundColor Yellow
    Install-Module -Name Microsoft.Graph.Intune -Force
    Write-Host "Importing Microsoft.Graph.Intune module" -ForegroundColor Yellow
    Import-Module Microsoft.Graph.Intune -Force
}
ELSE 
{
    Write-Host "Microsoft.Graph.Intune is Installed" -ForegroundColor Green
    Write-Host "Importing Microsoft.Graph.Intune module" -ForegroundColor Yellow
    Import-Module Microsoft.Graph.Intune -Force
}

Connect-MSGraph -Quiet
Update-MSGraphEnvironment -SchemaVersion "Beta" -Quiet
Write-Host ""
Write-Host "Downloading Applcation inventory Dump..........." -ForegroundColor Yellow
$Apps = Invoke-MSGraphRequest -HttpMethod GET -Url "deviceAppManagement/mobileApps" | Get-MSGraphAllPages | where {$_."@odata.type" -eq "#microsoft.graph.win32LobApp"} | Select-Object displayName,ID
Write-Host ""
Write-Host "Downloaded Application inventory Dump" -ForegroundColor Yellow
Write-Host ""
Write-Host "Total Win32 Apps are:-" $Apps.Count -ForegroundColor White

$reportData = @()
$totalApps = $Apps.Count
$currentAppIndex = 0

foreach ($App in $Apps) {
    $currentAppIndex++
    $progress = ($currentAppIndex / $totalApps) * 100
    $progressStatus = "Processing App $currentAppIndex of $totalApps"
    Write-Progress -Activity "Generating Dependency Application List Started" -Status $progressStatus -PercentComplete $progress

    $DependencyInfo = Invoke-MSGraphRequest -HttpMethod GET -Url "deviceAppManagement/mobileApps/$($App.ID)/relationships" | Get-MSGraphAllPages | where {$_.targetType -eq "Child"}  |Select-Object targetdisplayname, TargetDisplayversion, Dependencytype,targetType   

    foreach ($Dependency in $DependencyInfo) {
        $reportData += [PSCustomObject]@{
            ApplicationName              = $App.displayName
            ApplicationID                = $App.ID
            DependencyApplicationName    = $Dependency.targetdisplayname
            DependencyApplicationVersion = $Dependency.TargetDisplayversion
            DependencyInstallType        = $Dependency.Dependencytype
        }
    }
}

Write-Progress -Activity "Generating Dependency Applcation Report" -Status "Completed" -Completed 

if (-not (Test-Path $Pathfinalreport)) {
    Write-Host "The report path does not exist. Creating the report path." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path (Split-Path -Path $Pathfinalreport) -Force | Out-Null
}

$reportData | Export-Csv -Path $Pathfinalreport -NoTypeInformation
Write-Host ""
Write-Host "Creating Win32 Application Dependency Report." -ForegroundColor Yellow
Write-Host ""
Write-Host "Successfully created Report. Report path:" $Pathfinalreport -ForegroundColor green
Invoke-Item -Path $Pathfinalreport

Write-Host "" 
Write-Host "===============================  Find Win32 Application Dependency ====================================================(Completed)" -ForegroundColor  Magenta
