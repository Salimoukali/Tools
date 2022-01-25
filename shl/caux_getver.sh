#!/usr/bin/ksh


#
# The F3G-CAUX project
#
# getver.sh: Get the versions of dependant libraries to trace dependancies
#            between F3G-CAUX modules
#            This script is called by the CAUX Makefile
#
# history:
#
# 09/12/2002 - J.Delfosse - Creation
#


# Current RELEASE
RELEASE=""

fatal()
{
 echo "$0: Cannot find $1"
 exit 1
}


# Structure "F3GFAR-E: libX.so VersionBinaire = 1.2.0 build# 20021212-160320"

kernel()
{
 LIB=lib${1}.so
 if test ! -f ${CMNCAUX}/lib/${LIB} ; then
    fatal ${LIB}
 fi
 VER=`what ${CMNCAUX}/lib/${LIB} | grep "F3GFAR-E" | grep "VersionBinaire" | awk -F" " '{print $5}' `  
 if [ "X${VER}" = "X" ] ; then
    VER="UNDEFINED"
 fi
 echo "${LIB} ${VER}"
}



# Structure "(C) Cap Gemini TMNF 2002 , libX.so Version 1.X , DD/MM/YYYY"

tools()
{
 LIB=lib${1}.so
 if test ! -f ${CMNCAUX}/lib/${LIB} ; then
    fatal ${LIB}
 fi
 VER=`what ${CMNCAUX}/lib/${LIB} | grep "Cap Gemini" | grep "Version" | awk -F" " '{print $9}' `  
 if [ "X${VER}" = "X" ] ; then
    VER="UNDEFINED"
 fi
 echo "${LIB} ${VER}"
}


 
# Structure "F3GFAR-E: libX.so VersionBinaire = 1.2.0 build# 20021212-160320"

byteltools()
{
 LIB=lib${1}.so
 if test ! -f ${CMNCAUX}/lib/${LIB}  ; then
    fatal ${LIB}
 fi
 VER=`what ${CMNCAUX}/lib/${LIB} | grep "F3GFAR-E" | grep VersionBinaire | awk -F" " '{print $5}' `  
 if [ "X${VER}" = "X" ] ; then
    VER="UNDEFINED"
 fi
 echo "${LIB} ${VER}"
}
 

# Finally, the best way to get the oracle version is to query the database with
# "select * from v$version"  or  "select * from product_component_version"
# These two "tables" are in fact public synonyms and therefore are accessible to any auser
#
# I think it should be,
#
#   select version from product_component_version where product like 'Oracle%';
#
# J.Delfosse 23/06/2003

oracle()
{
 # Fiddle based on the listener
 # $ORACLE_HOME/install/unix.rgs is not reliable
 LIB=libclntsh.a
 if test ! -f ${ORACLE_HOME}/lib/${LIB} ; then
     fatal ${LIB}
 fi
 SUM=`sum ${ORACLE_HOME}/lib/${LIB} | awk -F" " '{print $1, $2}'`
 SUMTAG=" sum(${LIB})=${SUM}"
 if test ! -f lsnrctl
   then
     echo "$0: cannot find lsnrctl"
     exit 1
 fi
 LEFT=`lsnrctl version | grep LSNRCTL | awk -F" " '{print $2}'`
 VER=`echo ${LEFT} | awk -F" " '{print $2}'`
 echo "Oracle ${VER} ${SUMTAG}"
}



build()
{
 BN=`date +"%d/%m/%Y %H:%M:%S" `
 echo $BN
}




dev()
{
 repos=${COMMUNS}/verdev
 module=$(basename $1)
 if test ! -d ${repos} ; then
   mkdir -p ${repos}
   chmod a+rwx ${repos}
 fi
 if test ! -f ${repos}/${module} ; then
   echo 0 > ${repos}/${module}
   chmod a+rw ${repos}/${module}
 fi   
 nb=`cat ${repos}/${module}`
 ver=`expr ${nb} + 1`
 rm -f ${repos}/${module}
 echo ${ver} >  ${repos}/${module}
 chmod a+rw ${repos}/${module}
 echo DEV.${nb}
}



livr()
{
 echo ${RELEASE}
}



case $1 in
 arkernel       ) kernel $1 ;;
 extendedkernel ) kernel $1 ;;
 tools          ) tools $1;;
 oratools       ) tools $1;;
 byteltools     ) byteltools $1;;
 oracle         ) oracle ;;
 build          ) build ;;
 livr           ) livr ;; 
 dev            ) dev $2 ;;
 *              ) echo "$0: unsupported parameter"
                  exit 1 ;;
esac


