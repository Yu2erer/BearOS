#ifndef __DEVICE_IDE_H
#define __DEVICE_IDE_H
#include "stdint.h"
#include "../lib/kernel/list.h"
#include "bitmap.h"
#include "sync.h"

// 分区结构
struct partition {
    uint32_t start_lba; // 起始扇区
    uint32_t sec_cnt; // 扇区数
    struct disk* my_disk; // 分区所属硬盘
    struct list_elem part_tag; // 队列标记
    char name[8]; // 分区名
    struct super_block* sb; // 超级块
    struct bitmap block_bitmap; // 块位图
    struct bitmap inode_bitmap; // i 结点位图
    struct list open_inodes; // 本分区打开的i结点队列
};

struct disk {
    char name[8]; // 本硬盘名称
    struct ide_channel* my_channel; // 硬盘归属ide通道
    uint8_t dev_no; // 主0 从1
    struct partition prim_parts[4];
    struct partition logic_parts[8];
};
// ata 通道结构
struct ide_channel {
    char name[8]; // ata 通道名
    uint16_t port_base; // 通道起始端口号
    uint8_t irq_no; // 通道中断号
    struct lock lock; // 通道锁
    bool expecting_intr; // 是否等待硬盘的中断
    struct semaphore disk_done; // 阻塞唤醒驱动程序
    struct disk devices[2]; // 一个通道连接2个硬盘
};

void intr_hd_handler(uint8_t irq_no);
void ide_init();
extern uint8_t channel_cnt;
extern struct ide_channel channels[];
extern struct list partition_list;
void ide_read(struct disk* hd, uint32_t lba, void* buf, uint32_t sec_cnt);
void ide_write(struct disk* hd, uint32_t lba, void* buf, uint32_t sec_cnt);
#endif