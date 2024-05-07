#!/bin/bash

dbname=$1

read -p "delete dbname:<<$dbname>> tables, input yes to __detele__:" isTrue

if ["$isTrue"x == "yes"x]; then
    echo "input error!!!"
    exit
fi