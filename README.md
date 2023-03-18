# OZO MariaDB Backup

## Overview
This script is intended to run daily and creates a dump of all MariaDB databases (and will work with MySQL, too).

It runs with no arguments. When executed, it iterates through the MariaDB databases and creates a compressed dump file in MARIADB_DUMP_DIR e.g., `/var/lib/mysql-dump`. Upon successfully dumping a database, it will delete any dump files older than MARIADB_DUMP_KEEP_DAYS days (3).

Please visit https://onezeroone.dev to learn more about this script and my other work.

## Setup and Configuration

Install MariaDB e.g., as follows for RedHat-style distributions:

```
# dnf -y install mariadb mariadb-server
```

Enable and start the MariaDB service e.g., as follows for RedHat-style distributions:

```
# systemctl enable --now mariadb
```

Set a strong password for the MariaDB `root` user, substituting your own password for `****************`:

```
# mysqladmin -u root password '****************'
```

Create a mysql-backup user before using this script, substituting your own password for `****************`:

```
# mysql -u root -p`
mysql> GRANT SELECT, RELOAD, LOCK TABLES, SHOW VIEW ON *.* TO 'mysql-backup'@'localhost' IDENTIFIED BY '********';`
mysql> flush privileges;
mysql> quit;
```

### Clone the Repository and Copy Files

Clone this repository to a temporary directory. Then (as `root`):

- Copy `ozo-mariadb-backup.sh` to `/etc/cron.daily` and set permissions to `rwx------` (`0700`)
- Copy `ozo-mariadb-backup.conf` to `/etc` and set permissions to `rw-------` (`0600`)
- Modify `/etc/ozo-mariadb-backup.conf` to suit your environment:

  |Variable|Example Value|Description|
  |--------|-------------|-----------|
  |MARIADB_DUMP_USER|`"mysql-backup"`|The user that was granted permission to dump all databases|
  |MARIADB_DUMP_PASS|`"****************"`|The password for the `MARIADB_DUMP_USER` user|
  |MARIADB_DUMP_DIR|`"/var/lib/mysql-dump"`|The output directory for compressed dump files. The script will attempt to create this directory if it does not already exist|
  |MARIADB_DUMP_SKIP_DB|`"information_schema performance_schema"`|A space-separated list of databases to skip|
  |MARIADB_DUMP_KEEP_DAYS|`3`|Number of database backups to keep inm `MARIADB_DUMP_DIR`. This number can be low if backups are routinely performed of the system running MariaDB|
  