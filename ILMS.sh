#!/bin/bash

function welcome() {
    # Welcome messages to get started or exit, determines sequence to print based on passed parameter $run

    if [ "$1" == "1" ]; then
        echo "*** Welcome to the RHEL with MySQL Setup Script for HPE IMC! ***"
        echo "*** This script automatically prepares your RHEL 7.x Server for IMC deployment."
        echo "*** It is unofficial, free, open source, and comes with absolutely NO warranty."
        echo "*** IMPORTANT ***"
        echo "* This server must have internet access."
        echo "* Static IP address should be configured."
        echo "* RHEL must have an active subscription!"
        echo "* This script accomplishes all setup tasks to prepare the server for IMC..." 
        echo "* ...except for downloading and installing IMC."
        echo ">>> Please confirm that you have read the above and the server meets the prerequisites."
    else
        echo "*** Welcome back! This script will now complete some remaining tasks."
        echo "*** Please confirm that you are ready."
    fi

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

function check_config() {
    # Check if the ./ILMS.cfg file parameters are valid, exit otherwise

    if [ "$1" == "none" ] || [ "$1" == "client" ] || [ "$1" == "both" ] && [ -z "$2" ] || [ "$2" == "5.7" ] || [ "$2" == "5.6" ]; then
        echo "*** ILMS.cfg looks valid. Proceeding..."
    else
        echo "ERROR! $1 or $2 invalid. Ensure you did not modify ./ILMS.cfg manually."
        echo "If you think this is a bug, thanks in advance for reporting it to guse@hpe.com"
        exit 1
    fi
}

function valid_ip() {
    # Validate IP address, return true if valid, sourced from https://www.linuxjournal.com/content/validating-ip-address-bash-script

    local ip=$1
    local stat=1

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

function configured_ip() {
    # Ensure that IP address is already set, return true if valid

    local stat=1
    check=$( ip add | grep $1 | awk '{print $2}' )
    echo "*** Checking if the IP address is configured: $check"

    if [ -z "$check" ]; then
        echo "*** IP address not configured on any adapter!"
        stat=1
    else
        echo "*** IP address $check is configured."
        stat=0
    fi
    return $stat
}

function db_choices() {
    # Get input for database options, return true unless DB should not be installed

    echo "*** You will need to install a database for IMC."
    echo "* Only certain editions of MySQL and Oracle are officially supported with IMC on RHEL. Please check IMC Release Notes for details."
    echo "* Only MySQL Enterprise edition is officially supported for IMC, with up to 1000 managed devices per installation."
    echo "* This script can only install the free MySQL Community Edition, if you wish. It generally works but will not be officially supported."
    echo "* If you choose to install the DB yourself, make sure to enter 'no' below, and follow the steps in the IMC MySQL/Oracle Installation Guide."

    read -p "*** Should this script install and prepare MySQL for you? (yes/no) " prompt
    until [ "$prompt" == "yes" ] || [ "$prompt" == "no" ]; do
        echo "*** Invalid input! Enter yes or no continue."
        read -p "*** Would you like to have the script install and prepare MySQL for you? (yes/no) " prompt
    done

    if [ "$prompt" == "yes" ]; then
        echo "*** This script can install and setup MySQL 5.6/5.7 Community with Client & Server for IMC..."
        echo "*** If you are deploying IMC with Local DB, you need to install both the DB client and server on the IMC system."
        echo "*** If you are deploying with Remote DB instead, install only the DB client on the IMC system, and both on DB server."

        read -p "*** Install the MySQL Server & Client, or client only (required for remote DB)? (client/both) " dbconfig
        until [ "$dbconfig" == "client" ] || [ "$dbconfig" == "both" ]; do
            echo "*** Invalid input! Enter client or both to continue."
            read -p "*** Install the MySQL Server & Client, or Client only (required for remote DB)? (client/both) " dbconfig
        done
        echo "*** $dbconfig selected for installation."

        read -p "*** Which MySQL Version would you like to setup? (5.6/5.7) " myconfig
        until [ "$myconfig" == "5.6" ] || [ "$myconfig" == "5.7" ]; do
            echo "*** Invalid input! Enter 5.6 or 5.7 to continue."
            read -p "*** Which MySQL Version would you like to setup? (5.6/5.7) " myconfig
        done
        echo "*** MySQL $myconfig Community selected for install."

        echo "$dbconfig $myconfig" >> ./ILMS.cfg
        return 0
    else
        echo "*** MySQL will NOT be installed."
        return 1
    fi
}

function db_cleanup() {
    # Check for existing MySQL or MariaDB and prompt to remove them if found. Return true if cleaned or not needed, false if found but skipped.

    local mysql1=$( rpm -qa | grep mysql )
    local mysql2=$( rpm -qa | grep MySQL )
    local mariadb=$( rpm -qa | grep maria )
    local clean=0

    if [ -z "$mysql1" ] && [ -z "$mysql2" ] && [ -z "$mariadb" ]; then
        echo "*** Existing MySQL & MariaDB installations not found."
        return $clean
    else
        echo "*** MySQL/MariaDB installation(s) found. They must be removed before this script can install MySQL for you."

        if [ ! -z "$mysql1" ]; then
            read -p ">>> Would you like to remove the existing $mysql1? (yes/no) " prompt
            until [ "$prompt" == "yes" ] || [ "$prompt" == "no" ]; do
                echo "*** Invalid input! Enter yes or no to continue."
                read -p ">>> Would you like to remove the existing $mysql1? (yes/no) " prompt
            done

            if [ "$prompt" == "no" ]; then
                echo "*** MySQL will NOT be removed."
                clean=1
            else
                systemctl stop mysqld
                echo "*** mysqld Service stopped."
                
                yum remove mysql mysql-server -y
                # rpm -e --nodeps $( rpm -qa "mysql*" )
                echo "*** $mysql1 uninstalled."
                
                mv -f /var/lib/mysql /var/lib/mysql_old_backup
                echo "*** Moved old mysql leftovers to /var/lib/mysql_old_backup"
            fi
        fi

        if [ ! -z "$mysql2" ]; then
            read -p ">>> Would you like to remove the existing $mysql2? (yes/no) " prompt
            until [ "$prompt" == "yes" ] || [ "$prompt" == "no" ]; do
                echo "*** Invalid input! Enter yes or no to continue."
                read -p ">>> Would you like to remove the existing $mysql2? (yes/no) " prompt
            done

            if [ "$prompt" == "no" ]; then
                echo "*** MySQL will NOT be removed."
                clean=1
            else
                systemctl stop mysqld
                echo "*** mysqld Service stopped."
                
                yum remove mysql mysql-server -y
                # rpm -e --nodeps $( rpm -qa "MySQL*" )
                echo "*** $mysql2 uninstalled."

                mv -f /var/lib/mysql /var/lib/mysql_old_backup
                echo "*** Moved old mysql leftovers to /var/lib/mysql_old_backup"
            fi
        fi

        if [ ! -z "$mariadb" ]; then
            read -p ">>> Would you like to remove the existing $mariadb? (yes/no) " prompt
            until [ "$prompt" == "yes" ] || [ "$prompt" == "no" ]; do
                echo "*** Invalid input! Enter yes or no to continue."
                read -p ">>> Would you like to remove the existing $mariadb? (yes/no) " prompt
            done

            if [ "$prompt" == "no" ]; then
                "*** MariaDB will NOT be removed."
                clean=1
            else
                systemctl stop mariadb
                echo "*** mariadb Service stopped."

                yum remove mariadb mariadb-server -y
                echo "*** MariaDB uninstalled."

                mv -f /var/lib/mysql /var/lib/mysql_old_backup
                echo "*** Moved old mariadb/mysql leftovers to /var/lib/mysql_old_backup"
            fi
        fi

        if [ ! $clean ]; then
            echo "*** Pre-installed DBs were NOT removed. This script will NOT install or configure any MySQL DB Client/Server as a result!"
            rm -f ./ILMS.cfg
            echo "none" >> ./ILMS.cfg
        else
            yum clean all -y
            echo "*** Cleanup after removal(s) completed."
            return $clean
        fi
    fi
}

function db_install() {
    # Add MySQL repository, download & install MySQL 5.6/5.7 Community Client and/or Server, start and enable mysqld.
    
    wget https://dev.mysql.com/get/mysql57-community-release-el7-9.noarch.rpm
    echo "*** MySQL community repository downloaded."

    yum install mysql57-community-release-el7-9.noarch.rpm -y
    echo "*** MySQL community repository installed."

    if [ "$2" == "5.6" ]; then
        sudo yum-config-manager --disable mysql57-community
        echo "*** MySQL 5.7 release repository disabled."
        sudo yum-config-manager --enable mysql56-community
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
    read -p ">>> Install GNOME, KDE or none? (gnome/kde/none) " prompt
    until [ "$prompt" == "GNOME" ] || [ "$prompt" == "KDE" ] || [ "$prompt" == "none" ]; do
        echo "*** Invalid input! Enter GNOME, KDE or none."
        read -p ">>> Install GNOME, KDE or none? (GNOME/KDE/none) " prompt
    done

    if [ "$prompt" == "GNOME" ]; then
        echo "*** Installing GNOME Desktop, please wait..."
        yum groupinstall "GNOME Desktop" -y
        systemctl set-default graphical.target
    elif [ "$prompt" == "KDE" ]; then
        echo "*** Installing KDE Plasma Workspaces, please wait..."
        yum groupinstall "KDE Plasma Workspaces" -y
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

    if [ $update ]; then
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
    # Check ip, if found in /etc/hosts with hostname, otherwise ask for and validate it

    local ip="$1"
    
    if [ ! -z "$ip" ]; then
        echo "*** Found IP address $ip in /etc/hosts."

        if [ "configured_ip $ip" ] && [ "valid_ip $ip" ]; then
            read -p ">>> Is $ip the server's IPv4 address to be used for IMC? (yes/no) " prompt
            until [ "$prompt" == "yes" ] || [ "$prompt" == "no" ]; do
                echo "***Invalid input! Enter yes or no to continue."
                read -p ">>> Is $ip the server's IPv4 address to be used for IMC? (yes/no) " prompt
            done
            
            if [ "$prompt" == "yes" ]; then
                echo "*** Using $ip for IMC."
                ipaddr="$ip"
            else
                read -p ">>> Enter this server's primary IPv4 addr for IMC (eg. 10.10.10.200, or exit): " ip
                until [ "valid_ip $ip" ] && [ "configured_ip $ip" ]; do
                    read -p ">>> Enter this server's primary IPv4 addr for IMC (eg. 10.10.10.200, or exit): " ip
                    if [ "$ip" == "exit" ]; then
                        exit 0
                    fi
                done
            fi
        fi
        
    else
        echo "*** No IP address found in /etc/hosts for $HOSTNAME."
        read -p ">>> Enter this server's primary IPv4 addr for IMC (eg. 10.10.10.200, or exit): " ip
        until [ valid_ip $ip ] && [ configured_ip $ip ]; do
            read -p ">>> Enter this server's primary IPv4 addr for IMC (eg. 10.10.10.200, or exit): " ip
            if [ "$ip" == "exit" ]; then
                exit 0
            fi
        done

        echo "*** Valid configured IPv4 address $ip entered. Proceeding with script..."
        ipaddr="$ip"
    fi

}

function library_install() {
    # These 32-bit libraries are required to install IMC

    echo "*** Installing 32-bit libraries & tools required by IMC, please wait..."
    yum install glibc.i686 libgcc.i686 libaio.i686 libstdc++.i686 nss-softokn-freebl.i686 unzip perl telnet ftp -y
    echo "*** IMC required libraries & tools installed."
}

function my_config() {
    # Gets the MySQL version and then downloads & installs the correct my.cnf for MySQL Server

    echo "*** Downloading custom $1 my.cnf file for IMC from github..."
    wget https://raw.githubusercontent.com/Justinfact/imc-lmst/master/my-lmst-$1.txt

    echo "*** Creating backup of /etc/my.cnf as /etc/my.cnf.bak"
    cp /etc/my.cnf /etc/my.cnf.bak
    echo "*** Replacing /etc/my.cnf with the custom my.cnf file"
    mv -f my-lmst-$1.txt /etc/my.cnf
    echo "*** Downloaded and installed custom /etc/my.cnf file for IMC."

    limit=$( grep Limit /usr/lib/systemd/system/mysqld.service )
    if [ -z "$limit" ]; then
        echo -e "LimitNOFILE=infinity\nLimitMEMLOCK=infinity" >> /usr/lib/systemd/system/mysqld.service
        systemctl daemon-reload
        echo "*** Updated /usr/lib/systemd/system/mysqld.service limits."
    else
        echo "*** No need to update /usr/lib/systemd/system/mysqld.service limits."
    fi
}

function my_rootpass() {
    # Check for temporary MySQL root password and print it, prompt to change root password and store it for my_secure_install
    
    if [ "$1" == "both" ]; then
        local temppass=$( grep 'temporary password' /var/log/mysqld.log | awk '{print $11}' )
                    
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

    local match=1
    while [ $match == 1 ]; do
        read -p ">>> Please enter the password for MySQL 'root' user: " rootpass
        read -p ">>> Please confirm the password for MySQL 'root' user: " confirm
        if [ "$rootpass" == "$confirm" ]; then
            echo "*** Passwords match."
            match=0
        else
            echo "*** Passwords do not match. Please try again."
        fi
    done
}

function my_secure_install() {
    # Gets the rootpass and temppass, and automates mysql_secure_installation using config in ~/.my.cnf file
    
    FILE=~/.my.cnf
    if [ -f "$FILE" ]; then
        echo "*** ~/.my.cnf found, removing it."
        rm -f ~/.my.cnf
    fi

    if [ "$3" == "both" ]; then
        if [ -z "$2" ]; then
            echo -e "[client]\nuser = root\npassword = $1" >> ~/.my.cnf
            echo "*** Added user root with password $1 to ~/.my.cnf for simple mysql client login."         
            mypass="$1"   
        else
            echo -e "[client]\nuser = root\npassword = $2" >> ~/.my.cnf
            echo "*** Added user root with temporary password $2 to ~/.my.cnf for simple mysql client login."
            mypass="$2"
        fi
        
        mysql -u root -Bse "grant all privileges on *.* to root@'%' identified by '$mypass' with grant option;"
        echo "*** Granted all privileges to root."
        mysql -u root -Bse "DELETE FROM mysql.user WHERE User='';DROP DATABASE IF EXISTS test;DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';FLUSH PRIVILEGES;"
        echo "*** Configured equivalent of mysql_secure_installation."
        
        if [ ! -z "$2" ]; then
            mysql -u root -Bse "update user set authentication_string=PASSWORD("$1") where User='root';flush privileges;"
            rm -f ~/.my.cnf
            echo -e "[client]\nuser = root\npassword = $1" >> ~/.my.cnf
            echo "*** Updated ~/.my.cnf with user root using your password $1 for simple mysql client login."
        fi
    else
        if [ -z "$2" ]; then
            echo -e "[client]\nuser = root\npassword = $1" >> ~/.my.cnf
            echo "*** Added user root with password $1 to ~/.my.cnf for simple mysql client login."    
        else
            echo -e "[client]\nuser = root\npassword = $2" >> ~/.my.cnf
            echo "*** Added user root with temporary password $2 to ~/.my.cnf for simple mysql client login."
        fi
    fi
}

function goodbye() {
    # Goodbye messages and option to reboot now or later, determines sequence to print based on passed parameter $run
    
    if [ "$1" == "1" ]; then
        echo "*** Initial tasks completed. The server should now be rebooted."
        echo "*** SETUP IS NOT YET COMPLETE! Please re-run the script with ./ILMS.sh after rebooting."
        echo "*** The script has saved your choices to ./ILMS.cfg, please do not manually modify it."
        echo "*** The ./ILMS.cfg will be removed automatically once the setup is complete."
        read -p ">>> Having read the above, would you like to reboot now? (yes/no) " prompt
    else
        rm -f ./mysql57-community-release-el7-9.noarch.rpm*
        echo "*** Cleaned up MySQL RPM leftovers."

        rm -f ./ILMS-README.txt
        touch ./ILMS-README.txt
        echo -e "*** CONGRATULATIONS! The script has completed preparing this server for IMC.\n" >> ILMS-README.txt
        echo -e "*** REMAINING TASKS (for you, after reboot):\n" >> ILMS-README.txt

        if [ "$dbconfig" == "none" ]; then
            echo -e "-> You chose to skip having the DB installed for you!\n" >> ILMS-README.txt
            echo -e "-> Remove pre-installed MySQL/MariaDB manually if necessary.\n" >> ILMS-README.txt
            echo -e "-> Follow the IMC Deployment Guide & IMC MySQL/Oracle DB Installation Guide to setup the database correctly.\n" >> ILMS-README.txt
        fi

        echo -e "-> DOWNLOAD HPE IMC (free 60-day trial auto-activated upon installation)\n" >> ILMS-README.txt
        echo -e " -Standard - https://h10145.www1.hpe.com/downloads/SoftwareReleases.aspx?ProductNumber=JG747AAE \n" >> ILMS-README.txt
        echo -e " -Enterprise - https://h10145.www1.hpe.com/downloads/SoftwareReleases.aspx?ProductNumber=JG748AAE \n" >> ILMS-README.txt
        echo -e "-> Extract the downloaded archive, chmod +x '%IMC%/deploy/install.sh', ./install.sh to launch installer.\n" >> ILMS-README.txt
        echo -e "-> This information has been saved to ./ILMS-README.txt for future reference.\n" >> ILMS-README.txt
        cat ./ILMS-README.txt
        
        read -p ">>> One last reboot is needed, and you're good to go! Would you like to reboot now? (yes/no) " prompt
    fi

    until [ "$prompt" == "yes" ] || [ "$prompt" == "no" ]; do
        echo "*** Invalid input! Enter yes or no continue."
        read -p ">>> Would you like to reboot now (no if you will to do so later)? (yes/no) " prompt
    done
    
    if [ "$prompt" == "no" ]; then
        exit 0
    else
        shutdown -r now
    fi        
}

function main {

    dbconfig=$( cat ./ILMS.cfg | awk '{print $1}')
    myconfig=$( cat ./ILMS.cfg | awk '{print $2}')
    ipaddr=$( grep $HOSTNAME /etc/hosts | awk '{print $1}' )
    rootpass=""
    temppass=""

    # First run, when main parameters is 1
    if [ "$1" == "1" ]; then
        
        welcome $1
        
        ip_prompt $ipaddr
        hosts_config $ipaddr

        group_install
        library_install
        disable_security

        output=$( db_choices )
        if [ ! "$output" ]; then
            desktop_install

            rm -f ./ILMS.cfg
            echo "*** Removing ./ILMS.cfg as it is no longer needed."

            run="2"
        else
            db_cleanup
            goodbye $1
        fi

        goodbye $1

    # Second run, when main parameter is 2
    else

        welcome $1

        check_config $dbconfig $myconfig

        if [ "$dbconfig" == "none" ]; then
            echo "*** As per your choice, this script will skip installing & configuring MySQL for you."
        else
            db_install $dbconfig $myconfig
            my_rootpass $dbconfig
            my_secure_install $rootpass $temppass $dbconfig

            if [ "$dbconfig" == "both" ]; then
                systemctl stop mysqld
                my_config $myconfig
            fi

            systemctl start mysqld
            echo "MySQL $myconfig installed & configured."
        fi

        desktop_install

        rm -f ./ILMS.cfg
        echo "*** Removing ./ILMS.cfg as it is no longer needed."
        goodbye $1
    fi
}

# If the config file does not exist, add it. Run main function with 1 (first run) or 2 (second run).
FILE=./ILMS.cfg

if [ -f "$FILE" ]; then
    echo "*** ILMS.cfg found. Proceeding with script..."
    run="2"
else
    touch ./ILMS.cfg
    echo "*** Created ./ILMS.cfg. Please do not edit or remove it."
    run="1"
fi

main $run

# TO DO:
# * MySQL 5.6 verification and config file update
# * Testing on RHEL
# * Linking to MySQL 5.x installation guide