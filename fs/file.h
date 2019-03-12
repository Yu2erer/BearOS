#ifndef __FS_FILE_H
#define __FS_FILE_H
#include "stdint.h"
#include "inode.h"

// 文件结构
struct file {
    uint32_t fd_pos; // 当前文件操作的偏移量
    uint32_t fd_flag;
    struct inode* fd_inode;
};

// 标准输入输出描述符
enum std_fd {
    stdin_no, 
    stdout_no,
    stderr_no
};

// 位图类型
enum bitmap_type {
    INODE_BITMAP, // inode 位图
    BLOCK_BITMAP // 块位图
};

#define MAX_FILE_OPEN 32 // 系统最大可打开文件数

#endif