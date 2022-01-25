#!/bin/ksh
# This shell is called by the Makefile of the CAUX batches
# It only support the C++ batches made with OCI (no C source, no Pro*C)
# V 1.0 , J.Delfosse , 15/11/2002
# V 2.0 , A.Guillard , 19/10/2006


if test $# -ne 2
 then
  echo "Bad parameters"
  echo "$0: <name of module> <temporary directory>"
  exit 1
fi


NAME=$(basename $1)
DIRI=$2
echo "name="$1/$NAME

cd $DIRI

LIST=`ls *.i`
for i in $LIST
do
 echo "bytelC++_npp ${PWD}/${i}" >> `echo $i | sed 's/\.i$//'`_${NAME}.mca
done

test -d ../report || mkdir ../report
mccabe.sh . $NAME
\rm -f *.i
exit 0

