#!/bin/bash
# IMC Linux MySQL Setup script authored by Justin Guse (HPE Employee)
# This script automates the entire setup process to prepare the server for installation of HPE IMC on RHEL.
# All functionality is contained in separate functions that are called by main in the required sequence.

echo ">>> Begin executing ILMS.sh v0.99 (BETA) 19.08.2019 <<<"

function welcome() {
    # Welcome messages, prompt to get started or exit

    echo "*** Welcome to the HPE IMC Linux MySQL Setup Script! ***
*** This script automatically prepares your RHEL 7.x Server for IMC deployment.
*** It is unofficial, free, open source, and developed during free time after work.
*** While it has been tested and should work, it comes with absolutely NO warranty.
*** For feedback and feature requests, please contact 'jguse' on the HPE Forums.
!!! *** REQUIREMENTS *** !!!
* Static IP address must already be configured.
* RHEL must have an active subscription (for yum).
* YUM must be able to access the internet (directly or proxy).
* This script accomplishes all setup tasks to prepare the server for IMC...
* ...except for downloading and installing IMC.
!!! Please confirm you have understood the above, and the server meets the prerequisites."

    read -p ">>> Are you ready to get started? (yes/no) " prompt
    until [ "$prompt" == "yes" ] || [ "$prompt" == "no" ]; do
        echo "!!! Invalid input! Enter 'yes' or 'no' to continue."
        read -p ">>> Are you ready to get started? (yes/no) " prompt
    done

    if [ "$prompt" == "no" ]; then
        echo "!!! Script execution cancelled!"
        exit 0
    else
        echo "*** Beginning script execution..."
    fi
}

function check_os() {
    # Check if the OS is RedHat/CentOS and check for 64-bit OS, exit otherwise.

    local bits=$( uname -m )
    if [ "$bits" == "x86_64" ]; then
        echo "*** You are running on a 64-bit ($bits) OS which is compatible with IMC."
    else
        echo "*** You are running a 32-bit ($bits) OS which is NOT recommend for IMC.
*** This script will now exit. Please re-run on a 64-bit OS!"
        exit 0
    fi

    if [ -f /etc/os-release ]; then
        local rhel=$( grep A_PRODUCT= /etc/os-release | cut -d'=' -f2 | sed s/'"'//g )
        local centos=$( grep RT_PRODUCT= /etc/os-release | cut -d'=' -f2 | sed s/'"'//g )
        local centver=$( grep PRODUCT_VERSION= /etc/os-release | cut -d'=' -f2 | sed s/'"'//g )

        if [ "$rhel" == "Red Hat Enterprise Linux 7" ]; then
            echo "*** You are running on $rhel which is compatible with IMC 7.3 E0703 onwards."
        elif [ "$centos" == "centos" ] && [ "$centver" == "7" ]; then
            echo "!!! You are running on $centos $centver which is not supported for IMC.
!!! HPE does not officially support running CentOS instead of RHEL for IMC.
*** This script can continue, and IMC may be installed, but it is NOT for production use.
*** CentOS is recommended for test/non-production systems only."

            read -p ">>> Please enter 'yes' if you would like to continue anyway. (yes/no) " prompt
            until [ "$prompt" == "yes" ] || [ "$prompt" == "no" ]; do
                echo "!!! Invalid input! Enter 'yes' or 'no' continue."
                read -p ">>> Please enter 'yes' if you would like to continue anyway. (yes/no) " prompt
            done

            if [ "$prompt" == "no" ]; then
                exit 0
            else
                echo "*** Thanks for confirming. Script execution resuming..."
            fi
        else
            echo "*** $rhel $centos $centver is NOT supported for IMC.
*** Only RHEL 7.x distributions are supported by IMC 7.3 E0703.
*** This script will now exit. Please re-run on a supported OS."
            exit 0
        fi
    else
        echo "*** /etc/os-release not found. Likely due to unsupported OS.
*** Only RHEL 7.x distributions are supported by IMC 7.3 E0703.
*** If you think this is a bug, please report it to user 'jguse' on HPE Forums.
*** This script will now exit. Please re-run on a supported OS."
        exit 0
    fi
}

function db_choices() {
    # Prompt for database choices, set dbconfig to "none" if no DB should be installed

    echo "*** You will need to install a database for IMC.
* Only certain editions of MySQL and Oracle are officially supported with IMC on RHEL. Please check IMC Release Notes for details.
* Only MySQL Enterprise edition is officially supported for IMC, with up to 1000 managed devices per installation.
* This script can only install the free MySQL Community Edition, if you wish. It generally works but will not be officially supported.
* If you choose to install the DB yourself, make sure to enter 'no' below, and follow the steps in the IMC MySQL/Oracle Installation Guide."

    read -p ">>> Should this script install and prepare MySQL for you? (yes/no) " prompt
    until [ "$prompt" == "yes" ] || [ "$prompt" == "no" ]; do
        echo "!!! Invalid input! Enter 'yes' or 'no' continue."
        read -p ">>> Should this script install and prepare MySQL for you? (yes/no) " prompt
    done

    if [ "$prompt" == "yes" ]; then
        echo "*** This script can install and setup MySQL 5.6/5.7 Community with Client & Server for IMC...
*** If you are deploying IMC with Local DB:
--> You need to install 'both' the Client and Server on the IMC system.
*** If you are deploying IMC with Remote DB:
--> You should install only the 'client' on the IMC system, and 'both' on DB server."

        read -p ">>> Install both MySQL Client & Server, or Client only? (client/both) " dbconfig
        until [ "$dbconfig" == "client" ] || [ "$dbconfig" == "both" ]; do
            echo "!!! Invalid input! Enter client or both to continue."
            read -p ">>> Install the MySQL Server & Client, or Client only? (client/both) " dbconfig
        done
        echo "*** $dbconfig selected for installation."

        read -p ">>> Which MySQL Version would you like to setup? (5.6/5.7) " myconfig
        until [ "$myconfig" == "5.6" ] || [ "$myconfig" == "5.7" ]; do
            echo "!!! Invalid input! Enter 5.6 or 5.7 to continue."
            read -p ">>> Which MySQL Version would you like to setup? (5.6/5.7) " myconfig
        done
        echo "*** MySQL $myconfig Community selected for install."
    else
        echo "*** MySQL will NOT be installed."
        dbconfig="none"
    fi
}

function db_cleanup() {
    # Remove any MySQL and leftovers from previous MySQL installations if necessary.

    echo "*** Checking if mysqld service is running."
    service=$( systemctl is-active --quiet mysqld )
    if [ $service ]; then
        echo "*** mysqld service running, stopping it now."
        systemctl stop mysqld
    else
        echo "*** mysqld service is not running."
    fi

    FILE="/usr/lib/systemd/system/mysqld.service"
    if [ -f $FILE ]; then
        echo "*** Removing existing MySQL installation."
        yum remove mysql mysql-server -y
    else
        echo "*** MySQL is not installed."
    fi

    local time=$( date "+%Y.%m.%d-%H.%M.%S" )
    DIR="/var/lib/mysql/"
    if [ -d "$DIR" ]; then
        echo "*** Existing MySQL in /var/lib/mysql found, moving it to random /var/lib/mysql-backup-#"
        mv -f /var/lib/mysql/ /var/lib/mysql-backup-$time
    else
        echo "*** No leftovers from MySQL found."
    fi

    FILE="/var/log/mysqld.log"
    if [ -f "$FILE" ]; then
        echo "*** Existing MySQL Log found at /var/log/mysqld.log, moving it to random /var/log/mysqld-backup-#"
        mv -f /var/log/mysqld.log /var/lib/mysqld-backup-${time}.log
    else
        echo "*** No MySQL Log found."
    fi

    echo "*** Finished cleaning up existing MySQL installation."
}

function db_install() {
    # Add MySQL repository, download & install MySQL 5.6/5.7 Community Client and/or Server.

    yum localinstall https://dev.mysql.com/get/mysql57-community-release-el7-9.noarch.rpm -y
    echo "*** MySQL Community Repository installed."

    if [ "$2" == 5.6 ]; then
        yum-config-manager --disable mysql57-community
        echo "*** MySQL 5.7 release repository disabled."
        yum-config-manager --enable mysql56-community
        echo "*** MySQL 5.6 release repository enabled."
    fi

    echo "*** Installing MySQL $2 Client, please wait..."
    yum install mysql-community-client.x86_64 -y

    if [ "$1" == "both" ]; then
        echo "*** Installing MySQL $2 Server, please wait..."
        yum install mysql-community-server.x86_64 -y
    fi

    echo "*** Running yum update, please wait..."
    yum update -y
}

function disable_security() {
    # Disable SELinux and Firewall

    sed -i --follow-symlinks 's/^SELINUX=.*/SELINUX=disabled/g' /etc/sysconfig/selinux && cat /etc/sysconfig/selinux
    echo "*** SELINUX has been disabled."

    systemctl stop firewalld.service
    systemctl disable firewalld.service
    echo "*** Firewall stopped and disabled."
}

function hosts_config() {
    # Gets the IP address , checks if it is found in /etc/hosts, adds it otherwise with the hostname for IMC

    local ip=$1
    local hostsip=$( grep $ip /etc/hosts )

    if [ -z "$hostsip" ]; then
        echo -e "$ip \t $HOSTNAME" >> /etc/hosts
        echo "*** /etc/hosts updated for IMC."
        cat /etc/hosts
    else
        echo "*** /etc/hosts already configured."
    fi
}

function ip_prompt() {
    # Check if IP was found and double-check it with the user before proceeding, exit otherwise

    local ip=$1

    if [ -z "$ip" ]; then
        echo "!!! No IP address found for $HOSTNAME with command 'hostname --all-ip-addresses'
!!! Please configure an IP address on this server before running ILMS again.
!!! The script will now exit."
        exit 0
    else
        echo "*** Found IP address $ip configured for this system."

        read -p ">>> Is $ip the server's IPv4 address to be used for IMC? (yes/no) " prompt
        until [ "$prompt" == "yes" ] || [ "$prompt" == "no" ]; do
            echo "!!! Invalid input! Enter 'yes' or 'no' to continue."
            read -p ">>> Is $ip the server's IPv4 address to be used for IMC? (yes/no) " prompt
        done

        if [ "$prompt" == "yes" ]; then
            echo "*** Using $ip for IMC."
            ipaddr="$ip"
        else
            read -p ">>> Enter this server's IPv4 address for IMC (eg. 10.10.10.200): " ipprompt
            until valid_ip $ipprompt; do
                echo "!!! Invalid IP address! Enter an IPv4 address like '192.168.1.100' or '10.10.10.200'..."
                read -p ">>> Enter this server's  IPv4 address for IMC: " ipprompt
            done
            echo "*** Valid IPv4 address $ipprompt entered. Proceeding with script..."
            ipaddr="$ipprompt"
        fi
    fi
}

function my_config() {
    # Gets the MySQL version backs up and replaces /etc/my.cnf with the correct file for the MySQL Server

    echo "*** Creating backup of /etc/my.cnf as /etc/my.cnf.bak"
    mv -f /etc/my.cnf /etc/my.cnf.bak

    FILE=./my-ilms-$1.txt
    if [ -f "$FILE" ]; then
        echo "*** Copying local my-ilms-$1 to /etc/my.cnf"
        \cp ./my-ilms-$1.txt /etc/my.cnf
    else
        echo "*** Downloading custom $1 my.cnf file for IMC from github..."
        wget -O /etc/my.cnf "https://raw.githubusercontent.com/Justinfact/imc-ilms/master/my-ilms-$1.txt"
    fi

    echo "*** Installed custom /etc/my.cnf file for IMC:"
    cat /etc/my.cnf
}

function my_limits() {
    # Fixes the memory and open file limits in mysqld.service for IMC

    limit=$( grep LimitNO /usr/lib/systemd/system/mysqld.service )
    if [ -z "$limit" ]; then
        echo "LimitNOFILE=infinity" >> /usr/lib/systemd/system/mysqld.service
        echo "*** Updated mysqld.service open file limit to infinity."
    else
        sed -i 's/^LimitNOFILE.*/LimitNOFILE=infinity/g' /usr/lib/systemd/system/mysqld.service
        echo "*** Updated mysqld.service open file limit to infinity."
    fi

    limit=$( grep LimitMEM /usr/lib/systemd/system/mysqld.service )
    if [ -z "$limit" ]; then
        echo "LimitMEMLOCK=infinity" >> /usr/lib/systemd/system/mysqld.service
        echo "*** Updated mysqld.service memory limit to infinity."
    else
        sed -i 's/^LimitMEM.*/LimitMEMLOCK=infinity/g' /usr/lib/systemd/system/mysqld.service
        echo "*** Updated mysqld.service memory limit to infinity."
    fi
    systemctl daemon-reload
}

function my_remote_login() {
    # Prompts whether to configure a MySQL 'root'@'%' user for remote login, used for remote DB installations, and grants the user full privileges

    local myconf=$1

    echo "*** If this system will be used as a Remote DB server for IMC, please answer 'yes' below.
*** Otherwise you should answer 'no' below to prevent remote root login to IMC."

    read -p ">>> Configure account 'root'@'%' for remote MySQL root login? (yes/no) " prompt
    until [ "$prompt" == "yes" ] || [ "$prompt" == "no" ]; do
        echo "!!! Invalid input! Enter 'yes' or 'no' to continue."
        read -p ">>> Configure account 'root'@'%' for remote MySQL root login? (yes/no) " prompt
    done

    if [ "$prompt" == "yes" ]; then
        if [ "$myconf" == 5.6 ]; then
            mysql -u root -Be "CREATE USER 'root'@'%' IDENTIFIED BY '${rootpass}';\
            GRANT ALL ON *.* TO 'root'@'%' WITH GRANT OPTION;FLUSH PRIVILEGES;"
        elif [ "$myconf" == 5.7 ]; then
            mysql -u root -Be "CREATE USER 'root'@'%' IDENTIFIED WITH 'mysql_native_password' BY '${rootpass}';\
            GRANT ALL ON *.* TO 'root'@'%' WITH GRANT OPTION;FLUSH PRIVILEGES;"
        fi
        echo "*** Created 'root'@'%' user for remote MySQL login with the password you entered and granted full privileges."
    else
        echo "*** Remote MySQL root login will NOT be configured."
    fi
}

function my_rootpass() {
    # Check for temporary MySQL root password and print it, prompt to change root password and store it for my_secure_install

    if [ "$1" == "both" ]; then
        temppass=$( grep 'A temporary password' /var/log/mysqld.log | awk '{print $11}' )
        if [ -z "$temppass" ]; then
            echo "*** No temporary MySQL password found."
        else
            echo "*** MySQL 5.7 configured a temporary root password, it is $temppass and should be changed."
        fi

        echo "*** You will now be prompted to set a new MySQL root user password.
*** Make sure you remember it, you will enter it during IMC installation."
    else
        echo "*** You will now be prompted to enter the MySQL root user password.
*** This script will add it to a temporary ~/.my.cnf for you to simplify MySQL CLI login.
*** Make sure you remember it, you will enter it during IMC installation."
    fi

    rootpass=""
    confpass="123"

    until [ "$rootpass" == "$confpass" ] && valid_pass $rootpass; do
        read -p ">>> Please enter the password you would like to use for MySQL 'root' user: " rootpass
        read -p ">>> Please confirm the password: " confpass

        if [ "$rootpass" != "$confpass" ]; then
            echo "*** Passwords do not match. Please try again."
        elif ! (valid_pass $rootpass); then
            echo "*** Password does not meet MySQL complexity requirements."
        fi
    done
    echo "*** Password matches and meets MySQL complexity requirements."
}

function my_secure_install() {
    # Gets the rootpass, temppass (5.7 only) and myconf (mysql version), and runs mysql_secure_installation equivalent commands depending on MySQL version

    local rootpw="$rootpass"
    local temppw="$temppass"
    local myconf="$1"

    FILE=~/.my.cnf
    if [ -f "$FILE" ]; then
        echo "*** ~/.my.cnf found, removing it."
        rm -f ~/.my.cnf
    fi

    if [ "$myconf" == 5.6 ]; then
        mysqladmin password "${rootpw}"
        echo "*** Configured MySQL root user with the password you entered."

        echo -e "[client]\nuser = root\npassword = ${rootpw}" >> ~/.my.cnf
        echo "*** Added user root with password $rootpw to ~/.my.cnf for simple MySQL client login."

        mysql -u root -Be "DELETE FROM mysql.user WHERE User='';DROP DATABASE IF EXISTS test;DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';FLUSH PRIVILEGES;"
        echo "*** Configured equivalent of mysql_secure_installation."

    elif [ "$myconf" == 5.7 ]; then
        mysqladmin -u root --password="${temppw}" password "${rootpw}"
        echo "*** Configured MySQL root user with the password you entered."

        echo -e "[client]\nuser = root\npassword = ${rootpw}" >> ~/.my.cnf
        echo "*** Added user root with password $rootpw to ~/.my.cnf for simple MySQL client login."

        mysql -u root -Be "GRANT ALL ON *.* TO 'root'@'localhost' WITH GRANT OPTION;FLUSH PRIVILEGES;"
        echo "*** Granted full privileges to root@localhost."

        mysql -u root -Be "DROP DATABASE IF EXISTS test;DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';FLUSH PRIVILEGES;"
        echo "*** Configured equivalent of mysql_secure_installation for IMC."
    fi
}

function my_timezone() {
    # Fixes the known MySQL JDBC issue with Timezone that prevents IMC installation/upgrade by inserting the offset into /etc/my.cnf after default-storage-engine

    local tz=$( date +"%z" )
    local offset=$( echo "$tz" | sed 's/.../&:/g;s/:$//' )
    local config="default-time-zone = '${offset}'"

    echo "*** System indicates the UTC Offset is ${offset}.
*** Adding $config to /etc/my.cnf to fix the known timezone issue."
    sed -i "/^default-storage-engine.*/a ${config}" /etc/my.cnf
}

function package_installer() {
    # Download & install required package groups and libraries for IMC

    for group in "Server with GUI" "Development Tools" "Compatibility Libraries"; do
        installed=$( yum grouplist installed | grep "$group" )
        if [ -z "$installed" ]; then
            echo "*** Installing $group, please wait..."
            yum groupinstall "$group" -y
        else
            echo "*** $group already installed."
        fi
    done

    yum install glibc.i686 libgcc.i686 libaio.i686 libstdc++.i686 nss-softokn-freebl.i686 -y
    echo "*** 32-bit libraries required by IMC installed."

    echo "*** To run the HPE Deployment Monitoring Agent and install IMC, you should use a desktop environment."
    read -p ">>> Install GNOME, KDE or none? (GNOME/KDE/none) " prompt
    until [ "$prompt" == "GNOME" ] || [ "$prompt" == "KDE" ] || [ "$prompt" == "none" ]; do
        echo "!!! Invalid input! Enter 'GNOME', 'KDE' or 'none'."
        read -p ">>> Install GNOME, KDE or none? (GNOME/KDE/none) " prompt
    done

    if [ "$prompt" == "GNOME" ]; then
        echo "*** Installing GNOME Desktop, please wait..."
        yum groupinstall "GNOME Desktop" -y

        echo "*** Setting systemctl set-default graphical.target"
        systemctl set-default graphical.target

    elif [ "$prompt" == "KDE" ]; then
        echo "*** Installing KDE Plasma Workspaces, please wait..."
        yum groupinstall "KDE Plasma Workspaces" -y

        echo "*** Setting systemctl set-default graphical.target"
        systemctl set-default graphical.target
    else
        echo "*** Desktop environment will NOT be installed."
    fi

    echo "*** Updated all packages..."
    yum update -y
}

function valid_ip() {
    # Validate the IP address and return true if it is valid.

    local ip=$1
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        OIFS=$IFS
        IFS='.'
        ip=($ip)
        IFS=$OIFS
        [[ ${ip[0]} -le 254 && ${ip[1]} -le 254 \
            && ${ip[2]} -le 254 && ${ip[3]} -le 254 ]]
        stat=$?
    fi
    return $stat
}

function valid_pass() {
    # Validates that the MySQL Root password entered meets complexity requirements, return true if it does.

    if [[ ${#1} -ge 8 && "$1" == *[A-Z]* && "$1" == *[a-z]* && "$1" == *[0-9]* ]]; then
        return 0
    else
        return 1
    fi
}

function goodbye() {
    # Sends goodbye messages into ILMS-README.txt, option to reboot now or later.

    rm -f ./ILMS-README.txt
    touch ./ILMS-README.txt
    echo -e "*** CONGRATULATIONS! The script has completed preparing this server for IMC.
*** REMAINING TASKS (for you, after the reboot):" >> ILMS-README.txt

    if [ "$dbconfig" == "none" ]; then
        echo -e "!!! You chose to skip having the DB installed for you!
-> Remove pre-installed MySQL/MariaDB manually if necessary.
-> Follow the IMC Linux Deployment Guide & DB Installation Guide to setup your DB correctly.
-> For example, here is the IMC Linux MySQL 5.7 DB Installation Guide:
-> https://support.hpe.com/hpsc/doc/public/display?docLocale=en_US&docId=emr_na-a00075555en_us&withFrame" >> ILMS-README.txt
    else
        echo -e "!!! This script created a hidden file ~/.my.cnf which contains the MySQL root password in plaintext.
-> This file is read by MySQL and allows you to simply enter 'mysql -u root' to login to the MySQL CLI without password.
-> You can check this file to verify the MySQL root password that was configured based on your input.
-> This file should be removed manually with 'rm -f ~/.my.cnf' if you consider this a security risk." >> ILMS-README.txt
    fi

    echo -e "--> HPE IMC DOWNLOADS: (free 60-day trial auto-activated upon installation)
Standard - https://h10145.www1.hpe.com/downloads/SoftwareReleases.aspx?ProductNumber=JG747AAE
Enterprise - https://h10145.www1.hpe.com/downloads/SoftwareReleases.aspx?ProductNumber=JG748AAE
--> INSTALLATION STEPS:
    1. Extract the downloaded archive with unzip 'filename.zip'
    2. Make it executable with chmod +x <extracted-dir>/linux/install/install.sh
    3. Execute the installer with ./install.sh and follow the prompts to install IMC.
-> This information has been saved to ./ILMS-README.txt for future reference.
-> Thank you for using ILMS! Please provide any feedback about the script to user 'jguse' on the HPE Forums." >> ILMS-README.txt
    cat ./ILMS-README.txt

    echo "!!! Please reboot the server, and then you're good to go!"
    read -p "Would you like to reboot now? (yes/no) " prompt
    until [ "$prompt" == "yes" ] || [ "$prompt" == "no" ]; do
        echo "!!! Invalid input! Enter 'yes' or 'no' continue."
        read -p ">>> Would you like to reboot now (no if you will to do so later)? (yes/no) " prompt
    done

    if [ "$prompt" == "no" ]; then
        echo "!!! Script exiting, please remember to restart the server."
        exit 0
    else
        shutdown -r now
    fi
}

function main {
    # Main calls all other functions in the required order

    dbconfig=""
    myconfig=""
    ipaddr=$( hostname --all-ip-addresses )

    welcome
    check_os

    ip_prompt $ipaddr
    hosts_config $ipaddr

    db_choices
    package_installer
    disable_security

    if [ "$dbconfig" != "none" ]; then
        if [ "$dbconfig" == "both" ]; then
            db_cleanup
            db_install $dbconfig $myconfig
            echo "*** Beginning MySQL $myconfig Server setup..."
            systemctl start mysqld
            systemctl enable mysqld
            echo "*** mysqld service started and enabled."
            my_rootpass $dbconfig
            my_secure_install $myconfig
            my_remote_login $myconfig
            my_config $myconfig
            my_timezone
            my_limits
            systemctl restart mysqld
            echo "*** mysqld service restarted."
        else
            db_install $dbconfig $myconfig
        fi
        echo "*** MySQL $myconfig installed & configured."
    fi

    goodbye
}

main