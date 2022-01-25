#!/bin/bash
# ATTENTION : Ce "shell bang" est nécessaire car seul BASH permet de catcher les erreurs de chaque PIPE et gérer les regexp.
# Script écrit en UTF-8

      ##############################################################################     
# ###################################################################################### #
#         Archivage d'un DUMP de la base de donnees CAUX vers ARCSYS (SFTP)              #
# ###################################################################################### #
      ##############################################################################     


# Debug du script : export SHL_ODEBUG=1 / unset SHL_ODEBUG
[[ -n $SHL_ODEBUG ]] && set -vx

# Retire tout alias de commande (colorisation, affichage human readable, ...)
unalias -a

# Usage de grep -E portable vs egrep plus puissant mais moins portable (attention : restriction de certains usages comme ::alpha:: ou {n,m})
alias egrep='grep -E'

# Donne les mêmes droits au user caux/ppcaux qu'au groupe cauxgrp commun aux 2 (rwx).
# Permet au sn3mfact (all) de lister/lire (r.x) le contenu des dossiers/fichiers mais pas de modifier (w).
umask 0002


# ########################################################################################
# Variables globales
# ########################################################################################

# Le script
export SHELL_SCRIPT=$(basename ${0})
export SHELL_NAME=$(basename ${0} .sh)
export SHELL_HOME=$(cd $(dirname ${0});cd ..;pwd)
export SHELL_ARGS="$*"
export SHELL_PID=$$

export DIR_SHL=$SHELL_HOME/shl
export DIR_CFG=$SHELL_HOME/cfg

export DIR_LOG=$HOME/DATA/ARE/LOG

# Configuration du script (convention)
export CFG_FILE=$DIR_CFG/$SHELL_NAME.cfg

# Templates du fichier SIP (en 3 parties)
export SIP_DEB=$DIR_CFG/$SHELL_NAME.sip_head.xml
export SIP_LIGNE=$DIR_CFG/$SHELL_NAME.sip_line.xml
export SIP_FIN=$DIR_CFG/$SHELL_NAME.sip_foot.xml

# Configuration des logs ARE
export ARE_CODE_SUBSYSTEM="ARC" # sur 3 lettres
export ARE_CODE_PROGRAM=$SHELL_NAME
export ARE_CFG=$HOME/DATA/ARE/CONFIG/$SHELL_NAME.are.conf
export ARE_DIC=$HOME/DATA/ARE/DICO/$SHELL_NAME.are.dico

# Librairie des fonctions ARE, en version BASH (cf. FPATH pour la version KSH)
# La différence avec la version KSH : pas de shell bang ksh, les print sont traduits en echo, UTF-8
export ARE_LIB=$HOME/DATA/ARE/LIB/are30/init_logging_bash

# Fichier de contrôle de reprise
export CTL_REPRISE=$DIR_CFG/$SHELL_NAME.reprise

# Fichier de contrôle de parallel run
export CTL_ENCOURS=$DIR_CFG/$SHELL_NAME.encours

# Droits/Modes à positionner sur le serveur ARCSYS
export MODE_ARCSYS_FICHIER=660
export MODE_ARCSYS_DOSSIER=770



# ########################################################################################
# Trap (catch interruption utilisateur Ctrl+C pour killer les process en cours en plus du script lui-même)
# ########################################################################################

onTrap()
{
	[[ -n $SHL_ODEBUG ]] && set -vx # Debug du script

	trace ARC-0310 "Arrêt forcé du traitement. Clean du fichier $CTL_ENCOURS"
	rm -f $CTL_ENCOURS
	
	trace ARC-0310 "Arrêt forcé du traitement. Nettoyage des processus fils. Terminaison du script via kill -- -$$"
	ps -fu $USER # pour info
	kill -- -$$
	# à partir de là, le script n'est plus et il n'est plus possible de faire d'autres actions
}

trap 'onTrap' INT



# ########################################################################################
# Fonctions
# ########################################################################################


# Sortie du traitement
# Entrées :
#  $1 : Code de retour
# Sorties : aucune
sortir()
{
	[[ -n $SHL_ODEBUG ]] && set -vx # Debug du script

	# Argument
	rc=$1
	
	# Message de sortie suivant OK/KO
	if [[ $rc -eq 0 ]]
	then
		trace ARC-0500 "Traitement d'archivage terminé OK (pour les étapes demandées)"
	else # Code NOTICE car juste trace de fin ici (l'erreur a déjà été tracée et correctement typée)
		trace ARC-0500 "Traitement d'archivage terminé EN ERREUR (pour les étapes demandées)"
	fi
	
	# Nettoyage du fichier d'encours
	rm -f $CTL_ENCOURS
	
	# Sortie ...
	exit $1 # le seul exit du code avec le raccourci du -h et le controle_parallel() !!!
}



# Contrôle si le traitement est déjà en cours de run (qqsoit ses arguments)
# Entrées : aucune
# Sorties : aucune
controle_parallel()
{
	[[ -n $SHL_ODEBUG ]] && set -vx # Debug du script
	
	# Si le fichier de controle existe déjà alors on sort en erreur de // run
	if [[ -s $CTL_ENCOURS ]]
	then
		trace ARC-0310 "Le traitement tourne déjà ($CTL_ENCOURS existe et indique un PID $(< $CTL_ENCOURS))"
		trace ARC-0500 "Traitement d'archivage terminé EN ERREUR (parallel run)"
		exit 1
	fi
	
	# Pose du lock : sera détruit en sortie de traitement OK/KO (cf. sortir() )
	echo "$$" > $CTL_ENCOURS # son PID, pour info uniquement
	
	return 0 # obligatoire pour des enchainements && par exemple
}



# Initialisation du loggueur ARE
# Entrées : aucune
# Sorties : aucune
init_are()
{
	[[ -n $SHL_ODEBUG ]] && set -vx # Debug du script

	# Check de la lib ARE BASH (on est en bash donc pas possible d'utiliser la lib KSH à cause du shell bang mais aussi des print)
	[[ ! -s $ARE_LIB ]] && echo "Le loggueur ARE $ARE_LIB n'a pas été trouvé.  Désactivation des logs ARE dans la suite du traitement" && return 0
	
	# Initialisation ARE
	. $ARE_LIB
	init_logging "$ARE_CODE_SUBSYSTEM" $ARE_CFG "$ARE_CODE_PROGRAM"
	ret=$?
	
	# Erreurs ?
	[[ $ret -ne 0 ]] && echo "Le loggueur ARE n'a pas été initialisé correctement ($ret). Désactivation des logs ARE dans la suite du traitement" && return 0
	
	# OK
	DO_LOG_ARE=oui
	timestamp=$(date '+%d/%m/%Y %H:%M:%S')
	echo "$timestamp Les logs ARE sont écrits dans le fichier $HOME/DATA/ARE/LOG/$SHELL_NAME.$(date '+%Y%m%d').are.log (voir sur plusieurs jours)"
	
	return 0 # obligatoire pour des enchainnements && par exemple
}



# Tracer un message à la console et logguer dans les logs ARE
# Entrées :
#  DO_LOG_ARE ci-dessus (oui)
#  $1 : Code message ARE
#  $2 : Message console et Message ARE (un seul %s dans le dictionnaire !)
# Sorties : aucune
# NB : Messsage de dico ARE préalimentés :
#  ARC-0500;5;%s				pour les messages de début/fin de traitement
#  ARC-0600;6;%s				pour divers messages informatifs mais non verbeux !
#  ARC-0310;3;!TEX! %s		pour des erreurs de paramétrage bloquantes
#  ARC-0320;3;!TQ! %s		pour des erreurs techniques bloquantes
#  ARC-0400;4;%s				pour des warnings non bloquants
#  ARC-0700;7;%s				pour le DEBUG (verbeux acccepté)
trace()
{
	# Arguments
	cod="$1"
	msg="$2"
	
	# Conversion \r par \n (cf. rsync par exemple) et retrait lignes vides
	msg=$(echo "$msg" | tr '\r' '\n' | egrep -v '^[ 	]*$')
	[[ -z $msg ]] && return 0
	
	# mono/multi-lignes ?
	timestamp=$(date '+%d/%m/%Y %H:%M:%S')
	if [[ $(echo "$msg" | wc -l) -gt 1 ]]
	then
		echo "$msg" | while read ligne
		do
			[[ -n $modeVerbose ]] && echo "$timestamp   $ligne"
			[[ $DO_LOG_ARE == "oui" ]] && log_msg "$SHELL_NAME" "$cod" "  $ligne"
		done
	else
		echo "$timestamp $msg"
		[[ $DO_LOG_ARE == "oui" ]] && log_msg "$SHELL_NAME" "$cod" "$msg"
	fi
	
	return 0 # obligatoire pour les 'trace xxx && err=1' par exemple sinon enchainement impossible sans logs ARE
}



# Affichage de l'usage + sortie OK/KO si demandé
# Entrées :
#  $1 : (option) Code de sortie (exit)
#  $2 : (option) Code ARE du Message à afficher après l'usage et avant de sortir
#  $3 : (option) Message (console/ARE) à afficher après l'usage et avant de sortir
# Sorties :
#  EXIT $1 si $1 précisé
affiche_usage()
{
	# Usage
	echo "
		SYNOPSIS
			$SHELL_SCRIPT [-h] -l -d <date> [ -s ] [ -r <étape> ] [ -v ]
		DESCRIPTION
			Archivage du DUMP Oracle de la base de données CAUX vers ARCSYS.
			Il consomme les fichiers d'un dump RMAN de la BDD CAUX. Il produit un package ARCSYS local contenant un fichier sip.xml
			  et, pour chaque fichier du dump, une liste de fichiers .tar.nnnn ou .tgz.nnnn suivant la configuration choisie.
			Ensuite, il transfert ce package ARCSYS sur le serveur d'intégration d'ARCSYS des dumps CAUX, en SFTP.
			Et enfin, il archive le dump source en shiftant les archives (M-1, M-2, ...) suivant la profondeur configurée.
		OPTIONS
			-h           : Affichage de l'usage (idem si aucune option fournie)
			-l           : Lancement du script (obligatoire sauf pour le -h)
			-d <date>    : Date du dump à archiver au format YYYY-MM-DD, obligatoire même sur reprise
			               Le dump se trouvant dans le répertoire configuré doit avoir des fichiers de la date indiquée
			               Aucun sous-répertoire n'est pris en compte.
			-s           : Ne pas jouer le transfert vers ARCSYS ni l'archivage du dump. Cela permet de jouer TAR/META mais
			               d'attendre pour jouer SFTP (et ROLL) plus tard via un -r SFTP
			-r <étape>   : Reprise du traitement depuis l'étape indiquée (comprise)
			               Les étapes sont :
			                 - TAR   : TAR[GZ] du chaque fichier du dump et SPLIT en n fichiers blocs (demandé par ARCSYS)
			                 - META  : Remplissage du fichier des métadonnées ARCSYS (fichier SIP)
			                 - SFTP  : Transfert vers ARCSYS du package complet (incompatible avec -s)
			                 - ROLL  : Roll des dumps. Le dump archivé/transféré est déplacé dans les archives de dumps
			-v           : Afficher toutes les traces à la console (mode verbeux) sinon sans les détails
		DEBUG
			'export SHL_ODEBUG=oui' permet d'activer les traces d'exécution du script ('unset SHL_ODEBUG' pour les retirer)
		CONFIGURATION
			$CFG_FILE (bypass VTOM, chemins du dump (un seul),
			  paramètres de performance, cible ARCSYS, ...) : " | cut -c3-
	egrep -v '^#' $CFG_FILE | egrep -v '^$' | awk '{print "\t\t"$0}' 2> /dev/null
	echo "		NB : Le script ne peut être joué sur la machine principale des batchs CAUX mais uniquement sur la secondaire/backup à cause des
		ressources nécessaires très importantes durant le RUN.
		NB : Pour regénérer le dump original à partir d'une archive ARCSYS, il faut :
		- Se mettre dans le dossier de l'archive ARCSYS récupérée c-a-d là où se trouve les fichiers *.(tar|tgz).nnnn
		- Si fichiers tgz.*, lancez la commande suivante :
		    ls *.tgz.0000 | sed 's/.tgz.0000\$//g' | while read f; do echo \"Rebuild \$f ...\" && cat \$f.tgz.* | tar -xzv && rm \$f.tgz.*; done
		  Si fichiers tar.*, lancez la commande suivante :
		    ls *.tar.0000 | sed 's/.tar.0000\$//g' | while read f; do echo \"Rebuild \$f ...\" && cat \$f.tar.* | tar -xv && rm \$f.tar.*; done
		  Cela va, pour chaque fichier en série, reconstruire le fichier dump original et détruire les fichiers ARCYS (si OK)
		- Fournir ce dump aux DBAs pour remontage sur la base de votre choix
	" | cut -c3-
	
	# Message ?
	[[ -n $2 ]] && trace "$2" "$3"
	
	# Sortir ?
	[[ -n $1 ]] && sortir $1
	
	return 0 # obligatoire pour des enchainnements && par exemple
}



# Contrôle de la validité d'une date au format YYYY-MM-DD
# Entrées :
#  $1 : la date dont on doit valider/tester le format
# Sorties :
#  RC : 0 si OK sinon erreur
valide_date()
{
	[[ -n $SHL_ODEBUG ]] && set -vx # Debug du script

	trace ARC-0600 "Validation YYYY-MM-DD de la date $1 ..."
	
	# Contrôle syntaxique
	case "$1" in 
		[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]) DATE=$1 ;;
		*) return 9 ;;
	esac
	
	# Contrôle sémantique via la commande 'date'
	ANNEE=${DATE:0:4}
	MOIS=${DATE:5:2}
	JOUR=${DATE:8:2}
	date +"%Y%m%d" -d "$ANNEE-$MOIS-$JOUR" > /dev/null 2>&1
	rc=$?
	
	trace ARC-0600 "Validation YYYY-MM-DD de la date $1 terminée ($rc)"

	return $rc
}



# Parsing de la ligne de commande et vérification des arguments passés
# Entrées :
#  $* : Les arguments passés au script
# Sorties : (sortir sur erreur)
#  $dateDump : Date de dump à archiver
#  $noSftp : s'il ne faut pas jouer l'étape SFTP
#  $etapeReprise : Etape de reprise (from)
lire_arguments()
{
	[[ -n $SHL_ODEBUG ]] && set -vx # Debug du script

	trace ARC-0600 "Analyse de la ligne de commande ($*) ..."

	# Parsing de la ligne de commande
	dateDump=""
	etapeReprise=""
	while getopts :hld:sr:v OPT ; do
		case ${OPT} in 
			h) affiche_usage 0 ;;
			l) runScript=1 ;;
			d) dateDump=${OPTARG} ;;
			s) noSftp=1 ;;
			r) etapeReprise=${OPTARG} ;;
			v) modeVerbose=1 ;;
			\?) affiche_usage 1 ARC-0310 "L'option de ligne de commande -$OPTARG n'est pas reconnue par ce script" ;;
			:) affiche_usage 1 ARC-0310 "L'option -$OPTARG a un argument obligatoire" ;;
		esac
	done

	# Check -l obligatoire
	[[ -z $runScript ]] && affiche_usage 1 ARC-0310 "L'option -l est obligatoire"
	
	# Contrôle de la date
	valide_date ${dateDump} || affiche_usage 1 ARC-0310 "La date ${dateDump} est de format incorrect (YYYY-MM-DD attendu)"

	# Pas possible d'avoir -r SFTP et -s en même temps
	[[ -n $noSftp && $etapeReprise == "SFTP" ]] && affiche_usage 1 ARC-0310 "L'option -s est incompatible avec -r SFTP"
	
	# Controle de l'étape de reprise (option)
	[[ -n $etapeReprise ]] && [[ ! $etapeReprise =~ ^(TAR|META|SFTP)$ ]] && affiche_usage 1 ARC-0310 "L'étape ${etapeReprise} est inconnue (TAR|META|SFTP)"
	
	# Controle de la reprise si conforme au traitement nominal précédent
	if [[ -n $etapeReprise ]] && [[ $etapeReprise =~ ^(META|SFTP)$ ]]
	then
		[[ ! -s $CTL_REPRISE ]] && affiche_usage 1 ARC-0310 "La reprise n'est possible que si le traitement a déjà été lancé (présence de $CTL_REPRISE avec la date du dump $dateDump dedans)"
		avant=$(< $CTL_REPRISE)
		[[ $avant != $dateDump ]] && affiche_usage 1 ARC-0310 "La reprise n'est possible que sur la même date hors le précédent traitement était sur $avant et non sur $dateDump (cf. $CTL_REPRISE et sa date)"
	fi
	echo "$dateDump" > $CTL_REPRISE # systématiquement à chaque RUN (pour check de reprise ensuite) + date du run sur mtime

	trace ARC-0600 "Analyse de la ligne de commande ($*) terminée OK"
	
	return 0 # obligatoire pour des enchainnements && par exemple
}



# Lire/Vérifier la configuration principale
# Entrées : aucune
# Sorties : aucune (sortir sur erreur)
lire_configuration()
{
	[[ -n $SHL_ODEBUG ]] && set -vx # Debug du script

	trace ARC-0600 "Lecture/Validation de la configuration $CFG_FILE ..."
	err=0

	# Contrôle de la présence du fichier de configuration principale + sourcing
	[[ ! -s $CFG_FILE ]] && trace ARC-0310 "Le fichier de configuration $CFG_FILE est absent ou vide" && sortir 1
	. $CFG_FILE
	
	# Contrôle de la présence du fichier de log ARE et du fichier de dictionnaire ARE
	[[ ! -s $ARE_CFG ]] && trace ARC-0310 "Le fichier de configuration ARE $ARE_CFG est absent ou vide (non bloquant)"
	[[ ! -s $ARE_DIC ]] && trace ARC-0310 "Le fichier de dictionnaire ARE $ARE_DIC est absent ou vide (non bloquant)"
	
	# Contrôle des 3 fichiers de template sip.xml
	[[ ! -s $SIP_DEB ]] && trace ARC-0310 "Le fichier template de SIP $SIP_DEB est absent ou vide" && err=1
	[[ ! -s $SIP_LIGNE ]] && trace ARC-0310 "Le fichier template de SIP $SIP_DEB est absent ou vide" && err=1
	[[ ! -s $SIP_FIN ]] && trace ARC-0310 "Le fichier template de SIP $SIP_DEB est absent ou vide" && err=1

	# Contrôle du bypass VTOM : vtomBypass
	[[ -z $vtomBypass ]] && trace ARC-0310 "Le paramètre vtomBypass n'est pas valorisé dans le fichier de configuration $CFG_FILE" && err=1
	[[ ! $vtomBypass =~ ^(oui|non)$ ]] && trace ARC-0310 "Le paramètre vtomBypass=$vtomBypass n'est pas oui|non dans le fichier de configuration $CFG_FILE" && err=1

	# Contrôle des répertoires de dump(s)
	[[ -z $dumpDir ]] && trace ARC-0310 "Le paramètre dumpDir n'est pas valorisé dans le fichier de configuration $CFG_FILE" && err=1
	[[ ! -d $dumpDir ]] && trace ARC-0310 "Le répertoire dumpDir=$dumpDir du fichier de configuration $CFG_FILE n'existe pas" && err=1
	[[ ! -x $dumpDir ]] && trace ARC-0310 "Le répertoire dumpDir=$dumpDir du fichier de configuration $CFG_FILE n'est pas accessible (-x). Il faut les droits rx à minima !" && err=1
	[[ ! -r $dumpDir ]] && trace ARC-0310 "Le contenu du répertoire dumpDir=$dumpDir du fichier de configuration $CFG_FILE n'est pas accessible en lecture (-r). Il faut les droits rx à minima !" && err=1
	[[ ! -w $dumpDir/.. ]] && trace ARC-0400 "Le contenu du répertoire $dumpDir/.. n'est pas accessible en écriture (-w). Il faut les droits rwx dessus ! On ne bloque pas le traitement à ce stade mais cela deviendra bloquant lors du ROLL"
	# Non bloquant mais faudra régler le problème avant le ROLL (cf. reprise éventuelle)
	
	# Contrôle du sizing des dumps source
	[[ -z $tailleMinDumpGo ]] && trace ARC-0310 "Le paramètre tailleMinDumpGo n'est pas valorisé dans le fichier de configuration $CFG_FILE" && err=1
	[[ ! $tailleMinDumpGo =~ ^[0-9]+$ ]] && trace ARC-0310 "Le paramètre tailleMinDumpGo=$tailleMinDumpGo n'est pas un entier dans le fichier de configuration $CFG_FILE" && err=1
	[[ -z $tailleMaxDumpGo ]] && trace ARC-0310 "Le paramètre tailleMaxDumpGo n'est pas valorisé dans le fichier de configuration $CFG_FILE" && err=1
	[[ ! $tailleMaxDumpGo =~ ^[0-9]+$ ]] && trace ARC-0310 "Le paramètre tailleMaxDumpGo=$tailleMaxDumpGo n'est pas un entier dans le fichier de configuration $CFG_FILE" && err=1
	[[ -n $tailleMinDumpGo ]] && [[ -n $tailleMaxDumpGo ]] && \
		[[ $tailleMinDumpGo =~ ^[0-9]+$ ]] && [[ $tailleMaxDumpGo =~ ^[0-9]+$ ]] && \
		[[ $tailleMinDumpGo -ge $tailleMaxDumpGo ]] && trace ARC-0310 "Le paramètre tailleMinDumpGo=$tailleMinDumpGo n'est pas inférieur au paramètre tailleMaxDumpGo=$tailleMaxDumpGo dans le fichier de configuration $CFG_FILE" && err=1
	
	# Contrôle du répertoire d'archivage des dumps
	[[ -z $dumpArchDir ]] && trace ARC-0310 "Le paramètre dumpArchDir n'est pas valorisé dans le fichier de configuration $CFG_FILE" && err=1
	[[ ! -d $dumpArchDir ]] && trace ARC-0310 "Le répertoire dumpArchDir=$dumpArchDir du fichier de configuration $CFG_FILE n'existe pas" && err=1
	[[ ! -x $dumpArchDir ]] && trace ARC-0400 "Le répertoire dumpArchDir=$dumpArchDir du fichier de configuration $CFG_FILE n'est pas accessible (-x). Il faut les droits rwx ! On ne bloque pas le traitement à ce stade mais cela deviendra bloquant lors du ROLL"
	[[ ! -r $dumpArchDir ]] && trace ARC-0400 "Le contenu du répertoire dumpArchDir=$dumpArchDir du fichier de configuration $CFG_FILE n'est pas accessible en lecture (-r). Il faut les droits rwx ! On ne bloque pas le traitement à ce stade mais cela deviendra bloquant lors du ROLL"
	[[ ! -w $dumpArchDir ]] && trace ARC-0400 "Le contenu du répertoire dumpArchDir=$dumpArchDir du fichier de configuration $CFG_FILE n'est pas accessible en écriture (-w). Il faut les droits rwx ! On ne bloque pas le traitement à ce stade mais cela deviendra bloquant lors du ROLL"
	# Non bloquant mais faudra régler le problème avant le ROLL (cf. reprise éventuelle)
	
	# Contrôle nombre de dumps archivés (0 = aucune archive)
	[[ -z $rollMonths ]] && trace ARC-0310 "Le paramètre rollMonths n'est pas valorisé dans le fichier de configuration $CFG_FILE" && err=1
	[[ ! $rollMonths =~ ^[0-9]$ ]] && trace ARC-0310 "Le paramètre rollMonths=$rollMonths n'est pas un entier [0..9] dans le fichier de configuration $CFG_FILE" && err=1
	
	# Contrôle du répertoire de travail où sera produit le package ARCSYS et les fichiers de controles du traitement
	[[ -z $arcsysDir ]] && trace ARC-0310 "Le paramètre arcsysDir n'est pas valorisé dans le fichier de configuration $CFG_FILE" && err=1
	[[ ! -d $arcsysDir ]] && trace ARC-0310 "Le répertoire arcsysDir=$arcsysDir du fichier de configuration $CFG_FILE n'existe pas" && err=1
	[[ ! -x $arcsysDir ]] && trace ARC-0310 "Le répertoire arcsysDir=$arcsysDir du fichier de configuration $CFG_FILE n'est pas accessible (-x). Il faut les droits rwx !" && err=1
	[[ ! -r $arcsysDir ]] && trace ARC-0310 "Le contenu du répertoire arcsysDir=$arcsysDir du fichier de configuration $CFG_FILE n'est pas accessible en lecture (-r). Il faut les droits rwx !" && err=1
	[[ ! -w $arcsysDir ]] && trace ARC-0310 "Le contenu du répertoire arcsysDir=$arcsysDir du fichier de configuration $CFG_FILE n'est pas accessible en écriture (-w). Il faut les droits rwx !" && err=1

	# Contrôle des sous-repertoires data/ et control/
	if [[ -d $arcsysDir ]]
	then
		[[ ! -d $arcsysDir/data ]] && trace ARC-0600 "Création du répertoire de packaging ARCSYS $arcsysDir/data" && mkdir $arcsysDir/data && chmod 777 $arcsysDir/data
		[[ ! -x $arcsysDir/data || ! -r $arcsysDir/data || ! -w $arcsysDir/data ]] && trace ARC-0310 "Le répertoire $arcsysDir/data n'est pas accessible en lecture/écriture. Il faut les droits rwx !" && err=1
		[[ ! -d $arcsysDir/control ]] && trace ARC-0600 "Création du répertoire de contrôle du packaging ARCSYS $arcsysDir/control" && mkdir $arcsysDir/control && chmod 777 $arcsysDir/control
		[[ ! -x $arcsysDir/control || ! -r $arcsysDir/control || ! -w $arcsysDir/control ]] && trace ARC-0310 "Le répertoire $arcsysDir/control n'est pas accessible en lecture/écriture. Il faut les droits rwx !" && err=1
	fi
	
	# Contrôle du // de TARGZ/SPLIT de l'archivage locale vers le packaging ARCSYS
	[[ -z $tarSplitParallel ]] && trace ARC-0310 "Le paramètre tarSplitParallel n'est pas valorisé dans le fichier de configuration $CFG_FILE" && err=1
	[[ ! $tarSplitParallel =~ ^[1-9]$ ]] && trace ARC-0310 "Le paramètre tarSplitParallel=$tarSplitParallel n'est pas un entier [1..9] dans le fichier de configuration $CFG_FILE" && err=1
	
	# Contrôle du mode TAR ou TAR+GZIP du packaging
	[[ -z $tarGzip ]] && trace ARC-0310 "Le paramètre tarGzip n'est pas valorisé dans le fichier de configuration $CFG_FILE" && err=1
	[[ ! $tarGzip =~ ^(oui|non)$ ]] && trace ARC-0310 "Le paramètre tarGzip=$tarGzip n'est pas oui|non dans le fichier de configuration $CFG_FILE" && err=1
	
	# Contrôle du // de calcul de checksum/empreinte
	[[ -z $chksumParallel ]] && trace ARC-0310 "Le paramètre chksumParallel n'est pas valorisé dans le fichier de configuration $CFG_FILE" && err=1
	[[ ! $chksumParallel =~ ^[1-9]$ ]] && trace ARC-0310 "Le paramètre chksumParallel=$chksumParallel n'est pas un entier [1..9] dans le fichier de configuration $CFG_FILE" && err=1
	
	# Contrôle de la taille max de blocs ARCSYS (SPLIT)
	[[ -z $blockSize ]] && trace ARC-0310 "Le paramètre blockSize n'est pas valorisé dans le fichier de configuration $CFG_FILE" && err=1
	[[ ! $blockSize =~ ^[0-9]+$ ]] && trace ARC-0310 "Le paramètre blockSize=$blockSize n'est pas un entier dans le fichier de configuration $CFG_FILE" && err=1
	
	# Contrôle de la configuration du transfert SFTP vers ARCSYS
	[[ -z $sshUser ]] && trace ARC-0310 "Le paramètre sshUser n'est pas valorisé dans le fichier de configuration $CFG_FILE" && err=1
	[[ -z $sshHost ]] && trace ARC-0310 "Le paramètre sshHost n'est pas valorisé dans le fichier de configuration $CFG_FILE" && err=1
	[[ -z $sshDir ]] && trace ARC-0310 "Le paramètre sshDir n'est pas valorisé dans le fichier de configuration $CFG_FILE" && err=1
	
	[[ -z $sshOptions ]] && trace ARC-0310 "Le paramètre sshOptions n'est pas valorisé dans le fichier de configuration $CFG_FILE. Il doit contenir à minima -oBatchMode=yes voir -oPort=xxxx" && err=1

	# Contrôle du // de transfert SFTP
	[[ -z $sftpParallel ]] && trace ARC-0310 "Le paramètre sftpParallel n'est pas valorisé dans le fichier de configuration $CFG_FILE" && err=1
	[[ ! $sftpParallel =~ ^[1-9]$ ]] && trace ARC-0310 "Le paramètre sftpParallel=$sftpParallel n'est pas un entier [1..9] dans le fichier de configuration $CFG_FILE" && err=1
	
	# Contrôle de la machine PROD secondaire vs primaire interdite
	[[ -z $aliasDnsBatchCaux ]] && trace ARC-0310 "Le paramètre aliasDnsBatchCaux n'est pas valorisé dans le fichier de configuration $CFG_FILE" && err=1

	# Des erreurs bloquantes ?
	[[ $err -ne 0 ]] && trace ARC-0310 "Des erreurs de configuration/environnement bloque l'exécution du programme" && sortir 1
	
	trace ARC-0600 "Lecture/Validation de la configuration $CFG_FILE terminée OK"
	details=$(cat $CFG_FILE | egrep -v '^[ 	]*#' | egrep -v '^[ 	]*$') # Log de la configuration pour ce RUN
	trace ARC-0600 "$details"
	
	return 0 # obligatoire pour des enchainnements && par exemple
}



# Controle que,sur la PROD, le script n'est pas lancé de la machine active
# Entrées : aucune
# Sorties :
#  RC : 0 si OK sinon erreur
controle_backup_caux()
{
	[[ -n $SHL_ODEBUG ]] && set -vx # Debug du script

	trace ARC-0600 "Contrôle que le script ne tourne pas sur la machine active des batchs CAUX ..."

	# Lecture de l'IP de la machine active /alias DNS
	# Exemple de ping : (le souci est que ping passe par ICMP et c'est parfois bloqué comme sur AWS par défaut)
	#	[batchs_bacau_caux_pp1 ppcaux@bt1svlld:~]$ ping -w 1 -c 1 bt1fscaux01
	#	PING bt1svuu1g0.bpa.bouyguestelecom.fr (172.21.188.239) 56(84) bytes of data.
	# Exemple de host : (consulte le serveur DNS only sans faire de "ping" au serveur cible)
	#                   (on peut aussi utiliser dig ou son ancètre nslookup mais host est plus adapté au scripting)
	#	[batch_bacau_servers_dev6 caubtcd6@bt1svu0r:/usr/users/caubtcd6/cmnF3G/Tools/shl]$ host -T bt1svuui
	#	bt1svuui.bpa.bouyguestelecom.fr is an alias for bt1svuuig0.bpa.bouyguestelecom.fr.
	#	bt1svuuig0.bpa.bouyguestelecom.fr has address 172.21.197.83
	#ipActive=$(ping -w 1 -c 1 $aliasDnsBatchCaux | head -1 | awk '{print $3}') # pas de ping car restriction d'usage possible
	ipActive=$(host -T $aliasDnsBatchCaux | grep "has address" | awk '{print $4}')
	
	# Lecture de l'IP de la machine courante
	#ipCurrent=$(ping -w 1 -c 1 $(hostname) | head -1 | awk '{print $3}') # pas de ping car restriction d'usage possible
	#ipCurrent=$(host -T $(hostname) | grep "has address" | awk '{print $4}')
	#[[ $ipCurrent == $ipActive ]] && trace ARC-0400 "Il n'est pas possible de lancer ce script depuis la machine des batchs CAUX active (alias $aliasDnsBatchCaux)" && sortir 1
	# Il est préférable de rechercher l'IP ci-dessus dans les IP possible de la machine courante (multi-interface)
	
	# Check si l'IP v4 est dans les interfaces de la machines courante
	# Exemple :
	#	[batch_bacau_servers_dev6 caubtcd6@bt1svu0r:/usr/users/caubtcd6/cmnF3G/Tools/shl]$ ifconfig -a     ou      netstat -ie
	#	eth0: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
	#			  inet 172.19.115.191  netmask 255.255.255.0  broadcast 172.19.115.255
	#			  inet6 fe80::250:56ff:fe8d:1a4b  prefixlen 64  scopeid 0x20<link>
	#			  ether 00:50:56:8d:1a:4b  txqueuelen 1000  (Ethernet) .........
	#	eth1: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
	#			  inet 172.18.227.11  netmask 255.255.255.0  broadcast 172.18.227.255
	#			  inet6 fe80::250:56ff:fe8d:1e62  prefixlen 64  scopeid 0x20<link>
	#			  ether 00:50:56:8d:1e:62  txqueuelen 1000  (Ethernet) ....
	trouve=$(netstat -ie | grep "inet $ipActive ")
	[[ -n $trouve ]] && trace ARC-0400 "Il n'est pas possible de lancer ce script depuis la machine des batchs CAUX active (alias $aliasDnsBatchCaux : $trouve)" && sortir 1
	
	trace ARC-0600 "Contrôle que le script ne tourne pas sur la machine active des batchs CAUX OK (alias $aliasDnsBatchCaux : $ipActive)"
	
	return 0 # obligatoire pour des enchainnements && par exemple
}


# Contrôle du paramétrage SFTP yc le répertoire de dépôt
# Entrées : aucune
# Sorties :
#  RC : 0 si OK sinon erreur
controle_sftp()
{
	[[ -n $SHL_ODEBUG ]] && set -vx # Debug du script

	trace ARC-0600 "Contrôle du paramétrage SFTP (sftp $sshOptions $sshUser@$sshHost:$sshDir/) ..."
	
	# Test d'accès SFTP et du répertorie de dépôt aussi
	# NB : -oBatchMode=yes demande de générer un KO dès qu'il y a besoin de demander qq chose à l'utilisateur (ici le batch) comme un mot de passe
	#      c'est plus large que juste l'option -oPasswordAuthentication=no
	# Exemples de résultats :
	#  Si OK :
	#    Connected to bt1svu0r.
	#    Changing to: /appli/cxqud6/tools/
	#    sftp> bye
	#  Si KO d'authent (compte inexistant, pas de clé SSH public injectée sur la cible, ...) :
	#    Permission denied (publickey,gssapi-keyex,gssapi-with-mic,password).
	#    Couldn't read packet: Connection reset by peer
	#  Si KO de machine :
	#    ssh: Could not resolve hostname bt1vu0r: Name or service not known
	#    Couldn't read packet: Connection reset by peer
	#  Si KO de répertoire :
	#    Connected to bt1svu0r.
	#    File "/appli/cxqud6/tool/" not found.

	sftp $sshOptions $sshUser@$sshHost:$sshDir/ <<-EOF > $DIR_LOG/$SHELL_NAME.sftp.log 2>&1
		bye
	EOF
	rc=$?
	
	if [[ $rc -ne 0 ]]
	then
		trace ARC-0400 "L'accès SFTP est incorrect et/ou le chemin de dépôt $sshDir est incorrect/inaccessible"
		details=$(< $DIR_LOG/$SHELL_NAME.sftp.log 2> /dev/null) # Log de l'erreur SFTP + console
		[[ -n $details ]] && trace ARC-0600 "$details"
	else
		trace ARC-0600 "L'accès SFTP est OK et le chemin de dépôt existe"
	fi
	
	rm -f $DIR_LOG/$SHELL_NAME.sftp.log 2> /dev/null
	
	trace ARC-0600 "Contrôle du paramétrage SFTP (sftp $sshOptions $sshUser@$sshHost:$sshDir/) terminé ($rc)"

	return $rc
}



# TAR[GZ] et SPLIT d'une liste de fichiers, distinctement les uns des autres
# Les fichiers de block produits sont nommés <nom fichier source>.tar|tgz.<numéro 0000..nnnn>
# NB : Peut être lancé en background via &
# NB : Pas d'usage d trace() ici, que des echo afin d'être récupéré par > dans un log suivant le job &
# Entrées :
#  $1 : Fichier (et son chemin) contenant la liste des noms de fichiers à TAR[GZ]/SPLITTer
# Sorties :
#  RC : 0 si OK sinon erreur
tarGz_split()
{
	[[ -n $SHL_ODEBUG ]] && set -vx # Debug du script

	typeset -i nombre
	
	# Arguments
	listing=$1
	srcDir=$dumpDir
	dataDir=$arcsysDir/data
	ctlDir=$arcsysDir/control
	
	# Check minimum des variables
	[[ ! -s $listing ]] && echo "Le fichier $listing n'existe pas ou est vide" && return 1
	[[ ! -d $srcDir ]] && echo "Le dossier source $srcDir n'existe pas" && return 1
	[[ ! -d $dataDir ]] && echo "Le dossier destination $dataDir n'existe pas" && return 1
	[[ ! -d $ctlDir ]] && echo "Le dossier destination $ctlDir n'existe pas" && return 1
	
	# Option du tar et nommage des fichiers blocs
	extTarTgz=tar
	[[ $tarGzip == "oui" ]] && tarExtraOpt=z && extTarTgz=tgz
	
	# Jump dans le dossier source
	cd $srcDir
	
	# Indicateur d'erreur dans la packaging ARCSYS (par défaut, sera nettoyé si tout sort OK)
	cp $listing $ctlDir/$(basename $listing).TARGZ_SPLIT_EN_COURS_OU_EN_ERREUR
	
	# Nombre de fichiers à traiter
	quantite=$(wc -l $listing | awk '{print $1}')
	
	# Parcours des fichiers à traiter
	echo "Debut du job $listing ($quantite fichiers à traiter)"
	i=0
	while read f
	do
		
		(( i = $i + 1 ))
		
		timestamp1=$(date '+%d/%m/%Y %H:%M:%S')
		echo "#$i/$quantite FICHIER $f @ $timestamp1"
		
		# Taille du fichier source
		srcTailleMo=$(ls -l $f | egrep -v '^total' | awk '{print int($5/(1024*1024))}')
		
		# TAR[GZ du fichier + SPLIT dans la foulée ==> <nom fichier source>.tar|tgz.<numéro 0000..nnnn>
		tar -c${tarExtraOpt}vf - $f | split -d -a 4 -b ${blockSize}M - $dataDir/$f.$extTarTgz.
		rcPipes=(${PIPESTATUS[@]})
		
		# Analyse erreurs
		timestamp2=$(date '+%d/%m/%Y %H:%M:%S')
		if [[ ${rcPipes[0]} -eq 0 && ${rcPipes[1]} -eq 0 ]]
		then
			nombre=$(ls -1 $dataDir/$f.$extTarTgz.* | wc -l)
			echo "#$i/$quantite FICHIER $f : $nombre fichier(s) block(s) $dataDir/$f.$extTarTgz.* généré(s) OK @ $timestamp2"
		else
			[[ ${rcPipes[0]} -ne 0 ]] && echo "#$i/$quantite FICHIER $f : Une erreur ${rcPipes[0]} est survenue lors du TAR/GZ du fichier source @ $timestamp2"
			[[ ${rcPipes[1]} -ne 0 ]] && echo "#$i/$quantite FICHIER $f : Une erreur ${rcPipes[1]} est survenue lors du SPLIT @ $timestamp2"
			return 1
		fi
		
		# Création du fichier d'identité (pour le mode reprise)
		ls -lp --time-style=full-iso $srcDir/$f > $ctlDir/$f.ident
		
		# Taille des fichiers cibles (pour mesure de performance du compactage)
		dstTailleMo=$(ls -l $dataDir/$f.$extTarTgz.* | egrep -v '^total' | awk 'BEGIN {taille=0} {taille+=($5/(1024*1024))} END {print int(taille)}')
		
		# Performance de compression (si TGZ)
		if [[ $tarGzip == "oui" && $srcTailleMo -gt 0 ]]
		then
			(( gain = ( ( $srcTailleMo - $dstTailleMo ) * 100 ) / $srcTailleMo ))
			echo "#$i/$quantite FICHIER $f : Réduction de la taille du fichier source de $gain % ($srcTailleMo Mo -> $dstTailleMo Mo)"
		else
			echo "#$i/$quantite FICHIER $f : Réduction de la taille du fichier source de $srcTailleMo Mo -> $dstTailleMo Mo"
		fi
		
		# Débit de traitement (lecture fichier, compression, split, écriture blocs)
		#   taille d'entrée / temps de traitement total
		debitMbPerSec=$(echo "$timestamp1 $timestamp2 $srcTailleMo" | awk '{deb=substr($2,1,2)*3600+substr($2,4,2)*60+substr($2,7,2);fin=substr($4,1,2)*3600+substr($4,4,2)*60+substr($4,7,2);delta=fin-deb+1;print int($5*8/delta)}')
		echo "#$i/$quantite FICHIER $f : Débit visible du traitement = $debitMbPerSec Mb/s (lire la source, tar[gz)/split, écrire les blocs ; durée/taille du fichier source)"
		
	done < $listing
	echo "Fin du job $listing"

	# Nettoyage du flag encours/erreur
	rm -f $ctlDir/$(basename $listing).TARGZ_SPLIT_EN_COURS_OU_EN_ERREUR
	
	# Fin OK
	return 0
}







# TAR/GZ des fichiers du dump et Découpage de ce TGA en blocks pour ARCSYS (prérequis)
# NB : Les fichiers du dump, via RMAN, ne sont pas compressés à ce jour. Des tests de targz ont montré des compressions de 15-20%.
#      Ex. pour archive_CDBCAUX1_t1036536886_s3162_p1   --> -14%
#      Ex. pour online_CDBCAUX1_n1_t1036532472_s3137_p1 --> -21%
# NB : Les fichiers produits (en sortie du split) sont de la forme <xxxx.tar|tgz.nnnn>
#      avec xxxx le fichier d'origine et nnnn un nombre sur 4 digits ex. 0025
# Entrées : aucune
# Sorties : aucune (sortir sur erreur)
etape_tar()
{
	[[ -n $SHL_ODEBUG ]] && set -vx # Debug du script

	trace ARC-0500 "########### Etape TAR ($etapeReprise) ###########"
	
	# Répertoires de travail
	DATA_DIR=$arcsysDir/data
	CTL_DIR=$arcsysDir/control

	# Option du tar et nommage des fichiers blocs
	extTarTgz=tar
	[[ $tarGzip == "oui" ]] && extTarTgz=tgz

	
	# Test de l'accès aux fichiers du dump (en lecture)
	# -----------------------------------------------------------------------------------------------------
	
	trace ARC-0600 "Test des accès au dump (et check au moins un fichier à packager) ..."
	
	# Test de l'accès en lecture des fichiers du dump
	aucun=1
	for f in $(ls -L1p $dumpDir | egrep -v '/$') # Nom de fichier sans chemin, on suit le lien symbolique si c'en est un
	do
		aucun=0
		[[ ! -r $dumpDir/$f ]] && trace ARC-0320 "Le fichier $dumpDir/$f du dump n'est pas accesible en lecture" && sortir 1
	done
	[[ $aucun -eq 1 ]] && trace ARC-0320 "Aucun dump n'a été trouvé (0 fichiers) dans $dumpDir" && sortir 1 # return 0 NON
	
	trace ARC-0600 "Test/Listing effectué OK"
	details=$(ls -Llp $dumpDir | egrep -v '/$') # Log des fichiers à traiter + total en Ko (attention c'est pas en octets !!!)
	trace ARC-0700 "$details"
	
	
	# Test de la date du dump (le fichier le plus récent)
	# -----------------------------------------------------------------------------------------------------
	
	trace ARC-0600 "Test de la date du dump vs la date en argument $dateDump ..."
	
	# Récupération des dates du dump avec le nombre de fichiers associés (au jour près)
	#  et check vs date de dump indiquée en argument
	# NB : Le dump peut couvrir 2 jours (débuté le x et terminé le y) et il suffit de pointer une de ces dates)
	ok=$(ls -Llp --time-style=long-iso $dumpDir | egrep -v '^total' | egrep -v '/$' | awk '{print $6}' | grep "$dateDump")
	if [[ -z $ok ]]
	then
		trace ARC-0310 "Le dump n'est pas daté du $dateDump comme demandé (cf. timestamps fichiers). Ajustez votre date passée en argument -d"
		details=$(ls -Llp --time-style=long-iso $dumpDir | egrep -v '^total' | egrep -v '/$' | awk '{print $6}' | sort -u)
		trace ARC-0700 "$details"
		sortir 1
	fi

	trace ARC-0600 "Test de la date du dump vs la date en argument $dateDump OK"
	details=$(ls -Llp --time-style=long-iso $dumpDir | egrep -v '^total' | egrep -v '/$' | awk '{print $6}' | sort | uniq -c) # Log des dates observées sur le dump
	trace ARC-0700 "$details"
	
	
	# Test de la taille du dump
	# NB : en début 2020, le dump RMAN fait entre 900Go et 1To
	# -----------------------------------------------------------------------------------------------------
	
	trace ARC-0600 "Test de la taille du dump ..."
	
	# Récupération de la taille du dump, en Go (ls -l affiche en Ko par défaut)
	tailleGo=$(ls -l $dumpDir | grep -E '^total ' | awk '{print int($2/(1024*1024))}')
	
	# Check si entre min/max configuré
	if [[ $tailleGo -lt $tailleMinDumpGo || $tailleGo -gt $tailleMaxDumpGo ]]
	then
		trace ARC-0310 "Le dump n'est pas de bonne taille (violation de $tailleMinDumpGo <= $tailleGo <= $tailleMaxDumpGo). Vérifiez que le dump a été correctement généré ou mettez à jour le garde-fou dans la configuration."
		sortir 1
	fi

	trace ARC-0600 "Test de la taille du dump OK ($tailleMinDumpGo <= $tailleGo <= $tailleMaxDumpGo)"
	
	
	# Nettoyage de l'espace ARCSYS $arcsysDir (sauf en mode reprise pour cette étape TAR)
	# -----------------------------------------------------------------------------------------------------

	if [[ -z $etapeReprise || $etapeReprise != "TAR" ]]
	then
		trace ARC-0600 "Nettoyage du répertoire ARCSYS local (destruction du package s'y trouvant et des fichiers de contrôles) ... (sauf en mode reprise TAR où on va compléter)"

		trace ARC-0700 "Fichiers de $DATA_DIR à purger ..."
		#details=$(ls -lp $DATA_DIR) # Log des fichiers qui vont être supprimés (affichage d'éventuels répertoires)
		#trace ARC-0700 "$details" # trop verbeux et peu d'intéret in fine !!!
		rm -rf $DATA_DIR 2> /dev/null
		mkdir -p $DATA_DIR
		
		trace ARC-0700 "Fichiers de $CTL_DIR à purger ..."
		#details=$(ls -lp $CTL_DIR) # Log des fichiers qui vont être supprimés (affichage d'éventuels répertoires)
		#trace ARC-0700 "$details" # trop verbeux et peu d'intéret in fine !!!
		rm -rf $CTL_DIR 2> /dev/null
		mkdir -p $CTL_DIR
		
		[[ -n $(ls -1 $DATA_DIR/* $CTL_DIR/* 2> /dev/null) ]] && trace ARC-0320 "La purge de $arcsysDir est incomplète, il reste encore des fichiers/sous-répertoires" && sortir 1
		
		trace ARC-0600 "Nettoyage effectué"
	else
		trace ARC-0600 "Nettoyage uniquement des fichiers de jobs de l'étape TAR ... (on est en mode reprise TAR où on va compléter l'existant)"

		rm -f $CTL_DIR/job-tar.* # on garde les fichiers .ident éventuels
		
		trace ARC-0600 "Nettoyage effectué"
	fi

	
	# Check de l'espace dispo
	# -----------------------------------------------------------------------------------------------------
		
	trace ARC-0600 "Test de l'espace disponible sur le disque ..."
	
	# Lecture de l'espace disque restant sur la cible
	dispoMo=$(df --block-size=1M $arcsysDir | grep -v Filesystem | awk '{print $4}')
	
	# Lecture de l'espace disque nécessaire depuis le dump source (dumpDir/. pour prendre le cas du lien symbolique)
	besoinMaxMo=$(du --block-size=1M --summarize $dumpDir/. | awk '{print $1}')

	# Lecture de l'espace disque utilisé pour le package actuel (cf. en cas de reprise)
	usedMo=$(du --block-size=1M --summarize $DATA_DIR/. | awk '{print $1}')
	
	# Réduction de 10% minimum (efficacité de la compression GZIP)
	(( besoinMinMo = $besoinMaxMo * 9 / 10 ))

	# Déduction du déjà fait : direct sur le min, +10% sur le max
	(( besoinMinMo = $besoinMinMo - $usedMo ))
	(( besoinMaxMo = $besoinMaxMo - ( $usedMo * 11 / 10 ) ))
		
	trace ARC-0600 "Le package exige maximum $besoinMaxMo Mo, minimum $besoinMinMo Mo et il reste $dispoMo Mo sur l'espace local ARCSYS dont $usedMo Mo de deja fait (pris en compte dans ce besoin)"
	[[ $dispoMo -le $besoinMinMo ]] && trace ARC-0320 "Il n'y a pas assez de place sur le disque ($arcsysDir) pour accueillir le package ARCSYS du dump ($dumpDir) (espace minimum non dispo)" && sortir 1
	[[ $dispoMo -le $besoinMaxMo ]] && trace ARC-0400 "Il n'y a probablement pas assez de place sur le disque ($arcsysDir) pour accueillir le package ARCSYS du dump ($dumpDir (espace maximum non dispo)" # no exit

	trace ARC-0600 "Test de l'espace disponible OK"
	

	# Préparation des jobs de TAR/GZ
	# -----------------------------------------------------------------------------------------------------
	
	trace ARC-0600 "Préparation du TAR[GZ] parallèle $tarSplitParallel (gzip=$tarGzip) ..."

	# Listage des fichiers à TAR[GZ] par ordre croissant de taille et dispatch du travail en $tarSplitParallel jobs
	#   Création de $tarSplitParallel fichiers $CTL_DIR/job-tar.n avec n de 0 à $tarSplitParallel-1
	# NB : On ignore les sous-répertoires
	i=0
	ls -L1Srp $dumpDir | egrep -v '/$' | while read f # juste les noms de fichiers sans leur chemin
	do
		# Test si les fichiers .ident et .0000 à minima sont présents (reprise)
		if [[ -s $CTL_DIR/$f.ident && -s $DATA_DIR/$f.$extTarTgz.0000 ]]
		then
			avant=$(< $CTL_DIR/$f.ident)
			apres=$(ls -lp --time-style=full-iso $dumpDir/$f)
			# Si en phase alors on bypass le targz/split
			# NB : Le fichier .ident n'est créé que si les fichiers splittés ont tous été faits donc si le split est corrompu, on recalculera (no ident file)
			[[ $avant == $apres ]] && continue
		fi
		
		# Clean si présents car on doit les refaire ici
		rm -f $CTL_DIR/$f.ident $DATA_DIR/$f.$extTarTgz.*
		
		# Chaque fichier de job contient des fichiers de taille croissante, ventilés en round robin
		echo "$f" >> $CTL_DIR/job-tar.$i
		(( i = ( $i + 1 ) % $tarSplitParallel ))
	done

	# Au moins 1 job à faire ?
	[[ ! -s $CTL_DIR/job-tar.0 ]] && trace ARC-0400 "Aucun job n'a été défini (reprise d'un traitement entièrement terminé par exemple). Passage à l'étape suivante !" && return 0
	
	trace ARC-0600 "Préparation terminée ..."
	details=$(egrep -v '^$' $CTL_DIR/job-tar.*) # Log des jobs définis
	trace ARC-0600 "$details"

	
	# TAR/GZ et SPLIT des fichiers du dump (non //isable)
	# -----------------------------------------------------------------------------------------------------

	trace ARC-0600 "TARGZ+SPLIT parallèle $tarSplitParallel ... (lancement des jobs)"
	
	# Listing des ID de job
	ids=$(ls -1 $CTL_DIR/job-tar.* | sed 's/^.*\([0-9]\)$/\1/g')
	
	debut=$(date '+%H %M')
	
	# Lancement des jobs de TGZ
	# NB : usage de GNU gtar (tar linux) car il est plus puissant/intelligent (et renomme le fichier à destination si OK : .fic5_bin.ItyPVW --> fic5_bin)
	for i in $ids
	do
		trace ARC-0600 "Lancement du job $i (cf. $CTL_DIR/job-tar.$i.*)"
		tarGz_split $CTL_DIR/job-tar.$i > $CTL_DIR/job-tar.$i.log 2>&1 &
		pid=$!
		echo "$pid" > $CTL_DIR/job-tar.$i.pid # sauvegarde du PID pour le wait pour en récupérer le RC /PID
		sleep 1
	done

	trace ARC-0600 "TARGZ+SPLIT parallèle $tarSplitParallel ... (attente de la fin des jobs)"
	trace ARC-0700 "Vous pouvez suivre l'avancement des jobs dans les fichiers $CTL_DIR/job-tar.*.log"
	trace ARC-0700 "ou via la commande : egrep '(Debut|FICHIER|Fin)' $CTL_DIR/job-tar.?.log | sed 's/:/ /' | awk '(NR==1){old=\$1;lgn=\$0}(\$1!=old){print lgn;old=\$1}{lgn=\$0}END{print lgn}'"
	
	# Attente de la fin des jobs
	# NB : Si un casse, les autres le feront surement en même temps
	rcAll=0
	for i in $ids
	do
		pid=$(< $CTL_DIR/job-tar.$i.pid)
		wait $pid
		rc=$?
		if [[ $rc -eq 0 ]]
		then
			trace ARC-0600 "Job $i terminé OK ... on attend les autres jobs avant de poursuivre ..."
		else
			trace ARC-0320 "Job $i terminé KO ($rc / $CTL_DIR/job-tar.$i.log) ... on attend les autres jobs avant de poursuivre ..."
			(( rcAll = $rcAll + 1 ))
		fi
		echo "$rc" > $CTL_DIR/job-tar.$i.rc # sauvegarde du RC
		details=$(< $CTL_DIR/job-tar.$i.log) # Log du job
		trace ARC-0700 "$details"
	done

	fin=$(date '+%H %M')
	delta=$(echo "$debut $fin" | awk '{delta=(($3*60)+$4)-(($1*60)+$2)} (delta<0){delta+=24*60} {print int(delta*10/60)/10}')
	
	trace ARC-0600 "TARGZ+SPLIT parallèle $tarSplitParallel terminé en $delta heure(s)"
	details=$(ls -l $DATA_DIR) # Log des fichiers splittés + total en Ko (attention c'est pas en octets !!!)
	trace ARC-0700 "$details"
	
	# Sortie si KO
	[[ $rcAll -ne 0 ]] && trace ARC-0320 "$rcAll jobs sont tombés en erreur" && sortir 1

	# Check s'il reste des fichiers indicateur de traitement encours ou en erreur
	nok=$(ls -1 $CTL_DIR/*.TARGZ_SPLIT_EN_COURS_OU_EN_ERREUR 2> /dev/null)
	if [[ -n $nok ]]
	then
		trace ARC-0320 "Des traitements se sont mal terminés (cf. $CTL_DIR/*.TARGZ_SPLIT_EN_COURS_OU_EN_ERREUR et les logs dans $CTL_DIR/job-tar.*.log)"
		trace ARC-0320 "$nok" # Log des fichiers fautifs
		sortir 1
	fi

	
	# Reporting (pas de contrôle possible) du nombre et de la taille des fichiers (à défaut de checksum)
	# -----------------------------------------------------------------------------------------------------

	trace ARC-0600 "Reporting de travail ..."
	
	nbArcFiles=$(ls -L1p $dumpDir | egrep -vc '/$')
	trace ARC-0600 "Nous avions $nbArcFiles fichiers à packager TARGZ/SPLIT" 
	
	nbASFiles=$(ls -1 $DATA_DIR | wc -l)
	trace ARC-0600 "Nous avons produit $nbASFiles fichiers dans $DATA_DIR pour ARCSYS" 
	
	tailleArcFiles=$(ls -Llp $dumpDir | egrep -v '/$' | egrep -v '^total' | awk 'BEGIN {taille=0} {taille+=($5/(1024*1024))} END {print int(taille)}')
	trace ARC-0600 "Nous avions $tailleArcFiles Mo de fichiers à packager TARGZ/SPLIT" 
	
	tailleASFiles=$(ls -l $DATA_DIR | egrep -v '^total' | awk 'BEGIN {taille=0} {taille+=($5/(1024*1024))} END {print int(taille)}')
	trace ARC-0600 "Nous avons produit $tailleASFiles Mo dans $DATA_DIR pour ARCSYS" 

	if [[ $tailleArcFiles -gt 0 ]]
	then
		(( gain = ( ( $tailleArcFiles - $tailleASFiles ) * 100 ) / $tailleArcFiles ))
		trace ARC-0600 "Nous avons compacté l'archive de $gain % ($tailleArcFiles Mo -> $tailleASFiles Mo)"
	else
		trace ARC-0600 "Nous avons compacté l'archive $tailleArcFiles Mo -> $tailleASFiles Mo"
	fi
	
	trace ARC-0500 "########### Etape TAR terminée OK ###########"
	
	return 0 # obligatoire pour des enchainnements && par exemple
}




# Calcul le CheckSum/Empreinte d'une liste de fichiers pour ArcSys
# Pour chaque fichier xxx du listing, production d'un fichier xxx.chksum au même endroit qui contient le checksum 
# NB : Peut être lancé en background via &
# NB : Pas d'usage de trace() ici, que des echo afin d'être récupéré par > dans un log suivant le job &
# Entrées :
#  $1 : Chemin du fichier listant tous les noms de fichiers (sans leur chemin) à traiter
# Sorties :
#  RC : 0 si OK sinon erreur
calcule_empreintes()
{
	[[ -n $SHL_ODEBUG ]] && set -vx # Debug du script

	typeset -i nombre
	
	# Arguments
	listing=$1
	dataDir=$arcsysDir/data
	ctlDir=$arcsysDir/control
	
	# Check minimum des variables
	[[ ! -s $listing ]] && echo "Le fichier $listing n'existe pas ou est vide" && return 1
	[[ ! -d $dataDir ]] && echo "Le dossier $dataDir n'existe pas" && return 1
	[[ ! -d $ctlDir ]] && echo "Le dossier $ctlDir n'existe pas" && return 1
	
	# Jump dans le dossier source
	cd $dataDir
	
	# Indicateur d'erreur dans le calcul (par défaut, sera nettoyé si tout sort OK)
	cp $listing $ctlDir/$(basename $listing).CHKSUM_EN_COURS_OU_EN_ERREUR
	
	# Nombre de fichiers à traiter
	quantite=$(wc -l $listing | awk '{print $1}')
	
	# Parcours des fichiers à traiter
	echo "Debut du job $listing ($quantite fichiers à traiter)"
	i=0
	while read f
	do
		
		(( i = $i + 1 ))
		
		timestamp=$(date '+%d/%m/%Y %H:%M:%S')
		echo "#$i/$quantite FICHIER $f @ $timestamp"
		
		# Calcul de l'empreinte ==> <nom fichier source>.chksum
		sha256sum $f > $ctlDir/$f.chksum
		rc=$?
		
		# Analyse erreurs
		[[ $rc -ne 0 ]] && echo "#$i/$quantite FICHIER $f : Une erreur $rc est survenue lors du checksum du fichier $dataDir/$f @ $timestamp" && return 1
		
		# Création du fichier d'identité (pour le mode reprise)
		ls -lp --time-style=full-iso $dataDir/$f > $ctlDir/$f.idemp # pas .ident car pris par étape TAR
		
	done < $listing
	echo "Fin du job $listing"

	# Nettoyage du flag encours/erreur
	rm -f $ctlDir/$(basename $listing).CHKSUM_EN_COURS_OU_EN_ERREUR
	
	# Fin OK
	return 0
}





# Création du fichier SIP listant les fichiers de l'archive et leur métadonnées associées
# NB : Les fichiers blocks sont de la forme <xxxx.nnnn>
# Entrées : aucune
# Sorties : aucune (sortir sur erreur)
etape_meta()
{
	[[ -n $SHL_ODEBUG ]] && set -vx # Debug du script

	trace ARC-0500 "########### Etape META ($etapeReprise) ###########"

	# Répertoires de travail
	DATA_DIR=$arcsysDir/data
	CTL_DIR=$arcsysDir/control

	# Contrôle de la présence d'un dump packagé dans le SAS ARCSYS et qu'il n'y a pas d'erreurs
	# -----------------------------------------------------------------------------------------------------
	
	trace ARC-0600 "Test de la présence d'un package ARCSYS dans $DATA_DIR ..."
	
	ok=$(ls -1 $DATA_DIR 2> /dev/null)
	[[ -z $ok ]] && trace ARC-0310 "Il n'existe aucun package ARCSYS dans $DATA_DIR" && sortir 1
	
	trace ARC-0600 "Test de l'intégrité du package ARCSYS ..."
	
	# Check s'il existe des fichiers indicateur de traitement TARGZ encours ou en erreur
	nok=$(ls -1 $CTL_DIR/*.TARGZ_SPLIT_EN_COURS_OU_EN_ERREUR 2> /dev/null)
	if [[ -n $nok ]]
	then
		trace ARC-0320 "Des traitements TARGZ/SPLIT se sont mal terminés (cf. $CTL_DIR/*.TARGZ_SPLIT_EN_COURS_OU_EN_ERREUR et les logs dans $CTL_DIR/job-tar.*.log)"
		trace ARC-0320 "$nok" # Log des fichiers fautifs
		sortir 1
	fi
	
	trace ARC-0600 "Intégrité OK à priori ..."

	
	# Nettoyage des fichiers de calcul de checksum précédents et d'un éventuel SIP
	# -----------------------------------------------------------------------------------------------------
	
	if [[ -z $etapeReprise || $etapeReprise != "META" ]]
	then
		trace ARC-0600 "Nettoyage des checksum déjà calculés de $CTL_DIR ... (sauf en mode reprise META où on va compléter)"
		rm -f $CTL_DIR/*.chksum 2> /dev/null # fichier contenant "<checksum> <nom de fichier>"
		rm -f $CTL_DIR/*.idemp 2> /dev/null # fichier contenant "<taille> <mtime>" (pour détecter un écart éventuel)
		# pas .ident car pris par étape TAR
	fi
	
	trace ARC-0600 "Nettoyage d'un éventuel sip.xml* de $CTL_DIR ..."
	rm -f $CTL_DIR/sip.xml* 2> /dev/null
	
	# Clean des fichiers en cours de trt pour repartir d'une page blanche
	rm -f $CTL_DIR/*.CHKSUM_EN_COURS_OU_EN_ERREUR 2> /dev/null

	
	# Génération du HEADER du fichier SIP à partir de la date de dump fourni en argument
	# -----------------------------------------------------------------------------------------------------
	
	# ATTTENTION : Fichier SIP en UTF-8 ou ISO-8859-1 ... cf. le fichier de configuiration du header du SIP $SIP_DEB
	
	# Quelques définitions
	fichierSip=$CTL_DIR/sip.xml # il peut exister déjà (cf. reprise)
	idArcsys="CAUX_DB_$dateDump"
	nbFicPack=$(ls -1 $DATA_DIR | wc -l)
	(( stepProgress5pct = $nbFicPack / 20 ))
	[[ $stepProgress5pct -eq 0 ]] && nbFicPack=1
		
	trace ARC-0600 "Création du HEADER du fichier $fichierSip avec l'ID $idArcsys (reset du fichier s'il existe déjà) ..."
	# IDENTIFIANT : Identifiant unique de l'archive dans ARCSYS.
	#               On ne peut pas transmettre 2 fois le même ID !
	#               Le pack qui sera transmis à ARCSYS sur son serveur via SFTP sera de la forme :
	#                 <id>
	#                   \_ sip.xml
	#                   \_ DEPOT
	#                         \_ <liste des fichiers/blocs de l'archive>
	# LIBELLE : Description de l'archive (texte libre)
	# DATE_CONSERVATION : Date YYYY-MM-DD qui fait foi pour la purge du package/ID une fois le délai de rétention échu
	#                     Il s'agit de la date du dump tout simplement
	cat $SIP_DEB | \
		sed "s/\[IDENTIFIANT\]/$idArcsys/g" | \
		sed "s/\[LIBELLE\]/Dump caux/g" | \
		sed "s/\[DATE_CONSERVATION\]/${dateDump}/g" > $fichierSip.EN_COURS_OU_EN_ERREUR

		
	# Préparation des jobs du BODY du fichier SIP
	# -----------------------------------------------------------------------------------------------------
	
	trace ARC-0600 "Préparation au remplissage du BODY du fichier $fichierSip en parallèle $chksumParallel ..."

	# Clean des jobs passés
	rm -f $CTL_DIR/job-meta.* 2> /dev/null
	
	# Listage des fichiers xxx.nnnn à calculer par ordre croissant de taille et dispatch du travail en $chksumParallel jobs
	#   Création de $chksumParallel fichiers $CTL_DIR/job-meta.n avec n de 0 à $chksumParallel-1
	i=0
	ls -1Sr $DATA_DIR | while read f # juste les noms de fichiers sans leur chemin
	do
		# Test si les fichiers .idemp et .chksum sont présents (reprise) # pas .ident car pris par étape TAR
		if [[ -s $CTL_DIR/$f.idemp && -s $CTL_DIR/$f.chksum ]]
		then
			avant=$(< $CTL_DIR/$f.idemp)
			apres=$(ls -lp --time-style=full-iso $DATA_DIR/$f)
			# Si en phase alors on bypass le calcul de checksum (déjà fait)
			# NB : Le fichier .idemp n'est créé que si le fichier .chksum a été créé correctement (calcul OK) donc si le chksum est corrompu, on recalculera (no idemp file)
			[[ $avant == $apres ]] && continue
		fi
		
		# Clean si présents car on doit les refaire ici
		rm -f $CTL_DIR/$f.idemp $CTL_DIR/$f.chksum
		
		# Chaque fichier de job contient des fichiers de taille croissante, ventilés en round robin
		echo "$f" >> $CTL_DIR/job-meta.$i
		(( i = ( $i + 1 ) % $chksumParallel ))
	done

	# Au moins 1 job à faire ?
	if [[ ! -s $CTL_DIR/job-meta.0 ]]
	then
		trace ARC-0400 "Aucun job n'a été défini (reprise d'un traitement entièrement terminé par exemple). Bypass du calcul des empreintes !"
	else
		trace ARC-0600 "Préparation terminée ..."
		details=$(egrep -v '^$' $CTL_DIR/job-meta.*) # Log des jobs définis
		trace ARC-0600 "$details"
	fi
	
	# Bypass calcul des empreintes si reprise avec calcul complet déjà fait
	if [[ -s $CTL_DIR/job-meta.0 ]]
	then
	
		# Calcul des checksum/empreintes
		# -----------------------------------------------------------------------------------------------------

		trace ARC-0600 "Calcul des empreintes en parallèle $chksumParallel ... (lancement des jobs)"
		
		# Listing des ID de job
		ids=$(ls -1 $CTL_DIR/job-meta.* | sed 's/^.*\([0-9]\)$/\1/g')
		
		debut=$(date '+%H %M')
		
		# Lancement des jobs de calcul
		for i in $ids
		do
			trace ARC-0600 "Lancement du job $i (cf. $CTL_DIR/job-meta.$i.*)"
			calcule_empreintes $CTL_DIR/job-meta.$i > $CTL_DIR/job-meta.$i.log 2>&1 &
			pid=$!
			echo "$pid" > $CTL_DIR/job-meta.$i.pid # sauvegarde du PID pour le wait pour en récupérer le RC /PID
			sleep 1
		done

		trace ARC-0600 "Calcul parallèle $chksumParallel ... (attente de la fin des jobs)"
		trace ARC-0700 "Vous pouvez suivre l'avancement des jobs dans les fichiers $CTL_DIR/job-meta.*.log"
		trace ARC-0700 "ou via la commande : egrep '(Debut|FICHIER|Fin)' $CTL_DIR/job-meta.?.log | sed 's/:/ /' | awk '(NR==1){old=\$1;lgn=\$0}(\$1!=old){print lgn;old=\$1}{lgn=\$0}END{print lgn}'"
		
		# Attente de la fin des jobs
		# NB : Si un casse, les autres le feront surement en même temps
		rcAll=0
		for i in $ids
		do
			pid=$(< $CTL_DIR/job-meta.$i.pid)
			wait $pid
			rc=$?
			if [[ $rc -eq 0 ]]
			then
				trace ARC-0600 "Job $i terminé OK ... on attend les autres jobs avant de poursuivre ..."
			else
				trace ARC-0320 "Job $i terminé KO ($rc / $CTL_DIR/job-meta.$i.log) ... on attend les autres jobs avant de poursuivre ..."
				(( rcAll = $rcAll + 1 ))
			fi
			echo "$rc" > $CTL_DIR/job-meta.$i.rc # sauvegarde du RC
			details=$(< $CTL_DIR/job-meta.$i.log) # Log du job
			trace ARC-0700 "$details"
		done
		
		fin=$(date '+%H %M')
		delta=$(echo "$debut $fin" | awk '{delta=(($3*60)+$4)-(($1*60)+$2)} (delta<0){delta+=24*60} {print int(delta*10/60)/10}')

		trace ARC-0600 "Calcul parallèle $chksumParallel terminé en $delta heure(s)"
		details=$(ls -l $CTL_DIR/*.chksum) # Log des fichiers de checksum + total en Ko (attention c'est pas en octets !!!)
		trace ARC-0700 "$details"
		
		# Sortie si KO
		[[ $rcAll -ne 0 ]] && trace ARC-0320 "$rcAll jobs sont tombés en erreur" && sortir 1
		
		# Check s'il existe des fichiers indicateur de traitement encours ou en erreur
		nok=$(ls -1 $CTL_DIR/*.CHKSUM_EN_COURS_OU_EN_ERREUR 2> /dev/null)
		if [[ -n $nok ]]
		then
			trace ARC-0320 "Des traitements se sont mal terminés (cf. $CTL_DIR/*.CHKSUM_EN_COURS_OU_EN_ERREUR et les logs dans $CTL_DIR/job-meta.*.log)"
			trace ARC-0320 "$nok" # Log des fichiers fautifs
			sortir 1
		fi
		
		# Débit de traitement (lecture fichier, calcul sha256)
		#   taille d'entrée traité / temps de traitement total
		tailleMoTraite=0
		for f in $(cat $CTL_DIR/job-meta.?)
		do
			tailleMo=$(ls -l $DATA_DIR/$f | awk '{print int($5/(1024*1024))}')
			(( tailleMoTraite = $tailleMoTraite + $tailleMo ))
		done
		debitMbPerSec=$(echo "$debut $fin $tailleMoTraite" | awk '{deb=$1*60+$2;fin=$3*60+$4;delta=fin-deb+1;print int($5*8/(delta*60))}')
		trace ARC-0600 "Le débit visible du traitement = $debitMbPerSec Mb/s (lire la source, calcul du sha256, écrire le résultat) c-a-d principalement le débit disque/réseau"
		
	fi # GOTO_SIP
	
	
	# Remplissage du BODY du fichier sip.xml (1 ligne par fichier)
	# -----------------------------------------------------------------------------------------------------
	
	# ATTTENTION : Fichier SIP en UTF-8 ou ISO-8859-1 ... cf. le fichier de configuiration du header du SIP $SIP_DEB
	
	trace ARC-0600 "Remplissage du body du fichier sip.xml"
	
	# Parcours de chaque fichier à transmettre
	ls -1 $DATA_DIR | while read f # juste les noms de fichiers sans leur chemin
	do
		# Check fichiers idemp/checksum présents # pas .ident car pris par étape TAR
		[[ ! -s $CTL_DIR/$f.idemp || ! -s $CTL_DIR/$f.chksum ]] && trace ARC-0320 "Le checksum n'a pas été calculé/validé pour $DATA_DIR/$f" && sortir 1
		
		# Lecture de l'empreinte
		empreinte=$(awk '{print $1}' $CTL_DIR/$f.chksum)
		[[ -z $empreinte ]] && trace ARC-0320 "Le checksum n'a pu être lu dans le fichier $CTL_DIR/$f.chksum" && sortir 1
		
		# Ecriture de la ligne dans le SIP
		# ex. d'empreinte : 9c2a59e2e93635bb0f2e1ef56933f5eddf46601cd488bff52b68d28106de122b
		cat $SIP_LIGNE | \
			sed "s/\[NOM_FICHIER\]/${f}/g" | \
			sed "s/\[EMPREINTE_FICHIER\]/${empreinte}/g" >> $fichierSip.EN_COURS_OU_EN_ERREUR
	done


	# Génération du FOOTER du fichier SIP
	# -----------------------------------------------------------------------------------------------------
	
	# ATTTENTION : Fichier SIP en UTF-8 ou ISO-8859-1 ... cf. le fichier de configuiration du header du SIP $SIP_DEB
	
	trace ARC-0600 "Création du FOOTER du fichier $fichierSip ..."
	cat $SIP_FIN >> $fichierSip.EN_COURS_OU_EN_ERREUR
	
	
	trace ARC-0600 "Finalisation du fichier sip.xml"
	mv $fichierSip.EN_COURS_OU_EN_ERREUR $fichierSip

	
	trace ARC-0500 "########### Etape META terminée OK ###########"
	
	return 0 # obligatoire pour des enchainnements && par exemple
}






# Exécute une série de commandes via SFTP sur ARCSYS et retourne (fichier) le contenu de la sortie out/err SFTP.
# Cette sortie est de la forme suivante, pour chaque commande jouée :
#  sftp> commande
#  résultat de la commande sur 0..n lignes
# NB : Lors des transferts de fichiers, leur mode/time est conservé. Le mode BINARY est implicite en SSH/SFTP (pas de conversion ASCII).
# NB : Peut être lancée en background & et n'utilise que des echo (pas de trace) pour ne pas entrecroiser les logs
# Entrées :
#  $1 : Les commandes séparées par un ;. Une comnande en erreur est bloquante et sort stp en erreur aussi.
#       Mais une commande commençant par - ne bloque pas (les autres commandes sont jouées) et ne sorte pas sftp en erreur non plus.
#       Ex. : -rm existe_pas produit l'affichage "sftp> -rm existe_pas \n Couldn't delete file: No such file or directory" mais sftp sort OK (rc=0).
#  $2 : Fichier où sera produit le résultat de la commande SFTP (sa sortie out/err).
#       Cela permet de ne pas confndre la sortie "set -vx" et logs vs la sortie SFTP elle-même
# Sorties :
#  RC : 0 si OK sinon erreur
cmdes_sftp()
{
	[[ -n $SHL_ODEBUG ]] && set -vx # Debug du script
	[[ -n $SHL_ODEBUG ]] && verboseSftp="-v" # Debug SFTP aussi
	
	# Arguments
	cmdes="$1"
	sortie="$2"
	
	echo "Exécution des commandes SFTP '$cmdes' via 'sftp $verboseSftp -p -b $sortie.cmdes $sshOptions $sshUser@$sshHost' ..."
	
	# Génération du fichier des commandes SFTP (plus pratique que d'utiliser stdin sur sftp)
	echo "$cmdes" | tr ';' '\n' > $sortie.cmdes
	
	# Exécution des commandes
	# NB : -oBatchMode=yes demande de générer un KO dès qu'il y a besoin de demander qq chose à l'utilisateur (ici le batch) comme un mot de passe
	#      c'est plus large que juste l'option -oPasswordAuthentication=no
	# NB : -p permet de garder les mode/time du fichier source en cas de transfert de fichiers durant les commandes
	#      (Preserves modification times, access times, and modes from the original files transferred)
	# Exemples de résultats :
	#  Si OK :
	#    Connected to bt1svu0r.
	#    Changing to: /appli/cxqud6/tools/
	#    sftp> bye
	#  Si KO d'authent (compte inexistant, pas de clé SSH public injectée sur la cible, ...) :
	#    Permission denied (publickey,gssapi-keyex,gssapi-with-mic,password).
	#    Couldn't read packet: Connection reset by peer
	#  Si KO de machine :
	#    ssh: Could not resolve hostname bt1vu0r: Name or service not known
	#    Couldn't read packet: Connection reset by peer
	#  Si KO de répertoire :
	#    Connected to bt1svu0r.
	#    File "/appli/cxqud6/tool/" not found.
	echo "# sftp $verboseSftp -p -b $sortie.cmdes $sshOptions $sshUser@$sshHost" > $sortie
	sftp $verboseSftp -p -b $sortie.cmdes $sshOptions $sshUser@$sshHost >> $sortie 2>&1
	rc=$?
	
	if [[ $rc -ne 0 ]]
	then
		echo "Erreur $rc bloquante rencontrée lors de l'exécution des commandes (cf. $sortie)"
		cat $sortie
	else
		echo "Commandes exécutées OK/WARNING (cf. $sortie)"
	fi
	
	rm -f $sortie.cmdes 2> /dev/null

	return $rc
}




# Transfert les fichiers du package ARCSYS sur la machine d'ARCSYS, pour intégration
# Pour chaque fichier xxx du listing, "mise à jour" du fichier sur le distant. Cette màj permet la reprise sans tout uploader à nouveau.
# NB : Peut être lancé en background via &
# NB : Pas d'usage de trace() ici, que des echo afin d'être récupéré par > dans un log suivant le job &
# Entrées :
#  $1 : Chemin du fichier listant tous les noms de fichiers (sans leur chemin) à traiter
# Sorties :
#  RC : 0 si OK sinon erreur
rsync_sftp()
{
	[[ -n $SHL_ODEBUG ]] && set -vx # Debug du script

	typeset -i nombre
	
	# Arguments
	listing=$1
	dataDir=$arcsysDir/data
	ctlDir=$arcsysDir/control
	dstDir=$sshDir/CAUX_DB_$dateDump/DEPOT # créé par l'appelant sur le distant
	
	# Check minimum des variables
	[[ ! -s $listing ]] && echo "Le fichier $listing n'existe pas ou est vide" && return 1
	[[ ! -d $dataDir ]] && echo "Le dossier $dataDir n'existe pas" && return 1
	[[ ! -d $ctlDir ]] && echo "Le dossier $ctlDir n'existe pas" && return 1
	
	# Check de la connexion SFTP (bloquante ici si KO)
	# cf. dans l'appelant
	
	# Jump dans le dossier source
	cd $dataDir
	
	# Indicateur d'erreur dans le calcul (par défaut, sera nettoyé si tout sort OK)
	cp $listing $ctlDir/$(basename $listing).SFTP_EN_COURS_OU_EN_ERREUR
	
	# Nombre de fichiers à traiter
	quantite=$(wc -l $listing | awk '{print $1}')
	
	# Métrologie Globale - Début et Taille des fichiers
	debutGlobal=$(date '+%H %M %S')
	tailleGlobalMo=0
	
	# Parcours des fichiers à traiter
	echo "Debut du job $listing ($quantite fichiers à traiter)"
	i=0
	while read f
	do
		
		(( i = $i + 1 ))
		doIt=0
		
		timestamp=$(date '+%d/%m/%Y %H:%M:%S')
		echo "#$i/$quantite FICHIER $f @ $timestamp"

		# Clean initial des fichiers de travail
		rm -f $ctlDir/$f.ls.* $ctlDir/$f.put.*

		
		# EXISTANT
		# ------------------------------------------------------------------------------------------------------

		# Lecture du fichier sur la cible pour voir s'il faut le retransmettre ou pas (auto détection d'une reprise technique)
		cmdes_sftp "cd $dstDir;-ls -l $f" $ctlDir/$f.ls.out > $ctlDir/$f.ls.log 2>&1
		rc=$?
		[[ $rc -ne 0 ]] && cat $ctlDir/$f.ls.log && return 1
		
		# Analyse de la réponse (fichier existe ? quels attributs ?) ==> à (re)transmettre ou pas
		# Si le fichier n'existe pas :    (hors DEBUG mode)
		#	sftp> cd /servicepp/VERS/TEMP
		#	sftp> -ls -l test.test
		#	Can't ls: "/servicepp/VERS/TEMP/test.test" not found
		# Si le fichier existe :          (hors DEBUG mode)
		#	sftp> cd /servicepp/VERS/TEMP
		#	sftp> -ls -l test.test
		#	-rwxrwx---    0 25299    1000            5 Mar 30 01:02 test.test
		if [[ -n $(egrep 'Can.t ls: .* not found' $ctlDir/$f.ls.out) ]]
		then
			echo "#$i/$quantite FICHIER $f : Il n'existe pas sur la cible = à transférer ..."
			doIt=1
		else
			fDistant=$(egrep "..:.. $f\$" $ctlDir/$f.ls.out | awk '{print $9" de taille "$5" o. et de timestamp "$7" "$6" "$8}')
			fLocal=$(ls -l $f | awk '{print $9" de taille "$5" o. et de timestamp "$7" "$6" "$8}')
			# Exemple : -rwxrwx---. 1 ppcaux cauxgrp 5 Mar 30 01:02 test.test
			if [[ $fDistant == $fLocal ]]
			then
				echo "#$i/$quantite FICHIER $f : Il existe sur la cible et de bonne taille/timestamp = pas de retransfert à faire ..."
			else
				echo "#$i/$quantite FICHIER $f : Il existe sur la cible mais de mauvaise taille/timestamp ($fLocal vs distant $fDistant) = à retransférer ..."
				doIt=1
			fi
		fi

		
		# NOUVEAU ou màj
		# ------------------------------------------------------------------------------------------------------
		
		if [[ $doIt -eq 1 ]]
		then
		
			# Métrologie - Début et Taille fichier
			debut=$(date '+%H %M %S')
			tailleMo=$(ls -l $f | egrep -v '^total' | awk '{taille=$5/(1024*1024); print int(taille)}')
			(( tailleGlobalMo = $tailleGlobalMo + $tailleMo ))

			
			# Transmission du fichier sur ARCSYS (et delete fichier temporaire de transfert éventuel)
			# Exemple de trace :             (hors DEBUG mode)
			#	sftp> cd /servicepp/VERS/TEMP
			#	sftp> -rm test.test.tmp
			#	Couldn't delete file: No such file or directory
			#	sftp> -rm test.test
			#	Couldn't delete file: No such file or directory
			#	sftp> put test.test test.test.tmp
			#	sftp> rename test.test.tmp test.test
			#	sftp> ls test.test
			#	test.test
			# NB : progress est désactivé (et non réactivable) en mode -b : cela ne permet pas d'avoir le débit/durée/100% souhaité. Le 'ls' OK suffira donc.
			cmdes_sftp "cd $dstDir;-rm $f.tmp;-rm $f;put $f $f.tmp;chmod $MODE_ARCSYS_FICHIER $f.tmp;rename $f.tmp $f;ls $f" $ctlDir/$f.put.out > $ctlDir/$f.put.log 2>&1
			rc=$?
			[[ $rc -ne 0 ]] && cat $ctlDir/$f.put.log && return 1
			
			# Metrologie - Fin
			fin=$(date '+%H %M %S')
			debitMbPerSec=$(echo "$debut $fin $tailleMo" | awk '{delta=(($4*3600)+($5*60)+$6)-(($1*3600)+($2*60)+$3)+1} (delta<0){delta+=24*3600} {print int($7*8*10/delta)/10}')
			echo "#$i/$quantite FICHIER $f : Fichier de $tailleMo Mo transféré à $debitMbPerSec Mb/s"
			
		fi
		
	done < $listing
	echo "Fin du job $listing"

	# Metrologie Globale - Fin
	finGlobal=$(date '+%H %M %S')
	debitGlobalMbPerSec=$(echo "$debutGlobal $finGlobal $tailleGlobalMo" | awk '{delta=(($4*3600)+($5*60)+$6)-(($1*3600)+($2*60)+$3)+1} (delta<0){delta+=24*3600} {print int($7*8*10/delta)/10}')
	echo "Le débit global de transfert de ce job (en // des autres) est de $debitGlobalMbPerSec Mb/s pour $tailleGlobalMo Mo réellement transférés (somme des tailles des fichiers (hors ceux déjà sur cible) sur la durée du job)"
	# Attention, si vous changez cette phrase, il faut changer le calcul tailleMoTraite=XXX ci-dessous dans etape_sftp() !

	# Nettoyage du flag encours/erreur
	rm -f $ctlDir/$(basename $listing).SFTP_EN_COURS_OU_EN_ERREUR
	
	# Fin OK
	return 0
}




# Transfert SFTP du package à ARCSYS suivant l'arborescence cible
# Entrées : aucune
# Sorties : aucune (sortir sur erreur)
etape_sftp()
{
	[[ -n $SHL_ODEBUG ]] && set -vx # Debug du script

	trace ARC-0500 "########### Etape SFTP ($etapeReprise) ###########"

	# Répertoires de travail
	DATA_DIR=$arcsysDir/data
	CTL_DIR=$arcsysDir/control
	
	# Répertoire cible du package ARCSYS sur le serveur ARCSYS (racine de l'arborescence)
	TARGET_DIR=$sshDir/CAUX_DB_$dateDump
	
	
	# Check que le package est complet (check sip.xml est sufisant)
	# -----------------------------------------------------------------------------------------------------

	fichierSip=$CTL_DIR/sip.xml
	[[ ! -s $fichierSip ]] && trace ARC-0310 "Le fichier sip.xml est introuvable, le package est incomplet, rejouer l'étape META." && sortir 1


	# Check s'il existe des fichiers indicateur de traitement CHKSUM encours ou en erreur
	nok=$(ls -1 $CTL_DIR/*.CHKSUM_EN_COURS_OU_EN_ERREUR 2> /dev/null)
	if [[ -n $nok ]]
	then
		trace ARC-0320 "Des traitements de calcul des empreintes (étape META) se sont mal terminés (cf. $CTL_DIR/*.CHKSUM_EN_COURS_OU_EN_ERREUR et les logs dans $CTL_DIR/job-meta.*.log)"
		trace ARC-0320 "$nok" # Log des fichiers fautifs
		sortir 1
	fi
	
	trace ARC-0600 "Intégrité OK à priori ..."

	
	# Nettoyage des fichiers de contrôle des transferts ARCSYS
	# -----------------------------------------------------------------------------------------------------
	
	trace ARC-0600 "Nettoyage des fichiers de contrôle de transfert de $CTL_DIR ... (mode reprise ou non)"

	rm -f $CTL_DIR/*.SFTP_EN_COURS_OU_EN_ERREUR 2> /dev/null

	trace ARC-0600 "Nettoyage des fichiers de contrôle de transfert de $CTL_DIR terminé"

	
	# Check de la connexion SFTP (bloquante ici si KO)
	# -----------------------------------------------------------------------------------------------------

	trace ARC-0600 "Contrôle de l'accès SFTP à ARCSYS et son répertoire d'accueil $sshDir sur $sshUser@$sshHost ..."

	controle_sftp
	rc=$?

	[[ $rc -ne 0 ]] && trace ARC-0320 "Le répertoire d'accueil ARCSYS $sshDir est inaccessible !" && sortir 1
	
	
	# Création du répertoire d'archive sur ARCSYS (il va accueillir les fichiers de données dans DEPOT et le fichier sip.xml)
	# -----------------------------------------------------------------------------------------------------

	trace ARC-0600 "Création du répertoire de dépôt de l'archive ARCSYS CAUX $TARGET_DIR/DEPOT sur $sshUser@$sshHost:$sshDir/ ..."
	
	# Exemple de réponse SFTP :
	#	sftp> ls
	#	servicepp
	#	sftp> -mkdir /servicepp/VERS/TEMP/CAUX_DB_xxxx
	#	Couldn't create directory: Failure
	#	sftp> -mkdir /servicepp/VERS/TEMP/CAUX_DB_xxxx/DEPOT
	#	Couldn't create directory: Failure
	#	sftp> ls /servicepp/VERS/TEMP/CAUX_DB_xxxx/DEPOT
	#	sftp> ls /servicepp/VERS/TEMP/CAUX_DB_xxxx/DEPOTs
	#	Can't ls: "/servicepp/VERS/TEMP/CAUX_DB_xxxx/DEPOTs" not found
	# Si le 'ls' tombe KO alors on sort en erreur aussi. le mkdir peut tomber KO si le répertoire existe déjà (= OK)
	cmdes_sftp "ls;-mkdir $TARGET_DIR;chmod $MODE_ARCSYS_DOSSIER $TARGET_DIR;-mkdir $TARGET_DIR/DEPOT;chmod $MODE_ARCSYS_DOSSIER $TARGET_DIR/DEPOT;ls $TARGET_DIR/DEPOT" $CTL_DIR/job-sftp.mkdir.out > $CTL_DIR/job-sftp.mkdir.log 2>&1
	rc=$?
	
	if [[ $rc -ne 0 ]]
	then
		trace ARC-0320 "La création de l'arborescence d'accueil de l'archive ARCSYS CAUX $TARGET_DIR/DEPOT sur $sshUser@$sshHost est tombée en erreur ($rc) (cf. $CTL_DIR/job-sftp.mkdir.log)"
		details=$(< $CTL_DIR/job-sftp.mkdir.log)
		trace ARC-0320 "$details"
		sortir 1
	fi
	
	details=$(< $CTL_DIR/job-sftp.mkdir.out)
	trace ARC-0700 "$details"

	trace ARC-0600 "Arborescence d'accueil $TARGET_DIR/DEPOT créée"

	
	# Génération du fichier flag .ignore dans le dossier d'archivage ARCSYS de ce dump $TARGET_DIR
	# NB : Cela permet à ARCSYS de ne pas prendre en compte ce dossier durant le transfert. Le fichier .ignore est supprimé à la fin du transfert OK
	# -----------------------------------------------------------------------------------------------------

	trace ARC-0600 "Transfert du fichier flag .ignore vers $sshUser@$sshHost:$TARGET_DIR ..."
	touch $CTL_DIR/.ignore
	#rsync -e "ssh $sshOptions" --progress $CTL_DIR/.ignore $sshUser@$sshHost:$TARGET_DIR > $CTL_DIR/job-sftp.ignore.log 2>&1
	cmdes_sftp "cd $TARGET_DIR;-rm .ignore.tmp;-rm .ignore;put $CTL_DIR/.ignore .ignore.tmp;chmod $MODE_ARCSYS_FICHIER .ignore.tmp;rename .ignore.tmp .ignore;ls $TARGET_DIR/.ignore" $CTL_DIR/job-sftp.ignore.out > $CTL_DIR/job-sftp.ignore.log 2>&1
	rc=$?
	
	if [[ $rc -ne 0 ]]
	then
		trace ARC-0320 "Le transfert du fichier .ignore vers $sshUser@$sshHost:$TARGET_DIR est tombé en erreur ($rc) (cf. $CTL_DIR/job-sftp.ignore.log)"
		details=$(< $CTL_DIR/job-sftp.ignore.log)
		trace ARC-0320 "$details"
		sortir 1
	fi
	
	details=$(< $CTL_DIR/job-sftp.ignore.out)
	trace ARC-0700 "$details"
	
	trace ARC-0600 "Transfert du fichier flag .ignore vers $sshUser@$sshHost:$TARGET_DIR OK"	
	
	
	# Préparation des jobs de transfert des fichiers blocks
	# -----------------------------------------------------------------------------------------------------
	
	trace ARC-0600 "Préparation au transfert parallèle $sftpParallel ..."

	# Clean des jobs passés
	rm -f $CTL_DIR/job-sftp.* 2> /dev/null
	
	# Listage des fichiers à transférer par ordre croissant de taille et dispatch du travail en $sftpParallel jobs
	#   Création de $sftpParallel fichiers $CTL_DIR/job-sftp.n avec n de 0 à $sftpParallel-1
	i=0
	ls -1Sr $DATA_DIR | while read f # juste les noms de fichiers sans leur chemin
	do
		# Chaque fichier de job contient des fichiers de taille croissante, ventilés en round robin
		echo "$f" >> $CTL_DIR/job-sftp.$i
		(( i = ( $i + 1 ) % $sftpParallel ))
	done

	# Au moins 1 job à faire ?
	[[ ! -s $CTL_DIR/job-sftp.0 ]] && trace ARC-0400 "Aucun job n'a été défini (reprise d'un traitement entièrement terminé par exemple). Passage à l'étape suivante !" && return 0
	
	trace ARC-0600 "Préparation terminée ..."
	details=$(egrep -v '^$' $CTL_DIR/job-sftp.*) # Log des jobs définis
	trace ARC-0600 "$details"

	
	# Transfert des fichiers du package en //
	# -----------------------------------------------------------------------------------------------------

	trace ARC-0600 "Transfert parallèle $sftpParallel vers $sshUser@$sshHost:$TARGET_DIR/DEPOT ... (lancement des jobs)"
	
	# Listing des ID de job
	ids=$(ls -1 $CTL_DIR/job-sftp.* | sed 's/^.*\([0-9]\)$/\1/g')
	
	debut=$(date '+%H %M')

	# Lancement des jobs de copie
	# NB : usage de rsync car il est plus puissant/intelligent (et renomme le fichier à destination si OK : .fic5_bin.ItyPVW --> fic5_bin)
	#   Conservation des attributs/mtime du fichier (-ptg)
	#   Ne retransmet pas le fichier si déjà transmis (basé sur mtime et taille je pense d'où les options -ptg ci-dessus pour que rsync sache en profiter)
	#   Affichage de métrologie /fichier
	# MAIS ARCSYS ne permet que du SFTP : This service allows sftp connections only. RSYNC a besoin de SSH en entier. Pasage par une fonction /SFTP
	for i in $ids
	do
		trace ARC-0600 "Lancement du job $i (cf. $CTL_DIR/job-sftp.$i.*)"
		#rsync -ptg -e "ssh $sshOptions" --progress --files-from=$CTL_DIR/job-sftp.$i $DATA_DIR $sshUser@$sshHost:$TARGET_DIR/DEPOT > $CTL_DIR/job-sftp.$i.log 2>&1 &
		rsync_sftp $CTL_DIR/job-sftp.$i > $CTL_DIR/job-sftp.$i.log 2>&1 &
		pid=$!
		echo "$pid" > $CTL_DIR/job-sftp.$i.pid # sauvegarde du PID pour le wait pour en récupérer le RC /PID
		sleep 1
	done

	trace ARC-0600 "Transfert parallèle $sftpParallel vers $sshUser@$sshHost:$TARGET_DIR/DEPOT ... (attente de la fin des jobs)"
	trace ARC-0700 "Vous pouvez suivre l'avancement des jobs dans les fichiers $CTL_DIR/job-sftp.*.log"
	#trace ARC-0700 "ou via la commande : egrep '(to-check|sent)' $CTL_DIR/job-sftp.?.log | sed 's/:/ /' | awk '(NR==1){old=\$1;lgn=\$0}(\$1!=old){print lgn;old=\$1}{lgn=\$0}END{print lgn}'"
	trace ARC-0700 "ou via la commande : egrep '(Debut|FICHIER|Fin)' $CTL_DIR/job-sftp.?.log | sed 's/:/ /' | awk '(NR==1){old=\$1;lgn=\$0}(\$1!=old){print lgn;old=\$1}{lgn=\$0}END{print lgn}'"
	
	# Attente de la fin des jobs
	# NB : Si un casse, les autres le feront surement en même temps
	rcAll=0
	for i in $ids
	do
		pid=$(< $CTL_DIR/job-sftp.$i.pid)
		wait $pid
		rc=$?
		if [[ $rc -eq 0 ]]
		then
			trace ARC-0600 "Job $i terminé OK ... on attend les autres jobs avant de poursuivre ..."
		else
			trace ARC-0320 "Job $i terminé KO ($rc / $CTL_DIR/job-sftp.$i.log) ... on attend les autres jobs avant de poursuivre ..."
			(( rcAll = $rcAll + 1 ))
		fi
		echo "$rc" > $CTL_DIR/job-sftp.$i.rc # sauvegarde du RC
		details=$(< $CTL_DIR/job-sftp.$i.log) # Log du job
		trace ARC-0700 "$details"
	done
	
	fin=$(date '+%H %M')
	delta=$(echo "$debut $fin" | awk '{delta=(($3*60)+$4)-(($1*60)+$2)} (delta<0){delta+=24*60} {print int(delta*10/60)/10}')
	
	trace ARC-0600 "Transfert parallèle $sftpParallel vers $sshUser@$sshHost:$TARGET_DIR/DEPOT terminé en $delta heure(s)"
	
	# Sortie si KO
	[[ $rcAll -ne 0 ]] && trace ARC-0320 "$rcAll jobs sont tombés en erreur" && sortir 1

	# Débit de traitement (lecture fichier, écriture SSH sur le réseau)
	#   taille d'entrée traité / temps de traitement total
	# NB : seul les logs de rsync permettent de voir ce qu'il a réellement transmit (car pas de reprise sur déjà fait)
	#      Avec le passage en SFTP i/o RSYNC, cf. le log : 	echo "Le débit global de transfert de ce job ....."
	tailleMoTraite=$(egrep '^Le débit global de transfert de ce job' $CTL_DIR/job-sftp.?.log | awk 'BEGIN{tot=0}{tot+=$18}END{print tot}')
	debitMbPerSec=$(echo "$debut $fin $tailleMoTraite" | awk '{deb=$1*60+$2;fin=$3*60+$4;delta=fin-deb;if (delta<0){delta+=(24*60)};if (delta==0){delta=1};print int($5*8/(delta*60))}')
	trace ARC-0600 "Le débit visible du traitement = $debitMbPerSec Mb/s (lire la source, écrire sur la machine ARCSYS /ssh) (0 veut dire aucune màj distante) (précis à la minute)"

	
	# Controle des fichiers transmis (ls)
	# -----------------------------------------------------------------------------------------------------
	
	# non

	
	# Transfert du fichier sip.xml et delete du fichier .ignore (déclenche l'intégration dans ARCSYS)
	# -----------------------------------------------------------------------------------------------------

	trace ARC-0600 "Transfert du fichier sip.xml vers $sshUser@$sshHost:$TARGET_DIR ..."
	
	#rsync -e "ssh $sshOptions" --progress $CTL_DIR/sip.xml $sshUser@$sshHost:$TARGET_DIR > $CTL_DIR/job-sftp.sip.log 2>&1
	cmdes_sftp "cd $TARGET_DIR;-rm sip.xml.tmp;-rm sip.xml;put $CTL_DIR/sip.xml sip.xml.tmp;chmod $MODE_ARCSYS_FICHIER sip.xml.tmp;rename sip.xml.tmp sip.xml;ls $TARGET_DIR/sip.xml" $CTL_DIR/job-sftp.sip.out > $CTL_DIR/job-sftp.sip.log 2>&1
	rc=$?
	
	if [[ $rc -ne 0 ]]
	then
		trace ARC-0320 "Le transfert du fichier sip.xml vers $sshUser@$sshHost:$TARGET_DIR est tombé en erreur ($rc) (cf. $CTL_DIR/job-sftp.sip.log)"
		details=$(< $CTL_DIR/job-sftp.sip.log)
		trace ARC-0320 "$details"
		sortir 1
	fi
	
	details=$(< $CTL_DIR/job-sftp.sip.out)
	trace ARC-0700 "$details"
		
	trace ARC-0600 "Transfert du fichier sip.xml vers $sshUser@$sshHost:$TARGET_DIR OK"
	
	
	# Reset du fichier .ignore (déclenche l'intégration dans ARCSYS)
	# -----------------------------------------------------------------------------------------------------

	trace ARC-0600 "Destruction du fichier flag .ignore de $sshUser@$sshHost:$TARGET_DIR ..."
	cmdes_sftp "cd $TARGET_DIR;rm .ignore" $CTL_DIR/job-sftp.end.out > $CTL_DIR/job-sftp.end.log 2>&1
	rc=$?
	
	if [[ $rc -ne 0 ]]
	then
		trace ARC-0320 "La destruction du fichier flag .ignore de $sshUser@$sshHost:$TARGET_DIR est tombée en erreur ($rc) (cf. $CTL_DIR/job-sftp.end.log)"
		details=$(< $CTL_DIR/job-sftp.end.log)
		trace ARC-0320 "$details"
		sortir 1
	fi
	
	details=$(< $CTL_DIR/job-sftp.end.out)
	trace ARC-0700 "$details"
	
	trace ARC-0600 "Destruction du fichier flag .ignore de $sshUser@$sshHost:$TARGET_DIR OK"

	
	# Destruction du package ainsi transmis OK
	# -----------------------------------------------------------------------------------------------------
	
	# non on le garde jusqu'à la prochaine fois où il sera écrasé (DATA_DIR et CTL_DIR)
	
	
	
	# Indicateur de fin de transfert SFTP OK (cf. l'étape ROLL qui le check)
	touch $CTL_DIR/_end
	
	trace ARC-0500 "########### Etape SFTP terminée OK ###########"
	
	return 0 # obligatoire pour des enchainnements && par exemple
}






# Archivage du dump source et rollover des archives précédentes selon la configuration donnée
# Entrées : aucune
# Sorties : aucune (sortir sur erreur)
etape_roll()
{
	[[ -n $SHL_ODEBUG ]] && set -vx # Debug du script

	trace ARC-0500 "########### Etape ROLL ($etapeReprise) ###########"

	CTL_DIR=$arcsysDir/control

	
	# Check si l'archivage a déjà été fait
	# -----------------------------------------------------------------------------------------------------

	trace ARC-0600 "Check si l'archivage a déjà été effectué ..."
	[[ -f $CTL_DIR/job-roll.all.done ]] && trace ARC-0400 "L'archivage a déjà été effectué." && return 0
	trace ARC-0600 "Archivage à faire"


	# Check que le transfert est OK
	# -----------------------------------------------------------------------------------------------------

	trace ARC-0600 "Check du transfert terminé/OK vers ARCSYS ..."
	[[ ! -f $CTL_DIR/_end ]] && trace ARC-0310 "Le transfert SFTP n'a pas été complet (le fichier $CTL_DIR/_end n'a pas été généré). Rejouer l'étape SFTP." && sortir 1
	trace ARC-0600 "Check du transfert terminé/OK vers ARCSYS : OK"

	
	# Check que l'archivage est activé
	# -----------------------------------------------------------------------------------------------------

	trace ARC-0600 "Check si l'archivage est activé/demandé ..."
	[[ $rollMonths -eq 0 ]] && trace ARC-0400 "L'archivage n'est pas activé (rollMonths=$rollMonths) !" && return 0
	trace ARC-0600 "Archivage activé/demandé"

	
	# Résolution du lien vers le dump source (si lien symbolique et non dossier physique configuré)
	# -----------------------------------------------------------------------------------------------------

	trace ARC-0600 "Résolution du lien symbolique éventuel $dumpDir ..."
	dumpDir=$(cd -P $dumpDir;pwd)
	trace ARC-0600 "dumpDir devient $dumpDir"
	
	
	# Check que le dump source est déplaçable
	# -----------------------------------------------------------------------------------------------------

	trace ARC-0600 "Check du dossier source $dumpDir archivable ..."
	[[ ! -w $dumpDir/.. ]] && trace ARC-0320 "Le dump source $dumpDir n'est pas déplaçable car son dossier hôte n'est pas en écriture (-w) et bloque l'archivage" && sortir 1
	trace ARC-0600 "Dossier source $dumpDir archivable"
	# NB : -x permet l'accès au répertoire (on peut s'y déplacer et manipuler des objets s'y trouvant mais sans pouvoir les lister (-r nécessaire) ni les renommer/modifier (-w nécessaire))
	#      -r permet de lister/lire son contenu. On peut manipuler un objet s'y trouvant juste avec -x mais il faut alors connaitre son nom. -r sans -x est une abération et donne des affichages étranges.
	#      -w permet de modifier son contenu c-a-d renommer des objets, les déplacer ... -w sans -x est une abération et ne permet de rien faire.
	# Ici on doit pouvoir déplacer dumpDir de son dossier père donc il nous faut le droit xw à minima sur ce dernier (je ne fais pas de ls donc -r pas obligatoire mais c'est préférable).
	# Vu qu'on a pu lire dumpDir, xr est déjà là .. on check juste -w donc.


	# Check que le dossier d'archive est manipulable (rwx)
	# -----------------------------------------------------------------------------------------------------

	trace ARC-0600 "Check du dossier d'archive $dumpArchDir manipulable ..."
	[[ ! -x $dumpArchDir || ! -r $dumpArchDir || ! -w $dumpArchDir ]] && trace ARC-0320 "Le dossier d'archive $dumpArchDir n'est pas manipulable (rwx) et bloque l'archivage" && sortir 1
	trace ARC-0600 "Dossier d'archive $dumpArchDir manipulable"
	# NB : -x permet l'accès au répertoire (on peut s'y déplacer et manipuler des objets s'y trouvant mais sans pouvoir les lister (-r nécessaire) ni les renommer/modifier (-w nécessaire))
	#      -r permet de lister/lire son contenu. On peut manipuler un objet s'y trouvant juste avec -x mais il faut alors connaitre son nom. -r sans -x est une abération et donne des affichages étranges.
	#      -w permet de modifier son contenu c-a-d renommer des objets, les déplacer ... -w sans -x est une abération et ne permet de rien faire.
	# Ici on doit pouvoir déplacer des dossier de ce répertorie donc il nous faut les droits xw à minima (je ne fais pas de ls donc -r pas obligatoire mais c'est préférable)


	# Etat des archives courantes
	# -----------------------------------------------------------------------------------------------------
	
	trace ARC-0600 "Etat des archives courantes ..."
	details=$(ls -Llp --time-style=long-iso $dumpArchDir/M-*/* 2> /dev/null | egrep -v '^total' | egrep -v '/$' | sed "s:$dumpArchDir/::;s:/.*\$::" | awk '{print $8" "$6}' | sort | uniq -c) # Log des dates observées sur chaque archive
	trace ARC-0600 "$details"
	

	# Roll des archives précédentes dans la limite du nombre configuré
	# -----------------------------------------------------------------------------------------------------

	# Archive finale à purger (si pas déjà fait /mode reprise)
	if [[ -d $dumpArchDir/M-${rollMonths} && ! -f $CTL_DIR/job-roll.${rollMonths}.done ]]
	then
		trace ARC-0600 "Suppression de l'archive M-${rollMonths} en fin de vie"
		nok=$(rm -rf $dumpArchDir/M-${rollMonths} 2>&1)
		if [[ $? -ne 0 ]]
		then
			trace ARC-0320 "L'archive $dumpArchDir/M-${rollMonths} n'a pu être supprimée"
			trace ARC-0320 "$nok"
			sortir 1
		fi
		touch $CTL_DIR/job-roll.${rollMonths}.done # pour ne pas le refaire en mode reprise
	fi
	
	trace ARC-0600 "Rollover des archives précédentes dans la limite de $rollMonths mois archivés"
	(( moisSrc = $rollMonths - 1 ))
	while [[ $moisSrc -ge 1 ]]
	do
		(( moisDst = $moisSrc + 1 ))
		if [[ -d $dumpArchDir/M-${moisSrc} && ! -f $CTL_DIR/job-roll.${moisSrc}.done ]]
		then
			trace ARC-0600 "Shift de l'archive M-${moisSrc} vers M-${moisDst}"
			nok=$(mv $dumpArchDir/M-${moisSrc} $dumpArchDir/M-${moisDst} 2>&1)
			if [[ $? -ne 0 ]]
			then
				trace ARC-0320 "L'archive $dumpArchDir/M-${moisSrc} n'a pu être déplacée vers $dumpArchDir/M-${moisDst}"
				trace ARC-0320 "$nok"
				sortir 1
			fi
		fi
		touch $CTL_DIR/job-roll.${moisSrc}.done # pour ne pas le refaire en mode reprise
		(( moisSrc = $moisSrc - 1 )) # passage à l'archive suivante (en fait le mois d'avant encore)
	done
	
	trace ARC-0600 "Déplacement/Archivage du dump courant $dumpDir dans l'archive M-1 $dumpArchDir/M-1"
	nok=$(mv $dumpDir $dumpArchDir/M-1 2>&1)
	if [[ $? -ne 0 ]]
	then
		trace ARC-0320 "L'archivage de $dumpDir n'a pu être fait vers $dumpArchDir/M-1"
		trace ARC-0320 "$nok"
		sortir 1
	fi
	touch $CTL_DIR/job-roll.all.done # Archivage totalement effectué


	# Etat des archives post roll
	# -----------------------------------------------------------------------------------------------------
	
	trace ARC-0600 "Etat des archives post ROLL ..."
	details=$(ls -Llp --time-style=long-iso $dumpArchDir/M-*/* | egrep -v '^total' | egrep -v '/$' | sed "s:$dumpArchDir/::;s:/.*\$::" | awk '{print $8" "$6}' | sort | uniq -c) # Log des dates observées sur chaque archive
	trace ARC-0600 "$details"

	
	trace ARC-0500 "########### Etape ROLL terminée OK ###########"
	
	return 0 # obligatoire pour des enchainnements && par exemple
}






# ########################################################################################
# MAIN
# ########################################################################################

# Raccourcis du -h (ou aucun argument)
[[ $# -eq 0 || $1 == "-h" ]] && affiche_usage && exit 0 # 2nd exit du code

# Initialisation du loggueur ARE
init_are
trace ARC-0500 "Démarrage du traitement d'archivage selon les arguments $* "

# Controle d'un parallel run
controle_parallel

# Lecture/Vérification des arguments de la ligne de commande
lire_arguments $@

# Lecture/Vérification de la configuration
lire_configuration

trace ARC-0600 "Le chemin du dump de la BDD CAUX : $dumpDir"
trace ARC-0600 "Le chemin du package ARCSYS : $arcsysDir"

# Prise en compte du bypass du traitement si lancé de VTOM (équivalent d'un passage en SIMU du job)
[[ $vtomBypass == "oui" && -n $TOM_SCRIPT ]] && trace ARC-0400 "Bypass VTOM activé : Le traitement n'est pas exécuté et retour OK à VTOM" && sortir 0

# Controle de la permission de lancer ce script sur cette machine (utile en PROD)
controle_backup_caux

# Controle de l'accès SFTP à ARCSYS (non bloquant à ce stade (pour info et anticipation) mais seulement à l'étape SFTP)
controle_sftp

# Traitement suivant l'étape demandée (option de reprise)
[[ -z $etapeReprise || $etapeReprise =~ "TAR" ]] && etape_tar && etapeReprise="NEXT"
[[ -z $etapeReprise || $etapeReprise =~ ^(META|NEXT)$ ]] && etape_meta && etapeReprise="NEXT"
[[ -z $noSftp ]] && [[ -z $etapeReprise || $etapeReprise =~ ^(SFTP|NEXT)$ ]] && etape_sftp && etapeReprise="NEXT"
[[ -z $noSftp ]] && [[ -z $etapeReprise || $etapeReprise =~ ^(ROLL|NEXT)$ ]] && etape_roll && etapeReprise="NEXT"

# Sortie OK (les erreurs sont gérées dans les etape_xxxxx)
sortir 0

