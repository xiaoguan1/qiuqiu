#ifndef skynet_log_svccpu_h
#define skynet_log_svccpu_h

#include "skynet_env.h"
#include "skynet.h"

#include <stdio.h>
#include <stdint.h>

FILE * skynet_log_svccpu_open(struct skynet_context *ctx, uint32_t handle, const char *param);
void skynet_log_svccpu_close(struct skynet_context *ctx, FILE *f, uint32_t handle);
void skynet_log_svccpu_output(FILE *f, uint32_t source, int type, int session, uint64_t cost_time);
void skynet_log_svccpu_output_data(FILE *f, uint32_t source, int type, int session, uint64_t cost_time, void *buffer, size_t sz);

#endif
