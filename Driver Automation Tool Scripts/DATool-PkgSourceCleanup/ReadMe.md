# DATool-PkgSourceCleanup.ps1

We all love [Maurice Daly's Driver Automation Tool](https://github.com/maurice-daly/DriverAutomationTool). After adopting it in my Configuration Manager environment, I noticed it does not remove previous versions of package source folders, leaving me to manually search for and delete them. Of course I had to automate this task, so I wrote this quick and dirty script to do it for me.

This script removes these orphaned package source folders so I don't have to.

## Installation

* Copy the script to the folder you specify in the DA-Tool for "Package Storage Path"
  ![Screenshot01](https://github.com/dp250f/Documentation/blob/main/DATool-PkgSourceCleanup/DATool-PkgSourceCleanup01.PNG?raw=true)

* Modify script variables to match your environment:
  ```powershell
  # Set site-specific variables
  $DatSourceRoot = '\\SITE-SERVER\source\Packages\DA-Tool'
  $SiteCode = 'P01' # Site code 
  $ProviderMachineName = 'SITE-SERVER.domain.name' # SMS Provider machine name
  ```

## Usage

* Right-click the script and choose 'Run with Powershell'
  ![Screenshot02](https://github.com/dp250f/Documentation/blob/main/DATool-PkgSourceCleanup/DATool-PkgSourceCleanup02.PNG?raw=true)
* Make your choice (y/n)
* Script pauses after running so you can review deleted files

## Disclaimer
This script works for me in my environment. I cannot guarantee it will work in other environments. Always test other people's code thoroughly before using it in yours.

## Contributing
Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

## License
[GNU GPLv3](https://choosealicense.com/licenses/gpl-3.0/)
