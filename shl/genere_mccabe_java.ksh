#!/bin/ksh

 

if test $# -ne 2

 then

  echo "Bad parameters"

  echo "$0: <name of module> <temporary directory>"

  exit 1

fi

 

 

NAME=$(basename $1)

DIRI=$2

 

test -d report || mkdir report

test -d $DIRI || mkdir $DIRI

 

\rm -f $DIRI/*.java

find . -type f -name '*.java' -exec cp {} $DIRI/ \; 2> /dev/null

 

cd $DIRI

for i in `ls *.java`

do

        echo cw_Java_inst $PWD/$i > `echo $i | sed 's/\.i$//'`_${NAME}.mca

done

 

mccabe.sh . $NAME

\rm -f *.java

exit 0
