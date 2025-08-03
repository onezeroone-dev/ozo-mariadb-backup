#!/bin/bash
# Script Name: ozo-mariadb-backup.sh
# Version    : 1.0.1
# Description: Creates a dump of all MariaDB databases and performs history maintenance.
# Usage      : /usr/sbin/ozo-mariadb-backup.sh
# Author     : Andy Lievertz <alievertz@onezeroone.dev>
# Link       : https://github.com/onezeroone-dev/ozo-mariadb-backup/blob/main/README.md

# FUNCTIONS
function ozo-log {
    # Function   : ozo-log
    # Description: Logs output to the system log
    # Arguments  :
    #   LEVEL    : The log level. Allowed values are "err", "info", or "warning". Defaults to "info".
    #   MESSAGE  : The message to log.
    
    # Determine if LEVEL is null
    if [[ -z "${LEVEL}" ]]
    then
        # Level is null; set to "info"
        LEVEL="info"
    fi
    # Determine if MESSAGE is not null
    if [[ -n "${MESSAGE}" ]]
    then
        # Message is not null; log the MESSAGE with LEVEL
        logger -p local0.${LEVEL} -t "OZO MariaDB Backup" "${MESSAGE}"
    fi
}

function ozo-mariadb-dump-create-output-dir {
    # Function   : ozo-mariadb-dump-create-output-dir
    # Description: Checks for the existence of the output directory and creates it if missing. Returns 0 (TRUE) if the directory exists or is created successfully and 1 (FALSE) if the directory does not exist and cannot be created.

    # Control variable
    local RETURN=0
    # Determine if the dump directory does not exist
    if [[ ! -d "${MARIADB_DUMP_DIR}" ]]
    then
        # Directory does not exist; attempt to create
        if mkdir -p "${MARIADB_DUMP_DIR}"
        then
            # Success
        else
            # Failure
            RETURN=1
        fi
    fi
    # Return
    return ${RETURN}
}

function ozo-mariadb-dump-validate-configuration {
    # Function   : ozo-mariadb-dump-validate-configuration
    # Description: Performs a series of checks against the script configuration. Returns 0 (TRUE) if all checks pass and 1 (FALSE) if any check fails.

    # Control variable
    local RETURN=0
    # Determine if the configuration file exists
    if [[ -f "${MARIADB_DUMP_CONFIGURATION}" ]]
    then
        # Configuration file exists; source it
        source "${MARIADB_DUMP_CONFIGURATION}"
        # Iterate through all user-defined variables
        for USERDEFVAR in MARIADB_DUMP_USER MARIADB_DUMP_PASS MARIADB_DUMP_DIR MARIADB_DUMP_SKIP_DB
        do
            # Determine if the variable is null
            if [[ -z "${!USERDEFVAR}" ]]
            then
                # Variable is null
                LEVEL="err" MESSAGE="User-defined variable ${USERDEFVAR} is not set." ozo-log
                RETURN=1
            fi
        done
        # Iterate through required binaries
        for BINARY in mysql mysqldump mkdir chown find bzip2 rm
        do
            # Determine if binary does not exist
            if ! which ${BINARY}
            then
                # Binary does not exist
                LEVEL="err" MESSAGE="Missing ${BINARY} binary." ozo-log
                RETURN=1
            fi
        done
        # Determine if mariaDB service is not started
        if ! systemctl is-active --quiet mariadb
        then
            # Service is not started
            LEVEL="err" MESSAGE="MariaDB service is not running." ozo-log
            RETURN=1
        fi
    else
        # Configuration file does not exist
        LEVEL="err" MESSAGE="Missing configuration file ${MARIADB_DUMP_CONFIGURATION}" ozo-log
        RETURN=1
    fi
    # Return
    return ${RETURN}
}

function ozo-mariadb-dump-databases {
    # Function   : ozo-mariadb-dump-databases
    # Description: Generates a list of databases and performs a dump of each, skipping databases in MARIADB_DUMP_SKIP_DB. Returns 0 (TRUE) if all databases dump and 1 (FALSE) if any one job fails.

    # Control variable
    local RETURN=0
    # Obtain list of databases
    DATABASES="$(mysql -u ${MARIADB_DUMP_USER} -p${MARIADB_DUMP_PASS} -Bse 'show databases')"
    # Determine that DATABASES is not null
    if [[ -n ${DATABASES} ]]
    then
        # DATABASES is not null; iterate through the databases
        for DATABASE in ${DATABASES}
        do
            # Determine if database is found in MARIADB_DUMP_SKIP_DB
            if echo "${MARIADB_DUMP_SKIP_DB}" | grep -q "${DATABASE}"
            then
                # Database is found in MARIADB_DUMP_SKIP_DB; skip it
                LEVEL="warning" MESSAGE="Database ${DATABASE} found in MARIADB_DUMP_SKIP_DB; skipping." ozo-log
            else
                # Database is not found in MARIADB_DUMP_SKIP_DB; log
                MARIADB_DUMP_FILE="${MARIADB_DUMP_DIR}/$(date +%Y%m%d-%H%M%S)-${DATABASE}-mysqldump.sql"
                # Determine if database dump succeeded
                if mysqldump -u ${MARIADB_DUMP_USER} -p${MARIADB_DUMP_PASS} ${DATABASE} --ignore-table=mysql.event --flush-logs --routines=TRUE --default-character-set=utf8 --skip-lock-tables --single-transaction > ${MARIADB_DUMP_FILE}
                then
                    # Success; Determine if compressing the dump file succeeded
                    if bzip2 "${MARIADB_DUMP_FILE}"
                    then
                        # Success; remove the dump file
                        rm -f "${MARIADB_DUMP_FILE}"
                        # Remove dump files older than the configured number of days
                        find "${MARIADB_DUMP_DIR}/" -name "*-${DATABASE}-mysqldump*" -mtime +${MARIADB_DUMP_KEEP_DAYS} -exec rm {} \;
                        # Log
                        LEVEL="info" MESSAGE="Successfully dumped database ${DATABASE}." ozo-log
                    else
                        # Failure
                        LEVEL="err" MESSAGE="Error compressing ${MARIADB_DUMP_FILE}" ozo-log
                        RETURN=1
                    fi
                else
                    # Database did not dump; log
                    LEVEL="err" MESSAGE="Error dumping ${DATABASE}" ozo-log
                fi
            fi
        done
    else
        # No databases found
        LEVEL="warning" MESSAGE="No databases found." ozo-log
        RETURN=1
    fi
    # Return
    return ${RETURN}
}

function ozo-mariadb-dump-program-loop {
    # Function   : ozo-mariadb-dump-program-loop
    # Description: Validates configuration, creates output dir, dumps databases, performs maintenance. Returns 0 (TRUE) if all methods succeed and 1 (FALSE) if any method fails.

    # Control variable
    local RETURN=0
    # Determine if configruation validates
    if ozo-mariadb-dump-validate-configuration
    then
        # Configuration validates; determine if output directory exists or has been created
        if ozo-mariadb-dump-create-output-dir
        then
            # Output directory exists or has been created; determine if database dumping does not succeed
            if ! ozo-mariadb-dump-databases
            then
                # Databases failed to dump
                LEVEL="err" MESSAGE="Error dumping databases" ozo-log
                RETURN=1
            fi
        else
            # Output directory does not exist and could not be created
            LEVEL="err" MESSAGE="Output directory not found and could not be created" ozo-log
            RETURN=1
        fi
    else
        # Configuration failed to validate
        LEVEL="err" MESSAGE="Configuration did not validate" ozo-log
        RETURN=1
    fi
    return ${RETURN}
}

# MAIN
# Control variable
EXIT=0
# Set variables
MARIADB_DUMP_CONFIGURATION="/etc/ozo-mariadb-backup.conf"
# Log a process start message
LEVEL="info" MESSAGE="OZO MariaDB Backup process starting." ozo-log
# Determine if ozo-mariadb-backup succeeded
if ozo-mariadb-dump-program-loop > /dev/null 2>&1
then
    # Success
    LEVEL="info" MESSAGE="Finished MariaDB Backup with success." ozo-log
else
    # Failure
    LEVEL="info" MESSAGE="Finished MariaDB Backup with errors." ozo-log
    EXIT=1
fi
# Log a process complete message
LEVEL="info" MESSAGE="OZO MariaDB Backup process complete." ozo-log
# Exit
exit ${EXIT}
