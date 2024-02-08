#include "skynet_log_svccpu.h"
#include "skynet_timer.h"
#include "skynet.h"
#include "skynet_socket.h"
#include <string.h>
#include <time.h>

#include <stdlib.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>
#include <sys/time.h>

static int
create_dir(const char *path_name) {
	char dir_name[FILENAME_MAX + 1];
	strcpy(dir_name, path_name);
	int i, len = strlen(dir_name);
	for ( i = 1; i < len; ++i) {
		if (dir_name[i] == '/') {
			dir_name[i] = 0;
			if (access(dir_name, W_OK) != 0) {
				if (mkdir(dir_name, S_IRWXU | S_IRWXG | S_IROTH | S_IXOTH) == -1) {
					return -1;
				}
			}
			dir_name[i] = '/';
		}
	}
	return 0;
}

static FILE *
try_openfile(const char *file_name){
	create_dir(file_name);
	FILE *file = fopen(file_name, "ab");
	return file;
}

FILE *
skynet_log_svccpu_open(struct skynet_context *ctx, uint32_t handle, const char *param){
	const char * logpath = skynet_getenv("log_svccpu_path");
	if (logpath == NULL)
		return NULL;
	size_t sz = strlen(logpath);
	char tmp[sz + 100];
	sprintf(tmp, "%s/%s_%08x.log", logpath, param, handle);
	FILE *f = try_openfile(tmp);	// fopen(tmp, "ab")
	if (f) {
		skynet_error(ctx, "Open log file %s", tmp);
		fflush(f);
	} else {
		skynet_error(ctx, "Open log file %s fail", tmp);
	}
	return f;
}

void
skynet_log_svccpu_close(struct skynet_context *ctx, FILE *f, uint32_t handle){
	skynet_error(ctx, "Close log file :%08x", handle);
	fclose(f);
}

void
skynet_log_svccpu_output(FILE *f, uint32_t source, int type, int session, uint64_t cost_time){
	uint32_t starttime = skynet_starttime();
	uint64_t currenttime = skynet_now();
	uint32_t ti = (starttime + currenttime / 100);

	fprintf(f, "%d %ld :%08x %d %d\n", ti, cost_time, source, type, session);
	fflush(f);
}

static void
log_blob(FILE *f, void *buffer, size_t sz) {
	size_t i;
	uint8_t *buf = buffer;
	for (i = 0; i != sz; i++) {
		fprintf(f, "%02x", buf[i]);
	}
}

static void
log_socket(FILE *f, struct skynet_socket_message *message, size_t sz) {
	fprintf(f, "[socket] %d %d %d", message->type, message->id, message->ud);

	if (message->buffer == NULL) {
		const char *buffer = (const char *)(message + 1);
		sz -= sizeof(*message);
		const char *eol = memchr(buffer, '\0', sz);
		if (eol) {
			sz = eol - buffer;
		}
		fprintf(f, "[%*s]", (int)sz, (const char *)buffer);
	} else {
		sz = message->ud;
		log_blob(f, message->buffer, sz);
	}
}

void
skynet_log_svccpu_output_data(FILE *f, uint32_t source, int type, int session, uint64_t cost_time, void *buffer, size_t sz) {
	uint32_t starttime = skynet_starttime();
	uint64_t currenttime = skynet_now();
	uint32_t ti = (starttime + currenttime / 100);

	fprintf(f, "%d %ld :%08x %d %d\n", ti, cost_time, source, type, session);
	if (type == PTYPE_SOCKET) {
		log_socket(f, buffer, sz);
	} else {
		log_blob(f, buffer, sz);
	}
	fprintf(f, "\n");
	fflush(f);
}
