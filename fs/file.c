#include "file.h"
#include "stdio-kernel.h"

// 文件表
struct file file_table[MAX_FILE_OPEN];

// 从文件表中找一个空位
int32_t get_file_slot_in_global() {
    uint32_t fd_idx = 3;
    while (fd_idx < MAX_FILE_OPEN) {
        if (file_table[fd_idx].fd_inode == NULL) {
            break;
        }
        fd_idx++;
    }
    if (fd_idx == MAX_FILE_OPEN) {
        printk("exceed max open files\n");
        return -1;
    }
    return fd_idx;
}

int32_t pcb_fd_install(int32_t globa_fd_idx) {
    
}