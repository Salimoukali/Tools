#--- Marking Strings ------------------------------------------------
#--- @(#)F3GFAR-S: $Workfile:   liblock.sh  $ $Revision: 65 $
#--------------------------------------------------------------------
#--- @(#)F3GFAR-E: $Workfile:   liblock.sh  $ VersionLivraison = 2.1.11.1
#--------------------------------------------------------------------


# Historique:
# ===========
# J.Delfosse - 1.0 - 07/07/2004 - Création, basée sur l'exclusivité du "ln -s"
# J.Delfosse - 1.1 - 20/07/2004 - Ajout du PGID dans check_lock()
#
#


# Utilisation:
# ============
# Exemple d'utilisation pour $HOME/CAUX/batch/shl/batch.sh qui ne veut pas être lancé deux fois:
#
#  |#!/usr/bin/ksh
#  |
#  |. $HOME/cmnF3G/Tools/shl/liblock.sh
#  |
#  |LOCK=$HOME/CAUX/batch/shl/batch.sh.lock
#  |
#  |lock
#  |
#  |#Exécution du script batch.sh
#  | 
#  |unlock
#  |exit 0
#


# Comportement:
# =============
#
# * Verrouillage au niveau du shell (indépendamment de ce qui est lancé par le shell)
# * L'exclusivité du lancement se fait sur le nom du verrou LOCK
#   décidé par le shell appellant (conseil: mettre le répertoire complet de façon à
#   ce que le verrou soit créé dans le même répertoire que le shell appellant)
# * La fin du shell entraîne automatiquement l'appel de unlock (y compris les exit)
# * unlock attends par défaut tous les sous-process lancé par le shell appellant
#   (mettre LOCK_WAIT_UNLOCK=0 après le source de lock.sh pour désactiver cette attente; déconseillé)
# * Le shell appellant ne doit pas utiliser la fonction trap sur INT TERM et EXIT ou alors
#   il doit redéfinir le handler (trapper les signaux, et appeller unlock dans la nouvelle fonction)
# * En cas de crash (kill -9), le relancement du shell appellant détruit normalement le précédent
#   verrou devenu obsolète (Note: le "core dump" d'un batch lancé par le shell appellant ne détruit pas
#   le shell appellant).Si on a tué le shell père (qui a posé le verrou) mais pas ses fils, 
#    alors si ses fils continue à tourner (ils ont le même pgid) alors le script ne redémarre pas
# * Pour avoir les traces, mettre LOCK_VERBOSE=2 après le source de lock.sh
# * Un échec de lock conduit le shell appellant à un exit 1
# 
#

# Note sur le CTRL-Z :
# ===================
#
# Quand on lance un shell à la main dans un terminal et sans le & (background), puis que l'on fait 
# CTRL-Z, le shell est bloqué par le korn-shell.
# KSH envoie le signal TSTP (terminal stop) vers le process shell.
#
# La situation suivante peut arriver, le fils du shell (un éxécutable) a terminé, il apparaît
# alors <defunct> dans la commande ps. En effet, le shell père étant bloqué, le système attends
# que le shell père soit débloqué pour pouvoir signaler au père la mort du fils.
#
# Si on relance le shell après un CTRL-Z, le shell ne démarrera pas car le verrou est toujours 
# actif. Ceci est tout à fait normal car le shell est suspendu, il n'a pas terminé.
#
# Après un CTRL-Z, il faut toujours relancer le shell suspendu car il bloqué (stopped jobs) 
# Il faut utiliser soit la commande fg (pour le remettre en foreground), soit la commande bg 
# (pour le mettre en background) afin qu'il se termine.
#
# Le signal CTRL-Z n'est pas trappé par la librairie car CTRL-Z peut-être utile. Cependant 
# l'utilisateur du CTRL-Z doit être conscient que cela bloque le shell et qu'il faut le relancer 
# par fg ou bg
#


# Restriction:
# ============
#
# * On ne peut pas employer ce mode de verrouillage sur des shells qui lancent des
#   processus daemon. C'est le processus daemon qui doit implémenter un mécanisme de
#   verrouillage


#==============================================================================
#============================   S C R I P T   =================================
#==============================================================================

# Par défaut, le nom du verrou est le nom du script + ".lock"
# Cette variable peut-être modifiée par le script appellant après le chargement de ce script
# Le nom du verrou est de la responsabilité du script appellant
# Il vaut mieux redéfinir cette variable et mettre le répertoire dans lequel le verrou doit se trouver

LOCK=$0.lock


# Paramètres
LOCK_VERBOSE=0     # Mettre à 1 pour les traces majeures, 2 pour toutes les traces
LOCK_WAIT_UNLOCK=1 # Mettre à 0 si on ne veut pas que unlock() fasse un wait afin de ne
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


# Construit la clé de contrôle pour un PID donné (paramètre $1)
# On utilise des champs invariables de la commande ps pour un PID de façon à ce
# que cette clé soit invariable
# (On pourrait intégrer ici la date de création du processus ou introduire
# une notion de durée pour laquelle le verrou est valide)
build_lock_key()
{
 ppid=`ps -p $1 -o ppid=`
 pgid=`ps -p $1 -o pgid=`
 # construction de la chaîne
 tmps="PID=$1:PPID=$ppid:PGID=$pgid"
 lock_trace 2 "build_lock_key(): chaîne de base tmps=[$tmps]"
 # remplacement des espaces par des vides pour avoir une chaîne pleine
 LOCK_BUILD_KEY=`echo $tmps | sed 's/ //g'` 
 lock_trace 1 "build_lock_key(): chaîne de contrôle LOCK_BUILD_KEY=[$LOCK_BUILD_KEY]"
}


# On appelle cette fonction que si le verrou existe !
get_pidlock()
{
 # recupération de la clé de contrôle qui avait été créé 
 keylock=`head -n 1 $LOCK`
 lock_trace 1 "get_pidlock(): clé présente dans le fichier verrou keylock=[$keylock]"

 # récuperation du PID
 item1=`echo $keylock | cut -d : -f 1`
 lock_trace 2 "get_pidlock(): item1=$item1"
 LOCK_PIDF=`echo $item1 | cut -d = -f 2`
 lock_trace 1 "get_pidlock(): LOCK_PIDF=$LOCK_PIDF"
 
 # récuperation du PGID
 item3=`echo $keylock | cut -d : -f 3`
 lock_trace 2 "get_pidlock(): item3=$item3"
 LOCK_PGIDF=`echo $item3 | cut -d = -f 2`
 lock_trace 1 "get_pidlock(): LOCK_PGIDF=$LOCK_PGIDF"
}





check_lock()
{
 LOCK_CHECK=0

 # On attend éventuellement que le processus qui a pu poser le verrou
 # créé le fichier pointé par le lien symbolique
 # avec une sécurité pour ne pas boucler indéfiniment 
 #
 # Cas spécial: si le processus 1 a posé le verrou et qu'il est très rapide, alors
 # le processus 2 qui arrive ici (car il n'a pas pu poser le verrou) peut tomber dans
 # dans la boucle (car processus 1 n'a pas encore créé le fichier) et s'arrêter car
 # pendant un sleep 1 de la boucle, processus 1 a terminé est détruit le verrou
 # donc processus 2 ne le voit pas. Il s'arrête mais c'est ce qu'on voulait.
 cnt=0
 while test ! -f $LOCK ; do
   lock_trace 1 "check_lock(): endormissement"
   sleep 1
   cnt=$((cnt + 1))
   if (($cnt > 4)) ; then
     echo "lock.sh:pid=$$: Verrou éphémère: un autre processus a pu poser le verrou et l'a relâché"
     echo "pendant la phase de contrôle de ce processus (script probablement trop rapide et lancé"
     echo "en double),"
     echo "OU impossible de créer le lien (vérifier le chemin du nom du verrou,). Abandon."
     exit 1
   fi
 done 

 # le verrou existe, 
 get_pidlock

 # Reconstruire la clé de contrôle de ce PID
 build_lock_key $LOCK_PIDF
 
 currentkey=$LOCK_BUILD_KEY
 lock_trace 1 "check_lock(): clé reconstruite pour ce PID currentkey=[$currentkey]"

 # Si la clé est identique, alors ce processus qui est en train de tourner est bien le
 # propriétaire du verrou, sinon c'est un processus sans rapport avec le verrou enregistré
 # Cela arrive après un kill -9
 # Dans ce dernier cas, ce verrou peut etre ignoré car le processus qui l'avait créé est mort
 # mais attention à ses fils....
 
 if [ "X$currentkey" != "X$keylock" ] ; then
   LOCK_CHECK=1
   lock_trace 1 "check_lock(): clés différentes !"
   
   foo=/tmp/liblock.sh.$$
   ps -A -o ruser=,pid=,ppid=,pgid=,args= | grep $LOCK_PGIDF | grep -v "grep $LOCK_PGIDF" > $foo
   list_child=`cat $foo`

   # Si list_child n'est pas vide, alors il existe des process qui ont le même process group (pgid)
   # que le process qui avait posé le verrou. Nous sommes dans le cas où le shell qui a posé le 
   # verrou a été tué par un kill -9 mais pas ses fils, mais ses fils tournent encore.
   # Lors d'un kill -9 le ppid des fils est rattaché au pid 1 et non plus au pid du shell père, mais
   # pgid subsiste, tous les process fils du shell ont le même pgid (normalement).
   # il faut normalement tuer tous les fils avant le père ou faire un "kill -kill -PGID" pour tuer 
   # tous les process appartenant au même PGID
   
   if [ "X$list_child" != "X" ] ; then     
     LOCK_CHECK=0
     echo "lock.sh:pid=$$: Le verrou est obsolète (clés différentes) mais il existe des processus"
     echo "fils qui appartiennent au même process group (PGID) que le shell qui avait posé le verrou"
     echo "Ce shell a été probablement tué par un kill -9, mais pas ses fils"
     echo "Attendre la fin des fils ou les tuer, puis relancer"
     echo "USER  PID  PPID  PGID  ARGS"
     cat $foo     
   fi
   
   rm -f $foo
 fi 
}




# Cherche à poser le verrou de façon exclusive

lock()
{
 # On ne peut pas poser le verrou par défaut
 do_lock=0

 # La fonction ln est exclusive au niveau du système UNIX
 # ce qui veut dire qui si deux processus démarre simultanément
 # un seul arrivera à créer le lien symbolique (pour un même nom de verrou)
 # C'est cette opération qui garantie l'exclusivité de l'appel à lock()
 # Le nom de verrou est un lien symbolique qui pointe vers un fichier dont le nom
 # est le nom de verrou plus le PID, ce fichier n'est pas créé immédiatement, par contre
 # le lien est créé
 
 ln -s $LOCK.$$ $LOCK 2>/dev/null
 
 lnret=$?
 
 if test $lnret -eq 0 ; then
 
   do_lock=1  # le processus a le droit de poser le verrou

 else  
 
   # On entre ici que dans les cas d'arrêt brutal (kill -9), le verrou n'a pas été détruit
   # ou de lancements simultanés
 
           
   # Contrôle si le verrou est obsolète ou actif
   # s'il est obsolète, le verrou sera détruit et le processus
   # tentera de poser le verrou
   check_lock
   
   if (( $LOCK_CHECK == 1 )) ; then
 
     # On supprime l'ancien verrou
     remove_bad_lock
     echo "lock.sh:pid=$$: Note: verrou obsolète détruit (script probablement détruit par un kill -9)"     
 
     # On tente de reposer le nouveau verrou
     ln -s $LOCK.$$ $LOCK 2>/dev/null 
     lnret=$?

     if (( $lnret == 0 )) ; then  
        do_lock=1
     else
       # Ce cas arrive si on lance plus de deux fois le même script en même temps 
       # (informatiquement parlant)
       # alors que le précédent lancement avait été tué par un kill -9 
       # Un des deux process ne pourra pas démarrer
       # Dans ce cas, le process en échec ne tente pas de contrôler la validité du verrou
       # comme il vient de le faire 
       echo "lock.sh:pid=$$: fatal: impossible de poser le verrou après unlock d'un verrou obsolète"
       echo "lock.sh:pid=$$: un processus a redémarré et posé le verrou entre temps"       
     fi
   fi  
 fi  

 
 if (( $do_lock == 1 )) ; then

    # construit la clé de contrôle du processus courant
    build_lock_key $$ 
    K=$LOCK_BUILD_KEY
    lock_trace 2 "lock(): clé du processus courant K=[$K]"
    # renseigne le verrou
    echo $K > $LOCK  # ceci débloque un process bloqué dans check_lock() dans la boucle du sleep
    lock_trace 1 "lock(): Verrou $LOCK -> $LOCK.$$ posé"
  else

    # refus de démarrage pour cause de verrou
    echo "ERROR : Le process est déja en cours d’exécution (pid=$$), abandon de ce lancement"    
    exit 1
 fi
}


# Destruction du verrou, responsabilité de l'application appellante
# On détruit aussi le fichier pointé par le lien symbolique
# Le processus courant détruit toujours son verrou
# A cause des trap, cette fonction peut-être appellée plusieurs fois

unlock()
{
 if (( $LOCK_WAIT_UNLOCK == 1 )) ; then
  # On attends que les sous-process lancé par le process ont terminé
  # avant de détruire le verrou de ce process
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
     lock_trace 1 "unlock(): non destruction de verrou car non propriétaire"
   fi
 else
   # Cas d'un CTRL-C suivi d'un EXIT ; plusieurs appels à unlock()
   lock_trace 1 "unlock() : pas de verrou à détruire"
 fi
}


# Destruction d'un verrou obsolète
# On détruit aussi le fichier pointé par le lien symbolique
# la règle est que le pid contenu dans le fichier constitue le nom de
# ce fichier avec le nom du verrou
# En effet, on ne peut pas prendre le PID du processus courant car dans le
# cas d'un verrou obsolète que l'on cherche à détruire, il faut retrouver
# l'ancien numéro de PID

remove_bad_lock()
{
 get_pidlock
 rm -f $LOCK $LOCK.$LOCK_PIDF
 lock_trace 1 "remove_bad_lock(): destruction du verrou $LOCK -> $LOCK.$LOCK_PIDF" 
}


# CTRL-C et SIGTERM conduisent à la destruction du verrou
# EXIT est un "fake signal" du korn-shell appellé lors de la fin du script
# ou d'une fonction (dans notre cas, fin du script)
# Il n'est pas nécessaire de faire une fonction _exit() et de faire un alias
# avec exit afin de piéger les exit du shell appellant
# le cas des kill -9 et autre destruction sauvage est géré par check_lock() appellé dans lock()
# grâve à la clé de contrôle
# Si un shell redéfini le trap de INT TERM ou EXIT, il doit IMPERATIVEMENT appeller unlock() !!!

trap unlock INT TERM EXIT




