#include "stdio-kernel.h"
#include "stdio.h"
#include "../../device/console.h"
#include "print.h"
#include "global.h"

#define va_start(ap, format) ap = (va_list)&format
#define va_end(ap) ap = NULL

void printk(const char* format, ...) {
    va_list args;
    va_start(args, format);
    char buf[1024] = {0};
    vsprintf(buf, format, args);
    va_end(args);
    console_put_str(buf);
}
