#!/bin/bash
# IMC Linux MySQL Setup script authored by Justin Guse
# This script automates the entire setup process to prepare the server for installation of HPE IMC on RHEL.
# All functionality is contained in separate functions that are called by main in the required sequence.

echo ">>> Begin executing ILMS.sh v0.8 (BETA) 17.07.2019 <<<"

function welcome() {
    # Welcome messages to get started or exit, determines sequence to print based on input 1 (first run) or 2.

    echo "*** Welcome to the RHEL with MySQL Setup Script for HPE IMC! ***"
    echo "*** This script automatically prepares your RHEL 7.x Server for IMC deployment."
    echo "*** It is unofficial, free, open source, and comes with absolutely NO warranty."
    echo "*** IMPORTANT ***"
    echo "* This server must have internet access."
    echo "* Static IP address should already be configured."
    echo "* RHEL must have an active subscription (for yum/rpm)!"
    echo "* This script accomplishes all setup tasks to prepare the server for IMC..."
    echo "* ...except for downloading and installing IMC."
    echo ">>> Please confirm that you have read the above and the server meets the prerequisites."

    read -p ">>> Are you ready to get started? (yes/no) " prompt
    until [ "$prompt" == "yes" ] || [ "$prompt" == "no" ]; do
        echo "***Invalid input! Enter yes or no to continue."
        read -p ">>> Are you ready to get started? (yes/no) " prompt
    done

    if [ "$prompt" == "no" ]; then
        echo "*** Script execution cancelled!"
        exit 0
    else
        echo "*** Beginning script execution..."
    fi
}

function check_os() {
    # Check if the OS is RedHat/CentOS and check for 64bit OS, exit otherwise.

    local bits=$( uname -m )
    if [ "$bits" == "x86_64" ]; then
        echo "*** You are running on a 64bit ($bits) OS which is compatible with IMC."
    else
        echo "*** You are running a 32bit ($bits) OS which is NOT recommend for IMC."
        echo "*** This script will now exit. Please re-run on a 64bit OS!"
        exit 0
    fi

    if [ -f /etc/os-release ]; then
        local rhel=$( grep A_PRODUCT= /etc/os-release | cut -d'=' -f2 | sed s/'"'//g )
        local centos=$( grep RT_PRODUCT= /etc/os-release | cut -d'=' -f2 | sed s/'"'//g )
        local centver=$( grep PRODUCT_VERSION= /etc/os-release | cut -d'=' -f2 | sed s/'"'//g )

        if [ "$rhel" == "Red Hat Enterprise Linux 7" ]; then
            echo "*** You are running on $rhel which is compatible with IMC 7.3 E0703 onwards."
        elif [ "$centos" == "centos" ] && [ "$centver" == "7" ]; then
            echo "!!! You are running on $centos $centver which is not supported for IMC."
            echo "*** HPE does not officially support running CentOS instead of RHEL for IMC."
            echo "*** This script can continue, and IMC may be installed, but it is NOT for production use. CentOS should be used for test/non-production systems only."

            read -p ">>> Please enter 'yes' if you would like to continue anyway. (yes/no) " prompt
            until [ "$prompt" == "yes" ] || [ "$prompt" == "no" ]; do
                echo "*** Invalid input! Enter yes or no continue."
                read -p ">>> Please enter 'yes' if you would like to continue anyway. (yes/no) " prompt
            done

            if [ "$prompt" == "no" ]; then
                exit 0
            else
                echo "*** Thanks for confirming. Script execution resuming..."
            fi
        else
            echo "*** $rhel $centos $centver is NOT supported for IMC."
            echo "*** Only RHEL 7.x distributions are supported by IMC 7.3 E0703."
            echo "*** This script will now exit. Please re-run on a supported OS."
            exit 0
        fi
    else
        echo "*** /etc/os-release not found. Likely due to unsupported OS."
        echo "*** Only RHEL 7.x distributions are supported by IMC 7.3 E0703."
        echo "*** If you think this is a bug, thanks in advance for reporting it to guse@hpe.com"
        echo "*** This script will now exit. Please re-run on a supported OS."
        exit 0
    fi
}

function db_choices() {
    # Get input for database options, return true unless DB should not be installed

    echo "*** You will need to install a database for IMC."
    echo "* Only certain editions of MySQL and Oracle are officially supported with IMC on RHEL. Please check IMC Release Notes for details."
    echo "* Only MySQL Enterprise edition is officially supported for IMC, with up to 1000 managed devices per installation."
    echo "* This script can only install the free MySQL Community Edition, if you wish. It generally works but will not be officially supported."
    echo "* If you choose to install the DB yourself, make sure to enter 'no' below, and follow the steps in the IMC MySQL/Oracle Installation Guide."

    read -p ">>> Should this script install and prepare MySQL for you? (yes/no) " prompt
    until [ "$prompt" == "yes" ] || [ "$prompt" == "no" ]; do
        echo "*** Invalid input! Enter yes or no continue."
        read -p ">>> Should this script install and prepare MySQL for you? (yes/no) " prompt
    done

    if [ "$prompt" == "yes" ]; then
        echo "*** This script can install and setup MySQL 5.6/5.7 Community with Client & Server for IMC..."
        echo "*** If you are deploying IMC with Local DB, you need to install both the DB client and server on the IMC system."
        echo "*** If you are deploying with Remote DB instead, install only the DB client on the IMC system, and both on DB server."

        read -p ">>> Install the MySQL Server & Client, or client only (required for remote DB)? (client/both) " dbconfig
        until [ "$dbconfig" == "client" ] || [ "$dbconfig" == "both" ]; do
            echo "*** Invalid input! Enter client or both to continue."
            read -p ">>> Install the MySQL Server & Client, or Client only (required for remote DB)? (client/both) " dbconfig
        done
        echo "*** $dbconfig selected for installation."

        read -p ">>> Which MySQL Version would you like to setup? (5.6/5.7) " myconfig
        until [ "$myconfig" == "5.6" ] || [ "$myconfig" == "5.7" ]; do
            echo "*** Invalid input! Enter 5.6 or 5.7 to continue."
            read -p ">>> Which MySQL Version would you like to setup? (5.6/5.7) " myconfig
        done
        echo "*** MySQL $myconfig Community selected for install."
    else
        echo "*** MySQL will NOT be installed."
        dbconfig="none"
    fi
}

function db_install() {
    # Add MySQL repository, download & install MySQL 5.6/5.7 Community Client and/or Server, start and enable mysqld.

    yum localinstall https://dev.mysql.com/get/mysql57-community-release-el7-9.noarch.rpm -y
    echo "*** MySQL Community Repository installed."

    if [ "$2" == "5.6" ]; then
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

    yum update -y
    echo "*** Running yum update, please wait..."

    systemctl start mysqld
    systemctl enable mysqld
    echo "*** mysqld service started and enabled."
}

function disable_security() {
    # Disable SELinux and Firewall
    ### Future: Auto-configure SELinux and Firewalld for IMC

    sed -i --follow-symlinks 's/^SELINUX=.*/SELINUX=disabled/g' /etc/sysconfig/selinux && cat /etc/sysconfig/selinux
    echo "*** SELINUX has been disabled."

    systemctl stop firewalld.service
    systemctl disable firewalld.service
    echo "*** Firewall stopped and disabled."
}

function desktop_install() {
    # Prompt to install the desktop environment for IMC and install GNOME/KDE if chosen

    echo "*** To run the HPE Deployment Monitoring Agent and install IMC, you should use a desktop environment."
    read -p ">>> Install GNOME, KDE or none? (GNOME/KDE/none) " prompt
    until [ "$prompt" == "GNOME" ] || [ "$prompt" == "KDE" ] || [ "$prompt" == "none" ]; do
        echo "*** Invalid input! Enter GNOME, KDE or none."
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
}

function group_install() {
    # Download & install required package groups for IMC, if not already installed

    local update=1
    for group in "Server with GUI" "Development Tools" "Compatibility Libraries"; do
        installed=$( yum grouplist installed | grep "$group" )
        if [ -z "$installed" ]; then
            echo "*** Installing $group, please wait..."
            yum groupinstall "$group" -y
            update=0
        else
            echo "*** $group already installed."
        fi
    done

    if [ $update -eq 0 ]; then
        echo "*** Running yum update, please wait..."
        yum update -y
    else
        echo "*** No required groups need to be installed."
    fi
}

function hosts_config() {
    # Gets the IP address and checks if it is found in /etc/hosts, adds it otherwise with the hostname for IMC

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
    # Check ip, if it was found in /etc/hosts with hostname, otherwise ask for and validate it

    local ip=$1

    if [ -z "$ip" ]; then
        echo "*** No IP address found in /etc/hosts for $HOSTNAME."

        read -p ">>> Enter this server's primary IPv4 address for IMC (eg. 10.10.10.200): " ipprompt
        until valid_ip $ipprompt; do
            echo "*** Invalid IP address! Enter an IPv4 address like 192.168.1.100 or 10.10.10.200..."
            read -p ">>> Enter this server's primary IPv4 address for IMC: " ipprompt
        done
        echo "*** Valid IPv4 address $ipprompt entered. Proceeding with script..."
        ipaddr="$ipprompt"
    else
        echo "*** Found IP address $ip in /etc/hosts."

        read -p ">>> Is $ip the server's primary IPv4 address to be used for IMC? (yes/no) " prompt
        until [ "$prompt" == "yes" ] || [ "$prompt" == "no" ]; do
            echo "***Invalid input! Enter yes or no to continue."
            read -p ">>> Is $ip the server's primary IPv4 address to be used for IMC? (yes/no) " prompt
        done

        if [ "$prompt" == "yes" ]; then
            echo "*** Using $ip for IMC."
            ipaddr="$ip"
        else
            read -p ">>> Enter this server's primary IPv4 address for IMC (eg. 10.10.10.200): " ipprompt
            until valid_ip $ipprompt; do
                echo "*** Invalid IP address! Enter an IPv4 address like 192.168.1.100 or 10.10.10.200..."
                read -p ">>> Enter this server's primary IPv4 address for IMC: " ipprompt
            done
            echo "*** Valid IPv4 address $ipprompt entered. Proceeding with script..."
            ipaddr="$ipprompt"
        fi
    fi
}

function library_install() {
    # These 32-bit libraries are required to install IMC
    ### Are unzip perl telnet ftp really needed?

    echo "*** Installing 32-bit libraries & tools required by IMC, please wait..."
    yum install glibc.i686 libgcc.i686 libaio.i686 libstdc++.i686 nss-softokn-freebl.i686 unzip perl telnet ftp -y
    echo "*** IMC required libraries & tools installed."
}

function my_config() {
    # Gets the MySQL version and then downloads & installs the correct my.cnf for MySQL Server

    echo "*** Downloading custom $1 my.cnf file for IMC from github..."
    wget https://raw.githubusercontent.com/Justinfact/imc-ilms/master/my-ilms-$1.txt

    echo "*** Creating backup of /etc/my.cnf as /etc/my.cnf.bak"
    mv -f /etc/my.cnf /etc/my.cnf.bak
    echo "*** Replacing /etc/my.cnf with the custom my.cnf file"
    mv -f my-ilms-$1.txt /etc/my.cnf
    echo "*** Downloaded and installed custom /etc/my.cnf file for IMC:"
    cat /etc/my.cnf
}

function my_limits() {
    # Fixes the memory and open file limits in mysqld.service for IMC

    limit=$( grep LimitNO /usr/lib/systemd/system/mysqld.service )
    if [ -z "$limit" ]; then
        echo -e "LimitNOFILE=infinity" >> /usr/lib/systemd/system/mysqld.service
        echo "*** Updated mysqld.service open file limit to infinity."
    else
        sed -i 's/^LimitNOFILE.*/LimitNOFILE=infinity/g' /usr/lib/systemd/system/mysqld.service
        echo "*** Updated mysqld.service open file limit to infinity."
    fi

    limit=$( grep LimitMEM /usr/lib/systemd/system/mysqld.service )
    if [ -z "$limit" ]; then
        echo -e "LimitMEMLOCK=infinity" >> /usr/lib/systemd/system/mysqld.service
        echo "*** Updated mysqld.service memory limit to infinity."
    else
        sed -i 's/^LimitMEM.*/LimitMEMLOCK=infinity/g' /usr/lib/systemd/system/mysqld.service
        echo "*** Updated mysqld.service memory limit to infinity."
    fi
    systemctl daemon-reload
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

        echo "*** You will now be prompted to set a new MySQL root user password."
        echo "*** Make sure you remember it, you will enter it during IMC installation."
    else
        echo "*** You will now be prompted to enter the MySQL root user password."
        echo "*** This script will add it to ~/.my.cnf for you to simplify MySQL CLI login."
        echo "*** Make sure you remember it, you will enter it during IMC installation."
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
    # Gets the rootpass and temppass and myconf, and runs mysql_secure_installation equivalent commands using config in ~/.my.cnf file
    ### Need to add MySQL 8.0 in the future

    local rootpw="$rootpass"
    local temppw="$temppass"
    local myconf="$1"

    FILE=~/.my.cnf
    if [ -f "$FILE" ]; then
        echo "*** ~/.my.cnf found, removing it."
        rm -f ~/.my.cnf
    fi

    if [ "$myconf" == "5.6" ]; then
        mysql -u root -Be "UPDATE mysql.user SET Password=PASSWORD('${rootpw}'), password_expired='N' WHERE User='root' and plugin = 'mysql_old_password';"
        mysql -u root -Be "UPDATE mysql.user SET Password=PASSWORD('${rootpw}'), password_expired='N' WHERE User='root' and plugin in ('', 'mysql_native_password');"
        mysql -u root -Be "UPDATE mysql.user SET authentication_string=PASSWORD('${rootpw}'), password_expired='N' WHERE User='root' and plugin = 'sha256_password';FLUSH PRIVILEGES;"

        echo "*** Set the MySQL root password to your password of choice."

        echo -e "[client]\nuser = root\npassword = ${rootpw}" >> ~/.my.cnf
        echo "*** Added user root with password $rootpw to ~/.my.cnf for simple MySQL client login."

        mysql -u root -Be "DELETE FROM mysql.user WHERE User='';DROP DATABASE IF EXISTS test;DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';FLUSH PRIVILEGES;"
        echo "*** Configured equivalent of mysql_secure_installation."

        # Needed for remote login... add prompt for
        #mysql -u root -Be "UPDATE user set host='%' where user='root';grant all privileges on *.* to 'root'@'%' identified by '${rootpw}' with grant option;FLUSH PRIVILEGES;"
        #echo "*** Granted all privileges to root."
    elif [ "$myconf" == 5.7 ]; then
        echo -e "[client]\nuser = root\npassword = ${temppw}" >> ~/.my.cnf
        echo "*** Added user root with temporary password $temppw to ~/.my.cnf for simple MySQL client login."

        mysql -u root --connect-expired-password -Be "SET old_passwords = 0;SET PASSWORD = PASSWORD('${rootpw}');FLUSH PRIVILEGES;"
        echo "*** Changed temporary root password to your password of choice."

        rm -f ~/.my.cnf
        echo "*** Removing existing ~/.my.cnf..."

        echo -e "[client]\nuser = root\npassword = ${rootpw}" >> ~/.my.cnf
        echo "*** Added user root with password $rootpw to ~/.my.cnf for simple MySQL client login."

        mysql -u root --database=mysql -Be "UPDATE user set host='%' where user='root';grant all privileges on *.* to root@'%' identified by '${rootpw}' with grant option;FLUSH PRIVILEGES;"
        echo "*** Granted all privileges to root."
    fi
}

function my_timezone() {
    # Fixes the known MySQL JDBC issue with Timezone that prevents IMC installation/upgrade

    local tz=$( date +"%z" )
    local offset=$( echo "$tz" | sed 's/.../&:/g;s/:$//' )
    local config="default-time-zone = '${offset}'"

    echo "*** System indicates the UTC Offset is ${offset}."
    echo "*** Adding $config to /etc/my.cnf to fix the known timezone issue."
    sed "29i${config}" /etc/my.cnf
}

function valid_ip() {
    # Validate the IP address and return true if it is valid.

    local ip=$1
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        OIFS=$IFS
        IFS='.'
        ip=($ip)
        IFS=$OIFS
        [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 \
            && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
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
    # Goodbye messages into readme, option to reboot now or later.

    rm -f ./ILMS-README.txt
    touch ./ILMS-README.txt
    echo -e "*** CONGRATULATIONS! The script has completed preparing this server for IMC." >> ILMS-README.txt
    echo -e "*** REMAINING TASKS (for you, after the reboot):" >> ILMS-README.txt

    if [ "$dbconfig" == "none" ]; then
        echo -e "-> You chose to skip having the DB installed for you!" >> ILMS-README.txt
        echo -e "-> Remove pre-installed MySQL/MariaDB manually if necessary." >> ILMS-README.txt
        echo -e "-> Follow the IMC Linux Deployment Guide & DB Installation Guide to setup the DB correctly." >> ILMS-README.txt
        echo -e "-> For example, here is the IMC Linux MySQL 5.7 DB Installation Guide:" >> ILMS-README.txt
        echo -e "-> https://support.hpe.com/hpsc/doc/public/display?docLocale=en_US&docId=emr_na-a00075555en_us&withFrame" >> ILMS-README.txt
    fi

    echo -e "-> DOWNLOAD HPE IMC (free 60-day trial auto-activated upon installation)" >> ILMS-README.txt
    echo -e " -Standard - https://h10145.www1.hpe.com/downloads/SoftwareReleases.aspx?ProductNumber=JG747AAE" >> ILMS-README.txt
    echo -e " -Enterprise - https://h10145.www1.hpe.com/downloads/SoftwareReleases.aspx?ProductNumber=JG748AAE" >> ILMS-README.txt
    echo -e "-> Extract the downloaded archive, chmod +x '%IMC%/deploy/install.sh', ./install.sh to launch installer." >> ILMS-README.txt
    echo -e "-> This information has been saved to ./ILMS-README.txt for future reference." >> ILMS-README.txt
    cat ./ILMS-README.txt

    read -p ">>> One last reboot is needed, and you're good to go! Would you like to reboot now? (yes/no) " prompt

    until [ "$prompt" == "yes" ] || [ "$prompt" == "no" ]; do
        echo "*** Invalid input! Enter yes or no continue."
        read -p ">>> Would you like to reboot now (no if you will to do so later)? (yes/no) " prompt
    done

    if [ "$prompt" == "no" ]; then
        echo "*** Thanks for using IMC Linux MySQL Setup!"
        echo "!!! Please restart the server before beginning the IMC installation."
        exit 0
    else
        shutdown -r now
    fi
}

function main {

    dbconfig=""
    myconfig=""
    ipaddr=$( grep $HOSTNAME /etc/hosts | awk '{print $1}' )

    welcome

    check_os
    ip_prompt $ipaddr
    hosts_config $ipaddr

    db_choices
    group_install
    library_install
    disable_security

    if [ "$dbconfig" != "none" ]; then
        db_install $dbconfig $myconfig
        systemctl start mysqld
        if [ "$dbconfig" == "both" ]; then
            echo "*** Beginning MySQL $myconfig Server setup..."
            my_rootpass $dbconfig
            my_secure_install $myconfig
            my_config $myconfig
            my_timezone
            my_limits
            systemctl restart mysqld
        fi
        echo "*** MySQL $myconfig installed & configured."
    fi

    desktop_install
    goodbye
}

main

# TO DO:
# * Testing IMC installation after 5.6 DB install scripting
# * Testing on RHEL
# * Future features:
# - MySQL 8.0 setup
# - MySQL Commercial repo install and Enterprise install option