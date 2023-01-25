#!/bin/bash

dbname=common_db

# 插入数据
mysql -hlocalhost -uroot -proot $dbname << EOF 2>/dev/null  # 记得连上数据库 $dbname
insert into server_config(server_id, main_node_ip, main_node_port, cluster_node_ip, cluster_node_port) values
("1", "127.0.0.1", "8001", "127.0.0.1", "7771"),
("2", "127.0.0.1", "8002", "127.0.0.1", "7772");
EOF
[ $? -eq 0 ] && echo "insert database: server_config" || echo "exists insert: server_config";