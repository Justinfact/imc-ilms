# IMC Linux MySQL Setup (ILMS) v1.00 12.08.2020
Shell script that prepares your Red Hat Enterprise Linux 7.x system for installing HPE IMC 7.3 E0703+. It can perform all necessary prerequisite setup tasks, so all you need to do afterwards is download and install IMC.

## Overview
The purpose of this script is to provide an easy way to prepare a RHEL server for IMC installation. It should be executed on the server, will prompt you for some input, and perform all necessary setup tasks for either type of IMC deployment (Centralized/Distributed). It can install and setup MySQL 5.7/8.0 Community for you as well.

The script can save you a lot of time spent on a rather lengthy preparation process, and intends to be user-friendly, re-runable, verbose and relatively foolproof. It should be usable even for those inexperienced or unfamiliar with the setup process.

It is free, open source, and comes with absolutely NO warranty.

## Server Prerequisites
  * Supported RHEL or CentOS (unsupported but works) installed on the system.
  * Hardware properly adjusted for the size of the IMC installation.
  * For hardware scaling and recommendation see [Deployment & Hardware Configuration Schemes](https://support.hpe.com/hpsc/doc/public/display?docLocale=en_US&docId=emr_na-a00075913en_us&withFrame).
  * Static IP address must already be configured on the system.
  * Run the script as root (commands are not run with sudo).
  * The server must have internet access if my-ilms-**x**.txt (where x is 5.7/8.0) does not exist in the script directory.
  * RHEL Server must have an active subscription (for yum/rpm).
  
## Usage
  * Run this tool once per server to be configured for IMC.
  1) Login as root on CLI and copy the script to /root
  2) Make the script executable: chmod +x ./ILMS.sh
  3) Run the script with ./ILMS.sh
  4) Answer all prompts as requested and wait for the script to complete
  5) Reboot as prompted, and then download & install IMC

## Deployment Schemes
IMC provides numerous deployment models that can be used depending on the size and scale of your installation. Which model you use determines how you should answer the prompts in the script on the server(s) to prepare them for IMC.

**If you are deploying IMC in...**
  * **Centralized with Local DB**, choose to install "both" (MySQL Client & Server) on the IMC Server. You should not configure a remote MySQL root account when prompted.
  * **Centralized with Remote DB**, choose to install "client" on the IMC Server, and "both" on the Remote DB Server. Make sure to configure a remote MySQL root account when prompted.
  * **Distributed with Remote DB**, choose to install "client" on the Master and Subordinate server(s), and "both" on the Remote DB Server(s). Make sure to configure a remote MySQL root account when prompted.

## Known Issues

1) If you edited the script on Windows, you may need to change the End of Line character from Windows CR LF to Linux LF. On Linux you can run this to fix it: sed -i -e 's/\r$//' ./ILMS.sh
2) The script does not validate its command output. If a command fails to execute on your system, the script may print a message about successfully executing it anyways. Currently no plans to change this, as adding output validation would significantly increase the amount of code and complexity required.

## New Features & Fixes

### v1.00 12.08.2020
* Database choices updated to MySQL 5.7 or 8.0
* Added check to ensure script is run as root
* Added check to ensure password does not contain chars unsupported by IMC
* Easily visible X error indicator added
* Timestamp added to backup of old /var/lib/mysql
* Slowed the script execution down slightly for readability
* Merged user input into a single function and optimized it
* Various other minor code optimizations

### v0.99 19.08.2019
* Final beta release
* Script will now exit if it detects no IP address was configured yet on the system
* Improved my_config function to check if a local my-ilms-5.x.txt exists, and use that instead of downloading from github
* Fixed MySQL service start running when installing the client only, and moved start & enable mysqld from db_install to main
* Optimized package install functions into a single package_installer function
* Added db_cleanup function to check for old MySQL leftovers and remove them
* Minor bugfixes

### v0.95 22.07.2019
* Third and pre-final beta release
* Fully tested & working on CentOS 7-1810 with MySQL 5.6/5.7
* Updated my.cnf files for 5.6 and 5.7
* Added function to prompt and create remote MySQL root user if requested
* Improved ip_prompt function and method to get configured IP
* Script optimization, cleanup, removed redundant echos etc.
* Fixed a few other minor issues

### v0.9 19.07.2019
* Second Beta release
* Added function to auto-fix known MySQL Timezone issue on IMC 7.3 E0703
* Fixed issue with MySQL Timezone function not updating /etc/my.cnf properly
* Fixed MySQL root user password change for IMC (as it uses mysql_native_password authentication)

### v0.8 17.07.2019
* Initial Beta release

## Upcoming Features (future version)

1) Silent version of the script

## FAQ
  **Q: What do I need to do after the script finishes successfully?**
  
  A: Download and extract IMC for Linux, then navigate to the extracted folder and under /linux/install, run "chmod -x install.sh" and then "./install.sh" to start the installer. Make sure you are running a graphical environment.
    
  **Q: What if something goes wrong, and I have to run the script again? Will it break anything?**
  
  **A:** It was designed to support reruns, so you should not have any issues doing so - but try not to forcefully exit the script in the middle of running 'yum' or otherwise. If you find any issues, please report them to me.
  
  **Q: What if I plan to use a different version/edition of MySQL?**
  
  **A:** If you select "no" when asked whether to setup MySQL, no MySQL-related packages will be installed. Make sure you follow the respective official HPE MySQL 5.x Installation Guide for IMC.

  **Q: Does the script need internet access?**
  
  **A:** Yum needs internet access, directly or via proxy, to install various package groups and MySQL repository, which is not included in the default repositories of CentOS/RHEL.

  **Q: Do you have an 'offline' version of the script (that does not use wget)?**
  
  **A:** The script can be run 'offline' automatically since v0.99 - it will check if the file my-ilms-$1.txt (where $1 is 5.7/8.0) exists in the current directory, and download from github with wget only if it cannot be found. 

  **Q: Can I run the script silently (without prompting)?**
  
  **A:** Yes, it is theoretically possible to use a second script something like 'expect' to automatically run ILMS and answer the prompts for you. I have not written such a script yet, but it is planned in the future.
   
  **Q: Why no script for Oracle DB?**
  
  **A:** Oracle DB installation for IMC is relatively complex, and do you really need Oracle DB when you've got MySQL?
 
   **Q: Why no MySQL 5.6 option?**
  
  **A:** It was removed to encourage using newer 5.7/8.0 versions. I might add it back in the future...
 
  **Q: Why no MySQL 5.5 option?**
  
  **A:** It's outdated and no longer supported for IMC.
  
  **Q: What about MySQL Commercial (Standard/Enterprise)?**
  
  **A:** The paid variants of MySQL must be purchased, downloaded and installed manually, the script cannot do this for you.
  
  **Q: Why not simply create a fully prepared, packaged Appliance that can be imported on VMware ESX/Hyper-V?**
  
  **A:** Several reasons. First, it would be a very large file to host and download. Second, it would not give you the flexibility to choose installation options like the tool does. Third, IMC Engineering should provide and maintain such an image, which they do not.
  
  **Q: IMC Installer shows an error related to Timezone. What should I do?**
  
  **A:** This is due to a known issue with MySQL JDBC Driver for IMC. The script since v0.9x fixes this automatically for you, but in case you need it, here are the instructions to fix it manually. Please set the default timezone in the /etc/my.cnf by setting your server's time offset from UTC, following are some examples:
  
default-time-zone = ‘-06:00’

OR

default-time-zone = ‘+02:00’

See also:

https://stackoverflow.com/questions/930900/how-do-i-set-the-time-zone-of-mysql

https://www.interserver.net/tips/kb/change-mysql-server-time-zone/
