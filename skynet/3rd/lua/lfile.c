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

// 识别文件类型
static int ltype (lua_State *L) {
	size_t sz = 0;
	const char* filepath = luaL_checklstring(L, 1, &sz);
	if (sz <= 0)
		return luaL_error(L, "please input file path!");

	struct stat buf;
	if (stat(filepath, &buf) != 0) {
		lua_pushnil(L);
		return 1;
	}

	if (S_ISDIR(buf.st_mode))			// 文件夹
		lua_pushstring(L, "dir");
	else if (S_ISREG(buf.st_mode))		// 一般文件
		lua_pushstring(L, "file");
	else if (S_ISSOCK(buf.st_mode))		// socket
		lua_pushstring(L, "sock");
	else if (S_ISLNK(buf.st_mode))		// 符号链接(符号链接文件)
		lua_pushstring(L, "lnk");
	else if (S_ISBLK(buf.st_mode))		// 区块装置(块设备)
		lua_pushstring(L, "blk");
	else if (S_ISCHR(buf.st_mode))		// 字符装置(字符设备)
		lua_pushstring(L, "chr");
	else if (S_ISFIFO(buf.st_mode))		// 先进先出(管道)
		lua_pushstring(L, "fifo");
	else
		return luaL_error(L, "unable to recognize file type!");

	return 1;
}

// 返回当前的路径的文件权限

/* }====================================================== */

LUAMOD_API int luaopen_file (lua_State *L) {
	luaL_Reg l[] = {
		{"type",		ltype},
		{NULL, 			NULL},
	};
	luaL_newlib(L, l);
	return 1;
}

/* }====================================================== */