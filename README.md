# Azure SQL Managed Instance monitoring with Telegraf

Real-time monitoring solution for Azure SQL Server Managed instances using Telegraf, InfluxDB and grafana. Telegraf now supports managed instances from version 1.8.0.

Given Managed instances server properties and other storage aspects aren't the same as on-premise, a set of dashboards are available as well as described in the blog: 


### Step 1 : Install Git and Docker
##### Ubuntu: 
      sudo apt-get install git -y
      wget -qO- https://get.docker.com/ | sudo sh

##### RHEL/CentOS:
      sudo yum install git -y
      sudo yum install docker -y
      sudo systemctl enable docker
      sudo systemctl start docker

#### ote: On RHEL, SELinux is enabled by default. For the InfluxDB and Grafana containers to start successfully, we either have to disable SELinux, or add the right SELinux policy. With the default RHEL configuration, SELINUX configuration is set to enforcing. Changing this configuration to permissive or disabled will work around this issue. See this documentation article for more information. Alternatively set the right SELinux policy as described here.

### Step 2 : Clone the GitHub repo.
      cd $HOME
      sudo git clone https://github.com/denzilribeiro/sqlmimonitoring.git/

### Step 3 : Install and configure InfluxDB. 
a.	When creating the Azure VM, we added a separate data disk for InfluxDB. Now, mount this disk as /influxdb, following the steps in this documentation article (replace datadrive with influxdb).
b.	Optionally, edit the runinfluxdb.sh file and modify the INFLUXDB_HOST_DIRECTORY variable to point to the directory where you want the InfluxDB volume to be mounted, if it is something other than the default of /influxdb.

      cd $HOME/sqlmimonitoring/influxdb
      sudo vi runinfluxdb.sh

c.	Pull the InfluxDB Docker image.
      cd $HOME/sqlmimonitoring/influxdb
      sudo ./runinfluxdb.sh

### Step 4 : Install Grafana.
      cd $HOME/sqlmimonitoring/grafana
      sudo ./rungrafana.sh

### Step 5: Firewall ports
Optionally, if the firewall is enabled on the VM, create an exception for TCP port 3000 to allow web connections to Grafana.
##### Ubuntu:
        sudo ufw allow 3000/tcp 
        sudo ufw reload
##### RHEL/CentOS:
        sudo firewall-cmd --zone=public --add-port=3000/tcp -permanent
        sudo firewall-cmd --reload

### Step 6: Install Telegraf
Install Telegraf version 1.8.0 or later. Support for MI was first introduced in this version.
##### Ubuntu:
        cd $HOME
        wget https://dl.influxdata.com/telegraf/releases/telegraf_1.8.0-1_amd64.deb
        sudo dpkg -i telegraf_1.8.0-1_amd64.deb

##### RHEL/CentOS:
        cd $HOME
        wget https://dl.influxdata.com/telegraf/releases/telegraf-1.8.0-1.x86_64.rpm
        sudo yum localinstall telegraf-1.8.0-1.x86_64.rpm -y

Other platforms: https://portal.influxdata.com/downloads#telegraf 

### Step 7: Create monitoring Login
Create a login for Telegraf on each of the MI instances you want to monitor, and grant permissions. Here we create a login named telegraf, which is referenced in the Telegraf config file later.
      
        USE master;
        CREATE LOGIN telegraf WITH PASSWORD = N'MyComplexPassword1!', CHECK_POLICY = ON;
        GRANT VIEW SERVER STATE TO telegraf;
        GRANT VIEW ANY DEFINITION TO telegraf;

### Step 8: Configure telegraf
a.	A sample Telegraf configuration file (telegraf.conf) is included in sqlmimonitoring/telegraf for reference, and includes the configuration settings used by the solution and can be copied to /etc/telegraf/telegraf.conf

OR  

b.	Edit the /etc/telegraf/telegraf.conf file to configure these settings. 

      sudo vi /etc/telegraf/telegraf.conf

Uncomment every line shown below, and add a connection string for every instance/server you would like to monitor in the inputs.sqlserver section. Ensure the URL and database name for InfluxDB in the outputs.influxdb section are correct.  

    [[inputs.sqlserver]]
    servers = ["Server=server1.database.windows.net;User Id=telegraf;Password=MyComplexPassword1!;app name=telegraf;"
	   ,"Server=server2.database.windows.net;User Id=telegraf;Password=MyComplexPassword1!;app name=telegraf;"]
    query_version = 2

    [[outputs.influxdb]]
    urls = ["http://127.0.0.1:8086"]
    database = "telegraf"

c.	Note that the default polling interval in Telegraf is 10 seconds. If you want to change this, i.e. for more precise metrics, you will have to change the interval parameter in the [agent] section in the same telegraf.conf file.

d.	Once the changes are made, start the service.  

    sudo systemctl start telegraf

### Step 9: Configure grafana Datasource
In Grafana, create the data source for InfluxDB, and import MI dashboards.    

In this step, [GRAFANA_HOSTNAME_OR_IP_ADDRESS] refers to the public hostname or IP address of the Grafana VM, and [INFLUXDB_HOSTNAME_OR_IP_ADDRESS] refers to the hostname or IP address of the InfluxDB VM (either public or private) that is accessible from the Grafana VM. If using a single VM for all components, these values are the same.  

  a.	Browse to your Grafana instance - http://[GRAFANA_IP_ADDRESS_OR_SERVERNAME]:3000.
      Login with the default user admin with password admin. Grafana will prompt you to change the password on first login.

  b.	Add a data source for InfluxDB.Detailed instructions are at http://docs.grafana.org/features/datasources/influxdb/ 
  
          Click “Add data source”  
          Name: influxdb-01  
          Type: InfluxDB  
          URL: http://[INFLUXDB_HOSTNAME_OR_IP_ADDRESS]:8086. The default of http://localhost:8086 works if Grafana and InfluxDB are on the same machine; make sure to explicitly enter this URL in the field.  
          Database: telegraf  
          Click “Save & Test”. You should see the message “Data source is working”.  
        
  c.	Download Grafana dashboard JSON definitions from the GitHub repo dashboards folder for all dashboards, and then import them into Grafana. When importing each dashboard, make sure use the dropdown labeled InfluxDB-01 to select the data source created in the previous step. Detailed instructions: http://docs.grafana.org/reference/export_import/#importing-a-dashboard

You are done!
