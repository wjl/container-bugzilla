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

# Install bugzilla.
RUN \
	cd /var/www/html && \
	git clone --branch release-5.0-stable https://github.com/bugzilla/bugzilla

# Install configuration files.
COPY files/ /

# Setup apache.
RUN \
	cd /etc/apache2/ && \
	patch -p0 < apache2.conf.diff && \
	a2enmod cgid && \
	a2enmod expires && \
	a2enmod headers && \
	a2enmod rewrite && \
	ln -sf /dev/console /var/log/apache2/access.log && \
	ln -sf /dev/console /var/log/apache2/error.log && \
	apache2ctl -t

# Setup bugzilla.
RUN \
	cd /var/www/html/bugzilla && \
	./checksetup.pl --check-modules && \
	#rm localconfig && \
	chown -R www-data:www-data .

# Setup mariadb
RUN \
	cd /etc/mysql/ && \
	patch -p0 < mysql.conf.diff && \
	ln -sf /dev/console /var/log/mysql/error.log

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
