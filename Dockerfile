FROM ubuntu:18.04

# Install required packages.
RUN \
	apt-get -yq update && \
	apt-get -yq upgrade && \
	# Dependencies.
	apt-get -yq install \
		apache2 \
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
		libdbd-pg-perl \
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
		libtheschwartz-perl \
		liburi-perl \
		libxml-twig-perl \
		libxmlrpc-lite-perl \
		patchutils \
	&& \
	apt-get -yq clean && \
	rm -rf /var/lib/apt/*

# Install non-packaged perl modules.
RUN \
	apt-get update && \
	apt-get -yq install \
		make \
	&& \
	cpan -i PatchReader && \
	rm -rf /root/.cpan && \
	apt-get -yq purge \
		make \
	&& \
	apt-get -yq autoremove && \
	apt-get -yq clean && \
	rm -rf /var/lib/apt/*

# Install bugzilla.
RUN \
	apt-get update && \
	apt-get -yq install \
		git \
	&& \
	cd /var/www/html && \
	git clone --branch release-5.0-stable https://github.com/bugzilla/bugzilla && \
	apt-get -yq purge \
		git \
	&& \
	apt-get -yq autoremove && \
	apt-get -yq clean && \
	rm -rf /var/lib/apt/*

# Install configuration files.
#COPY rootfs/ /

# Configure apache.
RUN \
#	cd /etc/apache2/ && \
#	patch < httpd.conf.diff
	a2enmod cgid && \
	a2enmod expires && \
	a2enmod headers && \
	a2enmod rewrite && \
	true

# Fix permissions of bugzilla tree.
RUN \
	chown -R www-data:www-data /var/www/html/bugzilla

# Run as the www-data user.
USER www-data

# Set working directory to bugzilla area.
WORKDIR /var/www/html/bugzilla
