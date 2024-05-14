/**
 * 创建日期:2024/05/13
 * 创建者:guanguowei
 * 作用:lua的文件库
*/

#define LUA_LIB

#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"
#include <sys/stat.h>
#include <string.h>

// 获取文件的详细信息(文件类型、文件权限)
static int ldetailed (lua_State *L) {
	const char* filepath = luaL_checkstring(L, 1);

	struct stat buf;
	if (stat(filepath, &buf) != 0) {
		lua_pushnil(L);
		return 1;
	}

	const char * ftype;
	if (S_ISDIR(buf.st_mode))			// 文件夹
		ftype = "dir";
	else if (S_ISREG(buf.st_mode))		// 一般文件
		ftype = "file";
	else if (S_ISSOCK(buf.st_mode))		// socket
		ftype = "sock";
	else if (S_ISLNK(buf.st_mode))		// 符号链接(符号链接文件)
		ftype = "lnk";
	else if (S_ISBLK(buf.st_mode))		// 区块装置(块设备)
		ftype = "blk";
	else if (S_ISCHR(buf.st_mode))		// 字符装置(字符设备)
		ftype = "chr";
	else if (S_ISFIFO(buf.st_mode))		// 先进先出(管道)
		ftype = "fifo";
	else
		return luaL_error(L, "unable to recognize file type!");

	// 将权限数值转换成字符串
	mode_t modet = buf.st_mode & (S_IRWXU | S_IRWXG | S_IRWXO);
	char str[] = {
		[0] = (modet & S_IRUSR) ? 'r' : '-',
		[1] = (modet & S_IWUSR) ? 'w' : '-',
		[2] = (modet & S_IXUSR) ? 'x' : '-',
		[3] = (modet & S_IRGRP) ? 'r' : '-',
		[4] = (modet & S_IWGRP) ? 'w' : '-',
		[5] = (modet & S_IXGRP) ? 'x' : '-',
		[6] = (modet & S_IROTH) ? 'r' : '-',
		[7] = (modet & S_IWOTH) ? 'w' : '-',
		[8] = (modet & S_IXOTH) ? 'x' : '-',
		[9] = '\0'
	};

	lua_createtable(L, 0, 3);

	lua_pushstring(L, "type");
	lua_pushstring(L, ftype);
	lua_settable(L, 2);

	lua_pushstring(L, "mode");
	lua_pushstring(L, str);
	lua_settable(L, 2);

	lua_pushstring(L, "modet");
	lua_pushinteger(L, modet);
	lua_settable(L, 2);

	return 1;
}

// 修改文件的权限
static int lfchmod(lua_State *L) {
	const char* filepath = luaL_checkstring(L, 1);

	struct stat buf;
	if (stat(filepath, &buf) != 0)
		return luaL_error(L, "open file error!");

	size_t cmdLen;
	const char* strcmd = luaL_checklstring(L, 2, &cmdLen);
	if (cmdLen != 9)
		return luaL_error(L, "please chmod length error");

	mode_t modet = 0;
	int i;
	for (i = 0; i < 9; i++) {
		char c = strcmd[i];
		if (c == '-')
			continue;

		if (c == 'r' && i == 0)
			modet |= S_IRUSR;
		else if (c == 'w' && i == 1)
			modet |= S_IWUSR;
		else if (c == 'x' && i == 2)
			modet |= S_IXUSR;
		else if (c == 'r' && i == 3)
			modet |= S_IRGRP;
		else if (c == 'w' && i == 4)
			modet |= S_IWGRP;
		else if (c == 'x' && i == 5)
			modet |= S_IXGRP;
		else if (c == 'r' && i == 6)
			modet |= S_IROTH;
		else if (c == 'w' && i == 7)
			modet |= S_IWOTH;
		else if (c == 'x' && i == 8)
			modet |= S_IXOTH;
		else
			return luaL_error(L, "setting File permission parameter error!");
	}

	// 修改文件权限
	if (chmod(filepath, modet) != 0)
		return luaL_error(L, "set file permissions failed!");

	return 0;
}


/* }====================================================== */

LUAMOD_API int luaopen_file (lua_State *L) {
	luaL_Reg l[] = {
		{"detailed",	ldetailed},
		{"chmod", 		lfchmod},
		{NULL, 			NULL},
	};
	luaL_newlib(L, l);
	return 1;
}

/* }====================================================== */