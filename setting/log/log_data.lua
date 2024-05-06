--R--日志数据.xlsx - 日志
LogData={
    ["reward_bindyuanbao"] = {
        IsRoleInfo = 1,
        Indexs = {{"timestamp"}},
        Field = {
            ["bindyuanbao"] = {
                TableName="reward_bindyuanbao", IsRoleInfo=1, Indexs={{"timestamp"}}, Field="bindyuanbao", FieldType="int(11)", FieldDesc="获得绑定元宝",
            },
            ["rewardno"] = {
                TableName="reward_bindyuanbao", IsRoleInfo=1, Indexs={{"timestamp"}}, Field="rewardno", FieldType="int(11)", FieldDesc="奖励编号",
            },
            ["way"] = {
                TableName="reward_bindyuanbao", IsRoleInfo=1, Indexs={{"timestamp"}}, Field="way", FieldType="varchar(128)", FieldDesc="产出信息",
            },
        }
    },
    ["role_logout_err"] = {
        IsRoleInfo = 1,
        Indexs = {{"timestamp"}},
        Field = {
            ["err"] = {
                TableName="role_logout_err", IsRoleInfo=1, Indexs={{"timestamp"}}, Field="err", FieldType="text", FieldDesc="错误信息",
            },
        },
    },
}