#!/usr/bin/ksh
#--- Marking Strings ----------------------------------------------------------------------------
#--- @(#)F3GFAR-S: $Workfile:   PrepareFiles.sh  $ $Revision:   1.2  $
#------------------------------------------------------------------------------------------------
#--- @(#)F3GFAR-E: $Workfile:   PrepareFiles.sh  $ VersionLivraison = 2.0.0.0
#------------------------------------------------------------------------------------------------

#------------------------------------------------------------------------------------------------
#VERSION_Begin
#%ThisShell%: Version = 2.0.0.0
#VERSION_End
#------------------------------------------------------------------------------------------------
#USAGE_Begin
#
#    %ThisShell% --config=<config file> [--noheader] [--new] [--verbose] [--nolog] [--help] [--version]
#
#             --config=<config file>   ; donner un nom de fichier de configuration (sans l'extension).
#             --noheader               ; pour ne pas avoir de ligne d'enetête dans le fichier de contrôle.
#             --new                    ; pour ecraser le fichier de control s'ily en a déja un.
#                                        Par défaut rien est écrasé, on ajoute à la suite.
#             --verbose                ; pour que le shell sorte des information sur la sortie standard.
#             --nolog                  ; pour que le shell ne log rien.
#             --help                   ; pour avoir cette aide.
#             --version                ; pour avoir la version.
# 
#USAGE_End 
#------------------------------------------------------------------------------------------------

#------------------------------------------------------------------------------------------------
#--- Pour afficher la version du shell.
#------------------------------------------------------------------------------------------------

version() 
{
    echo

    sed "/^#VERSION_Begin.*/,/^#VERSION_End.*/!d;/VERSION_Begin/d;/VERSION_End/d;s/^#//g;s/%ThisShell%/${FACILITY_NAME}/g" ${FACILITY}

    echo

    exit ${OK}
}

#------------------------------------------------------------------------------------------------
#--- Ce qu'il faut afficher quand les parametres sont incorrects.
#------------------------------------------------------------------------------------------------

usage() 
{ 
    echo 
    echo "Usage:"
    sed "/^#USAGE_Begin.*/,/^#USAGE_End.*/!d;/USAGE_Begin/d;/USAGE_End/d;s/^#//g;s/%ThisShell%/${FACILITY_NAME}/g" ${FACILITY}

    exit ${NOK}
} 

function print_msg
{
  if [[ $2 -eq 1 ]]
  then
  echo $Program\>\> $1 >> ${FICHIER_LOG}
  fi
  if [[ $2 -eq 0 ]]
  then
  echo $Program\>\> $1 >> ${FICHIER_LOG}
  echo $Program\>\> $1
  fi
  return 0
}


#------------------------------------------------------------------------------------------------
#--- Pour afficher du text sur la sortie standard.
#------------------------------------------------------------------------------------------------

cout()
{
    if test ${VFLAG} -eq ${TRUE}
    then

        echo ${FACILITY_NAME}: $*

    fi
}

#------------------------------------------------------------------------------------------------
#--- Pour afficher du text dans ${LOGFILE}.
#------------------------------------------------------------------------------------------------

log() 
{ 
    if test ${LFLAG} -eq ${FALSE}
    then

        echo ${FACILITY_NAME}: $* >> ${LOGFILE}

    fi
} 

#------------------------------------------------------------------------------------------------
#--- Pour verifier si une variable d'environnement est positionnée.
#------------------------------------------------------------------------------------------------

checkEnvVariable()
{
    if test -z "$1"
    then

        log  "Variable" $2 "non positionnée."
        cout "Variable" $2 "non positionnée."

        exit ${NOK}

    fi      
}    

#------------------------------------------------------------------------------------------------
#--- Pour verifier l'existance d'un répertoire et l'acces a ce répertoire.
#------------------------------------------------------------------------------------------------

checkDirectory() 
{
    if test -d $1 -a -$2 $1
    then            
        return ${NOK}
    else            
        return ${OK}
    fi
}

#------------------------------------------------------------------------------------------------
#--- Pour verifier si le répertoire passé en paramètre existe et est accessible en lecture.
#------------------------------------------------------------------------------------------------

checkInputDirectory() 
{
    if checkDirectory "$1" "r"
    then

        log  "Répertoire" $1 "non accesible en lecture."
        cout "Répertoire" $1 "non accesible en lecture."

        exit ${NOK}

    fi
}

#------------------------------------------------------------------------------------------------
#--- Pour verifier si le fichier existe deja dans le fichier de control.
#------------------------------------------------------------------------------------------------

VerifyFileCTL() 
{

    RepFile=${WORKDIR}/${CTLFILE}
    File=`grep $1 ${RepFile}`

    if [[ ${File} = $1 ]] 
    then
        log "Le nom de fichier " $1 " existe dans " ${CTLFILE} "."  
        cout "Le nom de fichier" $1 "existe deja dans le fichier."
        return 1
    fi

    return 0

}

#------------------------------------------------------------------------------------------------
#--- Pour vérifier si le répertoire passe en paramètre existe et est accessible en ecriture.
#------------------------------------------------------------------------------------------------

checkOutputDirectory() 
{
    if checkDirectory "$1" "w"
    then

        log  "Répertoire" $1 "non accesible en écriture."
        cout "Répertoire" $1 "non accesible en écriture."

        exit ${NOK}

    fi
}


#------------------------------------------------------------------------------------------------
#--- Pour vérifier les variable d'environnement.
#------------------------------------------------------------------------------------------------

checkAllEnvVariables()
{       
    checkEnvVariable     "${LOGDIR}" "LOGDIR"
    checkOutputDirectory "${LOGDIR}"

    LOGFILE=${LOGDIR}/$(basename ${FACILITY_NAME} .${SHLEXT})_${DATE}.${LOGEXT}

    rm -f ${LOGFILE} > /dev/null 2>&1

    checkEnvVariable "${WORKDIR}" "WORKDIR"
    checkEnvVariable "${CTLFILE}" "CTLFILE"
    checkEnvVariable "${FILETAG}" "FILETAG"
        
    if test ${HFLAG} -eq ${TRUE}
    then

        checkEnvVariable "${HEADER}" "HEADER"

    fi

    checkInputDirectory  "${WORKDIR}"
    checkOutputDirectory "${WORKDIR}"
 }

#------------------------------------------------------------------------------------------------
#--- Pour construire la liste des fichiers 
#------------------------------------------------------------------------------------------------

getListFile()
{
    liste=`ls ${WORKDIR}/* | grep -v "\.ctl"`

    echo ${liste}
}

#------------------------------------------------------------------------------------------------
#--- Pour remplir le fichier de contrôle
#------------------------------------------------------------------------------------------------

writeCtl()
{
    echo "$1" >> ${WORKDIR}/${CTLFILE}

    ret=$?

    if [ "X$ret" != "X0" ]
    then

        log  "Impossible d'écrire dans le fichier" ${WORKDIR}/${CTLFILE}
        cout "Impossible d'écrire dans le fichier" ${WORKDIR}/${CTLFILE} ""
 	unlock
        exit ${NOK}

    fi
}

#------------------------------------------------------------------------------------------------
#--- Pour créer le fichier CheckSum.
#------------------------------------------------------------------------------------------------

sumCheck()
{
    SUM=`sum $1`

    ret=$?

    if [ "X$ret" != "X0" ]
    then

        log  "Problème de retour de la commande 'sum'"
        cout "Problème de retour de la commande 'sum'"
 	unlock
        exit ${NOK}

    fi

    echo ${SUM} | awk '{ print $1,$2 }' >> $1.CheckSum

    ret=$?

    if [ "X$ret" != "X0" ]
    then

        log  "Impossible d'écrire dans le fichier" $1.CheckSum
        cout "Impossible d'écrire dans le fichier" $1.CheckSum ""
 	unlock
        exit ${NOK}

    fi
}

#------------------------------------------------------------------------------------------------
#--- 
#------------------------------------------------------------------------------------------------

control_checksum()
{
    
    if test ! -f "${WORKDIR}/${CTLFILE}"
    then

        if test ${HFLAG} -eq ${TRUE}
        then

            writeCtl ${HEADER}

        fi

    else
        CTLEXIST=${TRUE}
 
        if test ${NFLAG} -eq ${TRUE}
        then

            log  "le fichier" ${CTLFILE} "existe déjà. On écrase"
            cout "le fichier" ${CTLFILE} "existe déjà. On écrase"

            rm -f ${WORKDIR}/${CTLFILE} 2>/dev/null

            if test ${HFLAG} -eq ${TRUE}
            then

                writeCtl ${HEADER}

            fi

        else

            log  "le fichier" ${CTLFILE} "existe déjà. On écrit à la suite."
            cout "le fichier" ${CTLFILE} "existe déjà. On écrit à la suite."

        fi

    fi

    for fichier in ${LISTFILE} 
    do
        File=${FILETAG}"="${fichier}
 
        # On verifie l enregistrement s'il existe si on n'ecrase pas le fichier de controle
        if [[ ${NFLAG} -eq ${FALSE} ]] && [[ ${CTLEXIST} -eq ${TRUE} ]]
        then
              VerifyFileCTL ${File}
              retour=$?
        fi

        # On reutilise le fichier de controle et l'enregistrement n'existe pas
        if [[ $retour = 0 ]] && [[ ${NFLAG} -eq ${FALSE} ]]
        then
            FlagTrait=1
        fi

        # Le fichier CTL n'existe et on demande d'ecraser le fichier
        if [[ ${CTLEXIST} -eq ${false}  ]] && [[ ${NFLAG} -eq ${FALSE} ]]
        then
            FlagTrait=1
        fi

        # Si le FlagTrait est a 1 ou si on ecrase le fichier de control 
        if [[ $FlagTrait -eq 1 ]] || [[ ${NFLAG} -eq ${TRUE} ]] 
        then
             writeCtl ${FILETAG}"="${fichier}
        fi
 
        sumCheck ${fichier}
        
        FlagTrait=0

    done

    sumCheck ${WORKDIR}/${CTLFILE}
}
 

#------------------------------------------------------------------------------------------------
#--- Positionnement des variables d'environement.
#------------------------------------------------------------------------------------------------

DATE=`date +"%Y%m%d%H%M%S"`

OK=${OK:=0} 
NOK=${NOK:=1} 

TRUE=${TRUE:=1} 
FALSE=${FALSE:=0} 

FACILITY=$0 
FACILITY_NAME=$(basename ${0})

HFLAG=${TRUE}
VFLAG=${FALSE}
LFLAG=${FALSE}
IFLAG=${FALSE}
NFLAG=${FALSE}
CTLEXIST=${FALSE}

LOGEXT=${LOGEXT:=log}
CFGEXT=${CFGEXT:=cfg}
SHLEXT=${SHLEXT:=sh}

CFGDIR=${CFGDIR:=../cfg}
SHLDIR=${SHLDIR:=../shl}
retour=2
FlagTrait=0 

#------------------------------------------------------------------------------------------------
#--- Parameter search.
#------------------------------------------------------------------------------------------------

for ac_option
do

    case "${ac_option}" in

        -*=*) ac_optarg=`echo "${ac_option}" | sed 's/[-_a-zA-Z0-9]*=//'`;;
           *) ac_optarg=                                                 ;;
    esac

    case "${ac_option}" in

         -new     | -ne     | -n     | --new   | --ne      | --n                         ) NFLAG=${TRUE};;
         -help    | -hel    | -he    |  -h     | --help    | --hel    | --he    | --h    ) usage        ;;
         -nolog   | -nolo   | -nol   | --nolog | --nolo    | --nol                       ) LFLAG=${TRUE};;
         -verbose | -verbos | -verbo |  -verb  | --verbose | --verbos | --verbo | --verb ) VFLAG=${TRUE};;

         -version |  -versio |  -versi |  -vers |  -ver |  -ve |  -v | \
        --version | --versio | --versi | --vers | --ver | --ve | --v     ) version;;

         -noheader |  -noheade |  -nohead |  -nohea |  -nohe |  -noh |  -no |  -n | \
        --noheader | --noheade | --nohead | --nohea | --nohe | --noh | --no | --n     ) HFLAG=${FALSE};;

         -config=* |  -confi=* |  -conf=* |  -con=* |  -co=* |  -c=* | \
        --config=* | --confi=* | --conf=* | --con=* | --co=* | --c=*     ) IFLAG=${TRUE}
                                                                           TMPCFGFILE=${ac_optarg}.${CFGEXT};;

         -config |  -confi |  -conf |  -con |  -co |  -c | \
        --config | --confi | --conf | --con | --co | --c     ) echo
                                                               echo "L'option --config nécessite un argument."
                                                               usage;;

        *) echo
           echo "Paramètre non supporté: ${ac_option}."
           usage;;

    esac

done

#------------------------------------------------------------------------------------------------
#--- Aide si pas de paramètre et test des paramètres obligatoires.
#------------------------------------------------------------------------------------------------

if test $# -eq 0 
then
    usage
fi

#------------------------------------------------------------------
#--- Vérification de la présence du fichier de config
#------------------------------------------------------------------

if test -f ${TMPCFGFILE}
then

    CFGFILE=${TMPCFGFILE}

elif test -f ${SHLDIR}/${TMPCFGFILE}
then

    CFGFILE=${SHLDIR}/${TMPCFGFILE}

elif test -f ${CFGDIR}/${TMPCFGFILE}
then

    CFGFILE=${CFGDIR}/${TMPCFGFILE}

else

    echo
    echo "Le fichier de configuration "${TMPCFGFILE}" n'a pas été trouvé."
    echo    
    exit ${NOK}

fi



#------------------------------------------------------------------------------------------------
#--- chargement de la configuration de ce shell.
#------------------------------------------------------------------------------------------------

. ${CFGFILE}

#------------------------------------------------------------------------------------------------
#--- Vérification des variables du fichier de configuration.
#------------------------------------------------------------------------------------------------

checkAllEnvVariables

. ${HOME}/cmnF3G/Tools/shl/liblock.sh

LOCK=${HOME}/cmnF3G/Tools/shl/PrepareFiles.sh.lock

lock

 # ----- initialisation des logs ARE -----
 areConf=${HOME}/DATA/ARE/CONFIG/PrepareFiles.are.conf
 Program=PrepareFiles
 autoload init_logging
 init_logging  "F3G" ${areConf} $Program
 ret=$?
 if [[ $ret -ne 0 ]] 
 then
     print_msg "Echec de l'appel de la fonction init_logging"
     unlock
     exit 1
 fi
 #-----------ARE--------------------------- 

log_msg "PrepareFiles" "2000" "Début de PrepareFiles"


#------------------------------------------------------------------------------------------------
#---Traitement
#------------------------------------------------------------------------------------------------

DATE=`date +"%Y/%m/%d %H:%M:%S"`

log  "Lancement du traitement le" ${DATE}
cout "Lancement du traitement le" ${DATE} "\b."

rm -f ${WORKDIR}/*.CheckSum 2>/dev/null

LISTFILE=`getListFile`

if test ! -z "${LISTFILE}"
then

      control_checksum

else
  
      log  "Aucun fichier trouvé dans" ${WORKDIR} 
      cout "Aucun fichier trouvé dans" ${WORKDIR} "."
      log_msg "PrepareFiles" "2000" "Fin de PrepareFiles"
      unlock
      exit ${OK}

fi
   
#------------------------------------------------------------------------------------------------
#--- Fin.
#------------------------------------------------------------------------------------------------

Date=`date +"%Y/%m/%d %H:%M:%S"`
  
log  "Fin du traitement normal le" ${DATE}
cout "Fin du traitement normal le" ${DATE} "\b."

log_msg "PrepareFiles" "2000" "Fin de PrepareFiles"

if test ${VFLAG} -eq ${TRUE}
then

    echo

fi

unlock

exit ${OK}




