# Copyright (c) 2022-2023, AllWorldIT.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to
# deal in the Software without restriction, including without limitation the
# rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
# sell copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
# IN THE SOFTWARE.


FROM registry.conarx.tech/containers/alpine/3.18 as builder

ENV RABBITMQ_VER=3.12.10


COPY usr/local/sbin/rabbitmq-script-wrapper /build/scripts/

# Install libs we need
# ref https://github.com/archlinux/svntogit-community/blob/packages/rabbitmq/trunk/PKGBUILD
RUN set -eux; \
	true "Installing dependencies"; \
	apk add --no-cache \
		build-base \
		\
		gawk \
		erlang \
		elixir \
		curl \
		git \
		rsync \
		sudo

# Download packages
RUN set -eux; \
	mkdir -p build; \
	cd build; \
	true "Versioning..."; \
	erl --version; \
	true "RabbitMQ..."; \
	wget "https://github.com/rabbitmq/rabbitmq-server/releases/download/v$RABBITMQ_VER/rabbitmq-server-$RABBITMQ_VER.tar.xz"; \
	tar -Jxf rabbitmq-server-${RABBITMQ_VER}.tar.xz; \
	cd "rabbitmq-server-$RABBITMQ_VER"; \
	true "Prepare RabbitMQ sources..."; \
	# Do not default SYS_PREFIX to RABBITMQ_HOME, leave it empty
	sed -E 's|^(SYS_PREFIX=).*$|\1|' -i deps/rabbit/scripts/rabbitmq-defaults; \
	grep -qE 'SYS_PREFIX=' "deps/rabbit/scripts/rabbitmq-defaults"; \
	sed -e "s|%%VSN%%|$RABBITMQ_VER|" -i deps/rabbitmq_management/bin/rabbitmqadmin; \
	sed -e "s|/usr/|/usr/local/|" -i scripts/rabbitmq-script-wrapper; \
	\
	true "Build RabbitMQ..."; \
	make -j$(nproc) -l 8; \
	true "Install RabbitMQ..."; \
	RABBITMQ_DESTDIR=/build/rabbitmq-root; \
	RABBITMQ_ROOT=/usr/local; \
	make \
		DESTDIR="$RABBITMQ_DESTDIR" \
		PREFIX="$RABBITMQ_ROOT" \
		RMQ_ROOTDIR="$RABBITMQ_ROOT/lib/rabbitmq" \
		install install-bin; \
	mkdir -p "$RABBITMQ_DESTDIR/var/lib/rabbitmq"; \
	mkdir -p "$RABBITMQ_DESTDIR/var/log/rabbitmq"; \
	mkdir -p "$RABBITMQ_DESTDIR/etc/rabbitmq/conf.d"; \
	mkdir -p "$RABBITMQ_DESTDIR/etc/rabbitmq/definitions.d"; \
	# Use script wrapper for better bin handling
	RABBITMQ_LIBDIR="$RABBITMQ_ROOT/lib/rabbitmq/lib/rabbitmq_server-$RABBITMQ_VER"; \
	RABBITMQ_MANAGEMENT_DIR="$RABBITMQ_LIBDIR/plugins/rabbitmq_management-$RABBITMQ_VER"; \
	install -d "$RABBITMQ_DESTDIR/$RABBITMQ_ROOT/sbin"; \
	install -Dm 755 ../scripts/rabbitmq-script-wrapper -t "$RABBITMQ_DESTDIR/$RABBITMQ_ROOT/lib/rabbitmq/sbin"; \
	install -m 755 "$RABBITMQ_DESTDIR/$RABBITMQ_MANAGEMENT_DIR/priv/www/cli/rabbitmqadmin" "$RABBITMQ_DESTDIR/$RABBITMQ_ROOT/lib/rabbitmq/bin/rabbitmqadmin"; \
	for script in "$RABBITMQ_DESTDIR/$RABBITMQ_ROOT/lib/rabbitmq/bin/rabbit"*; do \
		ln -sv \
			"../lib/rabbitmq/sbin/rabbitmq-script-wrapper" \
			"$RABBITMQ_DESTDIR/$RABBITMQ_ROOT/sbin/${script#$RABBITMQ_DESTDIR/$RABBITMQ_ROOT/lib/rabbitmq/bin/}"; \
	done; \
	# verify assumption of no stale cookies
	[ ! -e "/var/lib/.erlang.cookie" ]; \
	# Create user for testing below
	addgroup -S rabbitmq 2>/dev/null; \
	adduser -S -D -H -h /var/lib/rabbitmq -s /bin/sh -G rabbitmq -g rabbitmq rabbitmq; \
	# Temporarily create /var/lib/rabbitmq for the tests below; \
	mkdir /var/lib/rabbitmq; \
	chown root:rabbitmq /var/lib/rabbitmq; \
	chmod 770 /var/lib/rabbitmq; \
	# Ensure RabbitMQ was installed correctly by running a few commands that do not depend on a running server, as the rabbitmq user
	# If they all succeed, it's safe to assume that things have been set up correctly
	sudo -u rabbitmq -- /build/rabbitmq-root/usr/local/lib/rabbitmq/bin/rabbitmqctl help; \
	sudo -u rabbitmq -- /build/rabbitmq-root/usr/local/lib/rabbitmq/bin/rabbitmqctl list_ciphers; \
	sudo -u rabbitmq -- /build/rabbitmq-root/usr/local/lib/rabbitmq/bin/rabbitmq-plugins list; \
	sudo -u rabbitmq -- /build/rabbitmq-root/usr/local/lib/rabbitmq/bin/rabbitmqadmin help

RUN set -eux; \
	cd build/rabbitmq-root; \
	scanelf --recursive --nobanner --osabi --etype "ET_DYN,ET_EXEC" .  | awk '{print $3}' | xargs -r \
		strip \
			--remove-section=.comment \
			--remove-section=.note \
			-R .gnu.lto_* -R .gnu.debuglto_* \
			-N __gnu_lto_slim -N __gnu_lto_v1 \
			--strip-unneeded



FROM registry.conarx.tech/containers/alpine/3.18


ARG VERSION_INFO=
LABEL org.opencontainers.image.authors   "Nigel Kukard <nkukard@conarx.tech>"
LABEL org.opencontainers.image.version   "3.18"
LABEL org.opencontainers.image.base.name "registry.conarx.tech/containers/alpine/3.18"

# NK: things need to run with UTF-8 to prevent weirdness
ENV LANG=C.UTF-8 LANGUAGE=C.UTF-8 LC_ALL=C.UTF-8

# Copy in built binaries
COPY --from=builder /build/rabbitmq-root /

RUN set -eux; \
	true "RabbitMQ depedencies"; \
	apk add --no-cache \
		erlang \
		sudo; \
	true "User setup"; \
	addgroup -S rabbitmq 2>/dev/null; \
	adduser -S -D -H -h /var/lib/rabbitmq -s /bin/nologin -G rabbitmq -g rabbitmq rabbitmq; \
	true "Cleanup"; \
	rm -f /var/cache/apk/*; \
	# Make sure any stale cookie is deleted
	rm -f "/var/lib/rabbitmq/.erlang.cookie"; \
	# Disable  syslog
	rm -f "/etc/supervisor/conf.d/syslog-ng.conf"


# RabbitMQ
COPY etc/supervisor/conf.d/rabbitmq.conf /etc/supervisor/conf.d
COPY etc/rabbitmq/conf.d/10-defaults.conf /etc/rabbitmq/conf.d
COPY etc/rabbitmq/conf.d/50-import-definitions.conf /etc/rabbitmq/conf.d
COPY usr/local/sbin/create-rabbitmq-definitions /usr/local/sbin
COPY usr/local/sbin/rabbitmq-script-wrapper /usr/local/sbin
COPY usr/local/share/flexible-docker-containers/healthcheck.d/42-rabbitmq.sh /usr/local/share/flexible-docker-containers/healthcheck.d
COPY usr/local/share/flexible-docker-containers/init.d/42-rabbitmq.sh /usr/local/share/flexible-docker-containers/init.d
COPY usr/local/share/flexible-docker-containers/pre-init-tests.d/42-rabbitmq.sh /usr/local/share/flexible-docker-containers/pre-init-tests.d
COPY usr/local/share/flexible-docker-containers/tests.d/42-rabbitmq.sh /usr/local/share/flexible-docker-containers/tests.d
RUN set -eux; \
	true "Flexible Docker Containers"; \
	if [ -n "$VERSION_INFO" ]; then echo "$VERSION_INFO" >> /.VERSION_INFO; fi; \
	chown root:root \
		/usr/local/sbin/create-rabbitmq-definitions; \
	chown root:rabbitmq \
		/etc/rabbitmq \
		/var/lib/rabbitmq \
		/var/log/rabbitmq; \
	chmod 0750 \
		/etc/rabbitmq; \
	chmod 0775 \
		/usr/local/sbin/create-rabbitmq-definitions \
		/var/lib/rabbitmq \
		/var/log/rabbitmq; \
	fdc set-perms


EXPOSE 4369
EXPOSE 5671
EXPOSE 5672
EXPOSE 15671
EXPOSE 15672
EXPOSE 15691
EXPOSE 15692
EXPOSE 25672
