#!/bin/bash

# FUNCTIONS

function ozo-log {
  ### Logs output to the system log
  if [[ -z "${LEVEL}" ]]
  then
    LEVEL="info"
  fi
  if [[ -n "${MESSAGE}" ]]
  then
    logger -p local0.${LEVEL} -t "OZO MariaDB Backup" "${MESSAGE}"
  fi
}

function ozo-mariadb-dump-create-output-dir {
  ### Checks for the existence of the output directory and creates it if missing
  ### Returns 0 (TRUE) if the directory exists or is created successfully and 1 (FALSE) if the directory does not exist and cannot be created
  local RETURN=0
  if [[ -d "${MARIADB_DUMP_DIR}" ]]
  then
    LEVEL="info" MESSAGE="Found output directory ${MARIADB_DUMP_DIR}" ozo-log
  else
    if mkdir -p "${MARIADB_DUMP_DIR}"
    then
      LEVEL="info" MESSAGE="Created output directory ${MARIADB_DUMP_DIR}" ozo-log
    else
      LEVEL="err" MESSAGE="Unable to create output directory ${MARIADB_DUMP_DIR}" ozo-log
      RETURN=1
    fi
  fi
  return ${RETURN}
}

function ozo-mariadb-dump-validate-configuration {
  ### Performs a series of checks against the script configuration
  ### Returns 0 (TRUE) if all checks pass and 1 (FALSE) if any check fails
  local RETURN=0
  MARIADB_DUMP_CONFIGURATION="/etc/ozo-mariadb-backup.conf"
  if [[ -f "${MARIADB_DUMP_CONFIGURATION}" ]]
  then
    # source the configuration
    source "${MARIADB_DUMP_CONFIGURATION}"
    # check that all user-defined variables are set
    for USERDEFVAR in MARIADB_DUMP_USER MARIADB_DUMP_PASS MARIADB_DUMP_DIR MARIADB_DUMP_SKIP_DB
    do
      if [[ -z "${!USERDEFVAR}" ]]
      then
        LEVEL="err" MESSAGE="User-defined variable ${USERDEFVAR} is not set." ozo-log
        RETURN=1
      fi
    done
    # check that all required binaries are found in the path
    for BINARY in mysql mysqldump mkdir chown find bzip2 rm
    do
      if ! which ${BINARY}
      then
        LEVEL="err" MESSAGE="Missing ${BINARY} binary." ozo-log
        RETURN=1
      fi
    done
    # check that mariaDB service is started
    if ! systemctl is-active --quiet mariadb
    then
      LEVEL="err" MESSAGE="MariaDB service is not running." ozo-log
      RETURN=1
    fi
  else
    LEVEL="err" MESSAGE="Missing configuration file ${MARIADB_DUMP_CONFIGURATION}" ozo-log
    RETURN=1
  fi
  if ozo-mariadb-dump-create-output-dir
  then
    chmod 0700 "${MARIADB_DUMP_DIR}"
  else
    RETURN=1
  fi
  if [[ ${RETURN} == 0 ]]
  then
    LEVEL="info" MESSAGE="Configuration validates." ozo-log
  else
    LEVEL="err" MESSAGE="Error validating configuration." ozo-log
    RETURN=1
  fi
  return ${RETURN}
}

function ozo-mariadb-dump-databases {
  ### Generates a list of databases and performs a dump of each, skipping databases in MARIADB_DUMP_SKIP_DB
  ### Returns 0 (TRUE) if all databases dump and 1 (FALSE) if any one job fails
  local RETURN=0
  DATABASES="$(mysql -u ${MARIADB_DUMP_USER} -p${MARIADB_DUMP_PASS} -Bse 'show databases')"
  # check that databases were found
  if [[ -n ${DATABASES} ]]
  then
    # databases found; loop though the list
    for DATABASE in ${DATABASES}
    do
      # check if database is found in MARIADB_DUMP_SKIP_DB
      if echo "${MARIADB_DUMP_SKIP_DB}" | grep -q "${DATABASE}"
      then
        # database is found in MARIADB_DUMP_SKIP_DB; skip it
        LEVEL="warning" MESSAGE="Database ${DATABASE} found in MARIADB_DUMP_SKIP_DB; skipping." ozo-log
      else
        # database is not found in MARIADB_DUMP_SKIP_DB; dump it
        MARIADB_DUMP_FILE="${MARIADB_DUMP_DIR}/$(date +%Y%m%d-%H%M%S)-${DATABASE}-mysqldump.sql"
        if mysqldump -u ${MARIADB_DUMP_USER} -p${MARIADB_DUMP_PASS} ${DATABASE} --ignore-table=mysql.event --flush-logs --routines=TRUE --default-character-set=utf8 --skip-lock-tables --single-transaction > ${MARIADB_DUMP_FILE}
        then
          # database dumped; compress it
          if bzip2 "${MARIADB_DUMP_FILE}"
          then
            rm -f "${MARIADB_DUMP_FILE}"
            # remove dump files older than three days
            find "${MARIADB_DUMP_DIR}/" -name "*-${DATABASE}-mysqldump*" -mtime +${MARIADB_DUMP_KEEP_DAYS} -exec rm {} \;
            # log
            LEVEL="info" MESSAGE="Successfully dumped database ${DATABASE}." ozo-log
          else
            LEVEL="err" MESSAGE="Error compressing ${MARIADB_DUMP_FILE}" ozo-log
            RETURN=1
          fi
        else
          # database did not dump; log
          LEVEL="err" MESSAGE="Error dumping ${DATABASE}" ozo-log
        fi
      fi
    done
  else
    # no databases found
    LEVEL="warning" MESSAGE="No databases found." ozo-log
    RETURN=1
  fi
  return ${RETURN}
}

function ozo-mariadb-dump-program-loop {
  ### Validates configuration, creates output dir, dumps databases, performs maintenance
  ### Returns 0 (TRUE) if all methods succeed and 1 (FALSE) if any method fails
  local RETURN=0
  if ozo-mariadb-dump-validate-configuration
  then
    if ozo-mariadb-dump-create-output-dir
    then
      if ! ozo-mariadb-dump-databases
      then
        RETURN=1
      fi
    else
      RETURN=1
    fi
  else
    RETURN=1
  fi
  return ${RETURN}
}

# MAIN

EXIT=0

LEVEL="info" MESSAGE="Starting MariaDB Backup." ozo-log
if ozo-mariadb-dump-program-loop # > /dev/null 2>&1
then
  LEVEL="info" MESSAGE="Finished MariaDB Backup with success." ozo-log
else
  LEVEL="info" MESSAGE="Finished MariaDB Backup with errors." ozo-log
  EXIT=1
fi

exit ${EXIT}
