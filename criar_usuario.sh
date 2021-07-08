#!/bin/bash
for x in $(cat usuarios-samba.txt); do
	nome=$(echo $x|awk -F";" '{print $1}')
	senha=$(echo $x|awk -F";" '{print $2}')
	sobrenome=$(echo $x|awk -F";" '{print $3" "$4}')
	empresa=$(echo $x|awk -F";" '{print $5}')
	echo "samba-tool user create $nome $senha  --surname "$sobrenome"" 
done
