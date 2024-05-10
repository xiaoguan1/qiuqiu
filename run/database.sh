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
CREATE_DB_SH=$RUNDIR/database/createdb/createdb.sh
DELETE_DB_SH=$RUNDIR/database/deletedb/deletedb.sh
MAIN_CONFIG=$RUNDIR/../etc/main_node
CROSS_CONFIG=$RUNDIR/../etc/cross_node

echo "选择题:"
select w in 一键重置数据库
do
	case $w in
		一键重置数据库)
			# 找出主节点进程并杀死
			game_pid=`ps -ef | grep skynet | grep main | awk '{printf("%d", $2);}'`
			while [ "X$game_pid" != "X" ]; do
				if [ "X$game_pid" != "X" ]; then
					kill $game_pid
				fi
				sleep 1
				game_pid=`ps -ef | grep skynet | grep main | awk '{printf("%d", $2);}'`
			done
			cross_pid=`ps -ef | grep skynet | grep cross | awk '{printf("%d", $2);}'`
			while [ "X$cross_pid" != "X" ]; do
				if [ "X$cross_pid" != "X" ]; then
					kill $cross_pid
				fi
				sleep 1
				cross_pid=`ps -ef | grep skynet | grep cross | awk '{printf("%d", $2);}'`
			done
			dbname=`grep "dbname\s*=\s*" $MAIN_CONFIG | grep -o 'server[0-9]*'`
			if [ "X$dbname" == "X" ]; then
				echo "database_name error"
				exit 1
			fi
			echo "try delete database $dbname..."
			echo -e "yes" | sh $DELETE_DB_SH $dbname
			echo "try create database $dbname..."
			sh $CREATE_DB_SH $dbname
			# echo ""
			# dbname=`grep "dbname\s*=\s*" $CROSS_CONFIG | grep -o 'server[0-9]*'`
			# if [ "X$dbname" != "X" ]; then
			# 	echo "database_name error"
			# 	exit 1
			# fi
			# echo "try delete database $dbname..."
			# echo -e "yes" | sh $DELETE_DB_SH $dbname
			# echo "try create database $dbname..."
			# sh $CREATE_DB_SH $dbname
			echo ""
			sh $RUNDIR/database/createdb/create_centerdata.sh centerdata
			sh $RUNDIR/database/insertdb/insert_centerdata.sh centerdata
			break
			;;
	esac
done






# echo "一键重置数据库..."

# # 找出主节点进程并杀死
# game_pid=`ps -ef | grep skynet | grep main | awk '{printf("%d", $2);}'`
# while [ "X$game_pid" != "X" ]; do
# 	if [ "X$game_pid" != "X" ]; then
# 		kill $game_pid
# 	fi
# 	sleep 1
# 	game_pid=`ps -ef | grep skynet | grep main | awk '{printf("%d", $2);}'`
# done

# # 创建表
# #sh $RUNDIR/database/deletedb.sh	
# sh $RUNDIR/database/create/server_db.sh
# sh $RUNDIR/database/create/common_db.sh

# if [ $? -eq 0 ]; then
# 	# 插入数据
# 	sh $RUNDIR/database/insert/common_db.sh
# fi
