#!/bin/bash

# stop on errors
set -e

# check whether JasperReports Server is already deployed 
if [ -d "$TOMCAT_HOME/webapps/jasperserver" ]; then
	echo "JasperReports Server is already deployed."
else
	if [ -d "$ORACLE_BASE/oradata/dbconfig/$ORACLE_SID" ]; then
		if [ -f "$ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/.jasperserver.passwd" ]; then
			JASPERSERVER_PWD=${JASPERSERVER_PWD:-"`cat $ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/.jasperserver.passwd`"}
		else
			# auto generate JASPERSERVER password if not passed on
			JASPERSERVER_PWD=${JASPERSERVER_PWD:-"`tr -dc A-Za-z0-9 < /dev/urandom | head -c8`"}
			# store JASPERSERVER password
			JASPERSERVER_PWD_FILE=$ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/.jasperserver.passwd
			echo -n $JASPERSERVER_PWD > $JASPERSERVER_PWD_FILE
			chmod 600 $JASPERSERVER_PWD_FILE
			chown root:root $JASPERSERVER_PWD_FILE
		fi;
	else
			echo "Oracle configuration folder not found, run docker with: --volumes-from host $DATABASE_HOSTNAME."
			exit 1
	fi;

	if [ -f "$ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/.sysdba.passwd" ]; then
		SYSDBA_PWD=${SYSDBA_PWD:-"`cat $ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/.sysdba.passwd`"}
	else
		echo "Password for SYSDBA user not found."
		exit 1
	fi;

	# crate table creation script for Oracle based on MySQL script
	cp $JASPERSERVER_BUILDOMATIC_DIR/install_resources/sql/mysql/js-create.ddl $JASPERSERVER_BUILDOMATIC_DIR/install_resources/sql/oracle/

	sed -i "s/bigint/number(19,0)/g" $JASPERSERVER_BUILDOMATIC_DIR/install_resources/sql/oracle/js-create.ddl
	sed -i "s/integer/number(10,0)/g" $JASPERSERVER_BUILDOMATIC_DIR/install_resources/sql/oracle/js-create.ddl
	sed -i "s/tinyint/number(3,0)/g" $JASPERSERVER_BUILDOMATIC_DIR/install_resources/sql/oracle/js-create.ddl
	sed -i "s/bit/number(1,0)/g" $JASPERSERVER_BUILDOMATIC_DIR/install_resources/sql/oracle/js-create.ddl
	sed -i "s/varchar/nvarchar2/g" $JASPERSERVER_BUILDOMATIC_DIR/install_resources/sql/oracle/js-create.ddl
	sed -i "s/mediumtext/nclob/g" $JASPERSERVER_BUILDOMATIC_DIR/install_resources/sql/oracle/js-create.ddl
	sed -i "s/tinyblob/blob/g" $JASPERSERVER_BUILDOMATIC_DIR/install_resources/sql/oracle/js-create.ddl
	sed -i "s/mediumblob/blob/g" $JASPERSERVER_BUILDOMATIC_DIR/install_resources/sql/oracle/js-create.ddl
	sed -i "s/longblob/blob/g" $JASPERSERVER_BUILDOMATIC_DIR/install_resources/sql/oracle/js-create.ddl
	sed -i "s/datetime/date/g" $JASPERSERVER_BUILDOMATIC_DIR/install_resources/sql/oracle/js-create.ddl

	sed -i "s/uri(255)/uri/g" $JASPERSERVER_BUILDOMATIC_DIR/install_resources/sql/oracle/js-create.ddl

	sed -i "s/ ENGINE=InnoDB;/;/g" $JASPERSERVER_BUILDOMATIC_DIR/install_resources/sql/oracle/js-create.ddl
	sed -i "s/ auto_increment,/,/g" $JASPERSERVER_BUILDOMATIC_DIR/install_resources/sql/oracle/js-create.ddl

	sed -i "/add index FK.*,/d" $JASPERSERVER_BUILDOMATIC_DIR/install_resources/sql/oracle/js-create.ddl
	sed -i "/add index id_fk_idx (id),/d" $JASPERSERVER_BUILDOMATIC_DIR/install_resources/sql/oracle/js-create.ddl

	echo -e "\n    create sequence hibernate_sequence;" >> $JASPERSERVER_BUILDOMATIC_DIR/install_resources/sql/oracle/js-create.ddl

	# update values from environment variables
	echo "appServerType=tomcat7
appServerDir=$TOMCAT_HOME
dbType=oracle
dbUsername=JASPERSERVER
dbPassword=$JASPERSERVER_PWD
sysUsername=SYSTEM
sysPassword=$SYSDBA_PWD
dbHost=$DATABASE_HOSTNAME
dbPort=$DATABASE_PORT
sid=$ORACLE_SID
preserve_master_properties_footer_comments_when_encrypting_buildomatic=true
hibernateDialect=org.hibernate.dialect.OracleDialect" > $JASPERSERVER_BUILDOMATIC_DIR/default_master.properties

	# add oracle database as valid repository database for JasperReports Server CE
	sed -i '/<equals arg1="${dbType}" arg2="postgresql" \/>/a <equals arg1="${dbType}" arg2="oracle" \/>' $JASPERSERVER_BUILDOMATIC_DIR/bin/validation.xml

	pushd $JASPERSERVER_BUILDOMATIC_DIR
	./js-ant create-js-db || true # skip database creation if database already exists
	./js-ant init-js-db-ce 
	./js-ant import-minimal-ce 
	./js-ant deploy-webapp-ce

	export RUN_IMPORT=true

fi;

if [ $RUN_IMPORT ]; then
	echo "Starting import from '/docker-entrypoint-import.d':"

	for f in /docker-entrypoint-import.d/*
	do
		case "$f" in
			*.zip)
				echo "$0: running $f"
				pushd $JASPERSERVER_BUILDOMATIC_DIR && ./js-import.sh --input-zip $f 
				;;
			*)
				echo "$0: ignoring $f"
				;;
		esac
	done
fi;

echo
echo "JasperReports Server init process done. Ready for start up."
echo

exec catalina.sh "$1"
