#!/bin/bash
dir_name=$(date '+%b_%d_%Y_%H_%M_%S')
mkdir /backup/$dir_name
rm /backup/cronjob_binlog
for i in {0..9};
do
  mysql -h mysql-${i}.mysql -uslave -p${SLAVE_PASSWORD} -e 'SELECT 1' &> /dev/null
  if [ "$?" -eq 0 ];then
    BINLOG=$(mysql -h mysql-${i}.mysql -uslave -p${SLAVE_PASSWORD} -e 'show master status' | sed 's/|.*|/|/' | sed '1d')
    echo "mysql-${i} $BINLOG" >> /backup/cronjob_binlog
  fi
done

mariabackup --backup --password=${MYSQL_ROOT_PASSWORD} --host=${POD_IP} --user=root --target-dir=/backup/$dir_name --datadir=/opt/mysql/data
count_backups=$(ls -dr /backup/*/ | wc -l)
while [ $(ls -dr /backup/*/ | wc -l) -gt 3 ];do
	echo "Deleting old backup"
	old_backup=$(ls -dr /backup/*/ | tail -n 1)
	rm -rf $old_backup
done

