#!/usr/bin/ksh
#--- Marking Strings --------------------------------------
#--- @(#)F3GFAR-S: $Workfile:   kill_session.sh  $ $Revision:   1.2  $
#----------------------------------------------------------
#--- @(#)F3GFAR-E: $Workfile:   kill_session.sh  $ VersionLivraison = 2.0.0.0
#----------------------------------------------------------

#------------------------------------------------------------------
#--- Kill_Session.sh  Auteur : D. BENKACI
#------------------------------------------------------------------
usage()
{
 echo ""
 echo " ATTENTION : "
 echo ""
 echo "    Ce script doit etre lancé uniquement par l'administrateur de la base de donnée."
 echo "    Ce script désactive la séssion d'un user  "
 echo ""
 echo " Syntaxe de Lancement :" 
 echo "    $0 <user sysdba> <sysdba password> <base AR3G> <user name>"
 echo ""
 echo "    Avec : "
 echo "     - user sysdba     : Nom de l'administrateur de la base de donnée."
 echo "     - sysdba password : Mot de passe de connexion a la base de donnée."
 echo "     - base AR3G       : Nom de la base."
 echo "     - user name       : Nom du user, pour lequel on va désactiver la séssion."     
 echo ""
 exit $1
}

thedate() 
{ 
 echo `date +"%d/%m/%Y %H:%M:%S"` 
}

# -----------------------------------------------------------------
# --- Script de desactivation d'une session d'un user
# -----------------------------------------------------------------

####################################################################
# Main
####################################################################

PRG=`basename $0 .sh`

# -----------------------------------------------------------------------------
# Verification des parametres de configuration
# -----------------------------------------------------------------------------
if [[ "X$1" = "X-h" ]] 
then 
 usage 0
fi
 
if [[ $# -ne 4 ]] 
then
 echo "Il manque des paramètres."
 usage 1
fi

USERS=${USER}
USERPID=`id -u`
USERLOG="${USERS}_${USERPID}"

FICLOG=$HOME/DATA/LOG/CMN/Tools/kill_session_${USERLOG}.log

###########################################################################
### SECTION DE LANCEMENT DU SCRIPT                                      ###
########################################################################### 
DB_LOGIN=$1
DB_PASSWORD=$2
DB_DATABASE=$3
USERNAME=$4

 # ----- initialisation des logs ARE -----
areConf=${HOME}/DATA/ARE/CONFIG/kill_session.are.conf

autoload init_logging
   
 if ! init_logging  "F3G" ${areConf} $(basename ${0})
   then
         echo "Echec de l'appel de la fonction init_logging" 
         exit 1
fi

log_msg  $(basename ${0}) "2000"  "Début du $(basename ${0})"

# ----- ARE

clear
echo "DESACTIVATION DE LA SESSION DE L'UTILISATEUR $4\n"

ScriptKillSession="../sql/kill_session.sql"
KillUserSession="../sql/KillUserSession.sql"
   
sqlplus -s $DB_LOGIN/$DB_PASSWORD@$DB_DATABASE @$ScriptKillSession $USERNAME $KillUserSession >> $FICLOG << FINSQL
FINSQL

if test $? -ne 0
 then
  echo "\nProbleme avec la commande sqlplus"
  log_msg  $(basename ${0}) "2000"  "Fin du $(basename ${0})"
  exit 1
fi

rm -f ${KillUserSession} > /dev/null  2>&1

 checker=/tmp/${PRG}_${USERLOG}.tmp_check
 grep "ORA-" ${FICLOG} >> ${checker}

 if test -s ${checker} 
 then
  echo "Il y a des erreurs Oracle pendant l'exécution de $0, date=(`thedate`)."
  echo "Elles sont signalées dans le fichier ${FICLOG}.\n"
  echo "Veuillez l'écraser apres consultation\n"
  rm -f ${checker} > /dev/null  2>&1
  log_msg  $(basename ${0}) "2000"  "Fin du $(basename ${0})"
  exit 1
 fi

 echo "Fin normale de $0, date=(`thedate`).\n"
 rm -f ${checker} ${FICLOG}  > /dev/null  2>&1
 
log_msg  $(basename ${0}) "2000"  "Fin du $(basename ${0})"
 
 exit 0



