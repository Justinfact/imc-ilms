# IMC Linux MySQL Setup (ILMS) v0.9 (BETA)
Shell script that prepares your Red Hat Enterprise Linux 7.x system for installing HPE IMC 7.3 E0703+. It can perform all necessary prerequisite setup tasks, so all you need to do is download and install IMC.

## Overview
The purpose of this script is to provide an easy way to prepare a RHEL server for IMC installation. It should be executed on the server, will prompt you for some input, and perform all necessary setup tasks for either type of IMC deployment (Centralized/Distributed). It can install and setup MySQL 5.6/5.7 Community for you as well.

The script can save you a lot of time spent on a rather lengthy preparation process, and intends to be user-friendly, re-runable, verbose and relatively foolproof. It should be usable even for those inexperienced or unfamiliar with the setup process.

It is free, open source, and comes with absolutely NO warranty.

## Server Prerequisites
  * Supported RHEL or CentOS (unsupported but works) installed on your server.
  * Hardware properly adjusted for the size of the IMC installation.
  * Static IP address must already be configured.
  * Run the script as root (commands are not run with sudo)
  * The server must have internet access.
  * RHEL Server must have an active subscription (for yum/rpm).
  
## Usage
  * Run this tool once per server to be configured for IMC.
  1) Login as root on CLI and copy the script to /root
  2) Make the script executable: chmod +x ./ILMS.sh
  3) Run the script with ./ILMS.sh
  4) Answer all prompts as requested and wait for the script to complete
  5) Reboot as prompted, and then download & install IMC

## Known Issues

1) If you edited the script on Windows, you may need to change the End of Line character from Windows CR LF to Linux LF. On Linux you can run this to fix it: sed -i -e 's/\r$//' ./ILMS.sh
2) The script does not validate command output. If a command fails to execute on your system, it will print a message about success anyways. Currently no plans to change this, as adding output validation would significantly increase the amount of code required.
3) The script validates the IP address entered, but does not verify if it is configured. This may result in an incorrect IP address to Hostname entry in /etc/hosts if you make a typo or otherwise enter the wrong IP. This will be fixed in a future release.
4) The script checks if the MySQL root password you enter meets the MySQL default password policy requirements, but does not check for the special characters which are not supported by IMC. Please check the IMC MySQL Installation Guide for details. I would recommend using underscore _ or plus + sign in the password, which definitely work. This will be fixed in a future release.

## New Features & Fixes

### v0.9 19.07.2019
* Second Beta release
* Added function to auto-fix known MySQL Timezone issue on IMC 7.3 E0703
* Fixed issue with MySQL Timezone function not updating /etc/my.cnf properly
* Fixed MySQL root user password change for IMC (as it uses mysql_native_password authentication)

### v0.8 17.07.2019
* Initial Beta release

## Upcoming Features (future version)

1) MySQL Commercial (Enterprise) setup automation
2) MySQL 8.0 installation and setup automation
3) Improved input validation for IP address and MySQL root password

## FAQ
  **Q: What do I need to do after the script finishes successfully?**
  
  A: Download and extract IMC for Linux, then navigate to the extracted folder and under /linux/install, run "chmod -x install.sh" and then "./install.sh" to start the installater. Make sure you are running a graphical environment.
  
  **Q: What if I plan to use a different version/edition of MySQL?**
  
  A: If you select "no" when asked whether to setup MySQL, no MySQL-related packages will be installed. Make sure you follow the respective official HPE MySQL 5.x Installation Guide for IMC.
  
  **Q: IMC Installer shows an error related to Timezone. What should I do?**
  
  A: This is due to a known issue with MySQL JDBC Driver for IMC. The script since v0.9 fixes this automatically for you, but here are the instructions to fix it manually. Please set the default timezone in the /etc/my.cnf by setting your server's time offset from UTC, following are some examples:
  
default-time-zone = ‘-06:00’

OR

default-time-zone = ‘+02:00’

See also:

https://stackoverflow.com/questions/930900/how-do-i-set-the-time-zone-of-mysql

https://www.interserver.net/tips/kb/change-mysql-server-time-zone/

  **Q: Why no script for Oracle DB?**
  
  A: Oracle DB installation for IMC is relatively complex, and do you really need Oracle DB when you've got MySQL?
 
  **Q: Why no MySQL 5.5 option?**
  
  A: Because it's outdated and no longer supported for IMC.
  
  **Q: Why not simply create a fully prepared, packaged Appliance that can be imported on VMware ESX/Hyper-V?**
  
  A: Several reasons. First, it would be a very large file to host and download. Second, it would not give you the flexibility to choose installation options like the tool does. Third, IMC Engineering should provide and maintain such an image, which they do not.
  
  **Q: What if something goes wrong, and I have to run the script again? Will it break anything?**
  
  A: It was designed to support reruns, so you should not have any issues doing so. If you find any issues, please report them to me.
