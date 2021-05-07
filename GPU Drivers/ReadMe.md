# GPU Drivers

I prefer to install GPU drivers downloaded directly from AMD, Intel, and NVIDIA in my OS Deployment task sequences. They're always newer than the ones in each computer model's driver package. The only real downside is that it's a pain to manually update driver packages every month. Of course, I had to automate it as much as possible!

**What the basic parts are:**

* **Update-GpuPackages.ps1** script which creates and updates GPU packages
* The task sequence steps which use these packages
* **Detect-GPU.ps1** script which detects which GPU drivers to stage during a task sequence

**How to implement it:**

* 'Install' the script and its dependencies (7-zip)
* Edit script variables to suit your environment
* Download GPU packages and save in corresponding folders
* Run '**Update-GPUPackages.ps1**' - It creates/updates GPU packages in Configuration Manager
* Import task sequence steps, assign packages to each step, and copy them into your task sequence
* Add 7-zip files to a your **SMS10000** package
* Edit task sequence steps as needed to suit your 7zip location and chosen GPU package compression (7z or wim)

**How it works:**

* When **Update-GpuPackages.ps1** runs, it does this with each downloaded GPU driver (one at a time):
  * Extracts downloaded driver to a temp folder
  * Copies driver's **\*.inf** or **ListDevices.txt** file into the **GPU Detect** folder, renaming it to correspond with its driver package name
  * Compresses expanded driver and copies it to its ConfigMgr package source folder
  * Creates driver's ConfigMgr package, moves it to the desired folder, and distributes it to all non-cloud DP groups
* Once **Update-GpuPackages.ps1** is done processing each driver, it creates, moves, and distributes the **GPU Detect** package
* When an OS Deployment task sequence with these steps runs:
  * **Detect-GPU.ps1** enumerates the computer's display devices, detemines which GPU driver(s) to download and saves them to task sequence variables.
  * Task sequence steps with conditions using those variables download and stage each driver as necessary.
  * An '**Inject Staged Drivers with DISM**' task sequence step injects each GPU driver into a previously applied offline OS image.

## Prerequisites

* You need to be able to run the script from a local drive with credentials which have Configuration Manager rights to create/modify/delete packages. You also need to be able to create task sequences.

* You need to have **7-zip** in a package which can be used in Windows PE by the task sequence (You can see the path it uses in each 'Stage' step). I keep mine in my **SMS10000** package which is added to my boot media. I've included a step to download and extract a zipped **SMS10000** if the folder doesn't exist. You'll need to create that package if you want to do it this way.

  I hear what you're saying, and yes, I could have included it in the **GPU Detect** package. I use 7-zip for lots of other things in my task sequences so it makes more sense for me to include it in my **SMS10000** package. If you go your own way on this, make sure each step correctly references your 7zip executable.

# Update-GPUPackages.ps1

This script creates/updates GPU Driver and GPU Detect packages. The only thing you need to do is download drivers.

## Script 'Installation'

* Download this repository and extract 'GPU Drivers' into a local folder (keep the path short just in case)

  ![Screenshot01](https://github.com/dp250f/Documentation/blob/main/GPU-Drivers/Screenshot01.png?raw=true)

* Download and install 64-bit [7-zip](https://www.7-zip.org/)

* Copy **7z.exe** and **7z.dll** from **%ProgramFiles%\7-zip** into **GPU-Drivers\7Zip\7z-AMD64**

* Modify script variables to match your environment:
  ```powershell
  # Set script variables
  $GpuPackagesRoot = Get-Item -Path '\\SITE-SERVER\source\OSD\Driver-Packages'
  $CMSiteCode = 'P01'
  $CMPackagesFolder = "$($CMSiteCode):\package\IT Support\OSD\Drivers"
  $Compression = 'wim' # Can be '7z' or 'wim'
  ```

## Script Usage (creating/updating GPU packages)

* Download graphics drivers from AMD, Intel, and NVIDIA into their respective folders
  ![Screenshot02](https://github.com/dp250f/Documentation/blob/main/GPU-Drivers/Screenshot02.png?raw=true)

* Right-click **Update-GPUPackages.ps1** and choose 'Run with Powershell'

* Script will create all gpu driver packages, '**GPU Detect**' package and place them in the folders specified in script variables.

* Script pauses after running so you can review its activity.

# Task Sequence Steps

* Now that all the packages are created, you can import the task sequence which uses them. Import '**Task Sequence Steps.zip**' into your Configuration Manager environment. 

* Make sure the correct packages are referenced for each step. Package names are similar to each step name.

* If you chose 7z instead of wim compression in the script, you'll need to edit each 'Stage' step to use '\*.7z' instead of '\*.wim'

* Insert these steps after your '**Apply Operating System Image**' step and before your '**Setup Windows and ConfigMgr**' step. (You can have your other apply driver steps here. I removed them so everything would fit it in this screenshot)
  ![Screenshot03](https://github.com/dp250f/Documentation/blob/main/GPU-Drivers/Screenshot03.png?raw=true)

## Disclaimer

This script works for me in my environment. I cannot guarantee it will work in other environments. Always test other people's code thoroughly before using it in yours.

## Contributing

Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

## License

[GNU GPLv3](https://choosealicense.com/licenses/gpl-3.0/)