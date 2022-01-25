#!/usr/bin/ksh
#--- chaine de marquage SCCS --------------------------------------
#---  @(#)%name: sFTPSecMultiple.sh % %version:3 % %date_modified: Mon Feb 16 00:00:00 2004 % ";
#------------------------------------------------------------------

# File Name : FTPsecMultiple.sh
#
# Version :   
#
# Creation Date : 25/08/1999 (S. Meunier)
#
# Description : Script de transfert FTP d'un fichier precise en 
#               parametre avec controle du bon deroulement du transfert
#
#


export FIC_TMP=/tmp/fic.tmp.$$
export FIC_TMP2=/tmp/fic2.tmp.$$
export FIC_TMP3=/tmp/fic3.tmp.$$
set -A FILE_NAME
set -A SHORT_FILE_NAME

export TRANSFERT_FTP="OK"

UMASK=$(umask)
umask 077

AWK_CMDE="awk"
[[ "$(uname)" = "OSF1" ]] && AWK_CMDE="awk"
[[ "$(uname)" = "SunOS" ]] && AWK_CMDE="/usr/xpg4/bin/awk"

if [[ -f /usr/ucb/sum ]]
then
        alias sum='/usr/ucb/sum'
else
        alias sum='/bin/sum -r'
fi

#------------------------------------------------------------------
# Affichage de l'aide
#------------------------------------------------------------------
aide()
{
        affiche_aide="\n Usage : $(basename $0) <Server> <Login> <Passwd> <port ssh> <Attempt_Nb> <ModeFtp>\n
                                \t\t<Sens de transfert> <Option Purge> <Option transfert> <Dest_Path> <File_Name>\n
        avec\n
                \tServer = nom du serveur destination\n
                \tLogin = compte UNIX pour la connexion au serveur\n
                \tPasswd = mot de passe du compte UNIX (inutilise, conserve pour FTPSecMultiple)\n
                \tport ssh = port ssh \n
                \tAttempt_Nb = nombre de tentatives de double transfert FTP\n
                                \t\ta faire avant de conclure a un echec du\n
                                \t\ttransfert FTP\n
                \tModeFtp = mode ascii / binaire (inutilise, conserve pour FTPSecMultiple)
                \tSens de transfert = sens du transfert des fichiers\n
                                \t\tput : envoi\n
                                \t\tget : recuperation\n
                \tOption Purge = purge des fichiers dans le repertoire d'origine en fin de traitement\n
                                \t\tO : purge\n
                                \t\tN : pas de purge\n
                \tOption transfert = active le transfert sans fichier.en_cours et sans cksum\n
                                \t\tNO_SUM : transfert sans fichier.en_cours et sans cksum\n (PUT uniquement)
                                \t\tN : transfert classique\n                		
                \tDest_Path = repertoire ou il faut transferer le fichier\n
                                \t\tsur le serveur (chemin absolu)\n
                \tFile_Name = nom du (des) fichier(s) a transferer avec chemin complet\n
                                \t\tl'argument peut etre une expression reguliere\n
                                \t\tl'argument doit etre encadre de double quotes
                                \t\tpar exemple : \"/usr/users/compte/DATA/*.txt\""
          print $affiche_aide
}

#------------------------------------------------------------------
# Controle des parametres
#------------------------------------------------------------------
control()
{
        SORTIE=0

if [ "X$1" = "X-h" ]
then
        aide
	exit $SORTIE
else

        HOSTNAME=$1
        USER=$2
        PASSWD=$3
        SSH_PORT=$4
        NBESSAIS=$5
        MODEFTP=$6
        SENSTRANSFERT=$7
        OPTIONPURGE=$8
        OPTIONTRANSFERT=$9
        REP_DEST=${10}
        

#..................................................................
#       Recuperation des noms de fichiers
#..................................................................

        shift 10
        FILTRE_FTP="$*"
        SHORT_FILTRE_FTP=`echo "$FILTRE_FTP" | ${AWK_CMDE} -F "/" '{ print $NF }'`
        var=`eval echo $FILTRE_FTP` #------ suite au nouveau format d'entr�e des fichiers � transf�rer,
                                    #------ on �value les diff�rents fichiers en nom* pour ensuite
                                    #------ les traiter un par un


        echo $var | /bin/tr " " "\n" > $FIC_TMP #------ echo "$FILTRE_FTP" | /bin/tr " " "\n" > $FIC_TMP
                                                #------ on adapte le code en cons�quence
               
        integer n=1
        exec<$FIC_TMP
        while read i
        do
                FILE_NAME[n]=`echo "$i"`
                SHORT_FILE_NAME[n]=`echo "${FILE_NAME[n]}" | ${AWK_CMDE} -F "/" '{ print $NF }'`
                CHK_FILE_NAME[n]="${SHORT_FILE_NAME[n]}.CheckSum"
                ((n=n+1))
        done
        REP_ORIGIN=/`echo "${FILE_NAME[1]}" | ${AWK_CMDE} -F "/" '{$NF=""} {print}' | /bin/tr " " "/"`


#..................................................................
#       Controle de la coherence des parametres
#..................................................................

        if [[ -z $HOSTNAME ]]
        then
                SORTIE=1
                exit $SORTIE
        fi

        if [[ -z $USER ]]
        then
                SORTIE=1
                exit $SORTIE
        fi
        if [[ -z $PASSWD ]]
        then
                SORTIE=1
                exit $SORTIE
        fi
        
        # Gestion de la surcharge optionnelle du port SSH
		if [[ -z ${SSH_PORT} ]]
		then
                SORTIE=1
                exit $SORTIE
		fi
		
        if [[ -z $NBESSAIS ]]
        then
                SORTIE=1
                exit $SORTIE
        else
                if [[ $NBESSAIS -le 0 ]]
                then
                    SORTIE=1
                    exit $SORTIE
                fi
        fi
        if [[ -z $MODEFTP ]]
        then
                SORTIE=1
                exit $SORTIE
        fi

        if [[ -z $SENSTRANSFERT ]]
        then
                SORTIE=1
                exit $SORTIE
        else
                if [ $SENSTRANSFERT != "get" ] && [ $SENSTRANSFERT != "put" ]
                then
                    SORTIE=1
                    exit $SORTIE
                fi
        fi

        if [[ -z $OPTIONPURGE ]]
        then
                SORTIE=1
                exit $SORTIE
        else
                if [ $OPTIONPURGE != "O" ] && [ $OPTIONPURGE != "N" ]
                then
                    SORTIE=1
                    exit $SORTIE
                fi
        fi

        if [[ -z $REP_DEST ]]
        then
                SORTIE=1
                exit $SORTIE
        else
                if [[ $SENSTRANSFERT = "get" ]]
                then
                     if [[ ! -d $REP_DEST  ]]
                     then
                        SORTIE=2
                        exit $SORTIE
                     fi
                else
                     if [[ ! -f ${FILE_NAME[1]} ]]
                     then
                        SORTIE=2
			exit $SORTIE
                     fi
                fi
        fi

fi
}

#------------------------------------------------------------------
# Corps du programme
#------------------------------------------------------------------
typeset -i EXIT_VALUE=0
typeset -i iValRetour=0
typeset -i COUNT_FILES=0


#Appel de de la fonction de control des parametres

control "$1" "$2" "$3" "$4" "$5" "$6" "$7" "$8" "$9" "${10}" "${11}"
mkdir /tmp/ftp$$

#..................................................................
# Debut de la boucle de traitement
#..................................................................
integer i=1

export INIT_PWD=$PWD
while [ $i -le $NBESSAIS ]
do

cd $INIT_PWD

#JMLT - Added Timeout for unreachable hostes
integer ping_value=10


#JMLT - 02/2004 - Correction du handling du ping
case `uname` in
 SunOS*)
        if [[ -x /usr/sbin/ping ]]
        then 
            [[ $(/usr/sbin/ping $HOSTNAME $ping_value |grep -i "no answer"|wc -l | $AWK_CMDE '{ print $1; }' ) -ne 0 ]] && export ErreurFTP="Unknown Host (not alive)"
        fi
        ;;          
 OSF1*)
        if [[ -x /usr/sbin/ping ]]
        then 
            [[ $(/usr/sbin/ping -c 1 $HOSTNAME |grep -i " 0% packet loss"|wc -l | $AWK_CMDE '{ print $1; }' ) -eq 0 ]] && export ErreurFTP="Unknown Host (not alive)"
        fi
        ;;          
 *)
        #pas de ping g�r� ici.?
      ;;
esac


if [[ ! -n "$ERREURFTP" ]]
then
###################
#MODE PUT
###################
        if [ "${SENSTRANSFERT}" = "put" ]
        then
sftp -P ${SSH_PORT} -b - ${USER}@${HOSTNAME} <<Fin_FTP >>$FIC_TMP2 2>&1
cd ${REP_DEST}
lcd ${REP_ORIGIN}
lcd /tmp/ftp$$
Fin_FTP

###################
#MODE GET
###################
        else
sftp -P ${SSH_PORT} -b - ${USER}@${HOSTNAME} <<Fin_FTP >> $FIC_TMP2 2>&1
cd ${REP_ORIGIN}
lcd ${REP_DEST}
lcd /tmp/ftp$$
Fin_FTP

        fi
fi #TESTFTP
#..................................................................
# Verification de la connexion FTP
#..................................................................

    if [[ ! -n "$ERREURFTP" ]]
    then
            ERREURCONNEXION=`grep -i "no address associated with name" $FIC_TMP2`
            ERREURLOGIN=`grep -i "Permission denied" $FIC_TMP2`
            ERREURFILE=`grep -i "No such file or directory" $FIC_TMP2`
        else
        EXIT_VALUE=4
        fi

    if [ -n "$ERREURCONNEXION" ]
    then
            ERREURFTP="Unknown Host"
            EXIT_VALUE=4
            #exit 4
    else
            if [ -n "$ERREURLOGIN" ]
            then
                  ERREURFTP=$ERREURLOGIN
                  EXIT_VALUE=3
                  #exit 3
            else
                  if [ -n "$ERREURFILE" ]
                  then
                       ERREURFTP="${REP_ORIGIN}/${ERREURFILE}"
                       EXIT_VALUE=2
                       #exit 2
                  fi
            fi
    fi

    if [ -n "$ERREURFTP" ]
    then
          if [ $EXIT_VALUE -eq 3 ] || [ $EXIT_VALUE -eq 4 ]
          then
                 # echo "Probleme de connexion sur ${HOSTNAME} : ${ERREURFTP}"
                 \rm -f $FIC_TMP >/dev/null 2>&1
                 \rm -f ${SHORT_FILE_NAME[*]}.CheckSum >/dev/null 2>&1
          else
                 if [ $EXIT_VALUE -eq 2 ]
                 then
                       # echo "Noms de fichiers ou de dossiers specifies incorrects : ${ERREURFTP}"
                       \rm -f $FIC_TMP >/dev/null 2>&1
                       \rm -f ${SHORT_FILE_NAME[*]}.CheckSum >/dev/null 2>&1
                 fi
          fi
    else

###########################################################################################
####################################### MODE "PUT" ########################################
###########################################################################################
#On transfert fichier par fichier en passant par un nom temporaire pour eviter 
#que les fichiers ne soient consommes avant qu ils soient integralement copies
if [ "${SENSTRANSFERT}" = "put" ]
then
integer n=0
for FICHIER in ${SHORT_FILE_NAME[*]} 
do
    n=n+1
    if [[ "${OPTIONTRANSFERT}" = "NO_SUM" ]]
    then
		#echo " MODE NO_SUM : ${REP_ORIGIN} -> ${REP_DEST} , filename = ${SHORT_FILE_NAME[n]}"
sftp -P ${SSH_PORT} ${USER}@${HOSTNAME} <<Fin_FTP >> $FIC_TMP2 2>&1
cd ${REP_DEST}
lcd ${REP_ORIGIN}
rm ${SHORT_FILE_NAME[n]}
put ${SHORT_FILE_NAME[n]} ${SHORT_FILE_NAME[n]}
Fin_FTP
	else
    	#echo " MODE with_SUM : ${REP_ORIGIN} -> ${REP_DEST} , filename = ${SHORT_FILE_NAME[n]}"
sftp -P ${SSH_PORT} ${USER}@${HOSTNAME} <<Fin_FTP >> $FIC_TMP2 2>&1
cd ${REP_DEST}
lcd ${REP_ORIGIN}
rm ${SHORT_FILE_NAME[n]} ${SHORT_FILE_NAME[n]}.en_cours
put ${SHORT_FILE_NAME[n]} ${SHORT_FILE_NAME[n]}.en_cours
rename ${SHORT_FILE_NAME[n]}.en_cours ${SHORT_FILE_NAME[n]}
lcd /tmp/ftp$$
get ${SHORT_FILE_NAME[n]}
Fin_FTP
	fi	
done



###########################################################################################
####################################### MODE "GET" ########################################
###########################################################################################
        else

# -----------------------------------------------------
#Transfert des fichiers demand�s.
# -----------------------------------------------------
sftp -P ${SSH_PORT} ${USER}@${HOSTNAME} <<Fin_FTP >> $FIC_TMP2 2>&1
cd ${REP_ORIGIN}
lcd ${REP_DEST}
get ${SHORT_FILTRE_FTP}
Fin_FTP

# ------------------------------------------------------------------------
#Transfert des fichiers checksum des fichiers demand�s.                  -
#Nota JMLT: D�sol� de la double connection, mais                         -
#       le changement de fichier de log � la vol�e n'est pas possible    -
# ------------------------------------------------------------------------
sftp -P ${SSH_PORT} ${USER}@${HOSTNAME}<<Fin_FTP  >> $FIC_TMP3 2>&1
lcd /tmp/ftp$$
cd ${REP_ORIGIN}
get ${CHK_FILE_NAME[*]} 
Fin_FTP
# ------------------------------------------------------------------------
#JMLT MODIFICATION -> si les fichiers ramen�s forment une ligne trop longue, 
# on les ram�ne 1 par 1 _ET PIS C'EST TOUT_ !!!
# ------------------------------------------------------------------------
if  [[ $(cat $FIC_TMP2 $FIC_TMP3 |grep -i "line too long"|wc -l | $AWK_CMDE '{ print $1; }' ) -ne 0 ]]
then 
integer n=0

# ------------------------------------------------------------------------
#On vide les fichiers temporaires de leurs indications.
>|$FIC_TMP2
>|$FIC_TMP3
# ------------------------------------------------------------------------

#Allez, c'est parti pour le One 2 one :)
for FICHIER in ${SHORT_FILE_NAME[*]} 
do
    n=n+1
# -----------------------------------------------------
#Transfert des fichiers demand�s.
# -----------------------------------------------------
sftp -P ${SSH_PORT} ${USER}@${HOSTNAME}<<Fin_FTP >> $FIC_TMP2 2>&1
cd ${REP_ORIGIN}
lcd ${REP_DEST}
get ${SHORT_FILE_NAME[n]}
Fin_FTP

# ------------------------------------------------------------------------
#Transfert des fichiers checksum des fichiers demand�s.                  -
#Nota JMLT: D�sol� de la double connection, mais                         -
#       le changement de fichier de log � la vol�e n'est pas possible    -
# ------------------------------------------------------------------------
sftp -P ${SSH_PORT} ${USER}@${HOSTNAME} <<Fin_FTP >> $FIC_TMP3 2>&1
lcd /tmp/ftp$$
get ${CHK_FILE_NAME[n]}
Fin_FTP

done

fi

#.........................................
# Compter le nombre de fichiers rapatries
#.........................................
#JMLT - 02/2004 - Modifications pour le mode GET -> On ne transf�re qu'une seule fois !
#On doit donc se baser sur le fichier de log (d'o� la double connection)
#En effet des fichiers pr�sents peuvent correspondre sans avoir �t� transf�r�s cette fois ci.

GETTED_FILES=$(cat $FIC_TMP2 |grep -vi "No such file or directory"|grep "^Fetching .*$"| awk '{ print $NF }')
COUNT_FILES=$(cat $FIC_TMP2 |grep -vi "No such file or directory" |grep "^Fetching .*$"| wc -l)

                cd /tmp/ftp$$
    
                if [ $COUNT_FILES -ne 0 ]
                then
                    integer n=1
                    for GETTED_FILENAME in $GETTED_FILES
                    do
                        SHORT_FILE_NAME[n]="${GETTED_FILENAME}"
                        CHECK_FILE_NAME[n]="${GETTED_FILENAME}.CheckSum"
                        ((n=n+1))
                    done
                # Il n'y a pas de fichier transfer�
                else    
                   EXIT_VALUE=2
                   cd /tmp/ftp$$
                   \rm -f *.CheckSum > /dev/null
                fi

        fi #fin du ELSE du if [ "${SENSTRANSFERT}" = "put" ]
        
               
###########################################################################################
#################################### MODE "COMMUN" ########################################
###########################################################################################
if [ $EXIT_VALUE -eq 0 ]
then

#..................................................................
# Validation du transfert
#..................................................................
                n=1
                while [ "${SHORT_FILE_NAME[n]}" != "" ]
                do
###########################################################################################
####################################### MODE "PUT" ########################################
###########################################################################################
                        if [ "${SENSTRANSFERT}" = "put" ] 
                        then
                        	if [[ "${OPTIONTRANSFERT}" != "NO_SUM" ]]
                        	then
	                            # Creer un fichier .CheckSum pour Tous les Fichiers
	                            CHECKSUM_FICHIER=${REP_ORIGIN}/${SHORT_FILE_NAME[n]}.CheckSum.$$
	                            [[ -f ${REP_ORIGIN}/${SHORT_FILE_NAME[n]} ]] && sum ${REP_ORIGIN}/${SHORT_FILE_NAME[n]} | ${AWK_CMDE} '{ print $1 }' > ${CHECKSUM_FICHIER}
	
	                            # Creer un fichier .CheckSum pour Tous les Fichiers dans le repertoire tampon
	                            CHECKSUM_RECUP=/tmp/ftp$$/${SHORT_FILE_NAME[n]}.CheckSum.$$
	
	                            sum /tmp/ftp$$/${SHORT_FILE_NAME[n]} | ${AWK_CMDE} '{ print $1 }' > ${CHECKSUM_RECUP}
	
	                            if diff ${CHECKSUM_FICHIER} ${CHECKSUM_RECUP} 1>/dev/null
	                            then
	                                   TRANSFERT_FTP=OK
	                                   \rm -f /tmp/*$$* >/dev/null 2>&1
	                                   \rm -f ${CHECKSUM_RECUP} > /dev/null 2>&1
	                                   \rm -f ${CHECKSUM_FICHIER} > /dev/null 2>&1
	                                   EXIT_VALUE=0
	                            else
	                                   TRANSFERT_FTP=KO
	                                   EXIT_VALUE=5
	                            fi
                            fi
###########################################################################################
####################################### MODE "GET" ########################################
###########################################################################################
                        else
                            iValRetour=0
                            if [[ -f ${REP_DEST}/${SHORT_FILE_NAME[n]} ]] 
                            then 
#------------------------------------------------------------------------------------------
# GENERER les contenus des fichiers CheckSum->  METHODE 1
                                if [[ -f /usr/ucb/sum ]];then
                                    /usr/ucb/sum ${REP_DEST}/${SHORT_FILE_NAME[n]} | ${AWK_CMDE} '{ print $1 }' > /tmp/ftp$$/${SHORT_FILE_NAME[n]}.CheckSum.method1
                                    iValRetour=$?
                                else
                                    touch /tmp/ftp$$/${SHORT_FILE_NAME[n]}.CheckSum.method1
                                    iValRetour=0
                                fi
                                if [ $iValRetour -eq 0 ];then 
#------------------------------------------------------------------------------------------
# GENERER les contenus des fichiers CheckSum->  METHODE 2
                                    if [[ -f /bin/sum ]]; then
                                        /bin/sum -r  ${REP_DEST}/${SHORT_FILE_NAME[n]} | ${AWK_CMDE} '{ print $1 }' > /tmp/ftp$$/${SHORT_FILE_NAME[n]}.CheckSum.method2
                                        iValRetour=$?
                                    else
                                        touch /tmp/ftp$$/${SHORT_FILE_NAME[n]}.CheckSum.method2
                                        iValRetour=0
                                    fi
                                    if [ $iValRetour -eq 0 ];then 
#------------------------------------------------------------------------------------------
# GENERER les contenus des fichiers CheckSum->  METHODE 3 -> c'est l'inverse sur DEC et SUN quand on met pas d'option !
                                        if [[ -f /usr/bin/sum ]]; then
                                                /usr/bin/sum ${REP_DEST}/${SHORT_FILE_NAME[n]} | ${AWK_CMDE} '{ print $1 }' > /tmp/ftp$$/${SHORT_FILE_NAME[n]}.CheckSum.method3
                                                iValRetour=$?
                                            else
                                                touch /tmp/ftp$$/${SHORT_FILE_NAME[n]}.CheckSum.method3
                                                iValRetour=0
                                            fi
                                            if [ $iValRetour -eq 0 ];then 
#------------------------------------------------------------------------------------------
# GENERER les contenus des fichiers CheckSum->  METHODE 4 -> on cr�e les r�sultats inverse
                                                case `uname` in
                                                 SunOS*)
                                                        /usr/bin/sum -r ${REP_DEST}/${SHORT_FILE_NAME[n]} | ${AWK_CMDE} '{ print $1 }' > /tmp/ftp$$/${SHORT_FILE_NAME[n]}.CheckSum.method4
                                                        iValRetour=$?
                                                        ;;          
                                                 OSF1*)
                                                        /usr/bin/sum -o ${REP_DEST}/${SHORT_FILE_NAME[n]} | ${AWK_CMDE} '{ print $1 }' > /tmp/ftp$$/${SHORT_FILE_NAME[n]}.CheckSum.method4
                                                        iValRetour=$?
                                                        ;;          
                                                 *)
                                                 #pour les autres OSes
                                                        /usr/bin/sum ${REP_DEST}/${SHORT_FILE_NAME[n]} | ${AWK_CMDE} '{ print $1 }' > /tmp/ftp$$/${SHORT_FILE_NAME[n]}.CheckSum.method4
                                                        ;;
                                               esac
                                            fi
                                        fi
                                    fi
                                fi
#------------------------------------------------------------------------------------------
#Quelques Tests avant comparaison.
                                if [ ! -f /tmp/ftp$$/${SHORT_FILE_NAME[n]}.CheckSum ] && [ ${iValRetour} -eq 0 ]; then
                                   ls -lrt ${REP_DEST}/${CHECK_FILE_NAME[n]} >> ${FIC_TMP} 2>&1
                                   \rm -f ${REP_DEST}/${SHORT_FILE_NAME[n]}
                                   CHECK_FILE_NAME[n]=""
                                   ERREURFILE=`grep -i "No such file or directory" $FIC_TMP`
                                   if [ -n "$ERREURFILE" ]
                                   then
                                       EXIT_VALUE=6
                                   fi
                                   EXIT_VALUE=6
				   TRANSFERT_FTP=KO
#------------------------------------------------------------------------------------------
                                elif [ ${iValRetour} -eq 0 ]; then
# Formatter le fichier CheckSum recupere de maniere a ne retenir que le premier argument de controle
                                   \mv -f /tmp/ftp$$/${SHORT_FILE_NAME[n]}.CheckSum /tmp/ftp$$/${SHORT_FILE_NAME[n]}.CheckSum.move.$$
                                   head -n1 /tmp/ftp$$/${SHORT_FILE_NAME[n]}.CheckSum.move.$$ | $AWK_CMDE '{print $1}' > /tmp/ftp$$/${SHORT_FILE_NAME[n]}.CheckSum.COMPAT.$$
                                   
#------------------------------------------------------------------------------------------
# Comparer les contenus des fichiers CheckSum
# METHODE 1

                                   if diff /tmp/ftp$$/${SHORT_FILE_NAME[n]}.CheckSum.method1 /tmp/ftp$$/${SHORT_FILE_NAME[n]}.CheckSum.COMPAT.$$ 1>/dev/null 2>$FIC_TMP
                                   then
                                       if [[ $TRANSFERT_FTP != "KO" ]]; then
                                           TRANSFERT_FTP=OK
                                       fi
                                   else
#------------------------------------------------------------------------------------------
# Comparer les contenus des fichiers CheckSum
# METHODE 2
                                       if diff /tmp/ftp$$/${SHORT_FILE_NAME[n]}.CheckSum.method2 /tmp/ftp$$/${SHORT_FILE_NAME[n]}.CheckSum.COMPAT.$$ 1>/dev/null 2>$FIC_TMP
                                       then
                                           if [[ $TRANSFERT_FTP != "KO" ]]; then
                                               TRANSFERT_FTP=OK
                                           fi
                                       else
#------------------------------------------------------------------------------------------
# Comparer les contenus des fichiers CheckSum
# METHODE 3
                                           if diff /tmp/ftp$$/${SHORT_FILE_NAME[n]}.CheckSum.method3 /tmp/ftp$$/${SHORT_FILE_NAME[n]}.CheckSum.COMPAT.$$ 1>/dev/null 2>$FIC_TMP
                                           then
                                               if [[ $TRANSFERT_FTP != "KO" ]]; then
                                                   TRANSFERT_FTP=OK
                                               fi
                                           else                                   
#------------------------------------------------------------------------------------------
# Comparer les contenus des fichiers CheckSum
# METHODE 4
                                               if diff /tmp/ftp$$/${SHORT_FILE_NAME[n]}.CheckSum.method4 /tmp/ftp$$/${SHORT_FILE_NAME[n]}.CheckSum.COMPAT.$$ 1>/dev/null 2>$FIC_TMP
                                               then
                                                   if [[ $TRANSFERT_FTP != "KO" ]]; then
                                                       TRANSFERT_FTP=OK
                                                   fi
                                               else                                   
#------------------------------------------------------------------------------------------
# Aucune m�thode n'a ete valable pour trouver un checksum correct-> FAUTE
                                                   EXIT_VALUE=5
                                                   TRANSFERT_FTP=KO
                                                   \mv -f /tmp/ftp$$/${SHORT_FILE_NAME[n]}.CheckSum.move.$$ ${REP_DEST}/${SHORT_FILE_NAME[n]}.CheckSum
                                                   \rm -f ${REP_DEST}/${SHORT_FILE_NAME[n]}
                                                   \rm -f ${REP_DEST}/${CHECK_FILE_NAME[n]}
                                                   CHECK_FILE_NAME[n]=""
                                               fi
                                           fi
                                       fi
                                  fi
                             fi
#------------------------------------------------------------------------------------------
                        fi

                        ((n=n+1))
                done

#######################                         #########
# CAS DU TRANSFERT OK # -> On teste l'option de # PURGE #
#######################                         #########
                if [ $TRANSFERT_FTP = "OK" ]
                then
                        if [ $OPTIONPURGE = "O" ] 
                        then
###########################################################################################
####################################### MODE "PUT" ########################################
###########################################################################################
                                if [ "${SENSTRANSFERT}" = "put" ]
                                then
                                        \rm -f ${FILE_NAME[*]} >/dev/null 2>&1
                                        \rm -f ${REP_ORIGIN}/${CHECK_FILE_NAME[*]} >/dev/null 2>&1
###########################################################################################
####################################### MODE "GET" ########################################
###########################################################################################
                                else
				        n=1
                                        while [ "${SHORT_FILE_NAME[n]}" != "" ]
                                        do
                                           if [ "${CHECK_FILE_NAME[n]}" != "" ]; then
sftp -P ${SSH_PORT} ${USER}@${HOSTNAME} <<Fin_FTP >>$FIC_TMP2  2>&1
cd ${REP_ORIGIN}
rm ${SHORT_FILE_NAME[n]}
rm ${CHECK_FILE_NAME[n]}
Fin_FTP
                                           fi
                                           ((n=n+1))
                                        done
                                fi 
                        fi
                        break 1
                fi
        fi
fi
###########################################################################################
#################################### MODE "COMMUN" ########################################
###########################################################################################

        i=i+1
        
#JMLT - On stoppe par "d�sactivation" du while en cas de code erreur ==0
        if [ $EXIT_VALUE -eq 0 ]
        then
            i=$NBESSAIS+1
        fi
done

###########################################################################################
######################################## "FINAL" ##########################################
###########################################################################################
#JMLT - Finalisation nettoyage On �tait dans le repertoire /tmp/ftp<PID> donc 
#sa suppression �tait impossible et des r�sidus restaient (en l occurence, le r�pertoire dans /tmp)

cd $INIT_PWD


/bin/rm -Rf /tmp/ftp$$ >/dev/null 2>&1
/bin/rmdir /tmp/ftp$$ >/dev/null 2>&1

/bin/rm -f /tmp/fic*.tmp.$$ >/dev/null 2>&1
/bin/rm -Rf /tmp/*$$* >/dev/null 2>&1

umask ${UMASK} >/dev/null 2>&1

exit  $EXIT_VALUE    ######5
