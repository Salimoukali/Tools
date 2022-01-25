#!/bin/ksh

#--- Marking Strings--------------------------------------------------------------------
#--- @(#)F3GFAR-S: $Workfile:   start_Archive.sh  $ $Revision:   1.2  $
#---------------------------------------------------------------------------------------
#--- @(#)F3GFAR-E: $Workfile:   start_Archive.sh  $ VersionLivraison = 2.0.0.0
#---------------------------------------------------------------------------------------

#########################################################################################
#	File name :		start_Archive.sh
#	Version :		V1.0
#	Creation date :		19/05/2003
#	Updating dates :	
#	Description :	        archive le fichier de control et les fichiers de donnees
#				supprime les fichiers checksum associes
#########################################################################################


#################################################################
## Section fonctions (la section de démarrage est juste après) ##
#################################################################

usage()
{
 echo "USAGE : \n"
 echo "Ce script realise l'archivage du fichier de controle et des fichiers de donnees "
 echo "et la suppression des fichiers checksum associes.\n"
 echo "Le script est lance imperativement avec un parametre" 
 echo ""
 echo "Syntaxe d'utilisation : $0 -config=Inifile"
 echo "Inifile : correspond au chemin et nom du fichier de configuration"
 echo ""
 exit 1
}


thedate() 
{ 
 echo `date +"%d/%m/%Y %H:%M:%S"` 
}


#Recuperation des variables dans le fichier de configuration 
#---------------------------------------------------------------------------------------- 
function Control_Variables
{
  if [ ! -f $INIFILE ]
  then
	echo " \nLe fichier de configuration '$INIFILE' est inexistant !!!"
        Message
  else
	echo "Repertoire source = $REP_SOURCE"
        if [ ! -d $REP_SOURCE ]
        then 
             echo " \nLe repertoire source est inexistant!!!"
             Message
        fi

	echo "Repertoire archive = $REP_ARCHIVE"
        if [ ! -d $REP_ARCHIVE ]
        then 
             echo " \nLe repertoire d'archivage est inexistant!!!"
             Message
        fi

	echo "Nom du fichier de controle = $FILE_CTRL"
        if [ ! -f $REP_SOURCE/$FILE_CTRL ]
        then 
             echo " \nLe fichier de controle n'existe pas dans le repertoire source!!!"
             echo "\nIl n'y a donc pas de fichiers a archiver.\n"
             log_msg "start_Archive" "2000" "Fin de start_Archive"
             exit 0 
        fi

	echo "Extension des fichiers a archiver = $FILE_EXT"
        if [ "X$FILE_EXT" = "X" ]
        then 
             echo " \nLa variable FILE_EXT n'est pas renseignee dans le fichier $INIFILE!!!"
             echo "\nIl n'y a donc pas de fichiers a archiver.\n"
             log_msg "start_Archive" "2000" "Fin de start_Archive"
             exit 0 
        fi

  fi
}

function Message
{
    echo ""
    echo "l'Initialisation s'est mal déroulée" 
    echo "ECHEC de $SCRIPT\n"
    log_msg "start_Archive" "2000" "Fin de start_Archive"
    exit 1
}

function testConfigFile
{
  if [ ! -f $INIFILE ]
  then
	echo ""
	echo " Le fichier de configuration donne en parametre : <$INIFILE> est inexistant ou syntaxe erronee!!!"
	echo ""
        usage
  fi
}

###########################
## Section de controle   ##
###########################
clear

SCRIPT=$0

[[ "X$1" = "X-h" ]] && usage
[[ $# -gt 1 ]] && usage
[[ $# = 0 ]] && usage

 INIFILE=`echo "$1" | sed 's/-config=//' 2> /dev/null`
 
 testConfigFile

 
#--------------------------------- initialisation des logs ARE ---------------------------
 areConf=${HOME}/DATA/ARE/CONFIG/start_Archive.are.conf
 Program=start_Archive
 autoload init_logging
 init_logging  "F3G" ${areConf} $Program
 ret=$?
 if [[ $ret -ne 0 ]] 
 then
     print_msg "Echec de l'appel de la fonction init_logging" 
     exit 1
 fi
 #--------------------------------------------ARE----------------------------------------- 

log_msg "start_Archive" "2000" "Debut de start_Archive"

    
###########################
## Section de traitement ##
###########################
echo""
echo "commande = ($0 $*), lancé le = (`thedate`)" 
echo ""
echo ""
echo "Le fichier de configuration utilise : $INIFILE"
echo ""
 
. $INIFILE 

Control_Variables

cd ${REP_SOURCE}

#Recuperer les fichiers du fichier de controle
#-----------------------------------------------------------------------------------------
#LISTE=`/usr/bin/ls $FILE_CTRL | echo *.$FILE_EXT 2> /dev/null`

LISTE=`cat $FILE_CTRL | grep .$FILE_EXT`

# a afficher
echo ""
echo "Liste des fichiers a archiver :"
echo ""


#Archiver les fichiers contenus uniquement dans le fichier de controle 
#-----------------------------------------------------------------------------------------
if [[ ${LISTE} != "" ]]
then
    for FICHIER in ${LISTE}
    do
       #found=`/usr/bin/grep $fichier *.ctl 2> /dev/null`
       FOUND=`echo ${FICHIER} | cut -d "=" -f 2` 
       if [[ -f ${FOUND} ]]
       then
           echo "${FOUND}"
           mv ${FOUND} ${REP_ARCHIVE}
           if [[ -f "${FOUND}.CheckSum" ]]
           then
               rm -f "${FOUND}.CheckSum" > /dev/null 2>&1
           fi
       else
           echo "Le fichier ${FOUND} n'est pas present dans le repertoire ${REP_SOURCE}"
       fi
    done
fi

#Archiver le fichier de controle Correction Anomalie Webpt N49804
mv ${FILE_CTRL} ${REP_ARCHIVE}/${FILE_CTRL}.`date +%Y%m%d%H%M%S`
RET=$?
if  [[ -f ${FILE_CTRL}.CheckSum ]]
then
    rm -f "${FILE_CTRL}.CheckSum" > /dev/null 2>&1
fi

echo ""

if [ "${RET}" != "0" ]
then
     echo "Archivage incomplet."
     echo ""
     echo "ECHEC de ${SCRIPT}"
     echo ""
else
     echo "Archivage termine."
     echo ""
     echo "REUSSITE de ${SCRIPT}"
     echo ""
fi

log_msg "start_Archive" "2000" "Fin de start_Archive"

exit $ret


