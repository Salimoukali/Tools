#!/usr/bin/ksh
#--- Marking Strings ----------------------------------------------------------------------------
#--- @(#)F3GFAR-S: $Workfile:   destruktor.sh  $ $Revision:   1.2  $
#------------------------------------------------------------------------------------------------
#--- @(#)F3GFAR-E: $Workfile:   destruktor.sh  $ VersionLivraison = 2.0.0.0
#------------------------------------------------------------------------------------------------

#------------------------------------------------------------------------------------------------
#VERSION_Begin
#
#    %ThisShell%: 2.0.0.0
#
#VERSION_End
#------------------------------------------------------------------------------------------------
#USAGE_Begin
#
#    %ThisShell% [--config=<config file>] [--nolog] [--noverbose] [--version] [--help] 
#
#          --config=<config file>      ; donner un nom de fichier de configuration.
#          --nolog                     ; pour que le shell ne log rien
#          --noverbose                 ; Pour que le shell n'affiche rien
#          --version                   ; pour avoir la version.
#          --help                      ; pour avoir cette aide.
#
#          Toutes les options sont aussi acceptées avec un seul "-": exemple -nolog.
#          Toutes les options sont aussi acceptèes en abrégé       : exemple --h pour --help.
#          ATTENTION: -n et -no sont les abrégés de --noverbose.
#
#          Par defaut le fichier de configuration le fichier de configuration utilisé est
#          dans $HOME/cmnF3G/Tools/cfg/destruktor.cfg. Pour utiliser un autre fichier utiliser
#          l'option --config avec le nom complet du fichier (chemin compris).
#
#USAGE_End 
#------------------------------------------------------------------------------------------------

#------------------------------------------------------------------------------------------------
#--- Pour verifier l'existance d'un répertoire et l'acces a ce répertoire.
#------------------------------------------------------------------------------------------------

checkFilePresence() 
{
    if test -e ${2}
    then            

        OKS=`expr ${OKS} + 1`

        return ${OK}

    else

        NOKS=`expr ${NOKS} + 1`

        cout -f
        log  "Le fichier ou répertoire" ${1} "n'existe pas."
        cout "Le fichier ou répertoire "${1}" n'existe pas."

        return ${NOK}

    fi
}

#------------------------------------------------------------------------------------------------
#--- Pour verifier si le répertoire passé en paramètre existe et est accessible en lecture.
#------------------------------------------------------------------------------------------------

delete() 
{
    if checkFilePresence ${1} ${2}
    then

        cout -f
        log  "Effacement de" ${1} "2>/dev/null"
        cout "Effacement de "${1}" 2>/dev/null"
        log  "rm -rf" ${1}" 2>/dev/null"
        cout "rm -rf" ${1} "2>/dev/null"

        rm -rf ${2} 2>/dev/null

        log  "Effacement de" ${1} "2>/dev/null effectué."
        cout "Effacement de" ${1} "2>/dev/null effectué."

    fi
}

#------------------------------------------------------------------------------------------------
#--- fichier de configuration
#------------------------------------------------------------------------------------------------

getCfg() 
{
    if test ${IFLAG} -eq ${FALSE}
    then

        CFGFILE=${DEFCFGFILE}

    fi

    if [ "X${CFGFILE}" = "X" ]
    then

        cout -f
        log  "Le nom du fichier de configuration ne doit pas être vide."
        cout "Le nom du fichier de configuration ne doit pas être vide."
        cout -f

        exit ${NOK}

    fi

    if test ! -f ${CFGFILE}
    then

        cout -f
        log  ${CFGFILE} "not found."
        cout ""${CFGFILE}" not found."
        cout -f

        exit ${NOK}

    fi

    cout -f
    log  "Fichier de configuration utilisé:" ${CFGFILE}
    cout "Fichier de configuration utilisé: "${CFGFILE}""
}

#------------------------------------------------------------------------------------------------
#--- Pour afficher du text sur la sortie standard.
#------------------------------------------------------------------------------------------------

cout()
{
    if [ "X${1}" = "X-f" ]
    then

        shift

        if test ${VFLAG} -ne ${FALSE} 
        then

            echo ${*}

        fi

    else

        if test ${VFLAG} -ne ${FALSE} 
        then

            echo ${FACILITY_NAME}: ${*}

        fi

    fi
}

#------------------------------------------------------------------------------------------------
#--- Pour afficher du text dans ${LOGFILE}.
#------------------------------------------------------------------------------------------------

log() 
{ 
    if test ${LFLAG} -ne ${FALSE} 
    then

        echo ${FACILITY_NAME}: ${*} >> ${LOGFILE}

    fi
} 

#------------------------------------------------------------------------------------------------
#--- Pour afficher la version du shell.
#------------------------------------------------------------------------------------------------

version() 
{
    cout -f
    cout -f "Version:"

    sed "/^#VERSION_Begin.*/,/^#VERSION_End.*/!d;/VERSION_Begin/d;/VERSION_End/d;s/^#//g;s/%ThisShell%/${FACILITY_NAME}/g" ${FACILITY}

    exit ${OK}
}
  
#------------------------------------------------------------------------------------------------
#--- Ce qu'il faut afficher quand les parametres sont incorrects.
#------------------------------------------------------------------------------------------------

usage() 
{ 
    cout -f
    cout -f "Usage:"

    sed "/^#USAGE_Begin.*/,/^#USAGE_End.*/!d;/USAGE_Begin/d;/USAGE_End/d;s/^#//g;s/%ThisShell%/${FACILITY_NAME}/g" ${FACILITY}

    exit ${OK}
} 

#------------------------------------------------------------------------------------------------
#--- Positionnement des variables d'environement
#------------------------------------------------------------------------------------------------

DATE=`date +"%Y%m%d%H%M%S"`

OK=${OK:=0} 
NOK=${NOK:=1} 

TRUE=${TRUE:=1} 
FALSE=${FALSE:=0} 

FACILITY=$0 
FACILITY_NAME=$(basename $0)

VFLAG=${TRUE}
LFLAG=${TRUE}
IFLAG=${FALSE}

LOGEXT=${LOGEXT:=log}
CFGEXT=${CFGEXT:=cfg}
SHLEXT=${SHLEXT:=sh}

LOGDIR=${LOGDIR:=.}
CFGDIR=${CFGDIR:=../cfg}

LOGFILE=${LOGFILE:=${LOGDIR}/$(basename ${FACILITY_NAME} .${SHLEXT})_${DATE}.${LOGEXT}}
DEFCFGFILE=${DEFCFGFILE:=${CFGDIR}/$(basename ${FACILITY_NAME} .${SHLEXT}).${CFGEXT}}

NOKS=0
OKS=0

#------------------------------------------------------------------------------------------------
#--- Récupération des paramètres
#------------------------------------------------------------------------------------------------

for ac_option
do

    case "${ac_option}" in

        -*=*) ac_optarg=`cout -f "${ac_option}" | sed 's/[-_a-zA-Z0-9]*=//'`;;
           *) ac_optarg=                                                 ;;
    esac

    case "${ac_option}" in

         -help | -hel | -he | -h | --help | --hel | --he | --h ) usage;;

         -version |  -versio |  -versi |  -vers |  -ver |  -ve |  -v | \
        --version | --versio | --versi | --vers | --ver | --ve | --v     ) version;;

         -nolog | -nolo | -nol | --nolog | --nolo | --nol ) LFLAG=${FALSE};;

         -noverbose |  -noverbos |  -noverbo |  -noverb |  -nover |  -nove |  -nov |  -no |  -n | \
        --noverbose | --noverbos | --noverbo | --noverb | --nover | --nove | --nov | --no | --n     ) VFLAG=${FALSE};;

         -config=* |  -confi=* |  -conf=* |  -con=* |  -co=* |  -c=* | \
        --config=* | --confi=* | --conf=* | --con=* | --co=* | --c=*     ) IFLAG=${TRUE}
                                                                           CFGFILE=${ac_optarg};;

         -config |  -confi |  -conf |  -con |  -co |  -c | \
        --config | --confi | --conf | --con | --co | --c     ) cout -f
                                                               log  "L'option" ${ac_option} "nécessite un argument."
                                                               cout "L'option "${ac_option}" nécessite un argument."
                                                               usage;;

        *) log  "Paramètre non supporté:" ${ac_option}
           cout "Paramètre non supporté: "${ac_option}""
           usage;;

    esac

done

#------------------------------------------------------------------
#--- Récupération du fichier de conf
#------------------------------------------------------------------

getCfg

#------------------------------------------------------------------
#--- Lancement du binaire
#------------------------------------------------------------------

cout -f
log  "Ce shell va détruire les éléments suivants:"
cout "Ce shell va détruire les éléments suivants:"
cout -f

for i in `cat ${CFGFILE} | grep "TODELETE" | awk -F"=" -v name=${FACILITY_NAME} '{ printf( "%s\n", $2 ) }'`
do

    cout "\t\t"${i}

done

for j in `cat ${CFGFILE} | grep "TODELETE" | awk -F"=" -v name=${FACILITY_NAME} '{ print $2 }'`
do

    log "\t\t"${j}

done

cout -f
cout "Etes-vous sûr de vous (o/O)? \c"

if test ${VFLAG} -ne ${FALSE} 
then

    read REPONSE

    if [ "X${REPONSE}" != "Xo" ]
    then

        if [ "X${REPONSE}" != "XO" ]
        then

            log "Etes-vous sûr de vous (o/O)?" ${REPONSE}
            cout -f
            log  "Installation abandonnée."
            cout "Installation abandonnée."
            cout -f

            exit $NOK

        fi

        log "Etes-vous sûr de vous (o/O)?" ${REPONSE}

    else

        log "Etes-vous sûr de vous (o/O)?" ${REPONSE}
        cout "Etes-vous ABSOLUMENT sûr de vous (o/O)? \c"

        read REPONSE

        if [ "X${REPONSE}" != "Xo" ]
        then

            if [ "X${REPONSE}" != "XO" ]
            then

                log "Etes-vous ABSOLUMENT sûr de vous (o/O)?" ${REPONSE}
                cout -f
                log  "Installation abandonnée."
                cout "Installation abandonnée."
                cout -f

                exit $NOK

            fi

            log "Etes-vous ABSOLUMENT sûr de vous (o/O)?" ${REPONSE}

        fi

        log "Etes-vous ABSOLUMENT sûr de vous (o/O)?" ${REPONSE}

    fi
fi

for FILE in `cat ${CFGFILE} | grep "TODELETE" | awk -F"=" -v name=${FACILITY_NAME} '{ print $2 }'`
do

    TMP="echo ${FILE}"

    RES=`eval ${TMP}`

    delete ${FILE} ${RES}

done

cout -f

DATE=`date +"%Y%m%d%H%M%S"`

log  "Travail terminé. Renomage du fichier de configuration."
cout "Travail terminé. Renomage du fichier de configuration."

mv ${CFGFILE} ${CFGDIR}/$(basename ${CFGFILE} .${CFGEXT})_${DATE}_OKS_${OKS}_NOKS_${NOKS}.${CFGEXT}

log  "Consultez les fichier de log" ${LOGFILE}
cout "Consultez les fichier de log "${LOGFILE}""

log  "Bye for now ..."
cout "Bye for now ..."

cout -f

exit ${OK}
