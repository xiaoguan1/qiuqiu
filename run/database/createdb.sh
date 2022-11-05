#!/bin/bash

dbname=$1

# 重建数据库
mysql -hlocalhost -uroot -proot << EOF 2>/dev/null
DROP DATABASE if exists $dbname;
CREATE DATABASE $dbname default charset utf8mb4 COLLATE utf8mb4_general_ci;
EOF
[ $? -eq 0 ] && echo "create database: $dbname" || echo "exists database: $dbname";

# 重建表
mysql -hlocalhost -uroot -proot $dbname << EOF 2>/dev/null  # 记得连上数据库 $dbname
CREATE TABLE roles (
    account varchar(64) NOT NULL COMMENT '账号',
    passwd varchar(32) NOT NULL COMMENT '密码',
    PRIMARY KEY (account)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
EOF
[ $? -eq 0 ] && echo "create database: roles" || echo "exists database: roles";
