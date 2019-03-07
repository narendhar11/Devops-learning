#!/bin/bash

LOG=/tmp/stack.log
rm -f $LOG
R="\e[31m"
G="\e[32m"
C="\e[36m"
Y="\e[33m"
N="\e[0m"


#### 
TOMCAT_URL="https://archive.apache.org/dist/tomcat/tomcat-9/v9.0.6/bin/apache-tomcat-9.0.6.tar.gz"
TOMCAT_DIR=$(echo $TOMCAT_URL | awk -F / '{print $NF}' | sed -e 's/.tar.gz//')
WAR_URL="https://github.com/cit-aliqui/APP-STACK/raw/master/student.war"
JDBC_URL="https://github.com/cit-aliqui/APP-STACK/raw/master/mysql-connector-java-5.1.40.jar"
CONN_STRING='<Resource name="jdbc/TestDB" auth="Container" type="javax.sql.DataSource" maxActive="50" maxIdle="30" maxWait="10000" username="student" password="student@1" driverClassName="com.mysql.jdbc.Driver" url="jdbc:mysql://IPADDR:3306/studentapp"/>'
IPADDR=$(hostname -i)
CONN_STRING=$(echo $CONN_STRING|sed -e "s/IPADDR/$IPADDR/")
MODJK_URL='https://github.com/cit-astrum/project-manual/raw/master/mod_jk.so'

HEAD(){
	echo -e "\e[1;33m$1\e[0m"
}

Info(){
	echo -n -e "\t-> ${C}$1${N} - "
}

Stat(){
	if [ $1 -eq 0 ]; then
		echo -e "${G}SUCCESS${N}"
    elif [ $1 -eq 10 ]; then
        echo -e "${Y}SKIPPING${N}" 
	else
		echo -e  "${R}FAILURE${N}"
		echo "Check the log file for the error, Location of log file is $LOG"
		exit 1
	fi
}

DBF(){
    HEAD "DB COMPONENT SETUP"
    Info "Installing MariaDB Server"
    yum install mariadb-server -y &>>$LOG
    Stat $?

    systemctl enable mariadb &>>$LOG
    Info "Starting MariaDB Server"
    systemctl start mariadb &>>$LOG
    Stat $?

    echo "create database if not exists studentapp;
    use studentapp;
    CREATE TABLE if not exists Students(student_id INT NOT NULL AUTO_INCREMENT,
        student_name VARCHAR(100) NOT NULL,
        student_addr VARCHAR(100) NOT NULL,
        student_age VARCHAR(3) NOT NULL,
        student_qual VARCHAR(20) NOT NULL,
        student_percent VARCHAR(10) NOT NULL,
        student_year_passed VARCHAR(10) NOT NULL,
        PRIMARY KEY (student_id)
    );
    grant all privileges on studentapp.* to 'student'@'%' identified by 'student@1';
    flush privileges;" >/tmp/student.sql 

    Info "Configuring Databases"
    mysql </tmp/student.sql &>>$LOG 
    Stat $?
}

APPF(){
    HEAD "APP COMPONENT SETUP"
    Info "Installing Java"
    yum install java -y &>>$LOG 
    Stat $?
    cd /opt
    Info "Downloading Tomcat"
    if [ -d $TOMCAT_DIR ]; then 
        Stat 10
    else 
        wget -qO- $TOMCAT_URL | tar -xz &>>$LOG
        Stat $?
    fi
    rm -rf $TOMCAT_DIR/webapps/*
    Info "Downloading WAR File"
    wget $WAR_URL -O $TOMCAT_DIR/webapps/student.war &>>$LOG
    Stat $? 
    Info "Downloading JDBC Jar file"
    wget $JDBC_URL -O $TOMCAT_DIR/lib/mysql-connector-java-5.1.40.jar &>>$LOG
    Stat $?
    sed -i -e '/TestDB/ d' -e "$ i $CONN_STRING" $TOMCAT_DIR/conf/context.xml
    ps -ef | grep /opt/$TOMCAT_DIR | grep -v grep  &>>$LOG 
    if [ $? -eq 0 ]; then 
        Info "Stopping Tomcat"
        sh $TOMCAT_DIR/bin/shutdown.sh &>>$LOG 
        Stat $? 
        sleep 5
    fi
    Info "Starting Tomcat"
    sh $TOMCAT_DIR/bin/startup.sh &>>$LOG
    Stat $?
}


WEBF() {
    HEAD "WEB COMPONENT SETUP"
    Info "Installing HTTPD Server"
    yum install httpd -y &>>$LOG 
    Stat $? 

    Info "Downloading MOD_JK "
    wget $MODJK_URL -O /etc/httpd/modules/mod_jk.so &>>$LOG 
    Stat $?
    Info "Configuring Web Server"
    chmod +x /etc/httpd/modules/mod_jk.so
    echo 'LoadModule jk_module modules/mod_jk.so
JkWorkersFile conf.d/worker.properties
JkMount /student local
JkMount /student/* local' >/etc/httpd/conf.d/mod-jk.conf
    echo 'worker.list=local
worker.local.host=localhost
worker.local.port=8009' >/etc/httpd/conf.d/worker.properties 
    Stat $? 
    Info "Starting Web Server" 
    systemctl enable httpd &>>$LOG 
    systemctl start httpd &>>$LOG 
    Stat $?

}

### Main Program
USER_ID=$(id -u)
if [ $USER_ID -ne 0 ]; then
	echo -e "${R}You need to be a root user to perform this script${N}"
	exit 1
fi


read -p 'Select a component to installl (DB|APP|WEB|ALL): ' comp
case $comp in
    DB) DBF ;;
    APP) APPF ;;
    WEB) WEBF ;;
    ALL)
        DBF
        APPF
        WEBF
        ;;
    *) echo -e "Select one of the component!! Try Again ... "
    exit 1
    ;;
esac


exit

echo
HEAD "WEB COMPONENT SETUP"
Info "Installing HTTPD Server"