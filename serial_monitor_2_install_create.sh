#! /bin/bash

perl -MCPAN -e "install Data::Translate"

mkdir /var/monitor
mkdir /opt/monitor
mkdir /opt/pcontrol
mkdir /etc/pcontrol.d

echo "BINARY=/opt/monitor/serial_server.pl\n
PIDFILE=/var/run/serial_server.pid\n
LOGFILE=/var/log/serial_server.log\n
ARGS=\n
RUN=true\n
MAX_MEM=30000\n
MAX_CPU=9999\n" > /etc/pcontrol.d/serial_server

cd /opt
