#!/bin/bash

#
# Main script - Master/Slave cluster 
#
echo "Background script launched"
sleep 10
while :
do
	#Getting info from existing master
	if [ -f "/backup/master_info" ];
	then
		ordinal=$(cat /backup/master_info | awk '{print $1}' )
	else
		ordinal=0
	fi

	mysql -h mysql-${ordinal}.mysql.default.svc.cluster.local -uslave -p${SLAVE_PASSWORD} -e 'SELECT 1' &> /dev/null
	
	if [ "$?" -eq 0 ];then
		echo "Peer ${ordinal} already online."
	else
		#Looking for the first available pod
		while ! mysql -h mysql-${ordinal}.mysql.default.svc.cluster.local -uslave -p${MYSQL_ROOT_PASSWORD} -e 'SELECT 1' &> /dev/null
		do
			sleep 1
			((ordinal+=1))
			if [ $ordinal -gt 9 ]
			then
			     echo "ERROR - MariaDB cluster unreachable"
			     ordinal=0
			fi
		done
	fi
	
	#Ensure that this mysql instance is ready for requests
	while !(mysqladmin ping -uroot -p${MYSQL_ROOT_PASSWORD} --host=$POD_IP &> /dev/null)
	do
		sleep 1
	done
        
	#Deleting file containing the encryption keys (already loaded into memory)	
	[ -f "/mysql_conf/.keys" ] && rm /mysql_conf/.keys

	MASTER_IP=$(dig +short mysql-$ordinal.mysql.default.svc.cluster.local)
	
	if [ -z "$MASTER_IP" ];then
		sleep 3
		continue
	fi
	
	if [ "$POD_IP" == "$MASTER_IP" ];
	then
		#Master init
		echo "Serving now as the master - $MASTER_IP"
		mysql -h $POD_IP -uroot -p${MYSQL_ROOT_PASSWORD}<<EOF
		STOP SLAVE;
		RESET SLAVE;
EOF

		[ "${ordinal}" -ne 0 ] && echo "mysql-bin.000001 4" > $(ls -drt /backup/*/ | tail -n 1)xtrabackup_binlog_info

          	NEWMASTER_BIN_FILE=$(mysql -h $POD_IP -uroot -p${MYSQL_ROOT_PASSWORD} -e 'show master status' | sed 's/|.*|/|/' | sed '1d' | cut -f 1)
                NEWMASTER_BIN_POS=$(mysql -h $POD_IP -uroot -p${MYSQL_ROOT_PASSWORD} -e 'show master status' | sed 's/|.*|/|/' | sed '1d' | cut -f 2)
                echo "$ordinal $POD_IP $NEWMASTER_BIN_FILE $NEWMASTER_BIN_POS" > /backup/master_info

		mysql -h $POD_IP -uroot -p${MYSQL_ROOT_PASSWORD} -e "SET GLOBAL read_only=0;"

		sleep infinity

	else
		#Slave init
		echo "Switching to the master"
		if [ -f "/opt/mysql/data/xtrabackup_binlog_info" ];then
			echo "Reading BIN data from latest backup"
			BIN_FILE=$(cat /opt/mysql/data/xtrabackup_binlog_info | awk '{print $1}')
			BIN_POS=$(cat /opt/mysql/data/xtrabackup_binlog_info | awk '{print $2}')
			rm /opt/mysql/data/xtrabackup_binlog_info
		else
			while [ $(cat /backup/master_info | awk '{print $2}') != "$MASTER_IP" ];
			do
				sleep 1
			done
				BIN_FILE=$(cat /backup/master_info | awk '{print $3}')
				BIN_POS=$(cat /backup/master_info | awk '{print $4}')
		fi
		if [[ -z "$BIN_FILE" ]];
                then
			echo "Error: cannot get bin data from master"
			continue
		fi

		[ "$BIN_POS" -eq 4 ] && echo "WARNING: Bin info was reset. This could mean that the cluster recovered from master crash"

		echo -e "--- Bin data received ---\n- MASTER IP: $MASTER_IP \n- BIN FILE: $BIN_FILE\n- BIN POS: $BIN_POS"
		mysql -h $POD_IP -uroot -p${MYSQL_ROOT_PASSWORD}<<EOF
		STOP SLAVE;
		CHANGE MASTER TO 
		MASTER_HOST='${MASTER_IP}',
		MASTER_USER='slave',
		MASTER_PASSWORD='${SLAVE_PASSWORD}',
		MASTER_LOG_FILE='${BIN_FILE}',
		MASTER_LOG_POS=${BIN_POS};
		START SLAVE;
                SET GLOBAL read_only=1;
EOF
                echo "Connected"
	fi

	#Verifying the reachability of the master
	while (mysql -h $MASTER_IP -uslave -p${SLAVE_PASSWORD} -e 'SELECT 1' &> /dev/null)
	do
		sleep 3
	done
	echo "Master is down"
done
