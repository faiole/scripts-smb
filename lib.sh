#!/bin/bash
#./getDateTime.sh

function MsgType {
	msg="$1"
	error="$2"
	print_now=`date +"%Y-%m-%d %T"`
	if [ "$error" = 1 ]; then
		echo -e "\e[1m${print_now}: \e[31m $msg \e[0m"
		echo -e "\e[1m${print_now}: \e[31m Script parado. \e[0m"
		exit
	else
		echo -e "\e[1m${print_now}: \e[0;92m $msg \e[0m"
	fi
}

function LoadConfiguration {
	local config="$1"
	if [ -f "$config" ]; then
		MsgType "Arquivo de configuração: $config"
	else
		MsgType "Arquivo de configuração não encontrado!" 1
	fi
	source "$config"
}

function ValidateBackupSource {
	local source="$1"
	if [ -z "$source" ]; then
		MsgType "Nenhuma fonte de backup definida!" 1
	fi
	if [ ! -d "$source" ]; then
		MsgType "Fonte de backup não encontrada!" 1
	fi
	MsgType "Fonte do Backup : $source "
}

function ValidateBackupDestination {
	local destination="$1"
	if [ -z "$destination" ]; then
		MsgType "Nenhum destino de backup definido!" 1
	fi
	if [ ! -d "$destination" ]; then
		MsgType "Destino de backup não encontrado. Criando..."
		mkdir -p "$destination"
		if [ ! -d "$destination" ]; then
			MsgType "Não foi possível criar a pasta de backup." 1
		fi
	fi
	MsgType "Backup destino	: $destination "
}

function ValidateBackupParent {
	local parent="$1"
	local destination="$2"
	if [ -z "$parent" ]; then
		MsgType "Nenhum backup master definido!" 1
	fi
	if [ ! -d "$parent" ]; then
		parentDirs=($(find "$destination" -type d -name "$parent"))
		if [ "${#parentDirs[@]}" -gt 1 ]; then
			MsgType "Backup master é ambíguo!" 1
			for dir in "${parentDirs[@]}"; do
				MsgType "$dir" 1
			done
			MsgType "Não é possível continuar." 1
		elif [ "${#parentDirs[@]}" -eq 0 ]; then
			MsgType "Backup master não encontrado!" 1
		fi	
	fi
	MsgType "Backup master		: $parent "
}

function SetConfigField(){
	local path="$1"
	local field="$2"
	local value="$3"
	sudo sed -i "s/^\($field\s*=\s*\).*\$/\1$value/" $path
}

function FullBackup {
	MsgType "Backup completo solicitado."
	local source="$1"
	local destination="$2"
	local filename="$3"
	local config="$4"
	local snapshot="level0.snapshot"
	local timestamp=`date +%Y%m%d-%H%M%S`
	local directory="$destination/$timestamp-full"
	local archive="$filename.tar.gz"
	MsgType "Salvando novo master no arquivo de configuração..."
        SetConfigField $config BACKUP_PARENT "$timestamp-full"
	MsgType "Executando backup completo..."										
	PerformBackup "$source" "$directory" "$archive" "$snapshot"	
	#MsgType "Salvando novo master no arquivo de configuração..."
	#SetConfigField $config BACKUP_PARENT "$timestamp-full"
}

function IncrementalBackup {
	MsgType "Backup incremental solicitado."
	local source="$1"
	local destination="$2"
	local filename="$3"
	local config="$4"
	local parent="$5"
	local timestamp=`date +%Y%m%d-%H%M%S`
	local archive="$filename.tar.gz"
	local level=(`find $destination/$parent/ -name "*.snapshot" | wc -l`);
	local directory="$destination/$parent/$timestamp-incremental_$level"
	local lastlevel=$(($level-1))
	local lastfile=(`find $destination/$parent/ -name "level$lastlevel.snapshot"`);
	local parentSnapshot="${lastfile[0]}"
	if [ -z "$parentSnapshot" ]; then
		MsgType "Nenhum snapshot encontrado, faça backup completo primeiro." 1
	fi
	MsgType "Backup de		: $parentSnapshot"
	MsgType "Level increment		: $lastlevel -> $level"
	local snapshot="level$level.snapshot"				
	MsgType "Arquivo de Snapshot		: $snapshot"
	MsgType "Criando backup incremental ..."
	mkdir -p "$directory"
	cp -a "$parentSnapshot" "$directory/$snapshot"
	PerformBackup "$source" "$directory" "$archive" "$snapshot"
}

function PerformBackup {
	source="$1"
	destination="$2"
	backupFile="$3"
	snapshotFile="$4"
	mkdir -p "$destination"
	backupStart=$SECONDS	
	local tarOps="-cpvzf"
	tar --listed-incremental="$destination/$snapshotFile" $tarOps "$destination/$backupFile" -C "$source" .
	res=$?
	if [ ! $res -eq 0 ];
	then
		MsgType "Tar falhou! ($res)" 1
	else
		backupDuration=$(($SECONDS - $backupStart))
		backupMin=$(($backupDuration / 60))
		backupSec=$(($backupDuration % 60))
		MsgType "Backup completo. Tempo: ${backupMin}min ${backupSec}sec."
	fi
	return $res
}

function list {
	local destination="$1"
	readDirectory "$destination" 0 "$2"
}

function readDirectory {
	local directory="$1"
	local files=($directory/*)
	local fullDirs=()
	local depth="$2"
	local filename="$3"
	for file in "${files[@]}"; do
		[[ -d "$file" ]] && fullDirs+=("$file")
	done
	for currentDir in "${fullDirs[@]}"; do
		local backupName=`basename "$currentDir"`		
		readBackup "$currentDir" "$filename"
		if [ "${backupInfo[0]}" = false ]; then
			echo -n "[$backupName] "
			MsgType "${backupInfo[1]}" 1
		else
			local archiveDate=`date -r "$currentDir" "+%d.%m.%Y-%H:%M:%S"`		
			local archiveDateNumber=`date -r "$currentDir" "+%s.%N"`
			[ "$depth" -gt 0 ] && type="Level $depth"
			echo "$archiveDate $type Datetime: [$backupName]"
		fi
		readDirectory "$currentDir" "$((depth+1))" "$filename"
	done
}

function readBackup {
	local backupName=`basename $1`
	local filename="$2"
	local files=($(find "$1" -maxdepth 1 -type f -name "$filename.tar.gz" -o -type f -name "$filename.tar.gz2"))
	local archive="${files[0]}"
	files=($1/*.snapshot);
	local snapshot="${files[0]}"
	if [ ! -f "$archive" ]; then
		MsgType "Nenhum arquivo foi encontrado!" 1
	elif [ ! -f "$snapshot" ]; then
		MsgType "Nenhum snapshot foi encontrado!" 1
 	fi

	local level=${snapshot##*level}
	level=${level%.*}
	
	local success=true
	local error=""

	if [ ! -f "$archive" ]; then
		success=false
		error="Nenhum arquivo foi encontrado!"
	elif [ ! -f "$snapshot" ]; then
		success=false
		error="Nenhum snapshot foi encontrado!"
	elif [ -z "$level" ]; then
	 	success=false
	 	error="Não foi possível determinar o nível de backup!"
 	fi
	
	if [ "$success" = true ]; then
		backupInfo=(true "$archive" "$snapshot" "$level")
	else
		backupInfo=(false "$error")
	fi

}


function GetCloseSnap {
	MsgType "Procurando arquivos de backup..."
	local destination="$2"
	local date_c=$(date -d "$1" +%s)
	local actiontype="$3"
	local filename="$4"
	old_distance="$date_c"
	local old_value=""
	for d in $destination*; do
		for a in $d/*; do
			local date_a=$(date -r "$a" +%s)
			local distance=$(("$date_a"-"$date_c"))
			if (( 0 > $distance )) ;then
				distance=$((distance*-1))			
			fi
			if (( $old_distance > $distance )) ;then
				old_distance="$distance"
				if [[ $a == *"archive.tar.gz"* ]]; then
					old_value=$d
				else
					old_value=$a
				fi
			fi
		done
	done
	MsgType "A data mais próxima é: $(date -r "$old_value" +%d.%m.%Y-%H:%M:%S)"
	MsgType "Backup encontrado: $old_value"
	if (( $actiontype == 1)) ; then
		MsgType "Restaurando pasta..."
		local lastfile=(`find $old_value/ -name "level*.snapshot"`);
		local parentSnapshot="${lastfile[0]}"
		echo $parentSnapshot
		restore "$old_value" "$filename"
		MsgType "Pasta restaurada."
	else
		MsgType "Fornecendo metadados..."
		tar tzf "$old_value/archive.tar.gz"
		MsgType "Metadados fornecidos."
	fi
}


function restore {
	local backuppath="$1"
	local filename="$2"
	MsgType "Restauração solicitada." 
	readBackup "$backuppath" "$filename"
	if [ "${backupInfo[0]}" = false ]; then
		MsgType "${backupInfo[1]}" 1
	fi
	local archive="${backupInfo[1]}"
	local snapshot="${backupInfo[2]}"
	local level="${backupInfo[3]}"
	echo "Arquivo de backup       : `basename "$archive"`"
	echo "Snapshot                : `basename "$snapshot"`"
	echo "Level                   : $level"
	MsgType "Construindo cadeia de backup incremental..."
	local backupChain=($archive)
	local currentDirectory=`dirname "$archive"`
	local currentLevel="$level"

	local root_folder="${backuppath%/*}"
	while [ "$currentLevel" -gt 0 ]; do

		local findsnapshot=(`find $root_folder/ -name "*level$((currentLevel-1)).snapshot"`);
		local snapshotfound="${findsnapshot[0]}"
		local validpath="${snapshotfound%/*}"
		MsgType "Restaurando de: $validpath"
		readBackup "$validpath" "$filename"
		if [ "${backupInfo[0]}" = false ]; then
			MsgType "${backupInfo[1]}" 1
		fi
		backupChain+=(${backupInfo[1]})
		((currentLevel--))
	done
	printf '%s\n' "${backupChain[@]}"
	echo "Restaurando backup... "
	local chainLastIndex=$((${#backupChain[@]}-1))
	for ((chainIndex=$chainLastIndex; chainIndex >= 0; chainIndex--)); do
		local backupArchive="${backupChain[$chainIndex]}"
		local backupDir=`dirname "$backupArchive"`
		local backupName=`basename "$backupDir"`
		local tarOps="-x"
		tarOps="${tarOps}v"
		tarOps="${tarOps}z"		
		tarOps="${tarOps}f"
		MsgType "[$backupName] ... "
		tar $tarOps "$backupArchive" -C "$BACKUP_SOURCE"		
		res=$?
		if [[ "$res" -eq 0 ]]; then
			 MsgType "Concluído"
		else	
			echo "error $res"
			MsgType "Não foi possível restaurar o backup!" 1
		fi			
	done
}

