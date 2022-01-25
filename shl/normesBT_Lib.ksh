 #!/usr/bin/ksh
 #-----------------------------------------------------------------------------------
 #                                                            ___o.__               
 #                                                        ,oH8888888888o._          
 #                                                      dP',88888P'''`8888o.        
 #  ____                                              ,8',888888      888888o       
 # |  _ \                                            d8,d888888b    ,d8888888b      
 # | |_) | ___  _   _ _   _  __ _ _   _  ___  ___   ,8PPY8888888boo8888PPPP"'`b     
 # |  _ < / _ \| | | | | | |/ _` | | | |/ _ \/ __|  d8o_                     d8     
 # | |_) | (_) | |_| | |_| | (_| | |_| |  __/\__ \' d888bo.             _ooP d8'        
 # |____/ \___/ \__,_|\__, |\__, |\__,_|\___||___/  d8888888P     ,ooo88888P d8     
 #                     __/ | ___/_                  `8M8888P     ,88888888P ,8P     
 #                    |___/ |__ |  _  |  _  _  _ __  Y88Y88'    ,888888888' dP      
 #                              | (/_ | (/_(_ (_)|||  `8b8P    d8888888888,dP       
 #                                                     Y8,   d88888888888P'         
 #                                                       `Y=8888888888P'             
 #                                                           `''`'''                
 #                                                                                  
 # Systeme Technique F3GFAR                                                   
 #
 # (C) Copyright Bouygues Telecom 2010.                                                 
 #                                                                                  
 # Utilisation, reproduction et divulgation interdites                              
 # sans autorisation ecrite de Bouygues Telecom.           
 # 
 # @(#) $Id: normesBT_Lib.ksh $
 # @(#) $Type: Korn shell $
 # @(#) $Summary: Cette librairie permet de respecter les normes imposées par Bouygues Telecom $
 # @(#) $Inputs: $
 # @(#) $Output: $
 # @(#) $Creation: 10/06/2010 $
 # @(#) $Location: /usr/local/bin $
 # @(#) $Support: AIX 5.3 $
 # @(#) $Owner: F3GFAR $
 # @(#) $Copyright: DSI/DDSI/CDN mbonnot - Bouygues Telecom $ 
 #
 #-----------------------------------------------------------------------------------
 # Versions :
 # V1.0 [14/06/2010] : M. BONNOT du CDN
 #
 # MBONNOT  : 10/06/2010 - Creation
 # CULLOIS  : 22/09/2010 - Test de robustesse du cleanTMP
 # CULLOIS  : 04/01/2011 - Webano 194964 : Si lancement avec l'outil cmd, le test d'unicité échoue
 #                                                                                    
 #-----------------------------------------------------------------------------------


##################################################################
# CheckList des normes BT :
#==========================
#
# 1 Affichage de l'aide	OK
# 2 Les répertoires de fichiers temporaires et intermédiaires doivent être vides en début et fin d'exécution du script	OK

# 4 Deux instances du script ne peuvent pas être lancées en même temps	OK
# 5 Vérification de la définition des variables d'environnement	OK
# 6 Les logs ARE doivent être initialisés	OK
# 7 La purge des logs ARE doit être paramétrable	OK

# 9 Tester les accès aux bases de données	OK

# 8 Les logs ARE de type ERREUR ont une « description » et une « action »	OK / NOK
# 3 Les scripts fils ne peuvent pas être appelés indépendamment du script père	NOK

# 10 La présence et l'accès en lecture de fichier d'entrée est vérifiée	OK / NOK
# 11 Le code de retour du script chapeau est conforme aux normes d'exploitation	OK / NOK
# 12 Avant l'utilisation d'un fichier intermédiaire, vérifier la création de celui-ci	OK / NOK










##################################################################
##################################################################
# FONCTIONS DEFINITION DE VARIABLES :
# ===================================

typeset -r ok=${ok:=0}
typeset -r  ko=${ko:=1}
typeset -r  nok=${nok:=1}
typeset -r longdate="+%Y%m%d%H%M%S"
typeset -r shortdate="+%Y/%m/%d"
# Variable qui definit si les log are sont demarres
typeset logare_started=0

# Variable qui definit si le script a fini de charger sa configuration et est lance
typeset script_started=0

# Variable qui dit definit le point a partir du quel on est sur que l'instance
# courante du script est bien celle qui travail sur le dossier work
typeset script_works=0

##################################################################
##################################################################
# FONCTIONS UTILITAIRES :
# =======================
##################################################################


####################
# FONCTION 
# verifCommand :
# Verifie la bonne execution d'une commande
####################
unalias verifCommand
unset -f verifCommand
function verifCommand
{
	if [[ ${1} -eq 0 ]]; then
		print_msg " --> [ OK ] <--"
		return ${ok}
	else
		print_msg " --> [ KO ] <--"
		return ${ko}
	fi
}
typeset -fx verifCommand


####################
# FONCTION 
# execCommand :
# Se place dans un dossier et execute une commande
# arg1 : Le dossier dans lequel se placer
# arg2..n : La ligne de commande qui va être executee une fois dans le dossier 
####################
unalias execCommand
unset -f execCommand
function execCommand
{
	# On affecte le chemin a une variable
	path=${1}
	# On enleve le chemin de la liste des arguments
	shift
	# On affecte la nouvelle liste dans une variable
	command=$*
	# On se rend dans le dossier de la commande
	cd $path
	print_msg "Lancement de $command"
	# On lance la commande
	$command
	# On verifie la bonne execution de la commande
	verifCommand $?
	if [[ $? -eq ${ko} ]]; then
		cd -
		print_msg "Erreur au lancement de $command" 
		return ${ko}
	fi
	cd -
	return ${ok}
}
typeset -fx execCommand


####################
# FONCTION 
# print_msg :
# Ecrit un message selon les options choisies [Sortie standard OU/ET fichier de trace]
# arg1 : le message a logguer. Si arg1 est un fichier, on le recopie dans les logs
# Exemple : print_msg "Hello World"
# Exemple : print_msg "../out/Hello.txt" 
####################
unalias print_msg
unset -f print_msg
function print_msg
{
	if [[ ${DISP_ECHO} == "ON" ]] && [[ ${TRACE} == "ON" ]]; then
		if [[ -f ${1} ]]; then
			cat ${1} | tee -a ${LOG_PATH}
		else
			print - "$*" | tee -a ${LOG_PATH}
		fi
	elif [[ ${TRACE} == "ON" ]]; then
		if [[ -f ${1} ]]; then
			cat ${1} >> ${LOG_PATH}
		else
			print - "$*" >> ${LOG_PATH}
		fi
	elif [[ ${DISP_ECHO} == "ON" ]]; then
		if [[ -f ${1} ]]; then
			cat ${1}
		else
			print - "$*"
		fi
	fi
}
typeset -fx print_msg

####################
# FONCTION 
# print_are :
# Ecrit les log_are s'ils sont activés
# arg1 : Le nom du script
# arg2 : Le mot cle des logs are
# arg3 : La chaine de caractere si le mot cle en necessite une
# Exemple : print_are $0 MOT_CLE "Ma chaine de caractere"
####################
unalias print_are
unset -f print_are
function print_are
{
	if [[ ${LOG_ARE} == "TRUE" ]]; then 
		log_msg $*
	fi
}
typeset -fx print_are


####################
# FONCTION 
# verifDir :
# Verifie la lecture/ecriture/execution d'un repertoire
####################
unalias verifDir
unset -f verifDir
function verifDir
{
	# On verifie que le repertoire existe
	if [[ ! -d ${2} ]]; then
		print_msg "Le repertoire defini dans ${1}:${2} n'existe pas"
		print_are ${0} DIR_EXISTS_KO ${2}
		endScript ${ko}
	fi
	print_are ${0} DIR_EXISTS_OK ${2}

	# On verifie les droits du repertoire
	if [[ ! -w ${2} ]] || [[ ! -x ${2} ]] || [[ ! -r ${2} ]]; then
		print_msg "ERREUR : le repertoire $2 n a pas les droits RWX"
		print_are ${0} DIR_RIGHTS_KO ${2}
		endScript ${ko}
	fi
	print_are ${0} DIR_RIGHTS_OK ${2}
}
typeset -fx verifDir

####################
# FONCTION 
# verifFile :
# Verifie la lecture d'un fichier
####################
unalias verifFile
unset -f verifFile
function verifFile
{
if [[ ! -f ${2} ]]; then
	print_msg "Le fichier defini dans ${1}:${2} n'existe pas"
    print_are ${0} F_EXISTS_KO ${1}
    endScript ${ko}
else
	print_are ${0} F_EXISTS_OK ${1}
    if [[ ! -r ${1} ]]; then
		print_msg "Erreur: Fichier ${1} est interdit en lecture.\n"
		print_are ${0} F_RIGHTS_KO ${1} "R"
		endScript ${ko}
	fi
fi
print_are ${0} F_RIGHTS_OK ${1} "R"
}
typeset -fx verifFile


####################
# FONCTION 
# runSQLFile :
# Execute un fichier SQL et verifie les erreurs
# arg1 : Le nom du fichier à executer
# arg2 : Le fichier temporaire de resultats de console SQLPlus
# arg3..n : Les arguments de la commande SQLPlus
####################
unalias runSQLFile
unset -f runSQLFile
function runSQLFile
{
	# On recupere le nom du fichier SQL
	sqlFile=${1}
	tmpFile=${2}
	# On enleve le fichier SQL de la liste des arguments
	shift 2
	# On affiche le lancement du fichier SQL
	print_msg "Lancement du fichier SQL ${sqlFile} -- En cours"
	sqlplus -s $db_connect @${sqlFile} $* > ${tmpFile}
	ctSQLError=`grep -i "ORA-" "${tmpFile}"`
	if [[ "X${ctSQLError}" != "X" ]]; then
	   print_are ${0} DB_FILEEXEC_KO ${sqlFile}
	   print_are ${0} DB_ERROR ${ctSQLError}
	   print_msg "Erreur d'execution du fichier SQL ${sqlFile}"
	   # On sors en erreur
	   return ${ko}
	fi
	print_are ${0} DB_FILEEXEC_OK ${sqlFile}
	print_msg "Execution du fichier SQL ${sqlFile} -- OK"
	return ${ok}
}
typeset -fx runSQLFile

##################################################################
##################################################################
# FONCTIONS GENERIQUES :
# ======================
##################################################################


####################
# FONCTION 
# verifLaunchScript :
# Verifie le lancement d'une seule occurence du script
# --> CheckList 4
####################
unalias verifLaunchScript
unset -f verifLaunchScript
function verifLaunchScript
{
	# Verification du nombre d'occurence de lancement du script
	nombre_occurences=`ps -ef | grep ${SCRIPT_NAME} | grep -v grep | grep -v -E "(grep|vi|emacs|nedit|more|cmd|tail)[[:space:]]" | wc -l`

	# Si le script est deja lancé
	if [[ ${nombre_occurences} -gt 1 ]]; then
	  print_msg "Erreur : Le script est deja lance"
	  # On termine le script
	  # Il NE faut PAS lancer endScript sinon le dossier de travail est nettoye
	  exit 2
	fi
}
typeset -fx verifLaunchScript

####################
# FONCTION 
# checkDatabaseConnection :
# Nettoie le repertoire temporaire
####################
unalias checkDatabaseConnection
unset -f checkDatabaseConnection
function checkDatabaseConnection
{
	# Test de la connexion a la base
	testConnection=`sqlplus -s ${DB_ORACLE_USERNAME}/${DB_ORACLE_PASSWORD}@${DB_ORACLE_SID} << %EOT%
%EOT%`
	ctError=`print ${testConnection} | grep "ORA-"`
	# Si il y a une erreur
	if [[ "X${ctError}" != "X" ]]; then
	   print_are ${0} DB_CONNECT_KO ${DB_ORACLE_SID} ${DB_ORACLE_USERNAME}
	   print_msg "Erreur de connection a la base <${DB_ORACLE_SID}> pour le user <${DB_ORACLE_USERNAME}>"
	   # On termine le script
	   endScript ${ko}
	fi
	print_are ${0} DB_CONNECT_OK ${DB_ORACLE_SID} ${DB_ORACLE_USERNAME}
	print_msg "La connexion a la base <${DB_ORACLE_SID}> pour le user <${DB_ORACLE_USERNAME}> est etablie"
}
typeset -fx checkDatabaseConnection


####################
# FONCTION 
# get_passwd :
# Recupere le mot de passe Oracle (wrapper)
# param : login base passwd
####################
unalias get_passwd
unset -f get_passwd
function get_passwd
{
	retVal=""
	mon_pwd=$3
	#Nom de la ressource en minuscules
	ma_BaseMin=`echo "$1" | tr [A-Z] [a-z]`
	mon_UserMin=`echo "$2" | tr [A-Z] [a-z]`
	#Appel composant commun
	newPwd=`ExtPwd.sh "${ma_BaseMin}" "${mon_UserMin}" 2>/dev/null`
	if [ "X${newPwd}" != "X" ]
	then
	  mon_pwd="${newPwd}"
	fi
	DB_ORACLE_PASSWORD=${mon_pwd}
}
typeset -fx get_passwd


####################
# FONCTION 
# loadVar :
# Charge les variables generique du script
####################
unalias loadVar
unset -f loadVar
function loadVar
{
	# On verifie les variables du script
	print ${SCRIPT_NAME:?La variable SCRIPT_NAME est vide} > /dev/null

	#Chargement de la configuration
	if [[ ! -f '../cfg/'${SCRIPT_NAME}'.cfg' ]]; then
		# Le fichier de configuration n'etant pas charge on affiche simplement un message dans la console
		print "ERREUR, le fichier de configuration ${SCRIPT_DIR}/cfg/${SCRIPT_NAME}.cfg n'existe pas"
		endScript ${ko}
	fi
	# On charge le fichier de configuration
	. ../cfg/${SCRIPT_NAME}.cfg

	# On verfie les variables du Script
	print ${SCRIPT_DIR:?La variable SCRIPT_DIR est vide} > /dev/null
	print ${SCRIPT_DATEFOR:?La variable SCRIPT_DATEFOR est vide} > /dev/null
	print ${SCRIPT_TIME:?La variable SCRIPT_TIME est vide} > /dev/null
	# On verifie quelques variables indispensables du fichier
	print ${TRACE:?La variable TRACE est vide} > /dev/null
	if [[ $TRACE == "ON" ]]; then
		print ${LOG_DIR:?La variable LOG_DIR est vide} > /dev/null
		# On verifie les repertoire des traces
		print ${LOG_FILE:?La variable LOG_FILE est vide} > /dev/null
		print ${LOG_PATH:?La variable LOG_PATH est vide} > /dev/null
	fi
	print ${DISP_ECHO:?La variable DISP_ECHO est vide} > /dev/null
	print ${DB_IN_SCRIPT:?La variable DB_IN_SCRIPT est vide} > /dev/null

	# Si il y a une base de donnees, on verifie les variables relatives
	if [[ ${DB_IN_SCRIPT} == "TRUE" ]]; then
		print ${DB_ORACLE_USERNAME:?La variable DB_ORACLE_USERNAME est vide} > /dev/null
		print ${DB_ORACLE_PASSWORD:?La variable DB_ORACLE_PASSWORD est vide} > /dev/null
		print ${DB_ORACLE_SID:?La variable DB_ORACLE_SID est vide} > /dev/null
		
		get_passwd ${DB_ORACLE_USERNAME} ${DB_ORACLE_SID} ${DB_ORACLE_PASSWORD}
		db_connect=${DB_ORACLE_USERNAME}/${DB_ORACLE_PASSWORD}@${DB_ORACLE_SID}
	fi
}
typeset -fx loadVar

####################
# FONCTION 
# loadLibrairies :
# Charge les librairies generique du script
####################
unalias loadLibrairies
unset -f loadLibrairies
function loadLibrairies
{
	#Si la librairie de verrou est disponible
	if [[ -f $HOME/cmnF3G/Tools/shl/liblock.sh ]];then
		# Librarie de verrou
		. $HOME/cmnF3G/Tools/shl/liblock.sh
		# Nom du verrou
		LOCK=`pwd`"/${SCRIPT_NAME}.ksh.lock"
	else
		print "Erreur la librairie de verrouillage n'existe pas"
		endScript ${ko}
	fi
}
typeset -fx loadLibrairies

####################
# FONCTION 
# startScript :
# Demarre le script et pose un verrou de lancement
####################
unalias startScript
unset -f startScript
function startScript
{
	
	# Controle des parametres du script
	controlParameter $*
	
	# Chargement des variables generique
	loadVar
	
	# Chargement des variables utilisateur
	loadScriptVar
	
	# Chargement des librairies generiques
	loadLibrairies
	
	# Chargement des librairies utilisateur
	loadScriptLibrairies

	# Verfification de la non duplication de lancement
	verifLaunchScript

	# Initialisation des log ARE
	initLogARE
	logare_started=1

	# Demarrage du Script
	print "Initialisation du traitement: "`date` && print_msg "Initialisation du traitement: "`date`
	print_are ${0} MOT_BEGIN ${SCRIPT_NAME}
	
	# Verification des fichiers et repertoires du script
	if [[ $TRACE == "ON" ]]; then
			verifDir '${LOG_DIR}' ${LOG_DIR}
	fi
	verifDirectories
	
	# Poser un verrou de lancement pour empecher d'autres lancements
	# --> CheckList 4
	lock

	print
	print "================================================================================"
	print "========================= LANCEMENT DE ${SCRIPT_NAME}"
	print "================================================================================"
	print
	script_started=1
	
	# Nettoyage du repertoire temporaire
	cleanTMP
	script_works=1
	
	if [[ ${DB_IN_SCRIPT} == "TRUE" ]]; then
		# Verification de la connexion a la DB
		checkDatabaseConnection
	fi
}
typeset -fx startScript

####################
# FONCTION 
# endScript :
# Termine le script et libere le verrou
# arg1 : [ok | ko] defini le retour du script
####################
unalias endScript
unset -f endScript
function endScript
{
	# L'instance courante du script est celle qui travail sur le repetoire WORK
	if [[ ${script_works} -eq 1 ]]; then
		# Nettoyage du repertoire temporaire
		cleanTMP
	fi

	# Arret du Script
	if [[ ${1} -eq ${ok} ]]; then
		print "Fin normale du traitement le "`date` && print_msg "Fin normale du traitement: "`date`
		if [[ ${logare_started} -eq 1 ]]; then
			print_are ${0} MOT_END_OK ${SCRIPT_NAME}
		fi
		#Liberation du verrou de lancement si et seulement si le script est locked
		if [[ ${script_started} -eq 1 ]]; then
			unlock
		fi
		if [[ ${TRACE} == "ON" ]]; then
			print "*** Fichier log: ${LOG_PATH} ***\n"
		else
			print "*** Pas de fichier de log ***"
		fi
		exit ${ok}
    elif [[ ${1} -eq ${ko} ]]; then
		print "Fin anormale du traitement: "`date` && print_msg "Fin anormale du traitement: "`date`
		if [[ ${logare_started} -eq 1 ]]; then
			print_are ${0} MOT_END_KO ${SCRIPT_NAME}
		fi
		#Liberation du verrou de lancement si et seulement si le script est locked
		if [[ ${script_started} -eq 1 ]]; then
			unlock
		fi
		if [[ ${TRACE} == "ON" ]]; then
			print "*** Fichier log: ${LOG_PATH} ***\n"
		else
			print "*** Pas de fichier de log ***"
		fi
		exit ${ko}
    fi
}
typeset -fx endScript

####################
# FONCTION 
# initLogARE :
# initialise les log ARE
####################
unalias initLogARE
unset -f initLogARE
function initLogARE
{
	# On verifie les variables qui servent aux logs are
	print ${LOG_ARE:?La variable LOG_ARE est vide} > /dev/null
	print ${SUB_SYSTEME:?La variable SUB_SYSTEME est vide} > /dev/null
	print ${LOG_ARE_CONF:?La variable LOG_ARE_CONF est vide} > /dev/null
	
	# Les repertoires et les fichiers qui servent aux logs ARE sont verifies a leur initialisation
	
	if [[ ${LOG_ARE} == "TRUE" ]]; then 
		autoload init_logging
		init_logging ${SUB_SYSTEME} ${LOG_ARE_CONF} ${SCRIPT_NAME}
		if [ $? -ne ${ok} ]
		then
			print "Erreur lors de l initialisation des logs ARE"
			endScript ${ko}
		fi
	fi
}
typeset -fx initLogARE

####################
# FONCTION 
# cleanTMP :
# Nettoie le repertoire temporaire
# --> CheckList 2
####################
unalias cleanTMP
unset -f cleanTMP
function cleanTMP
{
	if [[ -n ${DIR_WORK} ]]; then
		print_msg "Nettoyage du repertoire temporaire"
		rm -rf ${DIR_WORK}/*
		verifCommand $?
		# On log en ARE le resultat
		if [[ $? -eq ${ok} ]]; then
			print_are ${0} MOT_CLN_TMP_OK ${DIR_WORK}
		else
			print_are ${0} MOT_CLN_TMP_KO ${DIR_WORK}
		fi
	fi
}
typeset -fx cleanTMP





####################################################################################################################################
# Les fonctions ci-dessus ne doivent pas etre modifiees
####################################################################################################################################
# Les fonctions suivantes doivent etre utilisees dans le script :
# -- 

# print_msg "Mon message" --> pour ecrire dans les fichiers de log et dans la console
# print_are $0 ERREUR "totot" --> conformement aux log are
# endScript ${ok}|${ko} pour terminer le script ok ou pas
# verifFile <Nom de la variable contenant le fichier> <$laVariable>
# verifDir <Nom de la variable contenant le repertoire> <$laVariable>
# verifCommand <$?> pour ecrire OK ou KO apres l'execution d'une commande

####################################################################################################################################
####################################################################################################################################
##################################################################
##################################################################
# FONCTIONS POUVANT ETRE SURCHARGEES :
# =======================
##################################################################

####################
# FONCTION 
# loadScriptVar :
# Charge les variables utilisateur du script
####################
unalias loadScriptVar
unset -f loadScriptVar
function loadScriptVar
{
	# Definir ici les variables particulieres qui vont etre utilisees dans le script
	#--------------
	# Exemple
	# typeset myVar=0
	#==============
	nimportequoiegalzero=0

	#--------------
	# A COMPLETER -
	#--------------
}
typeset -fx loadScriptVar


####################
# FONCTION 
# loadScriptLibrairies :
# Charge les librairies utilisateur du script
####################
unalias loadScriptLibrairies
unset -f loadScriptLibrairies
function loadScriptLibrairies
{
	# Definir ici les librairies particulieres qui vont etre utilisees dans le script
	#--------------
	# Exemple
	# . ./directory/librarie/mylib.ksh
	#==============
	nimportequoiegalzero=0

	#--------------
	# A COMPLETER -
	#--------------
}
typeset -fx loadScriptLibrairies


####################
# FONCTION 
# verifEnvVar :
# Verifie les variables d'environnement
####################
unalias verifEnvVar
unset -f verifEnvVar
function verifEnvVar
{
	#--------------
	# Definir ici les variables a verifier dans le script
	#--------------
	# Exemple
	# print ${USER:?La variable USER est vide} > /dev/null
	#==============
	nimportequoiegalzero=0

	#--------------
	# A COMPLETER -
	#--------------
}
typeset -fx verifEnvVar