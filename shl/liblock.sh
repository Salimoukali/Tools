#--- Marking Strings ------------------------------------------------
#--- @(#)F3GFAR-S: $Workfile:   liblock.sh  $ $Revision: 65 $
#--------------------------------------------------------------------
#--- @(#)F3GFAR-E: $Workfile:   liblock.sh  $ VersionLivraison = 2.1.11.1
#--------------------------------------------------------------------


# Historique:
# ===========
# J.Delfosse - 1.0 - 07/07/2004 - Cr�ation, bas�e sur l'exclusivit� du "ln -s"
# J.Delfosse - 1.1 - 20/07/2004 - Ajout du PGID dans check_lock()
#
#


# Utilisation:
# ============
# Exemple d'utilisation pour $HOME/CAUX/batch/shl/batch.sh qui ne veut pas �tre lanc� deux fois:
#
#  |#!/usr/bin/ksh
#  |
#  |. $HOME/cmnF3G/Tools/shl/liblock.sh
#  |
#  |LOCK=$HOME/CAUX/batch/shl/batch.sh.lock
#  |
#  |lock
#  |
#  |#Ex�cution du script batch.sh
#  | 
#  |unlock
#  |exit 0
#


# Comportement:
# =============
#
# * Verrouillage au niveau du shell (ind�pendamment de ce qui est lanc� par le shell)
# * L'exclusivit� du lancement se fait sur le nom du verrou LOCK
#   d�cid� par le shell appellant (conseil: mettre le r�pertoire complet de fa�on �
#   ce que le verrou soit cr�� dans le m�me r�pertoire que le shell appellant)
# * La fin du shell entra�ne automatiquement l'appel de unlock (y compris les exit)
# * unlock attends par d�faut tous les sous-process lanc� par le shell appellant
#   (mettre LOCK_WAIT_UNLOCK=0 apr�s le source de lock.sh pour d�sactiver cette attente; d�conseill�)
# * Le shell appellant ne doit pas utiliser la fonction trap sur INT TERM et EXIT ou alors
#   il doit red�finir le handler (trapper les signaux, et appeller unlock dans la nouvelle fonction)
# * En cas de crash (kill -9), le relancement du shell appellant d�truit normalement le pr�c�dent
#   verrou devenu obsol�te (Note: le "core dump" d'un batch lanc� par le shell appellant ne d�truit pas
#   le shell appellant).Si on a tu� le shell p�re (qui a pos� le verrou) mais pas ses fils, 
#    alors si ses fils continue � tourner (ils ont le m�me pgid) alors le script ne red�marre pas
# * Pour avoir les traces, mettre LOCK_VERBOSE=2 apr�s le source de lock.sh
# * Un �chec de lock conduit le shell appellant � un exit 1
# 
#

# Note sur le CTRL-Z :
# ===================
#
# Quand on lance un shell � la main dans un terminal et sans le & (background), puis que l'on fait 
# CTRL-Z, le shell est bloqu� par le korn-shell.
# KSH envoie le signal TSTP (terminal stop) vers le process shell.
#
# La situation suivante peut arriver, le fils du shell (un �x�cutable) a termin�, il appara�t
# alors <defunct> dans la commande ps. En effet, le shell p�re �tant bloqu�, le syst�me attends
# que le shell p�re soit d�bloqu� pour pouvoir signaler au p�re la mort du fils.
#
# Si on relance le shell apr�s un CTRL-Z, le shell ne d�marrera pas car le verrou est toujours 
# actif. Ceci est tout � fait normal car le shell est suspendu, il n'a pas termin�.
#
# Apr�s un CTRL-Z, il faut toujours relancer le shell suspendu car il bloqu� (stopped jobs) 
# Il faut utiliser soit la commande fg (pour le remettre en foreground), soit la commande bg 
# (pour le mettre en background) afin qu'il se termine.
#
# Le signal CTRL-Z n'est pas trapp� par la librairie car CTRL-Z peut-�tre utile. Cependant 
# l'utilisateur du CTRL-Z doit �tre conscient que cela bloque le shell et qu'il faut le relancer 
# par fg ou bg
#


# Restriction:
# ============
#
# * On ne peut pas employer ce mode de verrouillage sur des shells qui lancent des
#   processus daemon. C'est le processus daemon qui doit impl�menter un m�canisme de
#   verrouillage


#==============================================================================
#============================   S C R I P T   =================================
#==============================================================================

# Par d�faut, le nom du verrou est le nom du script + ".lock"
# Cette variable peut-�tre modifi�e par le script appellant apr�s le chargement de ce script
# Le nom du verrou est de la responsabilit� du script appellant
# Il vaut mieux red�finir cette variable et mettre le r�pertoire dans lequel le verrou doit se trouver

LOCK=$0.lock


# Param�tres
LOCK_VERBOSE=0     # Mettre � 1 pour les traces majeures, 2 pour toutes les traces
LOCK_WAIT_UNLOCK=1 # Mettre � 0 si on ne veut pas que unlock() fasse un wait afin de ne
                   # quitter le process tant que les sous-process n'ont pas fini

# Variables internes
LOCK_BUILD_KEY=
LOCK_CHECK=
LOCK_PIDF=
LOCK_PGIDF=


# Mode trace de lock.sh

lock_trace()
{
 lv=$1
 shift
 if (( $lv <= $LOCK_VERBOSE )) ; then 
  print "lock.sh:pid=$$: $*"
 fi
}


# Construit la cl� de contr�le pour un PID donn� (param�tre $1)
# On utilise des champs invariables de la commande ps pour un PID de fa�on � ce
# que cette cl� soit invariable
# (On pourrait int�grer ici la date de cr�ation du processus ou introduire
# une notion de dur�e pour laquelle le verrou est valide)
build_lock_key()
{
 ppid=`ps -p $1 -o ppid=`
 pgid=`ps -p $1 -o pgid=`
 # construction de la cha�ne
 tmps="PID=$1:PPID=$ppid:PGID=$pgid"
 lock_trace 2 "build_lock_key(): cha�ne de base tmps=[$tmps]"
 # remplacement des espaces par des vides pour avoir une cha�ne pleine
 LOCK_BUILD_KEY=`echo $tmps | sed 's/ //g'` 
 lock_trace 1 "build_lock_key(): cha�ne de contr�le LOCK_BUILD_KEY=[$LOCK_BUILD_KEY]"
}


# On appelle cette fonction que si le verrou existe !
get_pidlock()
{
 # recup�ration de la cl� de contr�le qui avait �t� cr�� 
 keylock=`head -n 1 $LOCK`
 lock_trace 1 "get_pidlock(): cl� pr�sente dans le fichier verrou keylock=[$keylock]"

 # r�cuperation du PID
 item1=`echo $keylock | cut -d : -f 1`
 lock_trace 2 "get_pidlock(): item1=$item1"
 LOCK_PIDF=`echo $item1 | cut -d = -f 2`
 lock_trace 1 "get_pidlock(): LOCK_PIDF=$LOCK_PIDF"
 
 # r�cuperation du PGID
 item3=`echo $keylock | cut -d : -f 3`
 lock_trace 2 "get_pidlock(): item3=$item3"
 LOCK_PGIDF=`echo $item3 | cut -d = -f 2`
 lock_trace 1 "get_pidlock(): LOCK_PGIDF=$LOCK_PGIDF"
}





check_lock()
{
 LOCK_CHECK=0

 # On attend �ventuellement que le processus qui a pu poser le verrou
 # cr�� le fichier point� par le lien symbolique
 # avec une s�curit� pour ne pas boucler ind�finiment 
 #
 # Cas sp�cial: si le processus 1 a pos� le verrou et qu'il est tr�s rapide, alors
 # le processus 2 qui arrive ici (car il n'a pas pu poser le verrou) peut tomber dans
 # dans la boucle (car processus 1 n'a pas encore cr�� le fichier) et s'arr�ter car
 # pendant un sleep 1 de la boucle, processus 1 a termin� est d�truit le verrou
 # donc processus 2 ne le voit pas. Il s'arr�te mais c'est ce qu'on voulait.
 cnt=0
 while test ! -f $LOCK ; do
   lock_trace 1 "check_lock(): endormissement"
   sleep 1
   cnt=$((cnt + 1))
   if (($cnt > 4)) ; then
     echo "lock.sh:pid=$$: Verrou �ph�m�re: un autre processus a pu poser le verrou et l'a rel�ch�"
     echo "pendant la phase de contr�le de ce processus (script probablement trop rapide et lanc�"
     echo "en double),"
     echo "OU impossible de cr�er le lien (v�rifier le chemin du nom du verrou,). Abandon."
     exit 1
   fi
 done 

 # le verrou existe, 
 get_pidlock

 # Reconstruire la cl� de contr�le de ce PID
 build_lock_key $LOCK_PIDF
 
 currentkey=$LOCK_BUILD_KEY
 lock_trace 1 "check_lock(): cl� reconstruite pour ce PID currentkey=[$currentkey]"

 # Si la cl� est identique, alors ce processus qui est en train de tourner est bien le
 # propri�taire du verrou, sinon c'est un processus sans rapport avec le verrou enregistr�
 # Cela arrive apr�s un kill -9
 # Dans ce dernier cas, ce verrou peut etre ignor� car le processus qui l'avait cr�� est mort
 # mais attention � ses fils....
 
 if [ "X$currentkey" != "X$keylock" ] ; then
   LOCK_CHECK=1
   lock_trace 1 "check_lock(): cl�s diff�rentes !"
   
   foo=/tmp/liblock.sh.$$
   ps -A -o ruser=,pid=,ppid=,pgid=,args= | grep $LOCK_PGIDF | grep -v "grep $LOCK_PGIDF" > $foo
   list_child=`cat $foo`

   # Si list_child n'est pas vide, alors il existe des process qui ont le m�me process group (pgid)
   # que le process qui avait pos� le verrou. Nous sommes dans le cas o� le shell qui a pos� le 
   # verrou a �t� tu� par un kill -9 mais pas ses fils, mais ses fils tournent encore.
   # Lors d'un kill -9 le ppid des fils est rattach� au pid 1 et non plus au pid du shell p�re, mais
   # pgid subsiste, tous les process fils du shell ont le m�me pgid (normalement).
   # il faut normalement tuer tous les fils avant le p�re ou faire un "kill -kill -PGID" pour tuer 
   # tous les process appartenant au m�me PGID
   
   if [ "X$list_child" != "X" ] ; then     
     LOCK_CHECK=0
     echo "lock.sh:pid=$$: Le verrou est obsol�te (cl�s diff�rentes) mais il existe des processus"
     echo "fils qui appartiennent au m�me process group (PGID) que le shell qui avait pos� le verrou"
     echo "Ce shell a �t� probablement tu� par un kill -9, mais pas ses fils"
     echo "Attendre la fin des fils ou les tuer, puis relancer"
     echo "USER  PID  PPID  PGID  ARGS"
     cat $foo     
   fi
   
   rm -f $foo
 fi 
}




# Cherche � poser le verrou de fa�on exclusive

lock()
{
 # On ne peut pas poser le verrou par d�faut
 do_lock=0

 # La fonction ln est exclusive au niveau du syst�me UNIX
 # ce qui veut dire qui si deux processus d�marre simultan�ment
 # un seul arrivera � cr�er le lien symbolique (pour un m�me nom de verrou)
 # C'est cette op�ration qui garantie l'exclusivit� de l'appel � lock()
 # Le nom de verrou est un lien symbolique qui pointe vers un fichier dont le nom
 # est le nom de verrou plus le PID, ce fichier n'est pas cr�� imm�diatement, par contre
 # le lien est cr��
 
 ln -s $LOCK.$$ $LOCK 2>/dev/null
 
 lnret=$?
 
 if test $lnret -eq 0 ; then
 
   do_lock=1  # le processus a le droit de poser le verrou

 else  
 
   # On entre ici que dans les cas d'arr�t brutal (kill -9), le verrou n'a pas �t� d�truit
   # ou de lancements simultan�s
 
           
   # Contr�le si le verrou est obsol�te ou actif
   # s'il est obsol�te, le verrou sera d�truit et le processus
   # tentera de poser le verrou
   check_lock
   
   if (( $LOCK_CHECK == 1 )) ; then
 
     # On supprime l'ancien verrou
     remove_bad_lock
     echo "lock.sh:pid=$$: Note: verrou obsol�te d�truit (script probablement d�truit par un kill -9)"     
 
     # On tente de reposer le nouveau verrou
     ln -s $LOCK.$$ $LOCK 2>/dev/null 
     lnret=$?

     if (( $lnret == 0 )) ; then  
        do_lock=1
     else
       # Ce cas arrive si on lance plus de deux fois le m�me script en m�me temps 
       # (informatiquement parlant)
       # alors que le pr�c�dent lancement avait �t� tu� par un kill -9 
       # Un des deux process ne pourra pas d�marrer
       # Dans ce cas, le process en �chec ne tente pas de contr�ler la validit� du verrou
       # comme il vient de le faire 
       echo "lock.sh:pid=$$: fatal: impossible de poser le verrou apr�s unlock d'un verrou obsol�te"
       echo "lock.sh:pid=$$: un processus a red�marr� et pos� le verrou entre temps"       
     fi
   fi  
 fi  

 
 if (( $do_lock == 1 )) ; then

    # construit la cl� de contr�le du processus courant
    build_lock_key $$ 
    K=$LOCK_BUILD_KEY
    lock_trace 2 "lock(): cl� du processus courant K=[$K]"
    # renseigne le verrou
    echo $K > $LOCK  # ceci d�bloque un process bloqu� dans check_lock() dans la boucle du sleep
    lock_trace 1 "lock(): Verrou $LOCK -> $LOCK.$$ pos�"
  else

    # refus de d�marrage pour cause de verrou
    echo "ERROR : Le process est d�ja en cours d�ex�cution (pid=$$), abandon de ce lancement"    
    exit 1
 fi
}


# Destruction du verrou, responsabilit� de l'application appellante
# On d�truit aussi le fichier point� par le lien symbolique
# Le processus courant d�truit toujours son verrou
# A cause des trap, cette fonction peut-�tre appell�e plusieurs fois

unlock()
{
 if (( $LOCK_WAIT_UNLOCK == 1 )) ; then
  # On attends que les sous-process lanc� par le process ont termin�
  # avant de d�truire le verrou de ce process
  lock_trace 1 "unlock(): wait"
  wait
 fi

 lock_trace 1 "unlock() : LOCK=$LOCK"

 if test -f $LOCK ; then
   
   get_pidlock
   
   if (( $LOCK_PIDF == $$ )) ; then
     rm -f $LOCK $LOCK.$$
     lock_trace 1 "unlock(): destruction du verrou $LOCK -> $LOCK.$$" 
   else
     lock_trace 1 "unlock(): non destruction de verrou car non propri�taire"
   fi
 else
   # Cas d'un CTRL-C suivi d'un EXIT ; plusieurs appels � unlock()
   lock_trace 1 "unlock() : pas de verrou � d�truire"
 fi
}


# Destruction d'un verrou obsol�te
# On d�truit aussi le fichier point� par le lien symbolique
# la r�gle est que le pid contenu dans le fichier constitue le nom de
# ce fichier avec le nom du verrou
# En effet, on ne peut pas prendre le PID du processus courant car dans le
# cas d'un verrou obsol�te que l'on cherche � d�truire, il faut retrouver
# l'ancien num�ro de PID

remove_bad_lock()
{
 get_pidlock
 rm -f $LOCK $LOCK.$LOCK_PIDF
 lock_trace 1 "remove_bad_lock(): destruction du verrou $LOCK -> $LOCK.$LOCK_PIDF" 
}


# CTRL-C et SIGTERM conduisent � la destruction du verrou
# EXIT est un "fake signal" du korn-shell appell� lors de la fin du script
# ou d'une fonction (dans notre cas, fin du script)
# Il n'est pas n�cessaire de faire une fonction _exit() et de faire un alias
# avec exit afin de pi�ger les exit du shell appellant
# le cas des kill -9 et autre destruction sauvage est g�r� par check_lock() appell� dans lock()
# gr�ve � la cl� de contr�le
# Si un shell red�fini le trap de INT TERM ou EXIT, il doit IMPERATIVEMENT appeller unlock() !!!

trap unlock INT TERM EXIT




