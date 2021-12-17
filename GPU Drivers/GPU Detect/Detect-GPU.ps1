# ---------- Functions ----------
function Start-Log {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true)]  
    [ValidateScript( { Split-Path $_ -Parent | Test-Path })]
    [string]$FilePath,

    [Parameter(Mandatory = $false)]
    [Switch]
    $Overwrite
  )
	
  try {
    if (!(Test-Path $FilePath) -or ($Overwrite)) {
      ## Create the log file
      New-Item $FilePath -Type 'File' -Force | Out-Null
    }
		
    ## Set the global variable to be used as the FilePath for all subsequent Write-Log
    ## calls in this session
    $global:ScriptLogFilePath = $FilePath
  } catch {
    Write-Error $_.Exception.Message
  }
}

function Write-Log {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true)]
    [string]$Message,
		
    [Parameter()]
    [ValidateSet('Information', 'Warning', 'Error')]
    $LogType = 'Information'
  )

  # Translate LogType to LogLevel and set host output color
  switch ($LogType) {
    Information { $LogLevel = '1'; $Color = 'Green'; Break }
    Warning     { $LogLevel = '2'; $Color = 'Yellow'; Break }
    Error       { $LogLevel = '3'; $Color = 'Red'; Break }
  }

  # Build log string compatible with CMTrace log file viewer
  $TimeGenerated = "$(Get-Date -Format HH:mm:ss).$((Get-Date).Millisecond)+000"
  $Line = '<![LOG[{0}]LOG]!><time="{1}" date="{2}" component="{3}" context="" type="{4}" thread="" file="">'
  $LineFormat = $Message, $TimeGenerated, (Get-Date -Format MM-dd-yyyy), "$($MyInvocation.ScriptName | Split-Path -Leaf):$($MyInvocation.ScriptLineNumber)", $LogLevel
  $Line = $Line -f $LineFormat

  # Output message to host and write log string to log file
  Write-Host "$(Get-Date) -- $Message" -ForegroundColor $Color
  If ($ScriptLogFilePath) {
    Add-Content -Value $Line -Path $ScriptLogFilePath
  }
}

# ---------- Main ----------

Try {
  # Create Task Sequence Environment com object
  $tsenv = New-Object -ComObject Microsoft.SMS.TSEnvironment -ErrorAction SilentlyContinue

  # Read TS variables
  $logPath = $tsenv.Value('_SMSTSLogPath')
} Catch {
  # Use test values
  $logPath = $PSScriptRoot
}

# Set log file name and start Logging
$aLog = "$logPath\$($myInvocation.MyCommand)".Split('.')
$logFile = "$($aLog[0..($aLog.Count - 2)] -join '.').log"
Start-Log -FilePath $logFile -Overwrite

if ($tsenv) {
  Write-Log -Message '**** Script is running in Task Sequence Environment ****' -LogType 'Information'
} else {
  Write-Log -Message '**** Script is running outside of Task Sequence Environment ****' -LogType 'Information'
}

# Get all display adapters, only save Name and PNPDeviceID (Win32_VideoController works in Windows and Win32_PNPEntity works in WinPE)
if ($env:SystemRoot -eq 'X:\Windows') {
  $DisplayAdapters = Get-WmiObject -Class Win32_PNPEntity -Filter "Name LIKE '%Video Controller%'" | Select-Object Name, PNPDeviceID
} else {
  $DisplayAdapters = Get-WmiObject -Class Win32_VideoController | Select-Object Name, PNPDeviceID
}

# Select only AMD, NVIDIA, and INTEL adapters
$DisplayAdapters = $DisplayAdapters | Where-Object {
  $_.PNPDeviceID -match 'VEN_1002' -or `
  $_.PNPDeviceID -match 'VEN_10DE' -or `
  $_.PNPDeviceID -match 'VEN_8086'
}

# Get all display adapter INF/Device List files
$DriverDetectFiles = Get-ChildItem -Path "$PSScriptRoot\*" -Include 'AMD-*.*','INTEL-*.*','NVIDIA-*.*'

$DriverPackages = @()
# Process each display adapter
ForEach ($Adapter in $DisplayAdapters) {
  $DriverMatches = @()
  If ($Adapter.PNPDeviceID -match 'VEN_1002') {
    # Process each AMD display adapter
    Write-Log -Message "Found AMD Display Adapter $($Adapter.PNPDeviceID)" -LogType 'Information'
    $SearchStr = "$($Adapter.PNPDeviceID -replace 'PCI\\' -replace '\&SUBSYS.*')"
    # Search each Driver Detect file for this adapter's DeviceID
    ForEach ($DetectFile in $DriverDetectFiles | Where-Object Name -match 'AMD-') {
      If (Select-String -Path $DetectFile -Pattern $SearchStr | Where-Object {$_.Line -notmatch 'Legacy'}) {
        # Add DetectFile name to $DriverMatches
        $DriverMatches += $DetectFile.BaseName
        Write-Log -Message "Found matching driver '$($DetectFile.BaseName)'" -LogType 'Information'
      }
    }

  } elseif ($Adapter.PNPDeviceID -match 'VEN_10DE') {
    # Process each NVIDIA display adapter
    Write-Log -Message "Found NVIDIA Display Adapter $($Adapter.PNPDeviceID)" -LogType 'Information'
    $SearchStr = "$($Adapter.PNPDeviceID -replace 'PCI\\VEN_10DE\&' -replace '\&SUBSYS.*')"
    # Search each Driver Detect file for this adapter's DeviceID
    ForEach ($DetectFile in $DriverDetectFiles | Where-Object Name -match 'NVIDIA-') {
      If (Select-String -Path $DetectFile -Pattern $SearchStr | Where-Object {$_.Line -notmatch 'Legacy'}) {
        # Add DetectFile name to $DriverMatches
        $DriverMatches += $DetectFile.BaseName
        Write-Log -Message "Found matching driver '$($DetectFile.BaseName)'" -LogType 'Information'
      }
    }
    
  } elseif ($Adapter.PNPDeviceID -match 'VEN_8086') {
    # Process each INTEL display adapter
    Write-Log -Message "Found INTEL Display Adapter $($Adapter.PNPDeviceID)" -LogType 'Information'
    $SearchStr = "$($Adapter.PNPDeviceID -replace 'PCI\\' -replace '\&SUBSYS.*')"
    # Search each Driver Detect file for this adapter's DeviceID
    ForEach ($DetectFile in $DriverDetectFiles | Where-Object Name -match 'INTEL-') {
      If (Select-String -Path $DetectFile -Pattern $SearchStr | Where-Object {$_.Line -notmatch 'Legacy'}) {
        # Add DetectFile name to $DriverMatches
        $DriverMatches += $DetectFile.BaseName
        Write-Log -Message "Found matching driver '$($DetectFile.BaseName)'" -LogType 'Information'
      }
    }

  } else {
    Write-Log -Message "No applicable display adapter found" -LogType 'Information'
  }

  # Add $DriverMatch to $DriverPackages (in order of preference - if more than one match, choose the Pro, followed by the newer non-pro driver)
  Switch ($DriverMatches) {
    # Add only RadeonPro
    { $DriverMatches -match 'RadeonPro' -notmatch 'Legacy' } {
      $DriverPackages += $DriverMatches -match 'RadeonPro' -notmatch 'Legacy' ; Break
    }
    # Add only RadeonProLegacy
    { $DriverMatches -match 'RadeonPro' -match 'Legacy' } {
      $DriverPackages += $DriverMatches -match 'RadeonPro' -match 'Legacy' ; Break
    }
    # Add only Radeon
    { $DriverMatches -match 'Radeon' -notmatch 'Pro|PreGCN|Legacy' } {
      $DriverPackages += $DriverMatches -match 'Radeon' -notmatch 'Pro|PreGCN|Legacy' ; Break
    }
    # Add only RadeonLegacy
    { $DriverMatches -match 'Radeon' -match 'Legacy' -notmatch 'Pro|PreGCN' } {
      $DriverPackages += $DriverMatches -match 'Radeon' -match 'Legacy' -notmatch 'Pro|PreGCN' ; Break
    }
    # Add only Quadro
    { $DriverMatches -match 'Quadro' -notmatch 'Legacy' } {
      $DriverPackages += $DriverMatches -match 'Quadro' -notmatch 'Legacy' ; Break
    }
    # Add only GeForce
    { $DriverMatches -match 'GeForce' -notmatch 'Kepler|Legacy' } {
      $DriverPackages += $DriverMatches -match 'GeForce' -notmatch 'Legacy' ; Break
    }
    # Add only GeForceKepler
    { $DriverMatches -match 'GeForce' -match 'Kepler' } {
      $DriverPackages += $DriverMatches -match 'GeForce' -notmatch 'Legacy' ; Break
    }
    # Add whatever older driver(s) were found - (NVIDIA Legacy or AMD FirePro or PreGCN)
    Default {
      $DriverPackages += $DriverMatches
    }
  }
}

# Create a TS variable for each matched DetectFile
If ($DriverPackages) {
  $DriverPackages | Select-Object -Unique | ForEach-Object {
    if ($tsenv) {
      # Save TS Variable 
      $tsenv.Value("GPU-$_") = 'True'
    }
    Write-Log -Message "Set TS Variable 'GPU-$_' = 'True'" -LogType 'Information'
  }
} else {
  Write-Log -Message "No applicable GPU driver packages found" -LogType 'Information'
}