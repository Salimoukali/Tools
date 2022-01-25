#!/usr/bin/ksh
#--- Marking Strings --------------------------------------
#--- @(#)F3GFAR-S: $Workfile:   GetFiles.sh  $ $Revision: 94 $
#----------------------------------------------------------
#--- @(#)F3GFAR-E: $Workfile:   GetFiles.sh  $ VersionLivraison = 2.1.23.1
#----------------------------------------------------------
#-----------------------------------------------------------------------------------
# @(#) $Id: GetFiles.sh $
# @(#) $Type: Korn shell $
# @(#) $Summary: Fichier de transfert de fichiers produits d'une machine distante vers F3GFAR distante via FTP $
# @(#) $Inputs: cf. MEX $
# @(#) $Output: 0 si OK sinon 1 $
# @(#) $Creation: 04/11/2005 $
# @(#) $Location: ${HOME}/cmnF3G/Tools/shl $
# @(#) $Support: AIX 5.3  et AIX 6.1 $
# @(#) $Owner: F3GFAR $
# @(#) $Copyright: DSI/DDSI/CDN  - Bouygues Telecom $ 
#-----------------------------------------------------------------------------------
# Author            : FPO
# Version           : V1.0
# Creation date     : 04/11/2005
# Updating dates    : 
#                     16/11/2005 - WebAno 82810 et 82875
#                     29/11/2005 - WebAno 83428
#                     05/12/2005 - WebAno 83866 et 83935
#                     06/12/2005 - WebAno 83936 et 83938
#                     08/12/2005 - WebAno 83927
#                     06/06/2006 - PVCS 118
#                     08/01/2007 - Report WebAno 102082
#					  25/07/2012 - WebAno 247036
# Input Data        : none
# Output Data       : none
#*****************************************************************************************


#*****************************************************************************************
# Liste des fonctions utilis�es
#*****************************************************************************************

# ----------------------------------------------------------------------------------------
# Nom:        usage
#
# Entrees:    Aucune
# Sorties:    Aucune
# Traitement: Affiche l'aide du shell.
# ----------------------------------------------------------------------------------------
function usage
{
   echo -e ""
   echo -e "######################################## MODE DE LANCEMENT ###############################################"
   echo -e ""
   echo -e "Ce script procede aux transferts FTP sortants."
   echo -e "\nSyntaxe d'utilisation : ${FACILITY_NAME} [-control] [-config=<an initialization file>] [-idfile=<a file id>] [-idgroup=<a groupfile id>] [-all] [-help]"
   echo -e ""
   echo -e "            -config=<an init file> pour sp�cifier un fichier (sans l'extension .cfg)"
   echo -e "            -control pour r�cup�rer le fichier de controle d�fini dans le fichier de configuration"
   echo -e "            -idfile=<Identifiant Fichier> permet de choisir le type de fichier � transf�rer"
   echo -e "            -idgroup=<Identifiant Groupe> permet de choisir le type de groupe de fichiers � transf�rer"
   echo -e "            -all pour transf�rer tous les fichiers"
   echo -e "            -nolog pour ne pas creer de fichier de log"
   echo -e "Note : les options -control -idfile, -idgroup et -all sont exclusives"
   echo -e ""
   echo -e "##########################################################################################################"
   echo -e ""
   exit ${1}
}

# ----------------------------------------------------------------------------------------
# Nom:        Exit_Program
#
# Entrees:    1 - Code de sortie du shell
# Sorties:    0K - NOK
# Traitement: G�re la sortie du shell
# ----------------------------------------------------------------------------------------
function Exit_Program
{
   nowdate="`date +%Y%m%d` `date +%H:%M:%S`"

   rm -f ${LsFile} >> /dev/null
   rm -f ${LsFileMatch} >> /dev/null
   rm -f ${ErrorFile} >> /dev/null
   
   if [ "${LOGFILE}" != "/dev/null" ]
   then
      \echo -e  "Fichier de logs : ${LOGFILE}"
   fi
   
   if [ ${ERRFTP} -ne ${OK} ]
   then
      \echo -e  "\n${nowdate} : Fin en erreur du shell.\n" | tee -a ${LOGFILE}
      log_msg "$Program" "2000" "Fin en erreur de $Program"
      exit ${ERRFTP}
   fi
   
   if [ $1 -eq ${OK} ]
   then
      \echo -e  "\n${nowdate} : Fin normale du shell.\n" | tee -a ${LOGFILE}
      log_msg "$Program" "2000" "Fin normale de $Program"
      exit ${OK}
   else
      \echo -e  "\n${nowdate} : Fin en erreur du shell.\n" | tee -a ${LOGFILE}
      log_msg "$Program" "2000" "Fin en erreur de $Program"
      exit ${NOK}   
   fi
}

# ----------------------------------------------------------------------------------------
# Nom:        ls_in_FTP
#
# Entrees:    1 - R�pertoire � interroger
#             2 - Fichier de spool
#             3 - 
#             4 - Option de tri (rt - t ou vide)
# Sorties:    0K - NOK
# Traitement: Liste le contenu d'un r�pertoire
# ----------------------------------------------------------------------------------------
function ls_in_FTP
{
retVal=${OK}

   sftp -P ${SSH_PORT} ${FTPUSER}@${FTPSERVER} <<EOF >${ErrorFile}
   cd ${1}
   dir -l${4} 
   quit
EOF
	
	cat ${ErrorFile} | grep -v 'sftp>' > ${2}
	sFTP_errors_handler
	retVal=$?

	return $retVal
}



# ----------------------------------------------------------------------------------------
# Nom:        get_sFTP
#
# Entrees:    
#             1 - Purge
#             2 - R�pertoire Cible
#             3 - Chemin du fichier Source
# Sorties:    0K - NOK
# Traitement: Recupere un fichier en sFTP
# ----------------------------------------------------------------------------------------
function get_sFTP
{
   isPurge=$1	
   localDir=$2
   getsrcdir=`dirname $3`
   getsrcfile=`basename $3`
   
   if [ "${isPurge}" = "O" ]
   then
		sftp -P ${SSH_PORT} -b - ${FTPUSER}@${FTPSERVER} <<-EOF >${ErrorFile} 2>&1
		cd ${getsrcdir}
		lcd ${localDir}
		get ${getsrcfile}
		rm ${getsrcfile}
		quit
		EOF
		
   else

    	sftp -P ${SSH_PORT} -b - ${FTPUSER}@${FTPSERVER} <<-EOF > ${ErrorFile} 2>&1
   		cd ${getsrcdir}
   		lcd ${localDir}
   		get ${getsrcfile}
   		quit
		EOF
   fi
   
   sFTP_errors_handler
   retourFtp=$?
   if [ "${retourFtp}" = "${OK}" ]  && [ "${CONVERT}" = "CONV" ]
   then 
  	#conversion du fichier en unix
  	convert_file ${localDir} ${getsrcfile}
   fi
   return $retourFtp
} 

# ----------------------------------------------------------------------------------------
# Nom:        convert_file
#
# Entrees:    
#             1 - Repertoire contenant le fichier � convertir
#			  2 - Nom du fichier � convertir
# Sorties:    retourne un fichier temporaire converti
# Traitement: Converti les fichier dos en unix
# ----------------------------------------------------------------------------------------
function convert_file
{
	convertFile=$1"/"$2
	
	TmpFile=/tmp/dos2ux_`date +%Y%m%d_%H%M%S`.tmp
	
	#Conversion au format unix et sauvegarde dans un fichier temporaire
	awk '{ sub("\r$", ""); print }' ${convertFile} > ${TmpFile}
	
	mv ${TmpFile} ${convertFile}
	
	rm -f ${TmpFile}
	
}

# ----------------------------------------------------------------------------------------
# Nom:        put_sFTP
#
# Entrees:    
#             1 - R�pertoire Cible
#             2 - Chemin du fichier Source
# Sorties:    0K - NOK
# Traitement: Envoie un fichier en sFTP
# ----------------------------------------------------------------------------------------
function put_sFTP
{
   remoteDir=$1	
   getsrcdir=`dirname $2`
   getsrcfile=`basename $2`
    
   sftp -b - ${FTPUSER}@${FTPSERVER} -P ${SSH_PORT} <<-EOF > ${ErrorFile} 2>&1
   cd ${remoteDir}
   lcd ${getsrcdir}
   put ${getsrcfile}
   quit
EOF
   	
   sFTP_errors_handler
   return $?
}

# ----------------------------------------------------------------------------------------
# Nom:        FTP_errors_handler
#
# Entrees:    1 - Fichier de spool de l'execution du FTP
# Sorties:    0K - NOK
# Traitement: Analyse l'execution d'un FTP
# ----------------------------------------------------------------------------------------
function FTP_errors_handler
{
   retval=${OK}
   unset FTPerror
   cat ${ErrorFile} | sed -n '/^5[35]0/p' | head -1 | read FTPerror
   if [ -n "${FTPerror}" ]
   then
      retval=${NOK}
      \echo -e  "    ERREUR : ${FTPerror}" | tee -a ${LOGFILE}
      log_msg "$Program" "1" "Erreur FTP: ${FTPerror}"
   fi
   \rm -f ${ErrorFile}
   return ${retval}
}

# ----------------------------------------------------------------------------------------
# Nom:        FTP_errors_handler
#
# Entrees:    1 - Fichier de spool de l'execution du sFTP
# Sorties:    0K - NOK
# Traitement: Analyse l'execution d'un sFTP
# ----------------------------------------------------------------------------------------
function sFTP_errors_handler
{ 		
   retval=${OK}
   unset FTPerror
   cat ${ErrorFile} | egrep "Permission denied|No such file or directory" | head -1 | read FTPerror
   if [ -n "${FTPerror}" ]
   then
      retval=${NOK}
      \echo -e  "    ERREUR : ${FTPerror}" | tee -a ${LOGFILE}
      log_msg "$Program" "1" "Erreur sFTP: ${FTPerror}"
   fi
   \rm -f ${ErrorFile}
   return ${retval}
}

# ----------------------------------------------------------------------------------------
# Nom:        AnalyseCSVFile
#
# Entrees:    1 - Fichier CSV
# Sorties:    Aucune
# Traitement: Recherche la pr�sence de doublon d'idfile dans le fichier CSV
# ----------------------------------------------------------------------------------------
function AnalyseCSVFile
{
   if [ ! -r "${FICHIERCSV}" ]
   then
      \echo -e  "    ERREUR : Le fichier CSV ${FICHIERCSV} n'est pas accessible en lecture\n" | tee -a ${LOGFILE}
      log_msg "$Program" "1" "Le fichier CSV ${FICHIERCSV} n'est pas accessible en lecture"
      Exit_Program ${NOK}
   else
      cat ${FICHIERCSV} |  grep -v "^#" | grep -v "^[\t ]*$" | cut -d";" -f1 |
      while read file_id
      do
         cat ${FICHIERCSV} | grep "^${file_id};" | wc -l | read nb_occu
         if [ ${nb_occu} -ne 1 ]
         then 
            \echo -e  "    ERREUR : L'idfile ${file_id} n'est pas unique dans le fichier CSV ${FICHIERCSV}\n" | tee -a ${LOGFILE}
            log_msg "$Program" "1" "L'idfile ${file_id} n'est pas unique dans le fichier CSV ${FICHIERCSV}"
            Exit_Program ${NOK}
         fi
      done
   fi
   return ${OK}
}

# ----------------------------------------------------------------------------------------
# Nom:        IsValidMode
#
# Entrees:    Aucune
# Sorties:    0K - NOK
# Traitement: v�rifie la validit� des options de transfert
# ----------------------------------------------------------------------------------------
function IsValidMode
{
   retval=${OK}
   
   if [ "$ARCHIVAGE" != "M" -a "$ARCHIVAGE" != "D" -a "$ARCHIVAGE" != "K" ]
   then
      retval=${NOK}
   fi
   
   echo $HORODATAGE | sed -e 's/[S]*[C]*[A]*//' | read IsValidHoro
   if [ -n "${IsValidHoro}" ]
   then
      retval=${NOK}
   fi
   
   IsLike "$HORODATAGE" "S"
   IsLikeVal=$?
   if [ "$ARCHIVAGE" = "M" -o "$ARCHIVAGE" = "D" ] && [ ${IsLikeVal} -eq ${OK} ]
   then
      retval=${NOK}
   fi
   
   IsLike "$HORODATAGE" "A"
   IsLikeVal=$?
   if [ "$ARCHIVAGE" = "E" -o "$ARCHIVAGE" = "D" ] && [ ${IsLikeVal} -eq ${OK} ]
   then
      retval=${NOK}
   fi
   
   return ${retval}
}

# ----------------------------------------------------------------------------------------
# Nom:        getListFile
#
# Entrees:    1 - Identifiant du fichier � traiter dans le fichier de controle
# Sorties:    1 - Liste des fichiers correspondant au pattern recherch� : ${LISTE}
# Traitement: G�n�re une liste des fichiers qui correspondent � l'identifiant recherch�
# ----------------------------------------------------------------------------------------
function getListFile
{
    if [ -r "${OUTDIR}/${FTPCTLFILE}" ]
    then
      LISTE=`cat ${OUTDIR}/${FTPCTLFILE} | grep -w $1 | awk -F"=" '{ print $2 }'`   
      echo ${LISTE}
    fi
}

# ----------------------------------------------------------------------------------------
# Nom:        GenerateMatchingDataFile
#
# Entrees:    1 - Identifiant du fichier � traiter dans le fichier CSV
# Sorties:    1 - Liste des fichiers correspondant au pattern recherch� : ${LsFileMatch}
# Traitement: G�n�re une liste des fichiers qui correspondent au pattern du ou des fichiers
#             � transf�rer.
# ----------------------------------------------------------------------------------------
function GenerateMatchingDataFile
{
   retval=${OK}
   
   #R�cup�ration du chemin des fichiers � r�cup�rer
   FileVar=`cat $FICHIERCSV | grep "^${1};" | cut -d";" -f3`
   evalVar ${FileVar}
   
   #R�cup�ration du r�pertoire des fichiers � r�cup�rer
   FileRep=`dirname ${VALUE}`
   evalVar ${FileRep}

   #G�n�ration du fichier des donn�es pr�sentes dans le r�pertoire
   if [ "${TRANSFERT}" = "O" ]
   then
      ls_in_FTP ${VALUE} ${LsFile} ${ErrorFile} "rt"
      retval=$?
   elif [ "${TRANSFERT}" = "N" ]
   then
      ls_in_FTP ${VALUE} ${LsFile} ${ErrorFile} "t"
      retval=$?
   else
      ls_in_FTP ${VALUE} ${LsFile} ${ErrorFile}
      retval=$?
   fi
   
   if [ ${retval} -ne ${OK} ]
   then
      return ${NOK}
   fi
   
   #G�n�ration du fichier des donn�es correspondant � la recherche
   FileNameExrReg=`echo "${FileVar}" | awk 'BEGIN {FS="/"} {print $NF}' | sed -e 's/*/.*/g'`

   if [ "${TRANSFERT}" = "O" -o "${TRANSFERT}" = "N" ]
   then
      if [ "${FTPSERVERFORMAT}" = "2" ]
      then
        cat ${LsFile} | grep -v '<DIR>' | grep -v ".CheckSum" | egrep "${FileNameExrReg}" | awk '{print $NF}' | tail -1 > ${LsFileMatch}
      else
        cat ${LsFile} | sed -n '/^-/p' | grep -v ".CheckSum" | egrep "${FileNameExrReg}" | awk '{print $NF}' | head -1 > ${LsFileMatch}
      fi
   else
      if [ "${FTPSERVERFORMAT}" = "2" ]
      then
        cat ${LsFile} | grep -v '<DIR>' | grep -v ".CheckSum" | egrep "${FileNameExrReg}" | awk '{print $NF}'> ${LsFileMatch}      
      else
        cat ${LsFile} | sed -n '/^-/p' | grep -v ".CheckSum" | egrep "${FileNameExrReg}" | awk '{print $NF}'> ${LsFileMatch}
      fi
   fi
   
   if [ "${TRANSFERT}" = "E" ] && [ `cat ${LsFileMatch} | wc -l` -gt 1 ]
   then
      \echo -e  "    ERREUR : Plus de 1 fichier correspondant, incompatible avec le Mode E" | tee -a ${LOGFILE}
      log_msg "$Program" "1" "Plus de 1 fichier correspondant, incompatible avec le Mode E"
      return ${NOK}
   fi
   
   return ${retval}
}

# ----------------------------------------------------------------------------------------
# Nom:        IsLike
#
# Entrees:    1 - Cha�ne � tester
#             2 - Cha�ne de r�f�rence
# Sorties:    0 (OK) ou 1 (KO)
# Traitement: V�rifie que la cha�ne � tester contient la cha�ne de r�f�rence
# ----------------------------------------------------------------------------------------
function IsLike
{
   if [ `echo "${1}" | sed -n "/${2}/p" | wc -l` -eq 0 ]
   then
      return 1
   fi
   return 0
}

# ----------------------------------------------------------------------------------------
# Nom:        evalVar
#
# Entrees:    1 - Variable � �valuer
# Sorties:    La variable �valu�e dans la variable $VALUE
# Traitement: Evalue la variable
# ----------------------------------------------------------------------------------------
function evalVar
{
    TMP="echo ${1}"
    VALUE=`eval ${TMP}`
}


# ----------------------------------------------------------------------------------------
# Nom:        horodate
#
# Entrees:    1 - Variable � horodater
# Sorties:    Aucune
# Traitement: Horodate le fichier
# ----------------------------------------------------------------------------------------
function horodate
{
   fichier=$1
   nom_de_base=`echo ${fichier%.*}`
   ladate=`date +"%Y%m%d%H%M%S"`
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

# ----------------------------------------------------------------------------------------
# Nom:        Verif_Variables_Conf
#
# Entrees:    1 - La liste de variables dans la variable ${ListVariable}
# Sorties:    Aucune
# Traitement: V�rifie l'initialisation des variables du fichier de configuration
# ----------------------------------------------------------------------------------------
function Verif_Variables_Conf
{
   Result="True"
   
   for VARIABLE_ENV in `echo "${ListVariable}"`
   do
      VALEUR=`print "$""$VARIABLE_ENV"`
      VALEUR=`eval echo $VALEUR`
      if [ "x$VALEUR" = "x" ]
      then
         \echo -e  "La variable d'environnement $VARIABLE_ENV n'est pas renseignee" | tee -a ${LOGFILE}
         log_msg "$Program" "1" "La variable d'environnement $VARIABLE_ENV n'est pas renseignee"
         Result="False"
      fi
   done
   
   if [ "$Result" = "False" ]
   then
      Exit_Program ${NOK}
   fi
}

# ----------------------------------------------------------------------------------------
# Nom:        recup_param_file
#
# Entrees:    1 - L'identifiant du fichier � transf�rer dans le fichier CSV
#             2 - Num�ro du champ � r�cup�rer
#             3 - Fichier de conf CSV
# Sorties:    La valeur du champ demand�
# Traitement: R�cup�re la valeur d'un champ dans le fichier de conf CSV
# ----------------------------------------------------------------------------------------
function recup_param_file
{
   #Cette fonction renvoie la valeur du champ recherch� $2 pour un enregistrement contenant la valeur $1,
   #dans le fichier csv $3. 
   champ=`cat $3 | grep "^$1;" | cut -d";" -f$2`
   tempChamp="echo $champ"
   Res=`eval $tempChamp`
   echo $Res ;
   exit 0
}

# ----------------------------------------------------------------------------------------
# Nom:        recup_param_transfert_file
#
# Entrees:    1 - L'identifiant du fichier � transf�rer dans le fichier CSV
#             2 - Num�ro du champ � r�cup�rer
#             3 - Fichier de conf CSV
# Sorties:    La valeur du champ demand�
# Traitement: R�cup�re la valeur d'un champ dans le fichier de conf CSV
# ----------------------------------------------------------------------------------------
function recup_param_transfert_file
{
   #Cette fonction renvoie la valeur du champ recherch� $2 pour un enregistrement contenant la valeur $1,
   #dans le fichier csv $3. 
   champ=`cat $3 | grep -v "^#" | grep "^$1;" | cut -d";" -f$2`
   champ=`echo $champ|awk '{print substr($0,1,1)}'`
   tempChamp="echo $champ"
   Res=`eval $tempChamp`
   echo $Res ;
   exit 0
}

# ----------------------------------------------------------------------------------------
# Nom:        recup_param_dirname_file
#
# Entrees:    1 - L'identifiant du fichier � transf�rer dans le fichier CSV
#             2 - Num�ro du champ � r�cup�rer
#             3 - Fichier de conf CSV
# Sorties:    La valeur du champ demand�
# Traitement: R�cup�re la valeur d'un champ dans le fichier de conf CSV
# ----------------------------------------------------------------------------------------
function recup_param_dirname_file
{
   #Cette fonction renvoie la valeur du champ recherch� $2 pour un enregistrement contenant la valeur $1,
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
   \echo -e  $Res ;
   exit 0
}

# ----------------------------------------------------------------------------------------
# Nom:        recup_param_group
#
# Entrees:    1 - La ligne de recherche
#             2 - Num�ro du champ � r�cup�rer
# Sorties:    La valeur du champ demand�
# Traitement: R�cup�re la valeur d'un champ dans la ligne pass�e
# ----------------------------------------------------------------------------------------
function recup_param_group
{
   #Cette fonction renvoie la valeur du champ recherch� $2 correspondant � la ligne pass�e dans $1.
   champ=`echo $1 | cut -d";" -f$2` ;
   tempChamp="echo $champ"
   Res=`eval $tempChamp`
   \echo -e  $Res ;
   exit 0
}

# ----------------------------------------------------------------------------------------
# Nom:        traitement_du_fichier
#
# Entrees:    1 - Chemin du fichier � transf�rer
# Sorties:    Aucune
# Traitement: Transfere le fichier et r�alise les op�rations configur�es
# ----------------------------------------------------------------------------------------
function traitement_du_fichier
{

   FILE=$1

   TransFileName=`basename "${FILE}"`
   HoroFileName=`horodate "$TransFileName"`
   SourceRepName=`dirname "$FILE"`
   TargetRepName="$OUTDIR"
   ArchiveRepName="$ARCHDIR"
   Purge="N"
   Put="False"
   retvalf=${OK}
   
   \echo -e  "\n    Traitement du fichier $TransFileName" | tee -a ${LOGFILE}
         
   #=Gestion de la purge=========================================================================
   if [ "$HORODATAGE" = "S" -o "$ARCHIVAGE" = "D" -o "$ARCHIVAGE" = "M" ]
   then
      Purge="O"
   fi
   #=Fin Gestion de la purge=====================================================================      
   
   #=Gestion du FTP pour le mode put=============================================================
   if [ "$HORODATAGE" = "S" ] #Test d'horodatage du fichier source
   then
      Put="True"
      PutDistDir="${SourceRepName}"
      PutDistFileName="${TargetRepName}/${HoroFileName}"
   elif [ "$ARCHIVAGE" = "M" ] #Test d'archivage du fichier
   then
      Put="True"
      IsLike "${HORODATAGE}" "A"
      IsLikeRet=$?
      if [ IsLikeRet -eq 0 ] #Test d'horodatage du fichier � archiver
      then
         PutDistDir="${ArchiveRepName}"
         PutDistFileName="${TargetRepName}/${HoroFileName}"
      else
         PutDistDir="${ArchiveRepName}"
         PutDistFileName="${TargetRepName}/${TransFileName}"
      fi
   fi
   #=Fin Gestion du FTP pour le mode put=========================================================    

   #=R�cup�ration du fichier sur le serveur distant==============================================
   
	if [ "${TYPEFTP}" = "sFTP" -o "${TYPEFTP}" = "FTP" ]
	then
		get_sFTP "$Purge" "$OUTDIR" "$FILE"
		
		if [ $? -ne ${OK} ]
		 then
		    \echo -e  "    ECHEC du transfert sFTP : sFTPerror" | tee -a ${LOGFILE}
		    log_msg "$Program" "1" "ECHEC du transfert sFTP : sFTPerror"
		    retvalf=${NOK}
		 fi 
	elif [ "${TYPEFTP}" = "sFTPSec" -o "${TYPEFTP}" = "FTPSec" ]
	then
		${SFTPSEC} "$FTPSERVER" "$FTPUSER" "$FTPPWD" "$SSH_PORT" "$FTPATTNB" "$MODEFTP" "get" "$Purge" "$OUTDIR" "$FILE"
		RES=${?}
		if [ ${RES} -ne ${OK} ]
		then
	      	ERRFTP=${RES}
	        MSG_ERREUR=`${REP_NAME}/FTPSec_printmsg.sh ${RES}`
	        \echo -e  "    ECHEC du transfert sFTPSEC avec le code retour : ${RES}:${MSG_ERREUR}" | tee -a ${LOGFILE}
	        log_msg "$Program" "1" "ECHEC du transfert sFTPSEC avec le code retour : ${RES}:${MSG_ERREUR}"
			retvalf=${NOK}
		fi
	fi
   #=Fin R�cup�ration du fichier sur le serveur distant==========================================

   #=Copie en cas d'horodatage===================================================================
   cp "${TargetRepName}/${TransFileName}" "${TargetRepName}/${HoroFileName}" 2>/dev/null
   #=Fin Copie en cas d'horodatage===============================================================
   
   #=Transfert des fichiers======================================================================
   #=Fichiers horodat�s (si mode K-S ou M-A[C]) ou fichier normal (si mode M-[C])  
    if [ ${retvalf} -eq ${OK} -a "${Put}" = "True" ]
    then
		if [ "${TYPEFTP}" = "FTP" -o "${TYPEFTP}" = "sFTP" ]
		then
			put_sFTP "$PutDistDir" "$PutDistFileName"
			if [ $? -ne ${OK} ]
			then
				\echo -e  "    ECHEC du transfert sFTP : sFTPerror" | tee -a ${LOGFILE}
				log_msg "$Program" "1" "ECHEC du transfert sFTP : sFTPerror"
				retvalf=${NOK}
			fi  
		elif [ "${TYPEFTP}" = "sFTPSec" -o "${TYPEFTP}" = "FTPSec" ]
		then
			${SFTPSEC} "$FTPSERVER" "$FTPUSER" "$FTPPWD" "$SSH_PORT" "$FTPATTNB" "$MODEFTP" "put" "N" "$PutDistDir" "$PutDistFileName"
			RES=${?}
			if [ ${RES} -ne ${OK} ]
			then
				ERRFTP=${RES}
				MSG_ERREUR=`${REP_NAME}/FTPSec_printmsg.sh ${RES}`
				\echo -e  "    ECHEC de l'archivage sFTPSEC avec le code retour : ${RES}:${MSG_ERREUR}" | tee -a ${LOGFILE}
				log_msg "$Program" "1" "ECHEC du transfert sFTPSEC avec le code retour : ${RES}:${MSG_ERREUR}"
				retvalf=${NOK}
			fi 
		fi
	fi
   #=Transfert des fichiers======================================================================

   #=Gestion de l'horodatage du fichier cible====================================================
   IsLike "${HORODATAGE}" "C"
   IsLikeRet=$?
   if [ IsLikeRet -eq 0 ]
   then
      rm -f "${TargetRepName}/${TransFileName}" 2>/dev/null
   else
      rm -f "${TargetRepName}/${HoroFileName}" 2>/dev/null
   fi    
   #=Fin Gestion de l'horodatage du fichier cible================================================
   
   return ${retvalf}
}


# ----------------------------------------------------------------------------------------
# Nom:        transfert_fichier_suivant_parametre_idfile
#
# Entrees:    1 - L'identifiant du fichier � transf�rer
# Sorties:    La valeur du champ demand�
# Traitement: Traite le fichier suivant son identifiant
# ----------------------------------------------------------------------------------------
function transfert_fichier_suivant_parametre_idfile
{
   retvalt=${OK}
   \echo -e  "  ====> Traitement de l'identifiant : $1" | tee -a ${LOGFILE}
   log_msg "$Program" "2000" "Traitement de l'identifiant : $1"
      
   IDFIL=`recup_param_file "$1" "1" "$FICHIERCSV"` 
   IDGROUP=`recup_param_file "$1" "2" "$FICHIERCSV"` 
   FILENM=`recup_param_dirname_file "$1" "3" "$FICHIERCSV"`
   FTPSERVER=`recup_param_file "$1" "4" "$FICHIERCSV"`    
   FTPUSER=`recup_param_file "$1" "5" "$FICHIERCSV"` 
   FTPPWD=`recup_param_file "$1" "6" "$FICHIERCSV"` 
   FTPSERVERFORMAT=`recup_param_file "$1" "7" "$FICHIERCSV"`
   OUTDIR=`recup_param_file "$1" "8" "$FICHIERCSV"`
   ARCHIVAGE=`recup_param_file "$1" "9" "$FICHIERCSV"` 
   ARCHDIR=`recup_param_file "$1" "10" "$FICHIERCSV"` 
   HORODATAGE=`recup_param_file "$1" "11" "$FICHIERCSV"` 
   TRANSFERT=`recup_param_transfert_file "$1" "12" "$FICHIERCSV"`
   TYPEFTP=`recup_param_file "$1" "13" "$FICHIERCSV"`
   CONVERT=`recup_param_file "$1" "14" "$FICHIERCSV"`
   SSH_PORT=`recup_param_file "$1" "15" "$FICHIERCSV"`
     
   ## si le port ssh n'est pas paramétré on fixe la variable avec le port ssh par défaut.
   if [[ -z $SSH_PORT ]]
   then
     echo "Port ssh par défaut utilisé "
     SSH_PORT=22
   fi
     
   IsValidMode
   IsValidModeVal=$?
   
   if [[ "X${OUTDIR}" = "X" ]] 
   then
      \echo -e  "    ERREUR : Il manque le r�pertoire de sortie" | tee -a ${LOGFILE}
      log_msg "$Program" "1" "Il manque le r�pertoire de sortie"
      retvalt=${NOK}
   elif [[ "X${FILENM}" = "X" ]] 
   then  
      \echo -e  "    ERREUR : Il manque l'identifiant du fichier � r�cup�rer" | tee -a ${LOGFILE}
      log_msg "$Program" "1" "Il manque l'identifiant du fichier � r�cup�rer"
      retvalt=${NOK}
   elif [[ "X${FTPSERVER}" = "X" ]] 
   then  
      \echo -e  "    ERREUR : Il manque le nom de serveur distant" | tee -a ${LOGFILE}
      log_msg "$Program" "1" "Il manque le nom de serveur distant"
      retvalt=${NOK}
   elif [[ "X${FTPUSER}" = "X" ]] 
   then  
      \echo -e  "    ERREUR : Il manque le login au serveur distant" | tee -a ${LOGFILE}
      log_msg "$Program" "1" "Il manque le login au serveur distant"
      retvalt=${NOK}
   elif [[ "X${FTPPWD}" = "X" ]] 
   then  
      \echo -e  "    ERREUR : Il manque le mot de passe au serveur distant" | tee -a ${LOGFILE}
      log_msg "$Program" "1" "Il manque le mot de passe au serveur distant"
      retvalt=${NOK}
   elif [[ "X${FTPSERVERFORMAT}" = "X" ]] 
   then
      \echo -e  "    ERREUR : Il manque le mode FTP du serveur (standard Unix ou Windows special)" | tee -a ${LOGFILE}
      log_msg "$Program" "1" "Il manque le mode FTP du serveur (standard Unix ou Windows special)"
      retvalt=${NOK}
   elif [ "X${FTPSERVERFORMAT}" != "X1" -a "X${FTPSERVERFORMAT}" != "X2" ]
   then
      \echo -e  "    ERREUR : Le mode d'affichage ${FTPSERVERFORMAT} n'est pas valide" | tee -a ${LOGFILE}
      log_msg "$Program" "1" "Le mode d'affichage ${FTPSERVERFORMAT} n'est pas valide"
      retvalt=${NOK}  
   elif [[ "X${TYPEFTP}" = "X" ]] 
   then  
      \echo -e  "    ERREUR : Il manque le type de FTP � utiliser" | tee -a ${LOGFILE}
      log_msg "$Program" "1" "Il manque le type de FTP � utiliser"
      retvalt=${NOK}
   elif [ "X${TYPEFTP}" != "XFTP" -a "X${TYPEFTP}" != "XFTPSec" -a "X${TYPEFTP}" != "XsFTPSec" -a "X${TYPEFTP}" != "XsFTP" ]
   then
      \echo -e  "    ERREUR : Le type de ftp ${TYPEFTP} n'est pas valide" | tee -a ${LOGFILE}
      log_msg "$Program" "1" "Le type de ftp ${TYPEFTP} n'est pas valide"
      retvalt=${NOK}
   elif [ ! -d ${OUTDIR} ]
   then  
      \echo -e  "    ERREUR : Le r�pertoire ${OUTDIR} n'existe pas." | tee -a ${LOGFILE}
      log_msg "$Program" "1" "Le r�pertoire ${OUTDIR} n'existe pas"
      retvalt=${NOK}
   elif [ IsValidModeVal -eq ${NOK} ]
   then  
      \echo -e  "    ERREUR : Les options d'archivage <$ARCHIVAGE> et d'horodatage <$HORODATAGE> sont incompatibles ou non valables." | tee -a ${LOGFILE}
      log_msg "$Program" "1" "Les options d'archivage <$ARCHIVAGE> et d'horodatage <$HORODATAGE> sont incompatibles ou non valables"
      retvalt=${NOK}
   elif [ "${TRANSFERT}" != "T" -a "${TRANSFERT}" != "O" -a "${TRANSFERT}" != "N" -a "${TRANSFERT}" != "E" ]
   then  
      \echo -e  "    ERREUR : L'option de transfert multiple <$TRANSFERT> n'est pas valide." | tee -a ${LOGFILE}
      log_msg "$Program" "1" "L'option de transfert multiple <$TRANSFERT> n'est pas valide"
      retvalt=${NOK}
   elif [ "${ARCHIVAGE}" = "M" -a -z "${ARCHDIR}" ]
   then  
      \echo -e  "    ERREUR : Le r�pertoire d'archivage n'est pas defini." | tee -a ${LOGFILE}
      log_msg "$Program" "1" "Le r�pertoire d'archivage n'est pas defini"
      retvalt=${NOK} 
   else
      GenerateMatchingDataFile "$1"
      if [ $? -ne ${NOK} ]
      then
         if [ -s ${LsFileMatch}  ]
         then
            cat ${LsFileMatch} | 
            while read file
            do
               traitement_du_fichier "${FileRep}/${file}"
               if [ $? -ne 0 ]
               then
                  \echo -e  "    Fin de transfert du fichier ${file} == <KO> ==" | tee -a ${LOGFILE}
                  retvalt=${NOK}
               else
                  \echo -e  "    Fin de transfert du fichier ${file} == <OK> ==" | tee -a ${LOGFILE}
               fi
            done
         else
            \echo -e  "    Aucun fichier trouv� pour le transfert." | tee -a ${LOGFILE}
            log_msg "$Program" "2000" "Aucun fichier trouv� pour le transfert"
         fi
      else
         retvalt=${NOK}
      fi
   fi
   \echo -e  "  <==== Fin du traitement de l'identifiant : $1\n" | tee -a ${LOGFILE}
   
   return ${retvalt}
}

OK=${OK:=0} 
NOK=${NOK:=1}
ERRFTP=${ERRFTP:=0}
IFLAG="False"
CFLAG="False"
Mode="Normal"
SHLEXT=${SHLEXT:=sh}
LOGEXT=${LOGEXT:=log}
CFGEXT=${CFGEXT:=cfg}
unset LOGFILE

#------------------------------------------------------------------------------------------------
#--- GESTION DE LA LIGNE DE COMMANDE
#------------------------------------------------------------------------------------------------

for ac_option
do

    case "${ac_option}" in

        -*=*) ac_optarg=$(exec echo "${ac_option}" | sed 's/[-_a-zA-Z0-9]*=//');;
           *) ac_optarg=""                                                     ;;
    esac

    case "${ac_option}" in
    -help | -hel | -he | -h | --help | --hel | --he | --h ) usage 0;;
         -config=* |  -confi=* |  -conf=* |  -con=* |  -co=* |  -c=* | \
        --config=* | --confi=* | --conf=* | --con=* | --co=* | --c=*     ) IFLAG="True"
                                                                           CFGFILE=${ac_optarg}.${CFGEXT};;
         -control | --control ) CFLAG="True";;
         -idfile=* ) typeset Idfile=${ac_optarg}
                     Mode="Param";;
         -idgroup=* ) typeset Idgroup=${ac_optarg}
                     Mode="Param";;
         --all | -all ) typeset Idall=1
                     Mode="Param";;
         -nolog | --nolog ) LOGFILE=/dev/null;;
         -verbose | --verbose );;
           *) \echo -e 
           \echo -e  "Param�tre non support�: "${ac_option}"."
           usage 1;;

    esac
done

#------------------------------------------------------------------------------------------------
#--- GESTION DES VARIABLES (1/2)
#------------------------------------------------------------------------------------------------
DATE=`date +"%Y%m%d%H%M%S"`
FACILITY_NAME=$(basename ${0})
REP_NAME=$(dirname ${0})

#------------------------------------------------------------------------------------------------
#--- GESTION DU FICHIER DE CONFIGURATION
#------------------------------------------------------------------------------------------------
if [ ${IFLAG} = "True" ]
then
   if [ -r ${CFGFILE} ]
   then
      . ${CFGFILE}
   elif [ -r ../shl/${CFGFILE} ]
   then
      . ../shl/${CFGFILE}
   elif [ -r ../cfg/${CFGFILE} ]
   then
      . ../cfg/${CFGFILE}
   else
      echo "  ERREUR : Fichier de configuration ${CFGFILE} non trouve."
      exit ${NOK}
   fi
else
   if [ -r "../cfg/GetFiles.cfg" -a "${Mode}" = "Param" ]
   then
      . ../cfg/GetFiles.cfg
   # Cas aux limites : GetFiles est appel� depuis un r�pertoire exotique (qui n'est pas celui de GetFiles.sh)
   # en mode "Param" sans avoir pr�ciser de fichier de config explicitement
   # --> on se place alors dans le r�pertoire de GetFiles.sh
   elif [ -r ${REP_NAME}/../cfg/${CFGFILE} -a "${Mode}" = "Param" ]
   then
      cd $REP_NAME
	  . ../cfg/GetFiles.cfg
   elif [ "${Mode}" = "Param" ]
   then
      echo "  ERREUR : Fichier de configuration ../cfg/GetFiles.cfg non trouve."
      exit ${NOK}
   else
      echo "  ERREUR : Aucun fichier de configuration n'a ete defini."
      exit ${NOK}
   fi
fi


#------------------------------------------------------------------------------------------------
#--- GESTION DES VARIABLES (2/2)
#------------------------------------------------------------------------------------------------

LsFile="tmp_list_file_$$.lst"
LsFileMatch="tmp_list_match_$$.lst"
ErrorFile="tmp_error_$$.lst"

SFTPSEC="sFTPSecMultiple.sh"

if [ -z "${LOGFILE}" ]
then
   LOGFILE=${LOGDIR}/$(basename ${FACILITY_NAME} .${SHLEXT})_${DATE}.${LOGEXT}
fi
ShellReturn=${OK}


areConf=${HOME}/DATA/ARE/CONFIG/GetFiles.are.conf

autoload init_logging

Program="GetFiles"
init_logging  "F3G" $areConf $Program
ret=$?
if [[ $ret -ne 0 ]] 
then
   echo "Echec de l'appel de la fonction init_logging" 
   exit ${NOK}
fi


nowdate="`date +%Y%m%d` `date +%H:%M:%S`"
\echo -e  "\n${nowdate} : Debut du shell.\n" | tee -a ${LOGFILE}
log_msg "$Program" "2000" "Debut de $Program"

#------------------------------------------------------------------------------------------------
#--- Cas ou l'on utilise pas le fichier de configuration GetFiles.cfg
#------------------------------------------------------------------------------------------------
if [ "${Mode}" = "Normal" ]
then
   ListVariable="FTPUSER FTPPWD FTPSERVER FTPATTNB PURGE FILETAG FTPCTLFILE LOGDIR OUTDIR FTPSRCDIR"

   Verif_Variables_Conf
   
   MODEFTP="ascii"
   HORODATAGE=""
   if [ "$PURGE" = "N" ]
   then
      ARCHIVAGE="K"
   else
      ARCHIVAGE="D"
   fi

   if [ "${CFLAG}" = "False" ]
   then
      LISTFILE=`getListFile ${FILETAG}`
      if [ -z "${LISTFILE}" ]
      then
         echo "Aucun nom de fichier correspondant au tag ${FILETAG} trouv� dans ${OUTDIR}/${FTPCTLFILE}." | tee -a ${LOGFILE}
         log_msg "$Program" "1" "Aucun nom de fichier correspondant au tag ${FILETAG} trouv� dans ${OUTDIR}/${FTPCTLFILE}"
         Exit_Program ${NOK}
      fi

      for NormalFile in ${LISTFILE}
      do
        traitement_du_fichier ${NormalFile}
        if [ $? -eq ${NOK} ]
        then
           Exit_Program ${NOK}
        fi
      done

      rm -f ${OUTDIR}/${FTPCTLFILE} 2>/dev/null

   else

      FILECTL=${FTPSRCDIR}/${FTPCTLFILE}
      traitement_du_fichier ${FILECTL}
      if [ $? -eq ${NOK} ]
      then
         Exit_Program ${NOK}
      fi

   fi
else
   ListVariable="FICHIERCSV FTPATTNB MODEFTP LOGDIR"

   Verif_Variables_Conf
   
   AnalyseCSVFile

   #------------------------------------------------------------------------------------------------
   #--- Si l'option choisie par l'utilisateur est -idfile
   #------------------------------------------------------------------------------------------------
   if test $Idfile 
   then
      TESTIDFILE=`cat $FICHIERCSV | grep -v "^#" | grep "^$Idfile"`
      if [[ "X${TESTIDFILE}" = "X" ]]
      then
        \echo -e  "  Identifiant idfile=$Idfile non trouv� dans le fichier de configuration : $FICHIERCSV" | tee -a ${LOGFILE}
        log_msg "$Program" "1" "Identifiant idfile=$Idfile non trouv� dans le fichier de configuration : $FICHIERCSV"
        Exit_Program ${NOK}
      fi
      
      transfert_fichier_suivant_parametre_idfile "$Idfile"
      if [ $? -eq ${NOK} ]
      then
         ShellReturn=${NOK}
      fi
   fi

   #------------------------------------------------------------------------------------------------
   #--- Si l'option choisie par l'utilisateur est -idgroup
   #------------------------------------------------------------------------------------------------
   if test $Idgroup 
   then
      TESTIDGROUP=`cat $FICHIERCSV | grep -v "^#" | grep "^[^;]*;${Idgroup};"`
      if [[ "X${TESTIDGROUP}" = "X" ]]
      then
         \echo -e  "  Identifiant idgroup=$Idgroup non trouv� dans le fichier de configuration : $FICHIERCSV" | tee -a ${LOGFILE}
         log_msg "$Program" "1" "Identifiant idgroup=$Idgroup non trouv� dans le fichier de configuration : $FICHIERCSV"
         Exit_Program ${NOK}
      fi
   
      for l in `cat $FICHIERCSV | grep -v "^#" | grep "^[^;]*;${Idgroup};"`
      do 
         Idfile=`recup_param_group "$l" "1" ` || { \echo -e  "  Recuperation de l'identifiant fichier KO: $IDFIL | tee -a ${LOGFILE}"; Exit_Program ${NOK};}
         transfert_fichier_suivant_parametre_idfile "$Idfile"
         if [ $? -eq ${NOK} ]
         then
            ShellReturn=${NOK}
         fi
      done
   fi 
   
   #------------------------------------------------------------------------------------------------
   #--- Si l'option choisie par l'utilisateur est -all
   #------------------------------------------------------------------------------------------------
   if test $Idall 
   then
      for l in `cat $FICHIERCSV | grep -v "^#"`
      do 
         Idfile=`recup_param_group "$l" "1" ` || { \echo -e  "  Recuperation de l'identifiant fichier KO: $IDFIL | tee -a ${LOGFILE} "; Exit_Program ${NOK};}
         transfert_fichier_suivant_parametre_idfile "$Idfile"
         if [ $? -eq ${NOK} ]
         then
            ShellReturn=${NOK}
         fi
      done
   fi
fi

Exit_Program ${ShellReturn}


