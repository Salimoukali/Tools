#!/usr/bin/ksh
#--- Marking Strings --------------------------------------
#--- @(#)F3GFAR-S: $Workfile:   PutFiles.sh  $ $Revision: 71 $
#----------------------------------------------------------
#--- @(#)F3GFAR-E: $Workfile:   PutFiles.sh  $ VersionLivraison = 2.1.11.2
#----------------------------------------------------------
#*****************************************************************************************
# File name         : PutFiles.sh
# Short Description : Fichier de transfert de fichiers produits par F3GFAR vers une machine distante via FTP
# Copyright         : TMN 2005
# Author            : R.Vieux
# Version           : V1.0
# Creation date     : 07/07/2005
# Updating dates    : 01/12/2005 - WebAno 83681
# Input Data        : none
# Output Data       : none
#*****************************************************************************************


#*****************************************************************************************
# Liste des fonctions utilisées
#*****************************************************************************************

#------------------------------------------------------------------------------------------------
#--- Affichage de l'aide.
#------------------------------------------------------------------------------------------------

usage()
{
 echo -e ""
 echo -e "######################################## MODE DE LANCEMENT ###############################################"
 echo -e ""
 echo -e "Ce script procede aux transferts FTP sortants."
 echo -e "\nSyntaxe d'utilisation : ${FACILITY_NAME} [-config=<an initialization file>] [-idfile=<a file id>] [-idgroup=<a groupfile id>] [-all] [-help]"
 echo -e ""
 echo -e "            -config pour specifier un fichier de configuration, '../cfg/PutFiles.ini' par defaut"
 echo -e "            -idfile=<Identifiant Fichier> permet de choisir le type de fichier a transferer"
 echo -e "            -idgroup=<Identifiant Groupe> permet de choisir le type de groupe de fichiers a transferer"
 echo -e "            -all pour transferer tous les fichiers"
 echo -e "Note : les options -idfile, -idgroup et -all sont exclusives"
 echo -e ""
 echo -e "##########################################################################################################"
 echo -e  ""
 exit 1
}


#------------------------------------------------------------------------------------------------
#--- Fonction de lecture du fichier de configuration
#------------------------------------------------------------------------------------------------

grepInit()
{
    VALUE=`grep -e ${1} ${INIFILE} | grep "=" | awk -F"=" '{ print $2 }'`
    if test -z "${VALUE}"
    then

        cout "La variables "${1}" n'est pas présente dans le fichier de configuration."

	log_msg "$Program" "1" "La variables "${1}" n'est pas présente dans le fichier de configuration."
	log_msg "$Program" "2000" "Fin de $Program"
        exit ${NOK}

    fi

    evalVar ${VALUE}
}


#------------------------------------------------------------------------------------------------
#--- Evaluation des variables d'environement.
#------------------------------------------------------------------------------------------------

evalVar()
{
    TMP="echo ${1}"
    VALUE=`eval ${TMP}`
}


#------------------------------------------------------------------------------------------------
#--- Fonctions d'affichage, de récupération de la date et d'horodatage.
#------------------------------------------------------------------------------------------------

cout()
{
	echo -e $1 
}

thedate()
{
	echo `date +"%Y%m%d%H%M%S"`
}


#------------------------------------------------------------------------------------------------
#--- Pour verifier la presence ou l'absence d'erreur dans le fichier d'erreur SFTP.
# Entrees:    1 - nom du fichier pour les erreurs
#------------------------------------------------------------------------------------------------
function sFTP_errors_handler
{
   retval=${OK}
   unset FTPerror
   
   cat ${1} | egrep "line [0-9]" | head -1 | read FTPerror
   if [ -n "${FTPerror}" ]
   then
      retval=${NOK}
      \echo "    ERREUR : ${FTPerror}" | tee -a ${LOGFILE}
      log_msg "$Program" "1" "Erreur sFTP: ${FTPerror}"
   fi
   >${1}
   return ${retval}

}


#------------------------------------------------------------------------------------------------
#--- Pour verifier l'existance d'un répertoire et l'acces en écriture a ce répertoire.
#------------------------------------------------------------------------------------------------
checkDirectory() 
{
	if [[ ! -d $1  ]]
	then            
		cout "Le repertoire ${1} n'existe pas"
		log_msg "$Program" "1" "Le repertoire ${1} n'existe pas"
		log_msg "$Program" "2000" "Fin de $Program"
		exit 1
	else            
		if [[ ! -w $1  ]]
		then            
			cout "Le repertoire ${1} n'est pas accessible en écriture"
			log_msg "$Program" "1" "Le repertoire ${1} n'est pas accessible en écriture"
			log_msg "$Program" "2000" "Fin de $Program"
		fi
	fi
}

horodate()
{
	fichier=$1
	nom_de_base=`echo ${fichier%.*}`
	ladate=`thedate`
	extension=`echo ${fichier##*.}`
	if [[ ${extension} = ${fichier} ]]
	then
		extension=""
	else
		extension=.$extension
	fi
	newName=$nom_de_base"-"$ladate$extension
	echo $newName
}


OK=${OK:=0} 
NOK=${NOK:=1} 

areConf=${HOME}/DATA/ARE/CONFIG/PutFiles.are.conf

autoload init_logging

Program="PutFiles"
init_logging  "F3G" $areConf $Program
ret=$?
if [[ $ret -ne 0 ]] 
then
	cout "Echec de l'appel de la fonction init_logging" 
	exit ${NOK}
else
	log_msg "$Program" "2000" "Debut de $Program"
fi

#------------------------------------------------------------------------------------------------
#--- Récupération des paramètres de lancement du script
#------------------------------------------------------------------------------------------------

for ac_option
do

    case "${ac_option}" in

        -*=*) ac_optarg=$(exec echo "${ac_option}" | sed 's/[-_a-zA-Z0-9]*=//');;
           *) ac_optarg=""                                                     ;;
    esac

    case "${ac_option}" in
	 -help | -hel | -he | -h | --help | --hel | --he | --h ) usage 0;;
         -version |  -versio |  -versi |  -vers |  -ver |  -ve |  -v | \
        --version | --versio | --versi | --vers | --ver | --ve | --v     ) version;;
         -config=* |  -confi=* |  -conf=* |  -con=* |  -co=* |  -c=* | \
        --config=* | --confi=* | --conf=* | --con=* | --co=* | --c=*     ) IFLAG=${TRUE}
                                                                           CFGFILE=${ac_optarg};;
         -idfile=* ) typeset Idfile=${ac_optarg};;
         -idgroup=* ) typeset Idgroup=${ac_optarg};;
        --all | -all ) typeset Idall=1;;
                *) cout
           cout "Paramètre non supporté: "${ac_option}"."
           usage;;

    esac
done


if [[ $# -lt 1  ]]
then
	usage
fi


#------------------------------------------------------------------------------------------------
#--- Positionnement des variables d'environement
#------------------------------------------------------------------------------------------------
DEFCFGFILE=$CFGFILE

if [ "X$CFGFILE" = "X" ]
then
	DEFCFGFILE=../cfg/PutFiles.ini
	cout "Pas de fichier de configuration en entrée, on prend le fichier par défaut: "${DEFCFGFILE}"."
fi

if test ${IFLAG} -eq ${FALSE}
then
	INIFILE=${DEFCFGFILE}
else
	if test -f ${CFGFILE}
	then
		cout "On prend le fichier de configuration: "${CFGFILE}"."
		INIFILE=${CFGFILE}
	else
		cout "Le fichier spécifié "${CFGFILE}" n'a pas été trouvé, on prend le fichier par défaut: "${DEFCFGFILE}"."
		INIFILE=${DEFCFGFILE}
	fi	
fi

grepInit "outil"
FTPSEC=${VALUE}

grepInit "fichiercsv"
FICHIERCSV=${VALUE}

grepInit "replog"
REPLOG=${VALUE}

DATE=`date +"%Y%m%d%H%M%S"`
FACILITY_NAME=$(basename ${0})
SHLEXT=${SHLEXT:=sh}
LOGEXT=${LOGEXT:=log}
LOGFILE=${REPLOG}/$(basename ${FACILITY_NAME} .${SHLEXT})_${DATE}.${LOGEXT}

grepInit "ftpConnRetry"
NBTENTATIVES=${VALUE}

grepInit "ftpSens"
SENSFTP=${VALUE}

grepInit "modeFTP"
MODEFTP=${VALUE}

grepInit "purge"
PURGE=${VALUE}


#------------------------------------------------------------------------------------------------
#--- Fonctions qui récupèrent les variables à passer en paramètres pour le transfert FTP.
#------------------------------------------------------------------------------------------------

recup_param_file()
{
	#Cette fonction renvoie la valeur du champ recherch $2 pour un enregistrement contenant la valeur $1,
	#dans le fichier csv $3. 
	champ=`cat $FICHIERCSV | grep -v "^#" | grep "^$1;" | cut -d";" -f$2`
	tempChamp="echo $champ"
	Res=`eval $tempChamp`
	echo $Res ;
	exit 0
}


recup_param_transfert_file()
{
	#Cette fonction renvoie la valeur du champ recherché $2 pour un enregistrement contenant la valeur $1,
	#dans le fichier csv $3. 
	champ=`cat $3 | grep -v "^#" | grep "^$1;" | cut -d";" -f$2`
	champ=`echo $champ|awk '{print substr($0,1,1)}'`
	tempChamp="echo $champ"
	Res=`eval $tempChamp`
	echo $Res ;
	exit 0
}


recup_param_dirname_file()
{
	#Cette fonction renvoie la valeur du champ recherché $2 pour un enregistrement contenant la valeur $1,
	#dans le fichier csv $3. 
	champ=`cat $3 | grep -v "^#" | grep "^$1;" | cut -d";" -f$2`
	champ2=`echo $champ | awk '{print(substr($0, length($0)-1, length($0)))}'`
	if [[ ${champ2} = "/*" ]]
	then
		champ3=`dirname $champ`
	else
		champ3=$champ
	fi
	tempChamp="echo $champ3"
	Res=`eval $tempChamp`
	cout "$Res" ;
	exit 0
}

recup_param_group()
{
	#Cette fonction renvoie la valeur du champ recherché $2 correspondant à la ligne passée dans $1.
	champ=`echo $1 | cut -d";" -f$2` ;
	tempChamp="echo $champ"
	Res=`eval $tempChamp`
	cout $Res ;
	exit 0
}

#------------------------------------------------------------------------------------------------
#--- Fonction qui traite le fichier source et le fichier cible avant et après le transfert FTP.
#------------------------------------------------------------------------------------------------

traitement_du_fichier()
{
FILE=$1
if [[ $ARCHIVAGE = "M" ]]
then 
	if [[ X${ARCHDIR} = "X" ]] 
	then
		cout "Il manque le répertoire d'archivage."
		log_msg "$Program" "1" "Il manque le répertoire d'archivage."
		log_msg "$Program" "2000" "Fin de $Program"
		exit ${NOK} 
	else
		if [[ $HORODATAGE = "A" ]]
		then
			${FTPSEC} $HOSTNAME $LOGIN $PASSWD ${SSH_PORT} $NBTENTATIVES $MODEFTP $SENSFTP $PURGE ${OPTION_TRANSFERT} $DISTDIR $FILE
			RES=${?}
			if test ${RES} -ne 0
			then
				MSG_ERREUR=`FTPSec_printmsg.sh ${RES}`
				cout "ECHEC du transfert FTP avec le code retour : ${RES}:${MSG_ERREUR}" 
				log_msg "$Program" "1" "ECHEC du transfert FTP avec le code retour : ${RES}:${MSG_ERREUR}"
				log_msg "$Program" "2000" "Fin de $Program"
				exit ${NOK} 
			else
				fichier=`basename "$FILE"`
				checkDirectory $ARCHDIR
				mv $FILE $ARCHDIR/`horodate "$fichier"`
				cout "On archive et on horodate le fichier source : $FILE"
				cout "On transfère le fichier : $FILE"
			fi
			cout ""
		elif [[ $HORODATAGE = "C" ]]
		then
			temp=$FILE
			tempHorodate=`horodate "$FILE"`
			mv $FILE $tempHorodate
			FILE=$tempHorodate
			${FTPSEC} $HOSTNAME $LOGIN $PASSWD ${SSH_PORT} $NBTENTATIVES $MODEFTP $SENSFTP $PURGE ${OPTION_TRANSFERT} $DISTDIR $FILE
			RES=${?}
			if test ${RES} -ne 0
			then
				mv $FILE $temp
				MSG_ERREUR=`FTPSec_printmsg.sh ${RES}`
				cout "ECHEC du transfert FTP avec le code retour : ${RES}:${MSG_ERREUR}" 
				log_msg "$Program" "1" "ECHEC du transfert FTP avec le code retour : ${RES}:${MSG_ERREUR}"
				log_msg "$Program" "2000" "Fin de $Program"
				exit ${NOK} 
			else
				cout "On transfère le fichier horodaté : $FILE"
				checkDirectory $ARCHDIR
				mv $FILE $ARCHDIR/
				cout "On archive le fichier source : $FILE"
			fi
			cout ""
		elif [[ $HORODATAGE = "CA" ]]
		then
			temp=$FILE
			tempHorodate=`horodate "$FILE"`
			mv $FILE $tempHorodate
			FILE=$tempHorodate
			${FTPSEC} $HOSTNAME $LOGIN $PASSWD ${SSH_PORT} $NBTENTATIVES $MODEFTP $SENSFTP $PURGE ${OPTION_TRANSFERT} $DISTDIR $FILE
			RES=${?}
			if test ${RES} -ne 0
			then
				mv $FILE $temp
				MSG_ERREUR=`FTPSec_printmsg.sh ${RES}`
				cout "ECHEC du transfert FTP avec le code retour : ${RES}:${MSG_ERREUR}" 
				log_msg "$Program" "1" "ECHEC du transfert FTP avec le code retour : ${RES}:${MSG_ERREUR}"
				log_msg "$Program" "2000" "Fin de $Program"
				exit ${NOK} 
			else
				fichier=`basename "$FILE"`
				checkDirectory $ARCHDIR
				mv $FILE $ARCHDIR/`horodate "$fichier"`
				cout "On archive et on horodate le fichier source : $FILE"
				cout "On transfère le fichier horodaté : $FILE"
			fi
			cout ""
		elif [[ $HORODATAGE = "" ]]
		then
			${FTPSEC} $HOSTNAME $LOGIN $PASSWD ${SSH_PORT} $NBTENTATIVES $MODEFTP $SENSFTP $PURGE ${OPTION_TRANSFERT} $DISTDIR $FILE
			RES=${?}
			if test ${RES} -ne 0
			then
				MSG_ERREUR=`FTPSec_printmsg.sh ${RES}`
				cout "ECHEC du transfert FTP avec le code retour : ${RES}:${MSG_ERREUR}" 
				log_msg "$Program" "1" "ECHEC du transfert FTP avec le code retour : ${RES}:${MSG_ERREUR}"
				log_msg "$Program" "2000" "Fin de $Program"
				exit ${NOK} 
			else
				checkDirectory $ARCHDIR
				mv $FILE $ARCHDIR/
				cout "On archive le fichier source : $FILE"
				cout "On transfère le fichier : $FILE"
			fi
			cout ""
		else
			cout "Le paramètre d'horodatage n'est pas correct"
			cout ""
		fi
	fi
elif [[ $ARCHIVAGE = "K" ]]
then
	if [[ $HORODATAGE = "S" ]]
	then
		${FTPSEC} $HOSTNAME $LOGIN $PASSWD ${SSH_PORT} $NBTENTATIVES $MODEFTP $SENSFTP $PURGE ${OPTION_TRANSFERT} $DISTDIR $FILE 
		RES=${?}
		if test ${RES} -ne 0
		then
			MSG_ERREUR=`FTPSec_printmsg.sh ${RES}`
			cout "ECHEC du transfert FTP avec le code retour : ${RES}:${MSG_ERREUR}" 
			log_msg "$Program" "1" "ECHEC du transfert FTP avec le code retour : ${RES}:${MSG_ERREUR}"
			log_msg "$Program" "2000" "Fin de $Program"
			exit ${NOK} 
		else
			mv $FILE `horodate "$FILE"`
			cout "On horodate le fichier source : $FILE"
			cout "On transfère le fichier : $FILE"
		fi
		echo ""
	elif [[ $HORODATAGE = "C" ]]
	then
		temp=$FILE
		tempHorodate=`horodate "$FILE"`
		mv $FILE $tempHorodate
		FILE=$tempHorodate
		${FTPSEC} $HOSTNAME $LOGIN $PASSWD ${SSH_PORT} $NBTENTATIVES $MODEFTP $SENSFTP $PURGE ${OPTION_TRANSFERT} $DISTDIR $FILE 
		RES=${?}
		if test ${RES} -ne 0
		then
			mv $FILE $temp
			MSG_ERREUR=`FTPSec_printmsg.sh ${RES}`
			cout "ECHEC du transfert FTP avec le code retour : ${RES}:${MSG_ERREUR}" 
			log_msg "$Program" "1" "ECHEC du transfert FTP avec le code retour : ${RES}:${MSG_ERREUR}"
			log_msg "$Program" "2000" "Fin de $Program"
			exit ${NOK} 
		else
			cout "On transfère le fichier horodaté : $FILE"
			mv $FILE $temp				
		fi
		cout ""
	elif [[ $HORODATAGE = "SC" ]]
	then
		temp=$FILE
		tempHorodate=`horodate "$FILE"`
		mv $FILE $tempHorodate
		FILE=$tempHorodate
		${FTPSEC} $HOSTNAME $LOGIN $PASSWD ${SSH_PORT} $NBTENTATIVES $MODEFTP $SENSFTP $PURGE ${OPTION_TRANSFERT} $DISTDIR $FILE
		RES=${?}
		if test ${RES} -ne 0
		then
			mv $FILE $temp
			MSG_ERREUR=`FTPSec_printmsg.sh ${RES}`
			cout "ECHEC du transfert FTP avec le code retour : ${RES}:${MSG_ERREUR}" 
			log_msg "$Program" "1" "ECHEC du transfert FTP avec le code retour : ${RES}:${MSG_ERREUR}"
			log_msg "$Program" "2000" "Fin de $Program"
			exit ${NOK} 
		else
			cout "On horodate le fichier source : $FILE"
			cout "On transfère le fichier horodaté : $FILE"
		fi
		cout ""
	elif [[ $HORODATAGE = "" ]]
	then
		${FTPSEC} $HOSTNAME $LOGIN $PASSWD ${SSH_PORT} $NBTENTATIVES $MODEFTP $SENSFTP $PURGE ${OPTION_TRANSFERT} $DISTDIR $FILE
		RES=${?}
		if test ${RES} -ne 0
		then
			MSG_ERREUR=`FTPSec_printmsg.sh ${RES}`
			cout "ECHEC du transfert FTP avec le code retour : ${RES}:${MSG_ERREUR}" 
			log_msg "$Program" "1" "ECHEC du transfert FTP avec le code retour : ${RES}:${MSG_ERREUR}"
			log_msg "$Program" "2000" "Fin de $Program"
			exit ${NOK} 
		else
			cout "On transfère le fichier : $FILE"
		fi
		cout ""
	else
		cout "Le paramtre d'horodatage n'est pas correct"
		cout ""
	fi
elif [[ $ARCHIVAGE = "D" ]]
then
	if [[ $HORODATAGE = "C" ]]
	then
		temp=$FILE
		tempHorodate=`horodate "$FILE"`
		mv $FILE $tempHorodate
		FILE=$tempHorodate
		${FTPSEC} $HOSTNAME $LOGIN $PASSWD ${SSH_PORT} $NBTENTATIVES $MODEFTP $SENSFTP $PURGE ${OPTION_TRANSFERT} $DISTDIR $FILE
		RES=${?}
		if test ${RES} -ne 0
		then
			mv $FILE $temp
			MSG_ERREUR=`FTPSec_printmsg.sh ${RES}`
			cout "ECHEC du transfert FTP avec le code retour : ${RES}:${MSG_ERREUR}" 
			log_msg "$Program" "1" "ECHEC du transfert FTP avec le code retour : ${RES}:${MSG_ERREUR}"
			log_msg "$Program" "2000" "Fin de $Program"
			exit ${NOK} 
		else
			cout "On supprime le fichier source : $temp"
			cout "On transfère le fichier horodaté : $FILE"
			rm $FILE
		fi
		cout ""
	elif [[ $HORODATAGE = "" ]]
	then
		${FTPSEC} $HOSTNAME $LOGIN $PASSWD ${SSH_PORT} $NBTENTATIVES $MODEFTP $SENSFTP $PURGE ${OPTION_TRANSFERT} $DISTDIR $FILE
		RES=${?}
		if test ${RES} -ne 0
		then
			MSG_ERREUR=`FTPSec_printmsg.sh ${RES}`
			cout "ECHEC du transfert FTP avec le code retour : ${RES}:${MSG_ERREUR}" 
			log_msg "$Program" "1" "ECHEC du transfert FTP avec le code retour : ${RES}:${MSG_ERREUR}"
			log_msg "$Program" "2000" "Fin de $Program"
			exit ${NOK} 
		else
			cout "On supprime le fichier source : $FILE"
			cout "On transfère le fichier : $FILE"
			rm $FILE
		fi
		cout ""
	else
		cout "Le paramètre d'horodatage n'est pas correct"
		cout ""
	fi
else
	cout "Le paramétrage d'archivage n'est pas correct"
	cout ""
fi
}


transfert_fichier_suivant_parametre_idfile()
{
	cout "\n\tTraitement du fichier dont l'identifiant est : $1\n"
		
	ErrorFile=./error_file_$$.tmp	
		
	IDFIL=`recup_param_file "$1" "1" "$FICHIERCSV"` 
	IDGROUP=`recup_param_file "$1" "2" "$FICHIERCSV"` 
	FILENM=`recup_param_dirname_file "$1" "3" "$FICHIERCSV"`
	HOSTNAME=`recup_param_file "$1" "4" "$FICHIERCSV"` 	
	LOGIN=`recup_param_file "$1" "5" "$FICHIERCSV"` 
	PASSWD=`recup_param_file "$1" "6" "$FICHIERCSV"` 
	DISTDIR=`recup_param_file "$1" "7" "$FICHIERCSV"` 
	ARCHIVAGE=`recup_param_file "$1" "8" "$FICHIERCSV"` 
	ARCHDIR=`recup_param_file "$1" "9" "$FICHIERCSV"` 
	HORODATAGE=`recup_param_file "$1" "10" "$FICHIERCSV"` 
	TRANSFERT=`recup_param_transfert_file "$1" "11" "$FICHIERCSV"`
	CREATEDISTDIR=`recup_param_transfert_file "$1" "12" "$FICHIERCSV"`
	SSH_PORT=`recup_param_file "$1" "13" "$FICHIERCSV"`
	OPTION_TRANSFERT=`recup_param_file "$1" "14" "$FICHIERCSV"`

	if [[ "X${SSH_PORT}" = "X" ]] 
	then
		cout "utilisation du port ssh par défaut"
		SSH_PORT=22
	else
		cout "utilisation du port ssh $SSH_PORT "
	fi
	
	if [[ "X${OPTION_TRANSFERT}" = "XNO_SUM" ]]
	then
		cout "Transfert avec debrayage du ctl du cksum et transfert sans fichier.en_cours"
	else
		cout "transfert classique avec ctl du chksum"
		OPTION_TRANSFERT="CLASSIC"
	fi
	
	if [[ "X${DISTDIR}" = "X" ]] 
	then
		cout "Il manque le répertoire distant"
		log_msg "$Program" "1" "Il manque le répertoire distant"
	elif [[ "X${FILENM}" = "X" ]] 
	then	
		cout "Il manque l'identifiant du fichier à récupérer"
		log_msg "$Program" "1" "Il manque l'identifiant du fichier à récupérer"
	elif [[ "X${HOSTNAME}" = "X" ]] 
	then	
		cout "Il manque le nom de serveur distant"
		log_msg "$Program" "1" "Il manque le nom de serveur distant"
	elif [[ "X${LOGIN}" = "X" ]] 
	then	
		cout "Il manque le login au serveur distant"
		log_msg "$Program" "1" "Il manque le login au serveur distant"
	elif [[ "X${PASSWD}" = "X" ]] 
	then	
		cout "Il manque le mot de passe au serveur distant"
		log_msg "$Program" "1" "Il manque le mot de passe au serveur distant"
   		
	else
	
	ssh ${LOGIN}@${HOSTNAME} -p ${SSH_PORT} "cd ${DISTDIR}" >${ErrorFile} 2>&1
    retval=$?

	if [ $retval -eq ${NOK} ]; then
		cout "Le repertoire ${DISTDIR} est inexistant"
		log_msg "$Program" "1" "Le repertoire ${DISTDIR} est inexistant"

		if [[ $CREATEDISTDIR = "O" ]]
		then

			cout "Creation du repertoire ${DISTDIR}"			
			log_msg "$Program" "1" "Creation du repertoire ${DISTDIR}"
			\rm -f ${ErrorFile} >/dev/null
			ssh ${LOGIN}@${HOSTNAME} -p ${SSH_PORT} "mkdir -p ${DISTDIR}" > ${ErrorFile} 2>&1
			retval1=$?
			if [ $retval1 -eq ${NOK} ]; then
				cout "Impossible de créer le repertoire ${DISTDIR}"
				log_msg "$Program" "1" "Impossible de créer le repertoire ${DISTDIR}"
				\rm -f ${ErrorFile} >/dev/null
				log_msg "$Program" "2000" "Fin de $Program"
				exit ${NOK}
			fi
		else
			cout " Impossible de faire le transfert vers le repertoire ${DISTDIR}"
			cout " Verifier l'existance du repertoire ${DISTDIR} ou les droits d'acces"
			log_msg "$Program" "1" "Impossible de faire le transfert vers le repertoire ${DISTDIR}"
			log_msg "$Program" "1" "Verifier l'existance du repertoire ${DISTDIR} ou les droits d'acces"
			log_msg "$Program" "2000" "Fin de $Program"
			exit ${NOK}
		fi
	fi
	
	\rm -f ${ErrorFile} >/dev/null
	
	case "${TRANSFERT}" in
		T) 	
			if test -z $FILENM
			then
				cout "Il n'y a pas de nom de fichier pour l'identifiant fichier $1" 
				log_msg "$Program" "1" "Il n'y a pas de nom de fichier pour l'identifiant fichier $1"
			else
				if test `(ls -F1 $FILENM | grep -v "/$") 2> /dev/null | wc -l `  -eq 0
				then
					cout "Aucun fichier correspondant à $FILENM"
					log_msg "$Program" "1" "Aucun fichier correspondant à $FILENM"
				else	
					ls -l ${FILENM} | grep -v "^d" | awk '{print $9}' 2> /dev/null > ${LOGFILE}
					for file in `cat ${LOGFILE}`
					do
					if test -d $file
					then 
						cout "$file est un dossier"
					else
						if test -d ${FILENM} 
						then 
							file=$FILENM/$file
						else
							file=$file
						fi
						#cout "On s'apprete à traiter le fichier : $file"
						traitement_du_fichier "$file"
					fi
					done 
				fi
			fi;;
		O)      	
			if test -z $FILENM
			then
				cout "Il n'y a pas de nom de fichier pour l'identifiant fichier $1"
				log_msg "$Program" "1" "Il n'y a pas de nom de fichier pour l'identifiant fichier $1"
			else
				if test `(ls -F1 $FILENM | grep -v "/$") 2> /dev/null | wc -l `  -eq 0
				then
					cout "Aucun fichier correspondant à $FILENM" 
					log_msg "$Program" "1" "Aucun fichier correspondant à $FILENM" 
				else
					file=`ls -rt1 $FILENM | head -n 1` 
					if test -d $file
					then 
						cout "$file est un dossier"
					else
						if test -d $FILENM 
						then 
							file=$FILENM/$file
							echo $file
						else
							file=$file
						fi
						traitement_du_fichier "$file"
					fi
				fi
			fi;;
		N)      
			if test -z $FILENM
			then
				cout "Il n'y a pas de nom de fichier pour l'identifiant fichier $1" 
				log_msg "$Program" "1" "Il n'y a pas de nom de fichier pour l'identifiant fichier $1"
			else				
				if test `(ls -F1 $FILENM | grep -v "/$") 2> /dev/null | wc -l `  -eq 0
				then
					cout "Aucun fichier correspondant à $FILENM" 
					log_msg "$Program" "1" "Aucun fichier correspondant à $FILENM"
				else
					file=`ls -rt1 $FILENM | tail -1` 
					if test -d $file
					then 
						cout "$file est un dossier"
					else
						if test -d $FILENM 
						then 
							file=$FILENM/$file
							cout $file
						else
							file=$file
						fi
						traitement_du_fichier "$file"
					fi
				fi
			fi;;
		E)	
			if test -z $FILENM
			then
				cout "Il n'y a pas de nom de fichier pour l'identifiant fichier $1" 
			else				
				if test `(ls -F1 $FILENM | grep -v "/$") | wc -l` -eq 0
				then
					cout "Aucun fichier correspondant à $FILENM" 
					log_msg "$Program" "1" "Aucun fichier correspondant à $FILENM"
				else
					cout "Aucun transfert n'est effectué. Sortie due au champ \"Transfert multiple\" fixé à E"
					log_msg "$Program" "1" "Aucun transfert n'est effectué. Sortie due au champ \"Transfert multiple\" fixé à E"
					log_msg "$Program" "2000" "Fin de $Program"
					exit ${NOK} 
				fi
			fi;;
		*) 	
			cout "Sortie en erreur. Le champ \"Transfert multiple\" n'est pas renseigné ou mal renseigné"
			log_msg "$Program" "1" "Sortie en erreur. Le champ \"Transfert multiple\" n'est pas renseigné ou mal renseigné"
			exit ${NOK}
			;;
	esac
	fi
}


#------------------------------------------------------------------------------------------------
#--- Si l'option choisie par l'utilisateur est -idfile
#------------------------------------------------------------------------------------------------
if test $Idfile 
then
	TESTIDFILE=`cat $FICHIERCSV | grep -v "^#" | grep "^$Idfile"`
	if [[ "X${TESTIDFILE}" = "X" ]]
	then
		cout "Identifiant idfile=$Idfile non trouvé dans le fichier de configuration : $FICHIERCSV"
		log_msg "$Program" "1" "Identifiant idfile=$Idfile non trouvé dans le fichier de configuration : $FICHIERCSV"
		log_msg "$Program" "2000" "Fin de $Program"
		exit ${NOK}
	fi

	transfert_fichier_suivant_parametre_idfile "$Idfile"
fi

#------------------------------------------------------------------------------------------------
#--- Si l'option choisie par l'utilisateur est -idgroup
#------------------------------------------------------------------------------------------------
if test $Idgroup
then
        TESTIDGROUP=`cat $FICHIERCSV | grep -v "^#" | grep "^[^;]*;${Idgroup};"`
        if [[ "X${TESTIDGROUP}" = "X" ]]
        then
                cout "Identifiant idgroup=$Idgroup non trouvé dans le fichier de configuration : $FICHIERCSV"
                log_msg "$Program" "1" "Identifiant idgroup=$Idgroup non trouvé dans le fichier de configuration : $FICHIERCSV"
                log_msg "$Program" "2000" "Fin de $Program"
                exit ${NOK}
        fi

        for ligne in `cat $FICHIERCSV | grep -v "^#" | grep "^[^;]*;${Idgroup};"`
        do
                Idfile=`echo $ligne | awk -F';' '{print $1}' ` || { cout "Recuperation de l'identifiant fichier KO: $IDFIL ";
                        log_msg "$Program" "1" "Recuperation de l'identifiant fichier KO: $IDFIL "
                        log_msg "$Program" "2000" "Fin de $Program"
                        exit ${NOK};}
                transfert_fichier_suivant_parametre_idfile "$Idfile"
        done
fi

#------------------------------------------------------------------------------------------------
#--- Si l'option choisie par l'utilisateur est -all
#------------------------------------------------------------------------------------------------
if test $Idall 
then
	for l in `cat $FICHIERCSV | grep -v "^#"`
	do 
		Idfile=`recup_param_group "$l" "1" ` || { cout "Recuperation de l'identifiant fichier KO: $IDFIL ";
			log_msg "$Program" "1" "Recuperation de l'identifiant fichier KO: $IDFIL "
			log_msg "$Program" "2000" "Fin de $Program"
			exit ${NOK};}
		transfert_fichier_suivant_parametre_idfile "$Idfile"
	done
fi

log_msg "$Program" "2000" "Fin de $Program"



