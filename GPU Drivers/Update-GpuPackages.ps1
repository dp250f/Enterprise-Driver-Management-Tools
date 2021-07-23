# This script unpacks each downloaded GPU driver and packs it back up into a 7-Zip or wim file, creates/updates a CM Package for each, and creates a GPU Detect package for Task Sequence use

# Download the latest version of each driver into its corresponding folder (if a newer version is available)
# If newer versions are available, delete the old files
# Run this script to create new archives **Must be run from a local drive letter for wim compression to work**

# ------------ Variables ------------ #

# Set script variables
$GpuPackagesRoot = Get-Item -Path '\\SITE-SERVER\source\OSD\Driver-Packages'
$CMSiteCode = 'P01'
$CMPackagesFolder = "$($CMSiteCode):\package\IT Support\OSD\Drivers"
$Compression = 'wim' # Can be '7z' or 'wim'

# ------------ Functions ------------ #

Function Update-CMPackage {
  Param (
    [AllowEmptyString()]$PkgName = $(throw('-PkgName object required')),
    [AllowEmptyString()]$PkgFolder = $(throw('-PkgFolder object required')),
    [AllowEmptyString()]$PkgCmFolder = $(throw('-PkgCmFolder object required'))
  )
  Push-Location
  # Import SCCM PowerShell Module
  If (-not(Test-Path -Path "$($CMSiteCode):")) {
    $ModuleName = (Get-Item $env:SMS_ADMIN_UI_PATH).parent.FullName + '\ConfigurationManager.psd1'
    Write-Host "$(Get-Date) -- Loading Configuration Manager PowerShell Module"
    Import-Module $ModuleName
  }

  # Create package if needed
  Set-Location "$($CMSiteCode):"
  If (-not (Get-CMPackage -Fast -Name $PkgName)) {
    # Create new package
    Write-Host "$(Get-Date) -- Creating ConfigMgr Package '$PkgName'"
    $null = New-CMPackage -Name $PkgName
  }

  # Update package
  Write-Host "$(Get-Date) -- Updating ConfigMgr Package '$PkgName'"
  Set-CMPackage -Name $PkgName -Path $PkgFolder -EnableBinaryDeltaReplication $true

  # Move package to manufacturer CM folder
  Write-Host "$(Get-Date) -- Moving '$PkgName' Package to '$PkgCmFolder'"
  If (-not (Test-Path $PkgCmFolder)) {
    New-Item -Path $PkgCmFolder -ItemType Directory
  }
  Get-CMPackage -Fast -Name $PkgName | Move-CMObject -FolderPath $PkgCmFolder

  # Distribute package to all DP Groups (or just redistribute)
  Write-Host "$(Get-Date) -- Distributing ConfigMgr Package '$PkgName'"
  $DPGroups = (Get-CMDistributionPointGroup).Name | Where-Object { $_ -ne 'Cloud' }
  Try {
    Start-CMContentDistribution -PackageName $PkgName -DistributionPointGroupName $DPGroups -ErrorAction SilentlyContinue
    Write-Host "$(Get-Date) -- Distributed ConfigMgr Package '$PkgName' to DP Groups: $DPGroups"
  } Catch {
    Update-CMDistributionPoint -PackageName $PkgName
    Write-Host "$(Get-Date) -- Updated content for ConfigMgr Package '$PkgName'"
  }
  Pop-Location
}

# ------------ Main ------------ #

# Self-elevate the script if required
if (-Not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')) {
  if ([int](Get-CimInstance -Class Win32_OperatingSystem | Select-Object -ExpandProperty BuildNumber) -ge 6000) {
      $CommandLine = "-ExecutionPolicy Bypass -File `"" + $MyInvocation.MyCommand.Path + "`" " + $MyInvocation.UnboundArguments
      Start-Process -FilePath PowerShell.exe -Verb Runas -ArgumentList $CommandLine
      Exit
  }
}

# Start Transcription (Logging)
Try { Start-Transcript -Path "$PSScriptRoot\$($myInvocation.MyCommand).log" -Force | Out-Null ; $Transcription = $True }
Catch { $Transcription = $False }

# Process all driver installer files (exe and zip)
$UpdateCount = 0
foreach ($DownloadFile in $(Get-ChildItem -Path "$PSScriptRoot\*\*\*" | Where-Object { $_.Name -match 'exe|zip' -and $_.Name -notmatch '7z\.' })) {
  Write-Host "$(Get-Date) -- Processing '$($DownloadFile.FullName)'"
  $ExtractedDriver = "$($DownloadFile.Directory.FullName)\$($DownloadFile.BaseName)"

  # Delete temporary folder (in case it's still there from a previous run)
  Get-Item -Path "$ExtractedDriver" -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force

  # If the compressed file doesn't exist
  If (-not (Test-Path -Path "$ExtractedDriver.$Compression")) {
    $UpdateCount++
    
    # Extract installer to temporary folder
    Write-Host "$(Get-Date) -- Extracting '$($DownloadFile.Name)'"
    $7zOutput = &"$PSScriptRoot\7Zip\7z-$env:PROCESSOR_ARCHITECTURE\7z.exe" x "$($DownloadFile.FullName)" -o"$($DownloadFile.Directory.FullName)\*"
    If (-not ($7zOutput -match 'Everything is Ok')) {
      Write-Host "$(Get-Date) -- 7Zip Failure:"
      $7ZOutput
      Break
    }

    # Create Compressed Source
    Write-Host "$(Get-Date) -- Compressing to '$ExtractedDriver.$Compression'"
    If ($Compression -eq '7z') {
      # Create 7zip compressed source
      $7zOutput = &"$PSScriptRoot\7Zip\7z-$env:PROCESSOR_ARCHITECTURE\7z.exe" a -mx=9 -mmt=on `
        "$ExtractedDriver.7z" "$ExtractedDriver\*"
      If (-not ($7zOutput -match 'Everything is Ok')) {
        Write-Host "$(Get-Date) -- 7Zip Failure:"
        $7ZOutput
        Break
      }
    } ElseIf ($Compression -eq 'wim') {
      # Create wim compressed source
      Try {
        New-WindowsImage -ImagePath "$ExtractedDriver.wim" -CapturePath "$ExtractedDriver" -Name 'GPU Driver Package' -Description 'GPU Driver Package' -CompressionType 'Max'
      } Catch {
        Write-Error "$(Get-Date) -- DISM Failure:"
        $Error
        Break
      }
    }

    # Create package source folder if necessary
    $CompressedDriver = Get-Item -Path "$ExtractedDriver.$Compression"
    New-Item -Path "$GpuPackagesRoot\$($CompressedDriver.Directory.Parent.Name)\$($CompressedDriver.Directory.Name)" -ItemType Directory -ErrorAction SilentlyContinue > $null

    # Delete existing package source file(s)
    $DriverSourceFolder = Get-Item -Path "$GpuPackagesRoot\$($CompressedDriver.Directory.Parent.Name)\$($CompressedDriver.Directory.Name)"
    Remove-Item -Path "$DriverSourceFolder\*" -Force -ErrorAction SilentlyContinue

    # Copy compressed driver file to $GpuPackagesRoot\MFG\Model package source folder
    Write-Host "$(Get-Date) -- Copying '$($CompressedDriver.Name)' to '$DriverSourceFolder'"
    Copy-Item $CompressedDriver -Destination "$DriverSourceFolder" -Force

    # Update/Create ConfigMgr Driver package
    Update-CMPackage -PkgName "$($DownloadFile.Directory.Parent.BaseName) $($DownloadFile.Directory.BaseName)" -PkgFolder "$DriverSourceFolder" -PkgCmFolder "$CMPackagesFolder\$($DownloadFile.Directory.Parent.BaseName)"

    # Find Detect file in extracted download for each manufacturer
    If ($DownloadFile.Directory.Parent.Name -match 'GPU - AMD') {
      Get-Item "$ExtractedDriver\Packages\Drivers\Display\WT6A_INF\*.msi" | ForEach-Object {
        $InfFile = Get-Item -Path "$($_.Directory)\$($_.BaseName).inf"
        $DetectFile = "$($DownloadFile.Directory.Parent.Parent.FullName)\GPU Detect\AMD-$(($DownloadFile.Directory.BaseName -split ' ')[0]).inf"
      }
    } ElseIf ($DownloadFile.Directory.Parent.Name -match 'GPU - INTEL') {
      Get-Item "$ExtractedDriver\Graphics\igdlh*.inf","$ExtractedDriver\Graphics\iigd_dch.inf" -ErrorAction SilentlyContinue | ForEach-Object {
        $InfFile = Get-Item -Path "$($_.Directory)\$($_.BaseName).inf"
        $DetectFile = "$($DownloadFile.Directory.Parent.Parent.FullName)\GPU Detect\INTEL-$(($DownloadFile.Directory.BaseName -split ' ')[0]).inf"
      }
    } ElseIf ($DownloadFile.Directory.Parent.Name -match 'GPU - NVIDIA') {
      Get-Item "$ExtractedDriver\ListDevices.txt" | ForEach-Object {
        $InfFile = Get-Item -Path "$($_.Directory)\$($_.BaseName).txt"
        $DetectFile = "$($DownloadFile.Directory.Parent.Parent.FullName)\GPU Detect\NVIDIA-$(($DownloadFile.Directory.BaseName -split ' ')[0]).txt"
      }
    }

    # Copy Detect file from extracted download to GPU Detect folder and package source folder
    If ($InfFile -and $DetectFile) {
      # Copy to GPU Detect folder
      Write-Host "$(Get-Date) -- Copying new Driver Detect File '$($InfFile.Name)' to '$DetectFile'"
      Copy-Item $InfFile -Destination "$DetectFile" -Force

      # Copy to GPU Detect package source folder
      Write-Host "$(Get-Date) -- Copying new Driver Detect File '$($DetectFile | Split-Path -Leaf)' to '$GpuPackagesRoot\GPU Detect'"
      Copy-Item $DetectFile -Destination "$GpuPackagesRoot\GPU Detect" -Force
    }

    # Delete temporary folder
    Get-Item -Path "$ExtractedDriver" | Remove-Item -Recurse -Force
  } Else {
    Write-Host "$(Get-Date) -- '$($DownloadFile.BaseName).$Compression' already exists"
  }
  Write-Host "----------"
}

If ($UpdateCount -ge 1) {
  # Update Detect-GPU.ps1 script
  Get-Item "$PSScriptRoot\GPU Detect\*.ps1" | Copy-Item -Destination "$GpuPackagesRoot\GPU Detect" -Force
  
  # Update/Create ConfigMgr Driver Detect package
  Update-CMPackage -PkgName 'GPU Detect' -PkgFolder "$GpuPackagesRoot\GPU Detect" -PkgCmFolder "$CMPackagesFolder"
}

# Stop Transcription (Logging)
If ($Transcription -eq $True) { Stop-Transcript }

# Keep powershell window open so tech can see results
Pause