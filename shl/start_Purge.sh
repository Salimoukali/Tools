#!/bin/ksh
#--- Marking Strings --------------------------------------
#--- @(#)F3GFAR-S: $Workfile:   start_Purge.sh  $ $Revision: 67 $
#----------------------------------------------------------
#--- @(#)F3GFAR-E: start_Purge.sh VersionLivraison = 2.1.12.0
#----------------------------------------------------------

#########################################################################################
#
#  Script:		start_Purge.sh
#  %version:		1.2 %
#  Description:		
#  %created_by:		f3gfar %
#  %date_created:	Thu Nov  2 15:08:31 2000 %
#########################################################################################
#  Modification :
#                20050831 FPE - Ajout de la gestion du WILDCARD de répertoire et du delete de répertoire
#
#########################################################################################

clear
usage()
{
    echo "\n\n\n############################################################################\n##"
    echo "## Usage :\n##"
    echo "## Ce script est lance imperativement avec deux parametres : \n##"
    echo "##\t   start_Purge.sh -config=<FileConfig.cfg> <NomFichier>\n##"
    echo "## FileConfig.cfg : chemin et nom du fichier de configuration\n##"
    echo "## NomFichier     : nom du fichier d'entrée a definir par l'exploitant\n##"
    echo "##################################################################################\n"
    exit $1
}

function testConfigFile
{
  if [ ! -f $INIFILE ]
  then
    echo ""
    echo " Le fichier de configuration donne en parametre : <$INIFILE> est inexistant ou syntaxe erronee!!!"
    echo ""
    usage 1
  fi
}

#Initialisation
NbreFicPurge=0
NbreFicPurgerep=0
NbreTotFic=0
NbreFicRestant=0
typeset -i NbrerepSup=0 
typeset -i RepaSup=0


areConf=${HOME}/DATA/ARE/CONFIG/start_Purge.are.conf

autoload init_logging

init_logging  "F3G" $areConf $Program
ret=$?
if [[ $ret -ne 0 ]] 
then
  print_msg "Echec de l'appel de la fonction init_logging" 
  exit 1
fi
#-----------ARE--------------------------- 



#Verification de la syntaxe
[[ "X$1" = "X-h" ]] && usage 0
if [ $# != 2 ] 
then
  usage 1
else
  INIFILE=`echo "$1" | sed 's/-config=//' 2> /dev/null`
  testConfigFile
  . ${INIFILE}
  log_msg "start_Purge" "2000" "Debut de start_Purge"
  FicEntree=${REP_CFG}/$2

  echo "\n\n\n##############################################################\n##"
  echo "## \tTraitement du fichier <$1> en cours \n##"
  echo "## \t\tVeuillez patientez ...\n##"
  echo "##############################################################\n"
fi


################################################
#-- Test de l'initialisation de la variable REPLOG
################################################
if [ "a${REPLOG}a" = "aa" ]
then
  echo "\n\n\tLa variable REPLOG n'est pas initalisée. Vérifiez le fichier de configuration ${INIFILE} \n\n"
  log_msg "start_Purge" "1" "La variable REPLOG n'est pas initalisée"
  log_msg "start_Purge" "2000" "Fin de start_Purge"
  exit -1
fi

################################################
#-- Test existence du repertoire de log
################################################
if test ! -d "$REPLOG"  
then
  echo "\n\n\tLe repertoire de log <$REPLOG> est inexistant\n\n"
  log_msg "start_Purge" "1" "Le repertoire de log est inexistant"
  log_msg "start_Purge" "2000" "Fin de start_Purge"
  exit -1
fi

################################################
#-- Test existence du repertoire du Compte Rendu
################################################
if test ! -d "$RepCompteRendu"
then
  echo "\n\n\tLe repertoire de Compte Rendu <$RepCompteRendu> est inexistant\n\n"
  log_msg "start_Purge" "1" "Le repertoire de Compte Rendu est inexistant"
  log_msg "start_Purge" "2000" "Fin de start_Purge"
  exit -1
fi

#Chemin du fichier de sortie

FicCompteRendu=$RepCompteRendu/PurgeReport.`date +%d%m%Y%H%M`

################################################
#Verification de existence du fichier donne en parametres
################################################
if test ! -f "$FicEntree"
then
  echo "\n\n##############################################################################\n##"
  echo "##\t Le fichier d'entree donne en parametre : <$2> est inexistant !!!!!"
  echo "##\n##############################################################################\n\n"
  log_msg "start_Purge" "2000" "Fin de start_Purge"
  exit -1
else

  echo "\t\t...Traitement en cours....\n"

#--Ecriture dans le Compte Rendu
  echo "\n\n=================================================================================================" > $REPLOG/CompteRenduTemp
  echo "====   Compte rendu pour chaque ligne du fichier d entree : $2     =======" >> $REPLOG/CompteRenduTemp
  echo "=================================================================================================\n" >> $REPLOG/CompteRenduTemp  

  echo "\n\n=================================================================================================" > $REPLOG/CompteRenduTempFin
  echo "=================================================================================================" > $REPLOG/CompteRenduTempErr

########################################################
#########   LECTURE DU FICHIER ENTREE       ############
########################################################
 
  # on supprime les ligne de commentaire et les espaces et lignes vides
  awk '! (/^ *#/ || /^$/) { print $0 }' $FicEntree | sed -e '/^[[:space:]]*$/d' -e 's/ //g' > $REPLOG/tempFileIN
  
  testFileOK=`awk -F";" '{print NF}' $REPLOG/tempFileIN | grep -v "4" | wc -l | sed -e 's/ //g'`
  if [[ "X${testFileOK}" != "X0" ]]
  then
    echo "Erreur : le fichier contient $testFileOK ligne(s) non valide(s)" | tee -a  $REPLOG/CompteRenduTempErr
    rm -f $REPLOG/tempFileIN
    log_msg "start_Purge" "1" "Erreur : le fichier contient $testFileOK ligne(s) non valide(s)"
    log_msg "start_Purge" "2000" "Fin de start_Purge"
    exit 1
  fi
  
  testFileOK=`awk -F";" '{print ";"$4";"}' $REPLOG/tempFileIN | awk '$1!=";;" {print $1}' | wc -l | sed -e 's/ //g'`
  if [[ "X${testFileOK}" != "X0" ]]
  then
    echo "Erreur : le fichier contient $testFileOK ligne(s) avec un quatrieme champ : format de fichier non valide" | tee -a   $REPLOG/CompteRenduTempErr
    rm -f $REPLOG/tempFileIN
    log_msg "start_Purge" "1" "Erreur : le fichier contient $testFileOK ligne(s) avec un quatrieme champ : format de fichier non valide"
    log_msg "start_Purge" "2000" "Fin de start_Purge"
    exit 1
  fi
  
  #Le fichier d'entrée a un format correct
  cat $REPLOG/tempFileIN | while read LignEntree
  do
    TypeFichier=`echo $LignEntree | awk -F\; '{print $1}'`
    echo "type fichier : $TypeFichier ;"
    CheminFichier=`echo $LignEntree | awk -F\; '{print $2}'`
    echo "Chemin du Fichier/Repertoire : $CheminFichier ;"
    DelaiPurge=`echo $LignEntree | awk -F\; '{print $3}'`
    echo "Delai Purge : $DelaiPurge ;"
    echo "##########################################"

    #Test si le delai et "F" ou "R" ou "D"
    if [ ${TypeFichier} != "F" -a ${TypeFichier} != "R"  -a ${TypeFichier} != "D" ]
    then
      echo "Dans $CheminFichier le Type Fichier <$TypeFichier> n'est pas correct" >> $REPLOG/CompteRenduTempErr
    fi

    #test si Delai est un entier

    TestEntier=`expr $DelaiPurge : '[0-9]*' `
    if [ $TestEntier -lt 1 ]
    then
      echo "Dans $CheminFichier le Delai <$DelaiPurge> n'est pas un entier " >> $REPLOG/CompteRenduTempErr
    else

##########################################
######   TEST SUR TYPEFICHIER      #######
##########################################
    if [[ $TypeFichier != "F" ]] && [[ $TypeFichier != "R" ]] && [[ $TypeFichier != "D" ]]
    then
      echo "Erreur de format du fichier <$FicEntree>, le premier champ doit etre F ou R ou D" >> $REPLOG/CompteRenduTempErr
      log_msg "start_Purge" "1" "Erreur de format du fichier <$FicEntree>, le premier champ doit etre F ou R ou D"
      log_msg "start_Purge" "2000" "Fin de start_Purge"
      exit 1
    fi

##########################################
######   CAS D UN FICHIER    #############
##########################################

    if [ $TypeFichier = "F" ]
    then

      sPath=`dirname "$CheminFichier"`
      sPath=`eval print ${sPath}`
      sPath=${sPath}"/"
      sFilename=`basename "$CheminFichier"`
       
#------------------------------------------------------#
#---On test si le repertoire donnee en entree existe---#
#------------------------------------------------------#

      if [ -d ${sPath} ]
      then
#-----------------------------------------------#
#---On compte le nbre de fichiers a supprimer---#
#-----------------------------------------------#
        NbreFicDansRep=0
        NbreFicRest=0
        NbreFicDansRep=`find "${sPath}" -type f -name "${sFilename}" | wc -l`
        NbreFicPurgerep=`find "${sPath}" -type f -name "${sFilename}" -mtime +$DelaiPurge | wc -l`
        
        NbreFicRest=`expr $NbreFicDansRep - $NbreFicPurgerep`
        echo "Dans $CheminFichier \t\t $NbreFicPurgerep Fichiers supprimes \t\t $NbreFicRest Fichiers restants" >> $REPLOG/CompteRenduTemp

#------------------------------#
#---On supprime les fichiers---#
#------------------------------#

       find "${sPath}" -type f -name "${sFilename}" -mtime +$DelaiPurge -exec rm -f {} \;

#-------------------------------------------------#
#---On incremente le nbre de fichiers supprimes---#
#-------------------------------------------------#

        NbreFicPurge=`expr $NbreFicPurge + $NbreFicPurgerep`
        NbreTotFic=`expr $NbreTotFic + $NbreFicDansRep`
      else
        log_msg "start_Purge" "1" "Le repertoire ${sPath} est inexistant"
        echo "Le dossier ${sPath} est inexistant" >> $REPLOG/CompteRenduTempFin
      fi
    fi

##########################################
#########  CAS D UN REPERTOIRE  ##########
##########################################

    if [ $TypeFichier = "R" ] || [ $TypeFichier = "D" ]
    then
     sFullPath=`eval echo ${CheminFichier}`
     
#------------------------------------------------------#
#---Cas WildCard --------------------------------------#
#------------------------------------------------------#
     for sPath in $sFullPath
     do
RepaSup=`find "${sPath}/" -type d -mtime +$DelaiPurge 2>/dev/null | wc -l `
         

#------------------------------------------------------#
#---On test si le repertoire donnee en entree existe---#
#------------------------------------------------------#
      if [ -d ${sPath} ]
      then

#-----------------------------------------------#
#---On compte le nbre de fichiers a supprimer---#
#-----------------------------------------------#
        NbreFicDansRep=0
        NbreFicDansRep=`find "${sPath}/" -type f | wc -l`
        NbreFicPurgerep=`find "${sPath}/" -type f -mtime +$DelaiPurge | wc -l`
        NbreFicRest=`expr $NbreFicDansRep - $NbreFicPurgerep`
        echo "Dans $sPath \t\t $NbreFicPurgerep Fichiers supprimes \t\t $NbreFicRest Fichiers restants" >> $REPLOG/CompteRenduTemp

#------------------------------#
#---On supprime les fichiers---#
#------------------------------#

        find "${sPath}/" -type f -mtime +$DelaiPurge -exec rm -f {} \;
        
#-------------------------------------------------#
#---On incremente le nbre de fichiers supprimes---#
#-------------------------------------------------#
        NbreFicPurge=`expr $NbreFicPurge + $NbreFicPurgerep`
        NbreTotFic=`expr $NbreTotFic + $NbreFicDansRep`

#-------------------------------------------------#
#---On supprime le répertoire si cas D et vide ---#
#-------------------------------------------------#
        NbreFicDansRep=`find "${sPath}/" -type f | wc -l`
        RepEstLien=`find ${sPath} -type l | wc -l`
        if [ $TypeFichier = "D" ] &&  [ 0 -eq $NbreFicDansRep ] && [ 0 -eq $RepEstLien ] && [ 0 -ne $RepaSup ]
        then
          echo "Suppression du répertoire $sPath car vide" >> $REPLOG/CompteRenduTemp
          rmdir $sPath
          NbrerepSup=`expr $NbrerepSup + 1`
        fi


      else
        log_msg "start_Purge" "1" "Le repertoire ${sPath} est inexistant"
        echo "Le repertoire $sPath est inexistant" >> $REPLOG/CompteRenduTempFin
      fi

     done
    fi
  fi
  done
  rm -f $REPLOG/tempFileIN
  NbreFicRestant=`expr $NbreTotFic - $NbreFicPurge`

##############################################################################
####### ECRITURE DANS LE FICHIER COMPTE RENDU : PurgeReport.<date> ###########
##############################################################################

  echo "Le nombre total de fichiers supprimes est : $NbreFicPurge" > ${FicCompteRendu}
  echo "Le nombre total de fichiers restant est : $NbreFicRestant" >> ${FicCompteRendu}
  echo "Le nombre total de repertoires supprimes est : $NbrerepSup" >> ${FicCompteRendu}
  echo "La volumetrie total (en Kilo) associee au compte `cd $HOME ; du -sk 2>/dev/null` " >> ${FicCompteRendu}
  

  cat $REPLOG/CompteRenduTemp >> ${FicCompteRendu}
  cat $REPLOG/CompteRenduTempFin >> ${FicCompteRendu}
  cat $REPLOG/CompteRenduTempErr >> ${FicCompteRendu}
  rm -f $REPLOG/CompteRenduTemp
  rm -f $REPLOG/CompteRenduTempFin
  rm -f $REPLOG/CompteRenduTempErr

  echo "Le nombre total de fichiers supprimes est : $NbreFicPurge\n"
  echo "Le nombre total de fichiers restant est : $NbreFicRestant\n"
  echo "Le nombre total de repertoires supprimes est : $NbrerepSup\n"

  echo "\n\n###################################################################################\n##"
  echo "##\tLe fichier de compte rendu de Start_Purge.sh $1 "  
  echo "##\test sous : ${FicCompteRendu}\n##"
  echo "###################################################################################\n\n"

fi

log_msg "start_Purge" "2000" "Fin de start_Purge"

#exit 0






