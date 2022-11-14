#!/bin/bash

getDir(){
	dir=`echo $0 | grep "^/"`
	if test "${dir}"; then	# test 变量。 dir 为空字符串("") 则为false，否则为true
		dirname $0
	else
		dirname `pwd`/$0
	fi
}

RUNUSER=`whoami` # 当前用户
nogame=$1
if [ "$RUNUSER" != "game" -a "X$nogame" = "X" ]; then
	echo "$0 must be run by game"
	exit
fi

RUNDIR=`getDir`	# 当前路径
 
echo "一键重置数据库..."

# 找出主节点进程并杀死
game_pid=`ps -ef | grep skynet | grep main | awk '{printf("%d", $2);}'`
while [ "X$game_pid" != "X" ]; do
	if [ "X$game_pid" != "X" ]; then
		kill $game_pid
	fi
	sleep 1
	game_pid=`ps -ef | grep skynet | grep main | awk '{printf("%d", $2);}'`
done

#sh $RUNDIR/database/deletedb.sh	
sh $RUNDIR/database/createdb.sh message_board

