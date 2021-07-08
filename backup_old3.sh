#!/bin/bash
# Script de backup dos arquivos do SAMBA
# Feito por: Filipe Faiole Moura
# Versão 1.0

DIR=/usr/local/backups

if [ `date +%d` != "01" ]
then
  PRIMEIRO_DIA_DO_MES="N"
  MES=`date +%b`
else
  PRIMEIRO_DIA_DO_MES="S"
fi

ORIGEM1=/dados
ORIGEM2=/etc

  INI=`date +'%Y_%m_%d-%H_%M'`
  DIA_DA_SEMANA=`date +'%a'`
  DIA_DA_SEMANA=`echo $DIA_DA_SEMANA | sed 'y/āáǎàēéěèīíǐìōóǒòūúǔùǖǘǚǜĀÁǍÀĒÉĚÈĪÍǏÌŌÓǑÒŪÚǓÙǕǗǙǛ/aaaaeeeeiiiioooouuuuüüüüAAAAEEEEIIIIOOOOUUUUÜÜÜÜ/'`
  echo $ORIGEM1

  echo "Efetuando backup dos dados: ${ORIGEM1}."
  NOME_ARQUIVO_BACKUP1="${ORIGEM1}.${HOSTNAME}.${DIA_DA_SEMANA}.${INI}"
  tar -czf $DIR/${NOME_ARQUIVO_BACKUP1}.tgz ${ORIGEM1}

  echo "Efetuando backup dos dados: ${ORIGEM2}."
  NOME_ARQUIVO_BACKUP2="${ORIGEM2}.${HOSTNAME}.${DIA_DA_SEMANA}.${INI}"
  tar -czf $DIR/${NOME_ARQUIVO_BACKUP2}.tgz ${ORIGEM2}

  if [ `date +%d` == "01" ]
  then
    NOME_ARQUIVO_BACKUP_MES1=$(echo "${NOME_ARQUIVO_BACKUP1}" | sed "s/\.${DIA_DA_SEMANA}\./${MES}/")
    mv $DIR/${NOME_ARQUIVO_BACKUP1}.tgz $DIR/${NOME_ARQUIVO_BACKUP_MES1}.tgz
    NOME_ARQUIVO_BACKUP1=${NOME_ARQUIVO_BACKUP_MES1}
  fi
  if [ `date +%d` == "01" ]
  then
    rm -f $DIR/${ORIGEM}.${HOSTNAME}.${MES}.*
  else
    #rm -f $DIR/${ORIGEM}.${HOSTNAME}.${DIA_DA_SEMANA}.*
  fi
  
  TEMPO="TEMPO-$(($SECONDS / 3600))hrs_$((($SECONDS / 60) % 60))min_$(($SECONDS % 60))seg"

  mv -f $DIR/${NOME_ARQUIVO_BACKUP}.tgz $DIR/${NOME_ARQUIVO_BACKUP}.${TEMPO}.${INI}.tgz
  NOME_ARQUIVO_BACKUP="${NOME_ARQUIVO_BACKUP}.${TEMPO}.tgz"

  echo "Enviado o backup para armazenamento na nuvem pública..."
  /usr/bin/rclone copy ${DIR} backup-fileserver:/Backup --update --verbose --transfers 30 --checkers 8 --contimeout 60s --timeout 300s --retries 3 --low-level-retries 10 --stats 1s
