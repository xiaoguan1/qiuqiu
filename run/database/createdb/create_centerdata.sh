#!/bin/bash

dbname=$1

if [ "X$dbname" = "X" ]; then
	echo "input dbname"
	exit
fi

######################create db######################
mysql -hlocalhost -uroot -proot << EOF 2>>/dev/null
DROP DATABASE if exists $dbname;
CREATE DATABASE $dbname default charset utf8mb4 COLLATE utf8mb4_general_ci;
EOF
[ $? -eq 0 ] && echo "create database: $dbname" || echo "exists database: $dbname";

######################create table######################
mysql -hlocalhost -uroot -proot $dbname << EOF 2>>/dev/null
CREATE TABLE game_server (
	server_id int(11) NOT NULL COMMENT '区服编号',
	main_node_ip varchar(16) NOT NULL COMMENT '给跨服服务器连接的ip(最好是内网ip)',
    main_node_port smallint unsigned NOT NULL COMMENT '给跨服服务器连接的端口',
	cadvarena_serverid int(11) NOT NULL COMMENT '连接跨服竞技场的区服编号',
	cclubmatch_serverid int(11) NOT NULL COMMENT '连接跨服公会战的区服编号',
	cchat_serverid int(11) NOT NULL COMMENT '连接跨服聊天的区服编号',
	cthemeact_serverid int(11) NOT NULL COMMENT '连接主题编号活动的区服编号',
	ctxranking_serverid int(11) NOT NULL COMMENT '连接天选赛巅峰赛的区服编号',
	centerchat_serverid int(11) NOT NULL COMMENT '连接同省聊天的区服编号',
	PRIMARY KEY (server_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
EOF
[ $? -eq 0 ] && echo "create table: game_server" || echo "exists table: game_server";

######################create table######################
mysql -hlocalhost -uroot -proot $dbname << EOF 2>>/dev/null
CREATE TABLE cross_server (
	server_id int(11) NOT NULL COMMENT '区服编号',
	node_ip varchar(16) NOT NULL COMMENT '给游戏服务器连接的ip(最好是内网ip)',
	node_port smallint unsigned NOT NULL COMMENT '给游戏服务器连接的端口',
	is_startup_cadvarena bool NOT NULL DEFAULT false COMMENT '是否开启跨服竞技场',
	is_startup_cclubmatch bool NOT NULL DEFAULT false COMMENT '是否开启跨服公会战',
	is_startup_cchat bool NOT NULL DEFAULT false COMMENT '是否开启跨服聊天',
	is_startup_cthemeact bool NOT NULL DEFAULT false COMMENT '是否开启主题活动',
	is_startup_ccenter bool NOT NULL DEFAULT false COMMENT '是否开启跨服中心服',
	is_startup_ctxranking bool NOT NULL DEFAULT false COMMENT '是否开启天选赛巅峰赛',
	is_startup_centerchat bool NOT NULL DEFAULT false COMMENT '是否开启同省聊天',
	is_startup_cmultpfcross bool NOT NULL DEFAULT false COMMENT '是否开启多平台跨服',
	is_startup_cmultpfcenter bool NOT NULL DEFAULT false COMMENT '是否开启多平台跨服中心服',
	ccenter_serverid int(11) COMMENT '连接跨服中心服的区服编号',
	cmultpfcenter_serverid int(11) COMMENT '连接多平台跨服中心服的区服编号',
	PRIMARY KEY (server_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
EOF
[ $? -eq 0 ] && echo "create table: cross_server" || echo "exists table: cross_server";

######################create table######################
mysql -hlocalhost -uroot -proot $dbname << EOF 2>>/dev/null
CREATE TABLE servernames (
	id int(11) NOT NULL AUTO_INCREMENT,
	serverid int(11) NOT NULL COMMENT '区服编号',
	pf int(11) NOT NULL COMMENT '平台编号',
	servername varchar(64) NOT NULL COMMENT '区服名字',
	PRIMARY KEY (id)
	UNIQUE serverid_pf(serverid, pf),
	KEY pf (pf)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
EOF
[ $? -eq 0 ] && echo "create table: servernames" || echo "exists table: servernames";

######################create table######################
mysql -hlocalhost -uroot -proot $dbname << EOF 2>>/dev/null
CREATE TABLE filterword (
	id int(11) unsigned NOT NULL AUTO_INCREMENT,
	name varchar(50) NOT NULL COMMENT '屏蔽字',
	PRIMARY KEY (id) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=18 DEFAULT CHARSET=utf8 COMMENT='屏蔽词表';
EOF
[ $? -eq 0 ] && echo "create table: filterword" || echo "exists table: filterword";

######################create table######################
mysql -hlocalhost -uroot -proot $dbname << EOF 2>>/dev/null
CREATE TABLE battle_server (
	server_id int(11) NOT NULL COMMENT '区服名字',
	node_ip varchar(16) COMMENT '给游戏服务器和跨服服务器连接的ip(最好使用内网ip)',
	node_port smallint unsigned COMMENT '给游戏服务器和跨服服务器连接的端口',
	pfid int(11) NOT NULL COMMENT '平台id',
	pfname varchar(128) DEFAULT NULL COMMENT '平台名',
	PRIMARY KEY (server_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
EOF
[ $? -eq 0 ] && echo "create table: battle_server" || echo "exists table: battle_server";

######################create table######################
mysql -hlocalhost -uroot -proot $dbname << EOF 2>>/dev/null
CREATE TABLE delete_record_rebate (
	account varchar(64) NOT NULL DEFAULT '' COMMENT '玩家账号',
	recharge int(11) NOT NULL DEFAULT '0' COMMENT '充值金额',
	pfid int(11) NOT NULL COMMENT '平台id',
	rebate_serverid int(11) NOT NULL COMMENT '0' COMMENT '返还区服id',
	PRIMARY KEY (account) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='删档充值返还表';
EOF
[ $? -eq 0 ] && echo "create table: delete_record_rebate" || echo "exists table: delete_record_rebate";

######################create table######################
mysql -hlocalhost -uroot -proot $dbname << EOF 2>>/dev/null
CREATE TABLE shield_word (
	id int(11) unsigned NOT NULL AUTO_INCREMENT,
	name varchar(50) NOT NULL COMMENT '防拉人词',
	PRIMARY KEY (id) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=18 DEFAULT CHARSET=utf8 COMMENT='防拉人词表';
EOF
[ $? -eq 0 ] && echo "create table: shield_word" || echo "exists table: shield_word";

######################create table######################
mysql -hlocalhost -uroot -proot $dbname << EOF 2>>/dev/null
CREATE TABLE small_game_open (
	corp_id int(11) unsigned NOT NULL AUTO_INCREMENT,
	game_id int(11) NOT NULL COMMENT '小游戏id',
	game_state int(11) NOT NULL COMMENT '小游戏状态',
	PRIMARY KEY (corp_id) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=18 DEFAULT CHARSET=utf8 COMMENT='小游戏开启表';
EOF
[ $? -eq 0 ] && echo "create table: small_game_open" || echo "exists table: small_game_open";

######################create table######################
mysql -hlocalhost -uroot -proot $dbname << EOF 2>>/dev/null
CREATE TABLE game_red_packet (
	corp_id int(11) unsigned NOT NULL,
	channel_id int(11) unsigned NOT NULL,
	shart_date int(11) NOT NULL COMMENT '开始日期',
	end_date int(11) NOT NULL COMMENT '结束日期',
	act_state int(11) NOT NULL COMMENT '活动状态 0:挂壁 1:开启',
	PRIMARY KEY (corp_id, channel_id) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=18 DEFAULT CHARSET=utf8 COMMENT='小游戏红包';
EOF
[ $? -eq 0 ] && echo "create table: game_red_packet" || echo "exists table: game_red_packet";

######################create table######################
mysql -hlocalhost -uroot -proot $dbname << EOF 2>>/dev/null
CREATE TABLE wechat_share (
	account varchar(64) NOT NULL COMMENT '玩家账号',
	corp_id int(11) unsigned NOT NULL COMMENT '平台id',
	server_id int(11) NOT NULL COMMENT '服务器id',
	yard_id varchar(64) NOT NULL COMMENT '分享码',
	set_time int(64) NOT NULL COMMENT '设置时间',
	PRIMARY KEY (account, corp_id) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=18 DEFAULT CHARSET=utf8 COMMENT='微信分享';
EOF
[ $? -eq 0 ] && echo "create table: wechat_share" || echo "exists table: wechat_share";

######################create table######################
mysql -hlocalhost -uroot -proot $dbname << EOF 2>>/dev/null
CREATE TABLE corp_act_info (
	id int(11) unsigned NOT NULL AUTO_INCREMENT,
	corp_id int(11) unsigned NOT NULL COMMENT '平台id',
	act_type int(11) unsigned NOT NULL COMMENT '活动类型',
	open_state int(11) unsigned NOT NULL COMMENT '开启状态 0:关闭 1:开启',
	limit_info text NOT NULL COMMENT '限制数据',
	PRIMARY KEY (id) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=18 DEFAULT CHARSET=utf8 COMMENT='平台活动';
EOF
[ $? -eq 0 ] && echo "create table: corp_act_info" || echo "exists table: corp_act_info";

######################create table######################
mysql -hlocalhost -uroot -proot $dbname << EOF 2>>/dev/null
CREATE TABLE corp_shield_world_pf_100 (
	id int(11) unsigned NOT NULL AUTO_INCREMENT,
	name varchar(50) NOT NULL COMMENT '屏蔽字',
	PRIMARY KEY (id) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=18 DEFAULT CHARSET=utf8 COMMENT='平台防拉人字库';
EOF
[ $? -eq 0 ] && echo "create table: corp_shield_world_pf_100" || echo "exists table: corp_shield_world_pf_100";

######################create table######################
mysql -hlocalhost -uroot -proot $dbname << EOF 2>>/dev/null
CREATE TABLE corp_shield_rule (
	corp_name varchar(50) NOT NULL COMMENT '平台名字',
	limit_info text NOT NULL COMMENT '限制数据',
	PRIMARY KEY (corp_name) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=18 DEFAULT CHARSET=utf8 COMMENT='平台防止拉人规则';
EOF
[ $? -eq 0 ] && echo "create table: corp_shield_rule" || echo "exists table: corp_shield_rule";

######################create table######################
mysql -hlocalhost -uroot -proot $dbname << EOF 2>>/dev/null
CREATE TABLE corp_account_banned (
	account varchar(50) NOT NULL COMMENT '账号',
	corp_id int(11) unsigned NOT NULL COMMENT '平台id',
	relieve_time int(11) unsigned NOT NULL COMMENT '解封时间戳 0:永久封禁',
	PRIMARY KEY (corp_name) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=18 DEFAULT CHARSET=utf8 COMMENT='平台账号禁言';
EOF
[ $? -eq 0 ] && echo "create table: corp_account_banned" || echo "exists table: corp_account_banned";

######################create table######################
mysql -hlocalhost -uroot -proot $dbname << EOF 2>>/dev/null
CREATE TABLE merge_serverinfo (
	server_id int(11) NOT NULL COMMENT '服务器id',
	serverlist mediumtext NOT NULL COMMENT '服务器信息列表',
	PRIMARY KEY (server_id)
) ENGINE=InnoDB AUTO_INCREMENT=18 DEFAULT CHARSET=utf8 COMMENT='合服信息';
EOF
[ $? -eq 0 ] && echo "create table: merge_serverinfo" || echo "exists table: merge_serverinfo";

######################create 所有小游戏活动######################
mysql -hlocalhost -uroot -proot $dbname << EOF 2>>/dev/null
CREATE TABLE all_samll_game_act (
	id int(11) unsigned NOT NULL AUTO_INCREMENT,
	corp_id int(11) unsigned NOT NULL COMMENT '平台id',
	act_type int(11) unsigned NOT NULL COMMENT '活动类型',
	open_state int(11) unsigned NOT NULL COMMENT '活动状态 0:关闭 1:开启',
	limit_info text NOT NULL '限制数据',
	PRIMARY KEY (id) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=18 DEFAULT CHARSET=utf8 COMMENT='平台活动';
EOF
[ $? -eq 0 ] && echo "create table: all_samll_game_act" || echo "exists table: all_samll_game_act";

######################create 马甲包配置######################
mysql -hlocalhost -uroot -proot $dbname << EOF 2>>/dev/null
CREATE TABLE other_setting_dir (
	id int(11) unsigned NOT NULL AUTO_INCREMENT,
	s_server_id int(11) unsigned NOT NULL COMMENT '开始服务器id',
	e_server_id int(11) unsigned NOT NULL COMMENT '开始服务器id',
	directory varchar(50) NOT NULL COMMENT '目录',
	PRIMARY KEY (id) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=18 DEFAULT CHARSET=utf8 COMMENT='马甲包配置';
EOF
[ $? -eq 0 ] && echo "create table: other_setting_dir" || echo "exists table: other_setting_dir";
