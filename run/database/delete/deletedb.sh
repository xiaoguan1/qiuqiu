#!/bin/bash

dbname=$1

read -p "delete dbname:<<$dbname>> tables, input yes to __detele__:" isTrue

if ["$isTrue"x == "yes"x]; then
    echo "input error!!!"
    exit
fi

mysql -hlocalhost -uroot -proot $dbname << EOF 2 >>/dev/null
delete from globalusr;
EOF
[ $? eq 0 ] && echo "delete table globalusr ok" || echo "delete table globalusr fail";

mysql -hlocalhost -uroot -proot $dbname << EOF 2 >>/dev/null
delete from list;
EOF
[ $? eq 0 ] && echo "delete table list ok" || echo "delete table list fail";

mysql -hlocalhost -uroot -proot $dbname << EOF 2 >>/dev/null
delete from role_data;
EOF
[ $? eq 0 ] && echo "delete table role_data ok" || echo "delete table role_data fail";

mysql -hlocalhost -uroot -proot $dbname << EOF 2 >>/dev/null
delete from role;
EOF
[ $? eq 0 ] && echo "delete table role ok" || echo "delete table role fail";

mysql -hlocalhost -uroot -proot $dbname << EOF 2 >>/dev/null
delete from module;
EOF
[ $? eq 0 ] && echo "delete table module ok" || echo "delete table module fail";

mysql -hlocalhost -uroot -proot $dbname << EOF 2 >>/dev/null
delete from setting;
EOF
[ $? eq 0 ] && echo "delete table setting ok" || echo "delete table setting fail";

mysql -hlocalhost -uroot -proot $dbname << EOF 2 >>/dev/null
delete from battlerecord;
EOF
[ $? eq 0 ] && echo "delete table battlerecord ok" || echo "delete table battlerecord fail";