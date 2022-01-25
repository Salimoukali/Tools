#!/usr/bin/ksh
#--- Marking Strings ----------------------------------------------------------------------------
#--- @(#)F3GFAR-S: $Workfile:   FTPSec_printmsg.sh  $ $Revision:   1.2  $
#------------------------------------------------------------------------------------------------
#--- @(#)F3GFAR-E: $Workfile:   FTPSec_printmsg.sh  $ VersionLivraison = 2.0.0.0
#------------------------------------------------------------------------------------------------

#VERSION_Begin
#%ThisShell%: Version = 2.0.0.0
#VERSION_End
#------------------------------------------------------------------------------------------------
#USAGE_Begin
#
#    %ThisShell% <coderet> | -h | --help | -v | --version
#
#	Ce shell prend un seul parametre en entree
#             <coderet> :  donner le code retour de GetFiles.sh.
#	      -h | --help : affiche cette aide
#	      -v | --version : affiche la version
# 
#USAGE_End 
#------------------------------------------------------------------------------------------------

#------------------------------------------------------------------------------------------------
#--- Pour afficher la version du shell.
#------------------------------------------------------------------------------------------------
version() 
{
    echo
    sed "/^#VERSION_Begin.*/,/^#VERSION_End.*/!d;/VERSION_Begin/d;/VERSION_End/d;s/^#//g;s/%ThisShell%/${FACILITY_NAME}/g" ${FACILITY} >&2
    echo
    exit ${OK}
}
  
#------------------------------------------------------------------------------------------------
#--- Ce qu'il faut afficher quand les parametres sont incorrects.
#------------------------------------------------------------------------------------------------
usage() 
{ 
    echo 
    echo "Usage:"                                                                                                              >&2 
    sed "/^#USAGE_Begin.*/,/^#USAGE_End.*/!d;/USAGE_Begin/d;/USAGE_End/d;s/^#//g;s/%ThisShell%/${FACILITY_NAME}/g" ${FACILITY} >&2
    exit ${NOK}
} 


#------------------------------------------------------------------------------------------------
#--- Fonction permettant de recuperer le chemin absolu d'un fichier
#------------------------------------------------------------------------------------------------
GetFullFilename()
{
	filename_tmp=$1
	
	if [ "`echo $filename_tmp | cut -c1`" != "/" ]
	then
		dirname_tmp=`/bin/pwd`
		
		while true
		do
			if [ -z "$filename_tmp" ]
			then
				echo "Error: Log file name provided is a directory"
				exit 1
			fi
			
			if [ "`echo $filename_tmp | cut -c1-3`" = "../" ]
			then
				if [ "$dirname_tmp" = "/" ]
				then
					echo "Error: Invalid log file name"
					exit 1
				fi
				dirname_tmp=`dirname $dirname_tmp`
				filename_tmp=`echo $filename_tmp | cut -c4-`
				break
				continue
			fi
			
			if [ "`echo $filename_tmp | cut -c1-2`" = "./" ]
			then
				filename_tmp=`echo ${filename_tmp} | cut -c3-`
			fi
			
			break
		done
		
		if [ "$dirname_tmp" = "/" ]
		then
			echo $dirname_tmp$filename_tmp
		else
			echo $dirname_tmp/$filename_tmp
		fi
	else
		echo $filename_tmp
	fi
}


#------------------------------------------------------------------------------------------------
#--- Positionnement des variables d'environement.
#------------------------------------------------------------------------------------------------
OK=${OK:=0}
NOK=${NOK:=1}
FACILITY=$0
FACILITY_NAME=$(basename ${0})

#------------------------------------------------------------------------------------------------
#--- Parameter search.
#------------------------------------------------------------------------------------------------
if [ $# -ne 1  -o  "$1" = "-h" -o  "$1" = "--help" ]
then
	usage
elif [ "$1" = "-v" -o  "$1" = "--version" ]
then
	version
else
	expr $1 "*" $1 + 1 1>/dev/null 2>&1
	[ $? -ne 0 ] && usage
fi

cd $(dirname $(GetFullFilename $0)) >/dev/null

(grep "^$1;" ../cfg/FTPSec_printmsg.dico || echo "$1;Code retour de FTPSec inconnu") | sed "s/^$1;//"

cd ->/dev/null

exit $OK



