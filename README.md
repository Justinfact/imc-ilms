# IMC Linux MySQL Setup (ILMS) v0.8 (BETA)
Shell script that prepares your Red Hat Enterprise Linux 7.x system for installing HPE IMC 7.3 E0703+. It can perform all necessary prerequisite setup tasks, so all you need to do is download and install IMC.

## Overview
The purpose of this tool is to provide an easy way to prepare a RHEL server for IMC installation. It should be executed on the server, will prompt you for some input, and perform all necessary setup tasks for either type of IMC deployment (Centralized/Distributed). It can install and setup MySQL 5.6/5.7 Community for you as well.

The tool can save you a lot of time spent on a rather lengthy preparation process, and intends to be user-friendly, re-runable, verbose and relatively foolproof. It should be usable even for those inexperienced or unfamiliar with the setup process.

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

NOTE: If you edited the script on Windows, you may need to change the End of Line character from Windows CR LF to Linux LF. On Linux you can run this to fix it: sed -i -e 's/\r$//' ./ILMS.sh

## FAQ
  **Q: What do I need to do after the script finishes successfully?**
  
  A: Download and extract IMC for Linux, then "chmod -R 777 /path/to/extracted/linux/folder" and run "./linux/install/install.sh" to start the installation. Make sure you are running the desktop environment.
  
  **Q: Why no script for Oracle DB?**
  
  A: Oracle DB installation for IMC is relatively complex, and do you really need Oracle DB when you've got MySQL?
 
  **Q: Why no MySQL 5.5 option?**
  
  A: Because it's outdated and no longer supported for IMC.
  
  **Q: Why not simply create a fully prepared, packaged Appliance that can be imported on VMware ESX/Hyper-V?**
  
  A: Several reasons. First, it would be a very large file to host and download. Second, it would not give you the flexibility to choose installation options like the tool does. Third, IMC Engineering should provide and maintain such an image, which they do not.
  
  **Q: What if something goes wrong, and I have to run the script again? Will it break anything?**
  
  A: It was designed to support reruns, so you should not have any issues doing so.
  
  **Q: What if I plan to use a different version/edition of MySQL?**
  
  A: If you select "no" when asked whether to setup MySQL, no MySQL-related packages will be installed. Make sure you follow the respective official HPE MySQL 5.x Installation Guide for IMC.
