FROM ubuntu:14.04
ENV DEBIAN_FRONTEND noninteractive

ENV NAGIOS_HOME /opt/nagios
ENV NAGIOS_USER nagios
ENV NAGIOS_GROUP nagios
ENV NAGIOS_CMDUSER nagios
ENV NAGIOS_CMDGROUP nagios
ENV NAGIOSADMIN_USER nagiosadmin
ENV NAGIOSADMIN_PASS nagios
ENV APACHE_RUN_USER nagios
ENV APACHE_RUN_GROUP nagios
ENV NAGIOS_TIMEZONE UTC
ENV NAGIOS_VER nagios-4.1.1
ENV NAGIOS_PLUG_VER nagios-plugins-2.1.1
ENV DOWNURLNAGIOS https://sourceforge.net/projects/nagios/files/nagios-4.x/nagios-4.1.1/${NAGIOS_VER}.tar.gz/download
ENV DOWNURLPLUG http://nagios-plugins.org/download/${NAGIOS_PLUG_VER}.tar.gz
ENV DOWNNRDP https://assets.nagios.com/downloads/nrdp/nrdp.zip


# Setup environment
RUN sed -i 's/universe/universe multiverse/' /etc/apt/sources.list
RUN apt-get update && apt-get install -y iputils-ping netcat build-essential snmp snmpd snmp-mibs-downloader php5-cli apache2 apache2-utils libapache2-mod-php5 runit bc postfix bsd-mailx unzip

# Create Users
RUN ( egrep -i  "^${NAGIOS_GROUP}" /etc/group || groupadd $NAGIOS_GROUP ) && ( egrep -i "^${NAGIOS_CMDGROUP}" /etc/group || groupadd $NAGIOS_CMDGROUP )
RUN ( id -u $NAGIOS_USER || useradd --system $NAGIOS_USER -g $NAGIOS_GROUP -d $NAGIOS_HOME ) && ( id -u $NAGIOS_CMDUSER || useradd --system -d $NAGIOS_HOME -g $NAGIOS_CMDGROUP $NAGIOS_CMDUSER )

# Setup Nagios
ADD $DOWNURLNAGIOS /tmp/nagios.tar.gz
RUN cd /tmp && tar -zxvf nagios.tar.gz && cd nagios-4.1.1  && ./configure --prefix=${NAGIOS_HOME} --exec-prefix=${NAGIOS_HOME} --enable-event-broker --with-nagios-command-user=${NAGIOS_CMDUSER} --with-command-group=${NAGIOS_CMDGROUP} --with-nagios-user=${NAGIOS_USER} --with-nagios-group=${NAGIOS_GROUP} && make all && make install && make install-config && make install-commandmode && cp daemon-init /etc/init.d/nagios && chmod +x /etc/init.d/nagios && cp sample-config/httpd.conf /etc/apache2/conf-available/nagios.conf && cd /etc/apache2/conf-enabled && ln -s /etc/apache2/conf-available/nagios.conf 

# Setup nagios Plugins
ADD $DOWNURLPLUG /tmp/nagios-plugins-2.1.1.tar.gz
RUN cd /tmp && tar -zxvf nagios-plugins-2.1.1.tar.gz && cd nagios-plugins-2.1.1 && ./configure --prefix=${NAGIOS_HOME} && make && make install

# Setup apache
RUN sed -i.bak 's/.*\=www\-data//g' /etc/apache2/envvars && echo "export APACHE_RUN_USER=www-data" >> /etc/apache2/envvars && echo "export APACHE_RUN_GROUP=www-data" >> /etc/apache2/envvars
RUN sed -i 's/^ULIMIT_MAX_FILES/#ULIMIT_MAX_FILES/g' /usr/sbin/apache2ctl
RUN export DOC_ROOT="DocumentRoot $(echo $NAGIOS_HOME/share)"; sed -i "s,DocumentRoot.*,$DOC_ROOT," /etc/apache2/sites-available/000-default.conf

# Setup Nagios
RUN ln -s ${NAGIOS_HOME}/bin/nagios /usr/local/bin/nagios && mkdir -p /usr/share/snmp/mibs && chmod 0755 /usr/share/snmp/mibs && touch /usr/share/snmp/mibs/.foo

RUN echo "use_timezone=$NAGIOS_TIMEZONE" >> ${NAGIOS_HOME}/etc/nagios.cfg && echo "SetEnv TZ \"${NAGIOS_TIMEZONE}\"" >> /etc/apache2/conf-available/nagios.conf

RUN mkdir -p ${NAGIOS_HOME}/etc/conf.d && mkdir -p ${NAGIOS_HOME}/etc/monitor && ln -s /usr/share/snmp/mibs ${NAGIOS_HOME}/libexec/mibs
RUN echo "cfg_dir=${NAGIOS_HOME}/etc/conf.d" >> ${NAGIOS_HOME}/etc/nagios.cfg && echo "cfg_dir=${NAGIOS_HOME}/etc/monitor" >> ${NAGIOS_HOME}/etc/nagios.cfg
RUN download-mibs && echo "mibs +ALL" > /etc/snmp/snmp.conf

RUN sed -i 's,/bin/mail,/usr/bin/mail,' /opt/nagios/etc/objects/commands.cfg && \
    sed -i 's,/usr/usr,/usr,' /opt/nagios/etc/objects/commands.cfg
RUN cp /etc/services /var/spool/postfix/etc/


# Setup NRDPE
ADD $DOWNNRDPE /tmp/nrdp.zip
RUN cd /tmp && unzip nrdp.zip


ADD start.sh /usr/local/bin/start_nagios
RUN chmod +x /usr/local/bin/start_nagios

ENV APACHE_LOCK_DIR /var/run
ENV APACHE_LOG_DIR /var/log/apache2

EXPOSE 80

VOLUME /opt/nagios/var
VOLUME /opt/nagios/etc
VOLUME /opt/nagios/libexec
VOLUME /var/log/apache2
VOLUME /usr/share/snmp/mibs

#CMD ["/bin/bash"]
CMD ["/usr/local/bin/start_nagios"]
