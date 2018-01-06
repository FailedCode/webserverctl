# Webserverctl

A little console gui to enable/disable webserver configuration files.

### Why?
Because nginx does not come with an enable/disable site script and `a2ensite` and `a2dissite` are little better than nothing.

### What does it do?
It reads the sites-available and site-enabled directories, lets you activate sites via console gui and restarts the webserver.

### Install
`git clone https://github.com/FailedCode/webserverctl.git /opt/webserverctl`

`ln -s /opt/webserverctl/webserverctl.sh /usr/bin/webserverctl`
