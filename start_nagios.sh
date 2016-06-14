#!/bin/bash

# Check if the htpasswd.users exsist, if not create from default values.
if [ ! -f ${NAGIOS_HOME}/etc/htpasswd.users ] ; then
  htpasswd -c -b -s ${NAGIOS_HOME}/etc/htpasswd.users ${NAGIOSADMIN_USER} ${NAGIOSADMIN_PASS}
  chown -R nagios.nagios ${NAGIOS_HOME}/etc/htpasswd.users
fi

#Set Security to the directory
for DIR in /usr/local/nagios/etc/ /usr/local/nagiosgraph/var/rrd/
do
	if [ -d $DIR ]; then
		chmod 755 $DIR
	fi
done

# Startup services and application
/etc/init.d/nagios start
/etc/init.d/apache2 start
/usr/local/radar/bin/radar.pl

# Everything is run in the background
# We could create a fancy init here but the hack below is better.
# http://kimh.github.io/blog/en/docker/gotchas-in-writing-dockerfile-en/#hack_to_run_container_in_the_background
tail -f /dev/null
