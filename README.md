# OZO MariaDB Backup

Create a mysql-backup user before using this script:

`mysql> GRANT SELECT, RELOAD, LOCK TABLES, SHOW VIEW ON *.* TO 'mysql-backup'@'localhost' IDENTIFIED BY '********';`
