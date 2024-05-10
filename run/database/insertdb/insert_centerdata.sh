#!/bin/bash

dbname=$1

if [ "X$dbname" = "X" ]; then
    echo "input dbname"
    exit;
fi

############################ insert into table ############################
mysql -hlocalhost -uroot -proot $dbname << EOF 2>/dev/null
insert into game_server(server_id, main_node_ip, main_node_port, cadvarena_serverid, cclubmatch_serverid, cchat_serverid, cthemeact_serverid, ctxranking_serverid, centerchat_serverid) values
(1, "127.0.0.1", 32526, 55001, 55001, 55001, 55001, 55001, 55001),
(2, "127.0.0.1", 32538, 55002, 55002, 55002, 55002, 55002, 55002),
(3, "127.0.0.1", 32548, 55003, 55003, 55003, 55003, 55003, 55003),
(100, "127.0.0.1", 32526, 55001, 55001, 55001, 55001, 55001, 55001);
EOF
[ $? -eq 0 ] && echo "insert table: game_server ok" || echo "insert table: game_server error";

############################ insert into table ############################
mysql -hlocalhost -uroot -proot $dbname << EOF 2>/dev/null
insert into cross_server(server_id, node_ip, node_port, is_startup_cadvarena, is_startup_cclubmatch, is_startup_cchat, is_startup_cthemeact, is_startup_ccenter, is_startup_ctxranking, is_startup_centerchat, is_startup_cmultpfcross, is_startup_cmultpfcenter, ccenter_serverid, cmultpfcenter_serverid) values
(55001, "127.0.0.1", 32527, true, true, true, true, true, true, true, true, true, 55001, 55001),
(55002, "127.0.0.1", 32529, true, true, true, true, true, true, true, true, true, 55002, 55002),
(55003, "127.0.0.1", 32530, true, true, true, true, true, true, true, true, true, 55003, 55003),
(55004, "127.0.0.1", 32531, true, true, true, true, true, true, true, true, true, 55004, 55004);
EOF
[ $? -eq 0 ] && echo "insert table: cross_server ok" || echo "insert table: cross_server error";

############################ insert into table ############################
mysql -hlocalhost -uroot -proot $dbname << EOF 2>/dev/null
insert into servernames(serverid, pf, servername) values
(1, 100, "s1"), (1, 101, "s1"), (1, 5276, "s1"),
(2, 100, "s2"), (2, 101, "s2"), (2, 5276, "s2"),
(3, 100, "s3"), (3, 101, "s2"), (3, 5276, "s3"),
(100, 100, "s100"), (100, 101, "s100"), (100, 5276, "s100");
EOF
[ $? -eq 0 ] && echo "insert table: servernames ok" || echo "insert table: servernames error";

############################ insert into table ############################
mysql -hlocalhost -uroot -proot $dbname << EOF 2>/dev/null
insert into battle_server(server_id, node_ip, node_port, pfid, pfname) values
(10001, "127.0.0.1", 18001, 100, "测试"),
(10002, "10.10.2.223", 18001, 100, "测试"),
(10003, "10.10.2.187", 18001, 100, "测试"),
(10004, "10.10.2.131", 18001, 100, "测试"),
(10005, "10.10.2.148", 18001, 100, "测试"),
(10006, "10.10.2.222", 18001, 100, "测试");
EOF
[ $? -eq 0 ] && echo "insert table: battle_server ok" || echo "insert table: battle_server error";

############################ insert into table ############################
mysql -hlocalhost -uroot -proot $dbname << EOF 2>/dev/null
insert into small_game_open(corp_id, game_id, game_state, grade) values
(100, 1, 0, 20);
EOF
[ $? -eq 0 ] && echo "insert table: small_game_open ok" || echo "insert table: small_game_open error";

############################ insert into table ############################
mysql -hlocalhost -uroot -proot $dbname << EOF 2>/dev/null
insert into game_red_packet(corp_id, channel_id, start_date, end_date, act_state) values
(100, 0, 1644519421, 1644619421, 1);
EOF
[ $? -eq 0 ] && echo "insert table: game_red_packet ok" || echo "insert table: game_red_packet error";

############################ insert into table ############################
mysql -hlocalhost -uroot -proot $dbname << EOF 2>/dev/null
insert into corp_act_info(id, corp_id, act_type, open_state, limit_info) values
(1, 0, 1, 0, '{"s_server_id":1, "e_server_id":10, "m_grade":0}'),
(2, 100, 1, 1, '{"s_server_id":1, "e_server_id":10, "m_grade":0}');
EOF
[ $? -eq 0 ] && echo "insert table: corp_act_info ok" || echo "insert table: corp_act_info error";

############################ insert into table ############################
mysql -hlocalhost -uroot -proot $dbname << EOF 2>/dev/null
insert into corp_shield_world_pf_100(id, name) values
(1, "年后")
EOF
[ $? -eq 0 ] && echo "insert table: corp_shield_world_pf_100 ok" || echo "insert table: corp_shield_world_pf_100 error";

############################ insert into table ############################
mysql -hlocalhost -uroot -proot $dbname << EOF 2>/dev/null
insert into corp_shield_rule(corp_name, limit_Info) values
("pf_100", '{"OtherShieldGrade":40, "CommRoleGrade":25, "VipShieldWard":{"0":{"MinVip":0,"VIPGrade":0},"1":{"MinVip":0,"VIPGrade":1}}, "BannedGrade":45}'),
("all", '{"OtherShieldGrade":40, "CommRoleGrade":25, "VipShieldWard":{"0":{"MinVip":0,"VIPGrade":0},"1":{"MinVip":0,"VIPGrade":1}}, "BannedGrade":45}');
EOF
[ $? -eq 0 ] && echo "insert table: corp_shield_rule ok" || echo "insert table: corp_shield_rule error";

############################ insert into table ############################
mysql -hlocalhost -uroot -proot $dbname << EOF 2>/dev/null
insert into corp_account_banned(account, corp_id, relieve_time) values
("t_t", 100, 0)
EOF
[ $? -eq 0 ] && echo "insert table: corp_account_banned ok" || echo "insert table: corp_account_banned error";

############################ insert into table ############################
mysql -hlocalhost -uroot -proot $dbname << EOF 2>/dev/null
insert into all_samll_game_act(id, corp_id, act_type, open_state, limit_info) values
(1, 0, 1001, 1, '{"s_server_id":1, "e_server_id":10, "s_grade":0, "e_grade":100}'),
(2, 0, 1102, 1, '{"s_server_id":1, "e_server_id":10, "s_grade":0, "e_grade":100}'),
(3, 0, 1103, 1, '{"s_server_id":1, "e_server_id":10, "s_grade":0, "e_grade":100}');
EOF
[ $? -eq 0 ] && echo "insert table: all_samll_game_act ok" || echo "insert table: all_samll_game_act error";

############################ insert into table ############################
mysql -hlocalhost -uroot -proot $dbname << EOF 2>/dev/null
insert into other_setting_dir(id, s_server_id, e_server_id, directory) values
("1", 100, 111, "001");
EOF
[ $? -eq 0 ] && echo "insert table: other_setting_dir ok" || echo "insert table: other_setting_dir error";
