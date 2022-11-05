#!/bin/bash

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

