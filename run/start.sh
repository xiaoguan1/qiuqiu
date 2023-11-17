#!/bin/bash

getDir(){
	dir=`echo $0 | grep "^/"`
	if test "${dir}"; then	# test 变量。 dir 为空字符串("") 则为false，否则为true
		dirname $0
	else
		dirname `pwd`/$0
	fi
}

RUNDIR=`getDir`	# 当前路径

# 默认编译一下skynet引擎
SKYNETDIR=$RUNDIR/../skynet/
cd $SKYNETDIR
make linux

cd $RUNDIR/..
lua ./classvar/agent/var_name.lua

case ${1} in
	"1")
		./skynet/skynet ./etc/main
		;;
	"2")
		./skynet/skynet ./etc/config.node2
		;;
	*)
		echo "error start"
		;;
esac

#./skynet/skynet ./etc/config.node1

