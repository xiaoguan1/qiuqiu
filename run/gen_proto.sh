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
echo $RUNDIR
# 默认lua的路径
LUADIR=$RUNDIR/../skynet/3rd/lua/lua

$LUADIR ./gen_proto/network_proto.lua
$LUADIR ./gen_proto/database_proto.lua

echo "proto script run finish!"