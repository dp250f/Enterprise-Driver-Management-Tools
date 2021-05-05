# This script cleans up unused source folders DA-Tool leaves behind

# Set site-specific variables
$DatSourceRoot = '\\CM-Server\source\packages\DA-Tool'
$SiteCode = "SC1" # Site code 
$ProviderMachineName = "CM-Server.domain.name" # SMS Provider machine name

# Import the ConfigurationManager.psd1 module 
Push-Location
if ((Get-Module ConfigurationManager) -eq $null) {
  Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1"
}
# Connect to the site's drive if it is not already present
if ((Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue) -eq $null) {
  New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $ProviderMachineName
}
Pop-Location

# Gather all source folder paths used by all DA-Tool packages
Push-Location
Set-Location "$($SiteCode):\"
$PackageSources = Get-CMPackage -Fast | Where-Object { $_.Name -like 'Drivers - *' -or $_.Name -like 'BIOS Update - *' } | Select-Object PkgSourcePath | Sort-Object PkgSourcePath
Pop-Location

# Gather all source folder paths in DA-Tool Source Root folder
$DatSources = Get-ChildItem -Path "$DatSourceRoot\*\*-Windows*","$DatSourceRoot\*\*\BIOS\*" -Directory | Select-Object FullName | Sort-Object FullName

# Build array of folders to delete
$FoldersToDelete = @()
ForEach ($DatSource in $DatSources.FullName) {
  # Check to see if this source folder is used by a package
  If (-not (($PackageSources.PkgSourcePath -replace '\\') -match ($DatSource -replace '\\'))) {
    # Source folder is not used by a package
    $FoldersToDelete += $DatSource
    Write-Host "'$DatSource' " -NoNewline -ForegroundColor Cyan
    Write-Host "is not in use."
  }
}

# Prompt to delete folders
If ($FoldersToDelete) {
  # Show folders which will be deleted and confirm deletion
  $msg = 'Do you want to delete these folders [Y/N]'
  do {
    $response = Read-Host -Prompt $msg
    if ($response -eq 'y') {
      Remove-Item -Path $FoldersToDelete -Recurse -Force -Verbose
    }
  } until ($response -match 'n|y')
} else {
  Write-Host "There are no unused DA-Tool package source folders to cleanup." -ForegroundColor Green
}

# Hold for applause...
Pause