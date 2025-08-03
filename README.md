# OZO MariaDB Backup Installation and Configuration

## Overview
This script creates a dump of all MariaDB databases and performs history maintenance. It runs with no arguments. When executed, it iterates through the MariaDB databases and creates a compressed dump file in `MARIADB_DUMP_DIR` (typically `/var/lib/mysql-dump`). Upon successfully dumping a database, it will delete any dump files older than `MARIADB_DUMP_KEEP_DAYS` days. This script should work with MySQL, too.

## Prerequisites
Install MariaDB, start services, and create a `mysql-backup` database user (substituting a strong password for '****************'.)

### AlmaLinux, Red Hat Enterprise Linux, Rocky Linux
```
dnf -y install mariadb mariadb-server
systemctl enable --now mariadb
mysqladmin -u root password '****************'
mysql -u root -p
mysql> GRANT SELECT, RELOAD, LOCK TABLES, SHOW VIEW ON *.* TO 'mysql-backup'@'localhost' IDENTIFIED BY '****************';
mysql> flush privileges;
mysql> quit;
```
### Debian
PENDING.

## Installation
To install this script on your system, you must first register the One Zero One repository.

### AlmaLinux 10, Red Hat Enterprise Linux 10, Rocky Linux 10 (RPM)
```bash
rpm -Uvh https://repositories.onezeroone.dev/el/10/noarch/onezeroone-release-latest.el10.noarch.rpm
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-ONEZEROONE
dnf repolist
dnf -y install ozo-mariadb-backup
```

### Debian (DEB)
PENDING.

## Configuration
### Modify /etc/ozo-mariadb-backup.conf
Set `MARIADB_DUMP_PASS` with the password you create for `mysql-backup` in the prerequisite steps, above. Review the remaining variables and adjust as needed to suit your environment.

|Variable|Example Value|Description|
|--------|-------------|-----------|
|MARIADB_DUMP_USER|`"mysql-backup"`|The user that was granted permission to dump all databases.|
|MARIADB_DUMP_PASS|`"****************"`|The password for the `MARIADB_DUMP_USER` user.|
|MARIADB_DUMP_DIR|`"/var/lib/mysql-dump"`|The output directory for compressed dump files. The script will attempt to create this directory if it does not already exist.|
|MARIADB_DUMP_SKIP_DB|`"information_schema performance_schema"`|A space-separated list of databases to skip.|
|MARIADB_DUMP_KEEP_DAYS|`3`|Number of database backups to keep in `MARIADB_DUMP_DIR`. This number can be low if backups are routinely performed of the system running MariaDB.|

### Configure Cron
Modify `/etc/cron.d/ozo-mariadb-backup` to suit your scheduling needs. The default configuration runs `ozo-mariadb-backup.sh` every day at 4:00am.

## Notes
Please visit [One Zero One](https://onezeroone.dev) to learn more about my other work.
