#!/bin/bash

# getDir(){
# 	dir=`echo $0 | grep "^/"`
# 	if test "${dir}"; then	# test 变量。 dir 为空字符串("") 则为false，否则为true
# 		dirname $0
# 	else
# 		dirname `pwd`/$0
# 	fi
# }

# RUNUSER=`whoami` # 当前用户
# nogame=$1
# if [ "$RUNUSER" != "game" -a "X$nogame" = "X" ]; then
# 	echo "$0 must be run by game"
# 	exit
# fi

# RUNDIR=`getDir`	# 当前路径

lua ./gen_proto/gen_proto.lua