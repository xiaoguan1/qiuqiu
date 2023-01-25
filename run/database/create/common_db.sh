#!/bin/bash

dbname=common_db

# 重建数据库
mysql -hlocalhost -uroot -proot << EOF 2>/dev/null
DROP DATABASE if exists $dbname;
CREATE DATABASE $dbname default charset utf8mb4 COLLATE utf8mb4_general_ci;
EOF
[ $? -eq 0 ] && echo "create database: $dbname" || echo "exists database: $dbname";

# 重建表
mysql -hlocalhost -uroot -proot $dbname << EOF 2>/dev/null  # 记得连上数据库 $dbname
CREATE TABLE server_config (
    server_id varchar(64) NOT NULL COMMENT '服务器id',
    main_node_ip varchar(64) NOT NULL COMMENT '服务器ip',
    main_node_port varchar(64) NOT NULL COMMENT '服务器port',
    cluster_node_ip varchar(64) NOT NULL COMMENT '集群ip',
    cluster_node_port varchar(64) NOT NULL COMMENT '集群port',
    PRIMARY KEY (server_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
EOF
[ $? -eq 0 ] && echo "create database: server_config" || echo "exists database: server_config";