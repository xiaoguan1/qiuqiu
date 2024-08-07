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

# 默认编译lua的路径
LUADIR=$RUNDIR/../skynet/3rd/lua

# 默认编译skynet引擎的路径
SKYNETDIR=$RUNDIR/../skynet/

cd $RUNDIR/..
lua ./charvar/agent/var_name.lua
lua ./charvar/gameserver/var_name.lua
lua ./charvar/activity/var_name.lua

echo "选择题:"
select w in 启动游戏 启动跨服 编译并启动游戏 关闭游戏
do
	case $w in
		启动游戏)
			./skynet/skynet ./etc/main_node
			break
			;;
		启动跨服)
			./skynet/skynet ./etc/cross_node
			break
			;;
		编译并启动游戏)
			cd $LUADIR
			make linux		# 编译lua

			cd $SKYNETDIR
			make linux		# 编译skynet

			cd $RUNDIR/..
			./skynet/skynet ./etc/main_node
			break
			;;
	esac
done

# case ${1} in
# 	"1")
# 		./skynet/skynet ./etc/main_node
# 		;;
# 	"2")
# 		./skynet/skynet ./etc/config.node2
# 		;;
# 	*)
# 		echo "error start"
# 		;;
# esac
