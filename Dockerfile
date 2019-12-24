FROM ubuntu:18.04

# Install required packages.
RUN \
	apt-get -yq update && \
	apt-get -yq upgrade && \
	# Dependencies.
	apt-get -yq install \
		apache2 \
		cron \
		git \
		graphviz \
		libappconfig-perl \
		libauthen-radius-perl \
		libcache-memcached-perl \
		libcgi-pm-perl \
		libchart-perl \
		libdaemon-generic-perl \
		libdate-calc-perl \
		libdatetime-perl \
		libdatetime-timezone-perl \
		libdbd-mysql-perl \
		libdbi-perl \
		libemail-mime-perl \
		libemail-reply-perl \
		libemail-sender-perl \
		libencode-detect-perl \
		libfile-copy-recursive-perl \
		libfile-mimeinfo-perl \
		libfile-which-perl \
		libhtml-formattext-withlinks-perl \
		libhtml-scrubber-perl \
		libjson-rpc-perl \
		libmath-random-isaac-perl \
		libnet-ldap-perl \
		libtemplate-perl \
		libtemplate-plugin-gd-perl \
		libtest-taint-perl \
		libtheschwartz-perl \
		liburi-perl \
		libxml-twig-perl \
		libxmlrpc-lite-perl \
		make \
		mariadb-server \
		patchutils \
		runit \
		wget \
	&& \
	DEBIAN_FRONTEND=noninteractive apt-get install tzdata && \
	apt-get -yq clean && \
	rm -rf /var/lib/apt/*

# Install non-packaged perl modules.
RUN \
	cpan -i \
		PatchReader \
	&& \
	rm -rf /root/.cpan

# Install configuration files.
COPY files/ /

# Setup mariadb
RUN \
	cd /etc/mysql/ && \
	patch -p0 < mysql.conf.diff && \
	ln -sf /dev/stderr /var/log/mysql/error.log

# Setup apache.
RUN \
	cd /etc/apache2/ && \
	patch -p0 < apache2.conf.diff && \
	a2enmod cgid && \
	a2enmod expires && \
	a2enmod headers && \
	a2enmod rewrite && \
	#ln -sf /proc/1/fd/1 /var/log/apache2/access.log && \
	#ln -sf /proc/1/fd/2 /var/log/apache2/error.log && \
	ln -sf /dev/stdout /var/log/apache2/access.log && \
	ln -sf /dev/stderr /var/log/apache2/error.log && \
	apache2ctl -t

# Install bugzilla & extensions.
RUN \
	# Start up MySQL in the background.
	/etc/runit/1 && \
	runsv /etc/service/mysql & \
	# Intall bugzilla.
	cd /var/www/html && \
	git clone --branch release-5.0-stable https://github.com/bugzilla/bugzilla && \
	chown -R www-data:www-data . && \
	cd bugzilla && \
	./checksetup.pl --check-modules && \
	# Give permissions to the bugzilla database user.
	printf '%s\n' \
		"GRANT" \
			"SELECT, INSERT, UPDATE, DELETE, INDEX, ALTER, CREATE," \
			"LOCK TABLES, CREATE TEMPORARY TABLES, DROP, REFERENCES" \
		"ON" \
			"bugzilla.*" \
		"TO" \
			"bugzilla@localhost" \
		"IDENTIFIED BY 'bugzilla';" \
		\
		"FLUSH PRIVILEGES;" \
	| mysql && \
	# We have to call checksetup twice initially this is a first-time run.
	./checksetup.pl /etc/bugzilla/checksetup.conf && \
	./checksetup.pl /etc/bugzilla/checksetup.conf && \
	# Install extensions, phase 1 (dependencies)
	cd extensions && \
	git clone https://github.com/bayoteers/BayotBase.git && \
	cd .. && \
	./checksetup.pl && \
	# Install extensions, phase 2 (normal extensions)
	cd extensions && \
	# Turn off AgileTools by default; it's a bit too invasive for what it does.
	#git clone https://github.com/bayoteers/AgileTools.git && \
	git clone https://github.com/bayoteers/ChangeLog.git && \
	git clone https://github.com/bayoteers/BugViewPlus.git && \
	git clone https://github.com/bayoteers/ActivityGraph.git && \
	git clone https://github.com/bayoteers/QuickIdeas.git && \
	cd .. && \
	./checksetup.pl && \
	# Install extensions, phase 3 (ones that need patches)
	cd extensions && \
	# Disable TreeViewPlus for now; patch doesn't QUITE apply cleanly to latest Bugzilla.
	# It could easily be fixed, and works fine if the rejected patch is applied by hand.
	#git clone https://github.com/bayoteers/TreeViewPlus.git && \
	cd .. && \
	#patch -p1 < extensions/TreeViewPlus/search_include_dependencies_5.0.patch && \
	./checksetup.pl && \
	# Shutdown MySQL cleanly.
	sv stop mysql

# Define volumes for configuration & data.
VOLUME \
	/var/lib/mysql \
	/var/www/html/bugzilla

# Expose http port.
EXPOSE 80/tcp

# Run apache in the foreground.
ENTRYPOINT ["/sbin/runit"]

# Runit expects a SIGCONT in order to shutdown.
STOPSIGNAL SIGCONT

# Check bugzilla health.
HEALTHCHECK --interval=30m --timeout=10s CMD \
	./testserver.pl http://localhost/bugzilla

# TODO:
# [ ] bugzilla jobqueue service
# [ ] bugzilla extensions
