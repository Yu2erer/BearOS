#ifndef __FS_FS_h
#define __FS_FS_h

#define MAX_FILES_PER_PART 4096 // 每个分区最大文件数
#define BITS_PER_SECTOR 4096 // 每扇区位数
#define SECTOR_SIZE 512 // 扇区字节大小
#define BLOCK_SIZE SECTOR_SIZE // 块字节大小

enum file_types {
    FT_UNKNOWN, 
    FT_REGULAR, // 普通文件
    FT_DIRECTOR // 目录
};

#endif