#!/bin/bash

lua ./gen_proto/network_proto.lua
lua ./gen_proto/database_proto.lua

echo "proto script run finish!"