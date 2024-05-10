#!/bin/bash

dbname=$1

######################create db######################
mysql -hlocalhost -uroot -proot << EOF 2>/dev/null
CREATE DATABASE $dbname default charset utf8mb4 COLLATE utf8mb4_general_ci;
EOF
[ $? -eq 0 ] && echo "create database: $dbname" || echo "exists database: $dbname";

######################create table######################
mysql -hlocalhost -uroot -proot $dbname << EOF 2>/dev/null
CREATE TABLE globaluser (
	account varchar(64) NOT NULL COMMENT '账号',
	passwd varchar(32) NOT NULL COMMENT '密码',
	channelid varchar(16) COMMENT '渠道id',
	mactype tinyint COMMENT '设备类型',
	PRIMARY KEY (account)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
EOF
[ $? -eq 0 ] && echo "create database: globaluser" || echo "exists database: globaluser";

mysql -hlocalhost -uroot -proot $dbname << EOF 2>/dev/null
CREATE TABLE list (
	acct_id varchar(64) NOT NULL COMMENT '外部账号_区服编号组合而成',
	list_data text NOT NULL COMMENT '账号数据',
	PRIMARY KEY (acct_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
EOF
[ $? -eq 0 ] && echo "create database: list" || echo "exists database: list";

mysql -hlocalhost -uroot -proot $dbname << EOF 2>/dev/null
CREATE TABLE role_data (
	uid varchar(32) NOT NULL COMMENT '玩家唯一id',
	name varchar(64) NOT NULL COMMENT '玩家名字',
	mapdata varchar(64) NOT NULL COMMENT '地图数据',
	data mediumtext NOT NULL COMMENT '玩家数据',
	Account varchar(64) COMMENT '玩家账号',
	PRIMARY KEY (uid),
	UNIQUE KEY UK_ROLE_NAME (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
EOF
[ $? -eq 0 ] && echo "create database: role_data" || echo "exists database: role_data";

mysql -hlocalhost -uroot -proot $dbname << EOF 2>/dev/null
CREATE TABLE role (
	uid varchar(32) NOT NULL COMMENT '玩家唯一id',
	name varchar(64) NOT NULL COMMENT '玩家名字',
	PRIMARY KEY (uid)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
EOF
[ $? -eq 0 ] && echo "create database: role" || echo "exists database: role";

mysql -hlocalhost -uroot -proot $dbname << EOF 2>/dev/null
CREATE TABLE module (
	mod_name varchar(128) NOT NULL COMMENT '模块名字',
	data longtext NOT NULL COMMENT '模块数据',
	PRIMARY KEY (mod_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
EOF
[ $? -eq 0 ] && echo "create database: module" || echo "exists database: module";

mysql -hlocalhost -uroot -proot $dbname << EOF 2>/dev/null
CREATE TABLE setting (
	name varchar(128) NOT NULL COMMENT '数据表名字',
	data longtext NOT NULL COMMENT '表格数据',
	PRIMARY KEY (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
EOF
[ $? -eq 0 ] && echo "create database: setting" || echo "exists database: setting";

mysql -hlocalhost -uroot -proot $dbname << EOF 2>/dev/null
CREATE TABLE servercmd (
	id bigint(20) NOT NULL AUTO_INCREMENT,
	serverid int(11) DEFAULT '0' COMMENT '服务器id',
	cmdid int(11) DEFAULT '0' COMMENT '命令的id',
	cmd varchar(11) DEFAULT '0' COMMENT '命令名称',
	param1 varchar(256) DEFAULT NULL COMMENT '参数1',
	param2 varchar(256) DEFAULT NULL COMMENT '参数2',
	param3 varchar(256) DEFAULT NULL COMMENT '参数3',
	param4 varchar(256) DEFAULT NULL COMMENT '参数4',
	param5 varchar(256) DEFAULT NULL COMMENT '参数5',
	PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='server cmd命令表';
EOF
[ $? -eq 0 ] && echo "create database: servercmd" || echo "exists database: servercmd";

