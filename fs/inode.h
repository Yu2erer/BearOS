#ifndef __FS_INODE_H
#define __FS_INODE_H
#include "stdint.h"
#include "list.h"

struct inode {
    uint32_t i_no; // inode 编号
    uint32_t i_size; // 若为目录 则指该目录下所有文件之和
    uint32_t i_open_cnts; // 记录此文件被打开次数
    bool write_deny; // 写文件不能并行 写文件前检查此标记
    uint32_t i_sectors[13]; // 0-11 直接快 12 一级间接块指针
    struct list_elem inode_tag;
};

#endif