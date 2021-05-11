# AddTo-Unattend.ps1

I had a need to add Synchronous Run items to the Specialize pass in my unattend.xml during an OSD task sequence. Instead of manually editing it and generating multiple templates to use in the 'Apply OS Image' step (The Horror!), I created a simple script which accepts parameters and so can easily be run in a task sequence step and accept task sequence variables as input(s).

This is that script.

## Usage

* Create a new 'Run Powershell Script' step immediately before the 'Setup Windows and Configuration Manager' step.
* Choose 'Enter a PowerShell script', click 'Edit Script' and paste this script into the input box.
* Choose 'Bypass' PowerShell execution policy
* Enter your parameters (the stuff you're adding Unattend.xml - this is just an example)
  ```cmd
  -UnattendFile '%OSDTargetSystemRoot%\Panther\Unattend\unattend.xml' -CmdPath 'reg.exe add HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System /v EnableCursorSuppression /t REG_DWORD /d 0 /f' -CmdDescription 'Disable Cursor Suppression'
  ```
* Now you have a task sequence step you can set conditions on to dynamically add Run Synchronous items to your Specialize Unattend pass.
![Screenshot01](https://github.com/dp250f/Documentation/blob/main/AddTo-Unattend/Screenshot01.png?raw=true)

## Disclaimer
This script works for me in my environment. I cannot guarantee it will work in other environments. Always test other people's code thoroughly before using it in yours.

## Contributing
Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

## License
[GNU GPLv3](https://choosealicense.com/licenses/gpl-3.0/)