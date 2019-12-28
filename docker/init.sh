#!/bin/bash

function wait_db {
  while ! mysqladmin ping -uroot -p${MYSQL_ROOT_PASSWORD} >/dev/null 2>&1;do
    sleep 1
    echo .
  done
}

[[ `hostname` =~ -([0-9]+)$ ]] || exit 1
ordinal=${BASH_REMATCH[1]}
cp /mnt/config-map/pod.cnf /etc/mysql/conf.d/
echo -e "bind-address=$POD_IP" >> /etc/mysql/conf.d/pod.cnf
recent_backup=$(ls -drt /backup/*/ | tail -n 1)
if [ -f "/backup/master_info" ];then
   last_master=$(cat /backup/master_info | awk '{print $1}' )
else
   last_master=-1
fi
echo server-id=$(( $RANDOM % 1000 + 1 )) >> /etc/mysql/conf.d/pod.cnf
if [[ $ordinal -eq 0 && $last_master -eq '-1' ]]; then
  if [ -z "$(ls /opt/mysql/data/)" ];then
      mysql_install_db --datadir=/opt/mysql/data --user=mysql
      chown -R mysql:mysql /opt/mysql/data
  fi
  mysqld_safe --datadir=/opt/mysql/data &
  wait_db
  count_backups=$(ls -dr /backup/*/ | wc -l)
      while [ $(ls -dr /backup/*/ | wc -l) -gt 3 ];do
        echo "Deleting old backup"
        old_backup=$(ls -dr /backup/*/ | tail -n 1)
        rm -rf $old_backup
        rm /backup/cronjob_binlog
      done
  mysql -uroot -p${MYSQL_ROOT_PASSWORD} \
  -e   "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}'; \
        GRANT ALL PRIVILEGES ON *.* TO '${DB_USERNAME}'@'%' IDENTIFIED BY '${DB_PASSWORD}'; \
        GRANT PROCESS, RELOAD, LOCK TABLES, REPLICATION CLIENT ON *.* to 'backup'@'%' IDENTIFIED BY '${BACKUP_PASSWORD}'; \
        GRANT SELECT,REPLICATION SLAVE,REPLICATION CLIENT ON *.* TO 'slave'@'%' IDENTIFIED BY '${SLAVE_PASSWORD}' WITH GRANT OPTION; \
        FLUSH PRIVILEGES;"
  dir_name=$(date "+%b_%d_%Y_%H_%M_%S")
  mkdir /backup/$dir_name
  mariabackup --backup --password=${MYSQL_ROOT_PASSWORD} --user=root --target-dir=/backup/$dir_name --datadir=/opt/mysql/data
else
  mariabackup --prepare --target-dir=$recent_backup
  rsync -B=131072 -ravP --delete-after $recent_backup /opt/mysql/data/
  chown -R mysql:mysql /opt/mysql/data
  mysqld_safe --datadir=/opt/mysql/data &
  wait_db
  #Avoid binlog conflict (the file might have changed during mariadb recovery)
  rsync ${recent_backup}xtrabackup_binlog_info /opt/mysql/data/
fi
exit 0
