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


fdc_test_start rabbitmq "Checking RabbitMQ responds to admin creating queue over IPv4"
if ! rabbitmqadmin --host 127.0.0.1 --username=testadmin --password=testadminpass declare queue name=testadminqueue; then
	fdc_test_fail rabbitmq "Creating queue as admin failed over IPv4"
	false
fi
fdc_test_pass rabbitmq "Created RabbitMQ queue as admin over IPv4"


fdc_test_start rabbitmq "Checking RabbitMQ responds to user creating queue over IPv4"
if ! amqp-declare-queue --server=127.0.0.1 --username=testuser --password=testpass --queue=testuserqueue; then
	fdc_test_fail rabbitmq "Creating queue as user failed over IPv4"
	false
fi
fdc_test_pass rabbitmq "Created RabbitMQ queue as user over IPv4"



# Return if we don't have IPv6 support
if [ -z "$(ip -6 route show default)" ]; then
	fdc_test_alert nginx "Not running IPv6 tests due to no IPv6 default route"
	return
fi


fdc_test_start rabbitmq "Checking RabbitMQ responds to admin creating queue over IPv6"
if ! rabbitmqadmin --host ::1 --username=testadmin --password=testadminpass declare queue name=testadminqueue6; then
	fdc_test_fail rabbitmq "Creating queue as admin failed over IPv6"
	false
fi
fdc_test_pass rabbitmq "Created RabbitMQ queue as admin over IPv6"


fdc_test_start rabbitmq "Checking RabbitMQ responds to user creating queue over IPv6"
if ! amqp-declare-queue --url="amqp://testuser:testpass@[::1]" --queue=testuserqueue6; then
	fdc_test_fail rabbitmq "Creating queue as user failed over IPv6"
	false
fi
fdc_test_pass rabbitmq "Created RabbitMQ queue as user over IPv6"
