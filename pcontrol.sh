#!/bin/bash

###################################################
### pcontrol.sh									###
### Start and maintain all monitor processes.	###
### A. Caravello 2/7/2013						###
###################################################

# Configuration
LOGFILE=/var/log/process_controller.log

# Some OS Level Preparation
mkdir -p /var/run/monitor

# Get Daemon Info
info ()
{
	PROCESS=$1
	FIELD=$2
	PATH=/etc/pcontrol.d/$PROCESS
	if [ ! -e $PATH ]
	then
		echo "No config file to load: $PATH" >> $LOGFILE
		exit 1
	fi
	VALUE=`/bin/grep "$FIELD=" /etc/pcontrol.d/$PROCESS|/usr/bin/cut -d'=' -f2-`
	echo $VALUE
}

# CPU Used
cpu_used ()
{
	PROCESS=$1
	PID=$(status $PROCESS)
	CPU_USED=`/bin/ps -p $PID -o pcpu --no-headers|/usr/bin/cut -d. -f1`
	echo $CPU_USED
}

# Memory Used
mem_used ()
{
	PROCESS=$1
	PID=$(status $PROCESS)
	MEM_USED=`/bin/ps -p $PID -o rss --no-headers`
	echo $MEM_USED
}

# Get Process Status
status ()
{
	PROCESS=$1
	PIDFILE=$(info $PROCESS PIDFILE)

	if [ -z "$PIDFILE" ]
	then
		PIDFILE=/var/run/$PROCESS.pid
	fi

	if [ -e "$PIDFILE" ]
	then
		PID=`cat $PIDFILE`
		PID="${PID%\\n}"
		if /bin/ps -p $PID > /dev/null
		then
			echo $PID
		else
			/bin/rm -f $PIDFILE
			echo 0
		fi
	else
		echo 0
	fi
}

# Start Process
start ()
{
	PROCESS=$1
	BINARY=$(info $PROCESS BINARY)
	PIDFILE=$(info $PROCESS PIDFILE)
	LOGFILE=$(info $PROCESS LOGFILE)
	ARGS=$(info $PROCESS ARGS)

	if [ -z "$BINARY" ]
	then
		echo "BINARY not set" >> $LOGFILE
		exit 1
	fi

	if [ ! -e "$BINARY" ]
	then
		echo "Binary file not found" >> $LOGFILE
		exit 1
	fi

	if [ -z "$PIDFILE" ]
	then
		PIDFILE=/var/run/$PROCESS.pid
	fi

	if [ -z "$LOGFILE" ]
	then
		LOGFILE=/var/log/$PROCESS.log
	fi

	PID=$(status $BINARY)
	if [ "$PID" -gt "0" ]
	then
		return 1
	fi

	echo -n "Starting $PROCESS ..." >> $LOGFILE

	if perl -I /opt/spectros/lib $BINARY $ARGS >> $LOGFILE 2>&1 &
	then
		WAIT=10
		while [ $(status $PROCESS) -eq 0 ]
		do
			sleep 1
			let WAIT=$WAIT-1
			if [ $WAIT -eq 0 ]
			then
				echo '[FAILED]' >> $LOGFILE
				return 1
			fi
		done
		echo '[OK]' >> $LOGFILE
		return 0
	else
		echo "[FAILED]" >> $LOGFILE
		return 1
	fi
}

# Stop Process
stop ()
{
	PROCESS=$1
	PID=$(status $PROCESS)
	if [ "$PID" -eq "0" ]
	then
		echo -n "$PROCESS not running" >> $LOGFILE
		return 0
	else
		echo -n "Killing $PROCESS [$PID] ..." >> $LOGFILE
		if kill $PID
		then
			WAIT=10
			while [ $(status $PROCESS) -gt 0 ]
			do
				sleep 1
				let WAIT=$WAIT-1
				if [ $WAIT -eq 0 ]
				then
					echo '[FAILED]' >> $LOGFILE
					return 1
				fi
			done
			echo '[OK]' >> $LOGFILE
			return 0
		else
			echo "[FAILED]" >> $LOGFILE
			return 1
		fi
	fi
}

if [ "$1" == "info" ]
then
	if [ -z "$2" ]
	then
		echo "Process required for info action" >> $LOGFILE
		exit 1
	else
		echo -n "BINARY:  "
		echo $(info $2 BINARY)
		echo -n "PIDFILE: " 
		echo $(info $2 PIDFILE)
		echo -n "ARGS:    "
		echo $(info $2 ARGS)
		echo -n "CPU(%):  "
		echo $(cpu_used $2)
		echo -n "MEM(KB): "
		echo $(mem_used $2)
		exit 0
	fi
elif [ "$1" == "status" ]
then
	if [ -z "$2" ]
	then
		echo "Process required for status action"
		exit 1
	else
		STATUS=$(status $2)
		echo $STATUS
		exit 0
	fi
else
	# Infinite Loop
	while true
	do
		for PROCESS in `/bin/ls /etc/pcontrol.d`
		do
			if [ $(status $PROCESS) -eq 0 ]
			then
				if [ $(info $PROCESS RUN) == 'true' ]
				then
					start $PROCESS
				fi
			else
				if [ $(info $PROCESS RUN) != 'true' ]
				then
					echo "Stopping $PROCESS" >> $LOGFILE
					stop $PROCESS
				else
					# Check Resource Usage
					MEM_USED=$(mem_used $PROCESS)
					MAX_MEM=$(info $PROCESS MAX_MEM)
					CPU_USED=$(cpu_used $PROCESS)
					MAX_CPU=$(info $PROCESS MAX_CPU)
					if [ ! -z "$MAX_MEM" ]
					then
						if [ $MEM_USED -gt $MAX_MEM ]
						then
							echo -n "Too much memory[${MEM_USED} > ${MAX_MEM}]: " >> $LOGFILE
							stop $PROCESS
						fi
					elif [ ! -z "$MAX_CPU" ]
					then
						if [ $CPU_USED -gt $MAX_CPU ]
						then
							echo -n "Too much CPU: " >> $LOGFILE
							stop $PROCESS
						fi
					fi
				fi
			fi
		done
		sleep 1
	done
fi
