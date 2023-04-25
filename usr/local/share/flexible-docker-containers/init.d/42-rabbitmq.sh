#!/bin/bash
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

fdc_notice "Setting up RabbitMQ permissions"

# Make sure our data directory perms are correct
chown root:rabbitmq /var/lib/rabbitmq
chmod 0770 /var/lib/rabbitmq
# Set permissions on Minio configuration
chown root:rabbitmq /etc/rabbitmq
chmod 0750 /etc/rabbitmq


fdc_notice "Setting up RabbitMQ environment"

RABBITMQ_NODENAME=${RABBITMQ_NODENAME:-rabbitmq}

RABBITMQ_ADMIN_USERNAME=${RABBITMQ_ADMIN_USERNAME:-rabbitmqadmin}
RABBITMQ_ADMIN_PASSWORD=${RABBITMQ_ADMIN_PASSWORD:-}

RABBITMQ_USERNAME=${RABBITMQ_USERNAME:-}
RABBITMQ_PASSWORD=${RABBITMQ_PASSWORD:-}


# Set database directory name so it doesn't get changed when our hostname changes (Docker)
# shellcheck disable=SC2034
RABBITMQ_MNESIA_DIR="mnesia"


# Check if IPv6 is enabled and enable listening
if [ -n "$(ip -6 route show default)" ]; then
	sed -i -e 's|#management.tcp.ip = ::|management.tcp.ip = ::|' /etc/rabbitmq/conf.d/10-defaults.conf
	# shellcheck disable=SC2034
	RABBITMQ_SERVER_ADDITIONAL_ERL_ARGS="-proto_dist inet6_tcp"
	# shellcheck disable=SC2034
	RABBITMQ_CTL_ERL_ARGS="-proto_dist inet6_tcp"
fi


# Write out environment and fix perms of the config file
set | grep -E '^RABBITMQ_' | grep -vE '^RABBITMQ_(ADMIN_)?(USERNAME|PASSWORD)' | \
	sed -e 's/^RABBITMQ_//' > /etc/rabbitmq/rabbitmq-env.conf || true
chown root:rabbitmq /etc/rabbitmq/rabbitmq-env.conf
chmod 0640 /etc/rabbitmq/rabbitmq-env.conf


# Generate user details to load into the database
if [ ! -d /var/lib/rabbitmq/mnesia ]; then
	(
		fdc_info "Adding RabbitMQ admin user"
		export RABBITMQ_ADMIN_USERNAME
		export RABBITMQ_ADMIN_PASSWORD
		if [ -n "$RABBITMQ_USERNAME" ] && [ -n "$RABBITMQ_PASSWORD" ]; then
			fdc_info "Adding RabbitMQ user"
			export RABBITMQ_USERNAME
			export RABBITMQ_PASSWORD
		fi
		/usr/local/sbin/create-rabbitmq-definitions
	)
fi

# Enable RabbitMQ management plugin
echo "[rabbitmq_management]." > /etc/rabbitmq/enabled_plugins
