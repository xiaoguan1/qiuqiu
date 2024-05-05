--T--同步数据表.xlsx - 数据表
SyncData={
    ["role_heros"] = {
        Primary={"hero_sid"},
        Field = {
            ["server_id"] = {
                TableName="role_heros",Primary={"hero_sid"},Field="server_id",FieldType="int(11)",FieldDesc="角色区服",Dupdate=0,RoleData="ServerId",
            },
            ["uid"] = {
                TableName="role_heros",Primary={"hero_sid"},Field="uid",FieldType="varchar(32)",FieldDesc="角色ID",Dupdate=0,RoleData="Uid",
            },
            ["hero_sid"] = {
                TableName="role_heros",Primary={"hero_sid"},Field="hero_sid",FieldType="varchar(64)",FieldDesc="英雄SID",Dupdate=0,
            },
            ["hero_no"] = {
                TableName="role_heros",Primary={"hero_sid"},Field="hero_no",FieldType="int(11)",FieldDesc="英雄号",Dupdate=0,
            },
            ["hero_rare"] = {
                TableName="role_heros",Primary={"hero_sid"},Field="hero_rare",FieldType="int(11)",FieldDesc="英雄品质",Dupdate=0,
            },
            ["hero_grade"] = {
                TableName="role_heros",Primary={"hero_sid"},Field="hero_grade",FieldType="int(11)",FieldDesc="英雄等级",Dupdate=1,
            },
            ["exclusive_grade"] = {
                TableName="role_heros",Primary={"hero_sid"},Field="exclusive_grade",FieldType="int(11)",FieldDesc="英雄专属武器等",Dupdate=0,
            },
        },
    },
    ["role_formation"] = {
        Primary={"uid", "battle_type", "ad_type"},
        Field = {
            ["server_id"] = {
                TableName="role_formation",Primary={"uid", "battle_type", "ad_type"},Field="server_id",FieldType="int(11)",FieldDesc="角色区服",Dupdate=0,RoleData="ServerId",
            },
            ["uid"] = {
                TableName="role_formation",Primary={"uid", "battle_type", "ad_type"},Field="uid",FieldType="varchar(32)",FieldDesc="角色ID",Dupdate=0,
            },
            ["vip"] = {
                TableName="role_formation",Primary={"uid", "battle_type", "ad_type"},Field="vip",FieldType="int(11)",FieldDesc="VIP等级",Dupdate=1,
            },
            ["battle_type"] = {
                TableName="role_formation",Primary={"uid", "battle_type", "ad_type"},Field="battle_type",FieldType="int(11)",FieldDesc="战斗类型",Dupdate=0,
            },
            ["ad_type"] = {
                TableName="role_formation",Primary={"uid", "battle_type", "ad_type"},Field="ad_type",FieldType="int(11)",FieldDesc="进攻/防守",Dupdate=0,
            },
            ["formation"] = {
                TableName="role_formation",Primary={"uid", "battle_type", "ad_type"},Field="formation",FieldType="text",FieldDesc="站位信息",Dupdate=1,
            },
        },
    },
}