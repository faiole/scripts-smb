#!/bin/bash
. /var/scripts/lib.sh
#################################################################
# Methods imported from lib:
# MsgType()
# LoadConfiguration(config)
# ValidateBackupSource(source)
# ValidateBackupDestination(destination)
# ValidateBackupParent(parent,destination)
# SetConfigField(path,field,value)
# FullBackup(source,destination,filename,config)
# IncrementalBackup(source,destination,filename,snapshot,parent)
# PerformBackup(source,destination,backupfile,snapshotfile)
#################################################################
MsgType "Bem-vindo à ferramenta de backups incrementais."

read -r -d '' welcome_print << EOM
Usage:
 *backup-full: Faça backup completo da pasta.
 *backup-increment: Executa backup incremental.
 *restore: Restaura a pasta para o estado a partir de um determinado momento [date]
	-exemplo:  restore '2020/01/11 09:35:00'
 *show: Mostra os arquivos nos arquivos de backup [date]
	-exemplo:  show '2020/01/11 09:35:00'
 *list: Lista todos os arquivos de backup 

EOM
echo  "$welcome_print"

MYDIR="$(dirname "$(readlink -f "$0")")"
CONFIG_FILE="$MYDIR/backup.conf"
LoadConfiguration $CONFIG_FILE
##################################################
# Fields loaded from the configuration.conf file:
# BACKUP_SOURCE
# BACKUP_DESTINATION
# BACKUP_PARENT
# BACKUP_FILENAME
##################################################

ValidateBackupSource $BACKUP_SOURCE
ValidateBackupDestination $BACKUP_DESTINATION

ACTION="$1"
ARGUMENT="$2"
case "$ACTION" in
	backup-full)
		FullBackup "$BACKUP_SOURCE" "$BACKUP_DESTINATION" "$BACKUP_FILENAME" "$CONFIG_FILE";;
	backup-increment)
		ValidateBackupParent "$BACKUP_PARENT" "$BACKUP_DESTINATION"
		IncrementalBackup "$BACKUP_SOURCE" "$BACKUP_DESTINATION" "$BACKUP_FILENAME" "$CONFIG_FILE" "$BACKUP_PARENT";;
	list)
		list "$BACKUP_DESTINATION" "$BACKUP_FILENAME";;
	restore)
		GetCloseSnap "$ARGUMENT" "$BACKUP_DESTINATION" 1 "$BACKUP_FILENAME";;
	show)
		GetCloseSnap "$ARGUMENT" "$BACKUP_DESTINATION" 0;;
	*)
		[ -z "$ACTION" ] && MsgType "No action supplied!" 1
		MsgType "Unknown action! ($ACTION)" 1
esac

exit 0
