#!/bin/bash
# IMC Linux MySQL Setup unofficial script authored by Justin Guse (HPE Employee)
# This script automates the entire setup process to prepare the server for installation of HPE IMC on RHEL.

# Color palette and error marker
red='\033[0;31m'
nc='\033[0m' # No Color
err=$( echo -e "[${red} X ${nc}]" ) # This is an error

function welcome() {
    # Welcome messages, helpful information.

    clear
    echo "*** Welcome to the HPE IMC Linux MySQL Setup Script! ***"
    echo "*** This script automatically prepares a RHEL 7.x Server for IMC deployment."
    echo "*** It is unofficial and free, developed during spare time."
    echo "*** While it has been tested, it comes with absolutely NO warranty."; sleep 3
    echo "!!! *** REQUIREMENTS *** !!!"
    echo "* Static IP address must already be configured."
    echo "* RHEL must have an active subscription (for yum)."
    echo "* YUM must be able to access the internet (directly or proxy)."
    echo "* This script accomplishes all setup tasks to prepare the server for IMC..."
    echo "* ...except for downloading and installing IMC."; sleep 5
}

function init_checks() {
    # Initial checks to ensure script is run as root, OS is RedHat/CentOS and 64-bit, exit otherwise

    local isroot=$( whoami 2>/dev/null )
    if [[ "$isroot" = "root" ]]; then
        echo "*** Script is run properly as root."; sleep 1
    else
        echo "${err} Script is not running as root. Please run it as root."
        exit 1
    fi

    if ( uname -m | grep -qs x86_64 ); then
        echo "*** OS is 64-bit which is recommended for IMC."; sleep 1
    else
        echo "${err} OS is 32-bit which is NOT recommend."
        echo "*** Please use a 64-bit OS for IMC!"
        exit 1
    fi

    if ( uname -r | grep -qs el7 ) && [[ -e /etc/centos-release || -e /etc/redhat-release ]]; then
        echo "*** Compatible RHEL/CentOS 7.x for IMC detected."; sleep 1
    else
        echo "${err} Incompatible OS or release for IMC detected."
        echo "*** Only RHEL 7.x distributions are supported. Please use a supported OS."
        exit 1
    fi

    ipaddr=$( hostname --all-ip-addresses | cut -d' ' -f1 )
    if [[ -z "$ipaddr" ]]; then
        echo "${err} No IP found for $HOSTNAME with 'hostname --all-ip-addresses'"
        echo "*** Please ensure a static IP has been configured on the system."
        exit 1
    fi
}

function db_cleanup() {
    # Remove any MySQL and leftovers from previous MySQL installations if necessary.

    echo "*** Checking if mysqld service is running."; sleep 1
    if ( systemctl is-active --quiet mysqld ); then
        echo "*** mysqld service running, stopping it now."; sleep 1
        systemctl stop mysqld
    else
        echo "*** mysqld service is not running."; sleep 1
    fi

    FILE="/usr/lib/systemd/system/mysqld.service"
    if [[ -f $FILE ]]; then
        echo "*** Removing existing MySQL installation."; sleep 1
        yum remove mysql mysql-server -y
    else
        echo "*** MySQL is not installed."; sleep 1
    fi

    local time=$( date "+%Y.%m.%d-%H.%M.%S" 2>/dev/null )
    DIR="/var/lib/mysql/"
    if [[ -d "$DIR" ]]; then
        echo "*** Existing MySQL in /var/lib/mysql found, moving it to /var/lib/mysql-backup-${time}"; sleep 1
        mv -f /var/lib/mysql/ /var/lib/mysql-backup-$time
    else
        echo "*** No leftovers from MySQL found."; sleep 1
    fi

    FILE="/root/.my.cnf"
    if [[ -f "$FILE" ]]; then
        echo "*** /root/.my.cnf found, removing it."; sleep 1
        rm -f /root/.my.cnf
    fi

    echo "*** Finished cleaning up existing MySQL installation."; sleep 1
}

function db_install() {
    # Add MySQL repository, download & install MySQL 5.6/5.7 Community Client and/or Server.

    yum localinstall https://dev.mysql.com/get/mysql80-community-release-el7-3.noarch.rpm -y
    echo "*** MySQL Community Repository installed."; sleep 1

    if [[ "$myconfig" = "5.7" ]]; then
        yum-config-manager --disable mysql80-community
        echo "*** MySQL 8.0 release repository disabled."; sleep 1
        yum-config-manager --enable mysql57-community
        echo "*** MySQL 5.7 release repository enabled."; sleep 1
    fi

    echo "*** Installing MySQL $myconfig Client, please wait..."; sleep 1
    yum install mysql -y

    if [[ "$dbconfig" = "both" ]]; then
        echo "*** Installing MySQL $myconfig Server, please wait..."; sleep 1
        yum install mysql-server -y
    fi
}

function disable_security() {
    # Disable SELinux and Firewall

    sed -i --follow-symlinks 's/^SELINUX=.*/SELINUX=disabled/g' /etc/sysconfig/selinux
    echo "*** SELinux has been disabled."; sleep 1

    systemctl stop firewalld.service
    systemctl disable firewalld.service
    echo "*** Firewall stopped and disabled."; sleep 1
}

function hosts_config() {
    # Checks if IP is found in /etc/hosts, adds it otherwise with the hostname

    if ! ( grep -qs "$ipaddr" /etc/hosts ); then
        echo -e "$ipaddr \t $HOSTNAME" >> /etc/hosts
        echo "*** /etc/hosts updated for IMC."; sleep 1
    else
        echo "*** /etc/hosts already configured."; sleep 1
    fi
}

function my_config() {
    # Replaces /etc/my.cnf with the correct file for IMC on MySQL

    FILE="/etc/my.cnf"
    if [[ -f "$FILE" ]]; then
        echo "*** Creating backup of /etc/my.cnf as /etc/my.cnf.bak"; sleep 1
        mv -f /etc/my.cnf /etc/my.cnf.bak
    fi

    FILE=./my-ilms-${myconfig}.txt
    if [[ -f "$FILE" ]]; then
        echo "*** Copying local my-ilms-${myconfig} to /etc/my.cnf"; sleep 1
        \cp ./my-ilms-${myconfig}.txt /etc/my.cnf
    else
        echo "*** Downloading custom ${myconfig} my.cnf file for IMC from GitHub..."; sleep 1
        wget -O /etc/my.cnf "https://raw.githubusercontent.com/Justinfact/imc-ilms/master/my-ilms-${myconfig}.txt"
    fi

    echo "*** Installed custom /etc/my.cnf file for IMC."
}

function my_limits() {
    # Adjusts the memory and open file limits in mysqld.service for IMC

    if ! ( grep -qs LimitNO /usr/lib/systemd/system/mysqld.service ); then
        echo "LimitNOFILE=infinity" >> /usr/lib/systemd/system/mysqld.service
        echo "*** Updated mysqld.service open file limit to infinity."; sleep 1
    else
        sed -i 's/^LimitNOFILE.*/LimitNOFILE=infinity/g' /usr/lib/systemd/system/mysqld.service
        echo "*** Updated mysqld.service open file limit to infinity."; sleep 1
    fi

    if ! ( grep -qs LimitMEM /usr/lib/systemd/system/mysqld.service ); then
        echo "LimitMEMLOCK=infinity" >> /usr/lib/systemd/system/mysqld.service
        echo "*** Updated mysqld.service memory limit to infinity."; sleep 1
    else
        sed -i 's/^LimitMEM.*/LimitMEMLOCK=infinity/g' /usr/lib/systemd/system/mysqld.service
        echo "*** Updated mysqld.service memory limit to infinity."; sleep 1
    fi
    systemctl daemon-reload
}

function my_remote_login() {
    # Configures a MySQL 'root'@'%' user for remote login, used for remote DB installations, and grants the user full privileges

    mysql -u root -Be "CREATE USER 'root'@'%' IDENTIFIED WITH 'mysql_native_password' BY '${rootpass}';\
    GRANT ALL ON *.* TO 'root'@'%' WITH GRANT OPTION;FLUSH PRIVILEGES;"
    echo "*** Created 'root'@'%' user for remote MySQL login and granted full privileges."; sleep 1
}

function my_secure_install() {
    # Runs mysql_secure_installation equivalent commands

    if [[ "$myconfig" = "5.7" ]]; then
        local temppw=$( grep 'A temporary password' /var/lib/mysql/error.log | awk '{print $11}' )
    else
        local temppw=$( grep 'A temporary password' /var/lib/mysql/error.log | awk '{print $13}' )
    fi

    if [[ -z "$temppw" ]]; then
        echo "${err} No temporary MySQL password found."; sleep 1
    else
        echo "*** MySQL set a temporary root password, it will be changed."; sleep 1
    fi
    mysqladmin -u root --password="${temppw}" password "${rootpass}"
    echo "*** Configured MySQL root user with the password you entered."; sleep 1

    echo -e "[client]\nuser = root\npassword = ${rootpass}" >> /root/.my.cnf
    echo "*** Added user root with password to temporary ~/.my.cnf for script MySQL login."; sleep 1

    mysql -u root -Be "GRANT ALL ON *.* TO 'root'@'localhost' WITH GRANT OPTION;FLUSH PRIVILEGES;"
    echo "*** Granted full privileges to root@localhost."; sleep 1

    mysql -u root -Be "DROP DATABASE IF EXISTS test;DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';FLUSH PRIVILEGES;"
    echo "*** Configured equivalent of mysql_secure_installation for IMC."; sleep 1
}

function my_timezone() {
    # Fixes the known MySQL JDBC issue with Timezone that prevents IMC installation/upgrade by inserting the offset into /etc/my.cnf after default-storage-engine

    local tz=$( date +"%z" )
    local offset=$( echo "$tz" | sed 's/.../&:/g;s/:$//' )
    local config="default-time-zone = '${offset}'"

    echo "*** System indicates the UTC Offset is ${offset}."; sleep 1
    echo "*** Adding $config to /etc/my.cnf to fix timezone issue."; sleep 1
    sed -i "/^default-storage-engine.*/a ${config}" /etc/my.cnf
}

function package_installer() {
    # Download & install required package groups and libraries for IMC

    for group in "Server with GUI" "Development Tools" "Compatibility Libraries"; do
        installed=$( yum grouplist installed | grep "$group" )
        if [[ -z "$installed" ]]; then
            echo "*** Installing $group, please wait..."; sleep 1
            yum groupinstall "$group" -y
        else
            echo "*** $group already installed."; sleep 1
        fi
    done

    yum install glibc.i686 libgcc.i686 libaio.i686 libstdc++.i686 nss-softokn-freebl.i686 -y
    echo "*** 32-bit libraries required by IMC installed."; sleep 1

    if [[ "$guiconfig" = "GNOME" ]]; then
        echo "*** Installing GNOME Desktop, please wait..."; sleep 1
        yum groupinstall "GNOME Desktop" -y

        echo "*** Setting default boot from GUI..."; sleep 1
        systemctl set-default graphical.target

    elif [[ "$guiconfig" = "KDE" ]]; then
        echo "*** Installing KDE Plasma Workspaces, please wait..."; sleep 1
        yum groupinstall "KDE Plasma Workspaces" -y

        echo "*** Setting default boot from GUI..."; sleep 1
        systemctl set-default graphical.target
    else
        echo "*** Desktop environment will NOT be installed."; sleep 1
    fi

    echo "*** Running yum update, please wait..."; sleep 1
    yum update -y
}

function user_input() {
    # Determine how to run the script based on user input.

    clear
    read -p ">>> Is $ipaddr the server's IPv4 address for IMC? [y/N]: " prompt
    until [[ "$prompt" =~ ^[yYnN].*$ ]]; do
        echo "${err} $prompt is invalid."
        read -p ">>> Is $ipaddr the server's IPv4 address for IMC? [y/N]: " prompt
    done
    if [[ "$prompt" =~ ^[yY].*$ ]]; then
        echo "*** Using $ipaddr for IMC."; sleep 2
    else
        read -p ">>> Enter this server's IPv4 address for IMC: " ip
        until valid_ip $ip; do
            echo "${err} $ip is invalid. Enter an address like '10.10.10.200'."
            read -p ">>> Enter this server's IPv4 address for IMC: " ip
        done
        echo "*** Valid IPv4 address $ip entered."; sleep 2
        ipaddr="$ip"
    fi

    clear
    echo "*** To run DMA and install IMC, you will need a desktop environment."
    read -p ">>> Install GNOME, KDE or none? [GNOME/KDE/none]: " guiconfig
    until [[ "$guiconfig" = "GNOME" || "$guiconfig" = "KDE" || "$guiconfig" == "none" ]]; do
        echo "${err} $guiconfig is invalid."; sleep 1
        read -p ">>> Install GNOME, KDE or none? [GNOME/KDE/none]: " guiconfig
    done
    sleep 2

    clear
    echo "*** You need to install and configure a database for IMC."
    echo "*** This script can setup MySQL Community Edition for you."
    echo "*** It is supported for IMC since 7.3 E070x, with up to 1000 managed devices."
    read -p ">>> Should this script install and prepare MySQL for you? [y/N]: " dbchoice
    until [[ "$dbchoice" =~ ^[yYnN].*$ ]]; do
        echo "${err} $dbchoice is invalid."
        read -p ">>> Should this script install and prepare MySQL for you? [y/N]: " dbchoice
    done
    if [[ "$dbchoice" =~ ^[yY].*$ ]]; then
        clear
        echo "*** This script can install MySQL 5.7/8.0 Community DB for IMC..."
        echo "*** If you are deploying IMC with Local DB, you should choose 'both'."
        echo "*** For IMC with Remote DB, choose 'client' on IMC and 'both' on remote DB."
        read -p ">>> Install both MySQL Client & Server, or Client only? [client/both]: " dbconfig
        until [[ "$dbconfig" = "client" || "$dbconfig" = "both" ]]; do
            echo "${err} $dbconfig is invalid."
            read -p ">>> Install the MySQL Server & Client, or Client only? [client/both]: " dbconfig
        done
        echo "*** $dbconfig selected for installation."; sleep 2

        clear
        read -p ">>> Which MySQL Version would you like to setup? [5.7/8.0]: " myconfig
        until [[ "$myconfig" = "5.7" || "$myconfig" = "8.0" ]]; do
            echo "${err} $myconfig is invalid."
            read -p ">>> Which MySQL Version would you like to setup? [5.7/8.0]: " myconfig
        done
        echo "*** MySQL $myconfig Community selected for install."; sleep 2

        clear
        echo "*** You now need to set a password for the MySQL root user."
        echo "*** Remember this password, you will need it for iMC installation!"
        until [[ "$rootpass" = "$confpass" ]] && valid_pass $rootpass && valid_pass_imc $rootpass; do
            read -s -p ">>> Please enter the password for MySQL 'root': " rootpass; echo
            read -s -p ">>> Please confirm the password: " confpass; echo
            if [[ "$rootpass" != "$confpass" ]]; then
                echo "*** Passwords do not match. Please try again."
            elif ! (valid_pass $rootpass); then
                echo "*** Password does not meet MySQL complexity requirements."
            elif ! (valid_pass_imc $rootpass); then
                echo "*** Password contains a symbol not supported by iMC."
                echo "*** Unsupported symbols: @ & ' \ / ^ $ ! < > ( ) \" | ; \` and any blank space"
            fi
        done
        echo "*** Your password matches and meets requirements."; sleep 2

        clear
        echo "*** If this system is a Remote DB server for IMC, answer 'y' below."
        echo "*** Otherwise you can answer 'n' to prevent remote root login."
        read -p ">>> Configure MySQL account 'root'@'%' for remote login? [y/N]: " remoteroot
        until [[ "$remoteroot" =~ ^[yYnN].*$ ]]; do
            echo "${err} $remoteroot is invalid."
            read -p ">>> Configure MySQL account 'root'@'%' for remote login? [y/N]: " remoteroot
        done
    else
        echo "*** Skipping database setup."; sleep 2
        dbconfig="none"
    fi

    clear
    echo "*** Once the script completes, you will need to reboot."
    read -p ">>> Should the script reboot the server for you? [y/N]: " reboot
    until [[ "$reboot" =~ ^[yYnN].*$ ]]; do
        echo "${err} $reboot is invalid."
        read -p ">>> Should the script reboot the server for you? [y/N]: " reboot
    done
}

function valid_ip() {
    # Validates the IP address and returns true if it is valid.

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
    # Validates that the MySQL Root password entered meets complexity requirements, returns true if it does.

    if [[ ${#1} -ge 8 && "$1" == *[A-Z]* && "$1" == *[a-z]* && "$1" == *[0-9]* ]]; then
        return 0
    else
        return 1
    fi
}

function valid_pass_imc() {
    # Checks if the password contains any IMC disallowed symbols and returns true if it doesn't.
    # Symbols matched: <any blank space> @ & ' \ / ^ $ ! < > ( ) " | ; ` 

    if [[ "$1" == *['!'\s@\&\'\\\^\$\!\<\>\(\)\"\/\|\;\`]* ]]; then
        return 1
    else
        return 0
    fi
}

function goodbye() {
    # Performs cleanup, sends goodbye messages into ILMS-README.txt, reboot if chosen during user input.

    rootpass=""
    rm -f ./.my.cnf
    rm -f ./ILMS-README.txt

    touch ./ILMS-README.txt
    clear
    echo "*** CONGRATULATIONS! The script has completed preparing this server for IMC.
*** REMAINING TASKS (for you, after the reboot):" >> ILMS-README.txt; sleep 2

    if [[ "$dbconfig" = "none" ]]; then
        echo "You chose to skip having the DB installed for you.
1. Remove pre-installed MySQL/MariaDB manually if necessary.
2. Follow the IMC Linux Deployment Guide & DB Installation Guide to setup your DB correctly.
--> For example, here is the IMC Linux MySQL 5.7 DB Installation Guide:
https://support.hpe.com/hpsc/doc/public/display?docLocale=en_US&docId=emr_na-a00075555en_us&withFrame" >> ILMS-README.txt
    fi

    echo "--> HPE IMC DOWNLOADS: (free 60-day trial auto-activated upon installation)
Standard - https://h10145.www1.hpe.com/downloads/SoftwareReleases.aspx?ProductNumber=JG747AAE
Enterprise - https://h10145.www1.hpe.com/downloads/SoftwareReleases.aspx?ProductNumber=JG748AAE
--> INSTALLATION STEPS (after reboot to GUI):
    1. Extract the downloaded archive with unzip 'filename.zip'
    2. Make it executable with chmod +x <extracted-dir>/linux/install/install.sh
    3. Execute the installer with ./install.sh and follow the prompts to install IMC.
-> This information has been saved to ./ILMS-README.txt for future reference.
-> Thank you for using ILMS!" >> ILMS-README.txt
    cat ./ILMS-README.txt

    if [[ "$reboot" =~ ^[nN].*$ ]]; then
        echo "*** Script exiting, please remember to restart the server."; sleep 1
        exit 0
    else
        shutdown -r now
    fi
}

function main {
    # Main calls all other functions in the required order

    welcome
    init_checks
    user_input

    hosts_config
    package_installer
    disable_security

    if [[ "$dbconfig" = "both" ]]; then
        db_cleanup
        db_install
        my_config
        systemctl start mysqld
        systemctl enable mysqld
        echo "*** mysqld service started and enabled."; sleep 1
        echo "*** Beginning MySQL $myconfig Server setup..."; sleep 1
        my_secure_install
        if [[ "$remoteroot" =~ ^[yY].*$ ]]; then
            my_remote_login
        else
            echo "*** Remote MySQL root login will NOT be configured."; sleep 1
        fi
        my_timezone
        my_limits
        systemctl restart mysqld
        echo "*** mysqld service restarted."; sleep 1
        echo "*** MySQL $myconfig installed & configured."; sleep 1
    elif [[ "$dbconfig" = "client" ]]; then
        db_install
        echo "*** MySQL $myconfig installed & configured."; sleep 1
    else
        echo "*** Database installation skipped as requested."; sleep 1
    fi

    goodbye
}

echo ">>> Begin executing ILMS.sh v1.00 (BETA) 12.08.2020 <<<"; sleep 1
main