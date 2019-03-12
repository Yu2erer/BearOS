#ifndef __FS_DIR_H
#define __FS_DIR_H
#include "stdint.h"
#include "inode.h"
#include "ide.h"
#include "global.h"
#include "fs.h"

#define MAX_FILE_NAME_LEN 16 // 最大文件名长度

struct dir {
    struct inode* inode;
    uint32_t dir_pos; // 在目录内的偏移
    uint8_t dir_buf[512]; // 目录数据缓存
};

struct dir_entry {
    char filename[MAX_FILE_NAME_LEN];
    uint32_t i_no;
    enum file_types f_type;
};
#endif