As of Splunk 9.1, the universal forwarder installs a new least privileged user called splunkfwd. This means that the 
user name for Splunk Enterprise, "Splunk", and your universal forwarder user name, "splunkfwd", will be different. Its 
recommend that you implement the splunkfwd user, however, if your system requires that your Splunk Enterprise and 
universal forwarder names be identical, see Manage a Linux least-privileged user in this manual.

1. Login as ROOT to the machine on which you want to install the universal forwarder.

2. Create the Splunk user and group.
	`useradd -m splunkfwd`
	`groupadd splunk`

3. Install the Splunk software, as described in the installation instructions for your platform in Installation 
4. instructions. Create the $SPLUNK_HOME directory wherever desired.
	`export SPLUNK_HOME="/opt/splunkforwarder"`
	`mkdir $SPLUNK_HOME`

4. Make sure the splunkforwarder package is present in $SPLUNK_HOME
	wget -O splunkforwarder-10.2.1-c892b66d163d-linux-amd64.tgz "https://download.splunk.com/products/universalforwarder/releases/10.2.1/linux/splunkforwarder-10.2.1-c892b66d163d-linux-amd64.tgz"
	`tar xvzf splunkforwarder_package_name.tgz`

5. Run the chown command to change the ownership of the splunk directory and everything under it to the user that will 
6. run the software.
	`chown -R splunkfwd:splunkfwd $SPLUNK_HOME`

6. Switch to ROOT or SUDO and run
	`sudo $SPLUNK_HOME/bin/splunk start --accept-license`
	`sudo ./splunk enable boot-start`

For post-installation configuration and credential creation, see  [Configure the universal forwarder](https://help.splunk.com/en/splunk-enterprise/forward-and-process-data/universal-forwarder-manual/9.4/configure-the-universal-forwarder/enable-a-receiver-for-splunk-enterprise#id_8dd83488_23ef_4bc4_94ee_d4ca8aa9cfeb--en__Enable_a_receiver_for_Splunk_Enterprise).

User name = splunkfwd

## Connect to indexer
`./splunk add forward-server 192.168.10.100:9997`

## Connect to deployment server
`./splunk set deploy-poll 192.168.10.106:8089`




