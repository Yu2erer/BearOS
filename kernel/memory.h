#ifndef __KERNEL_MEMORY_H
#define __KERNEL_MEMORY_H
#include "stdint.h"
#include "../lib/kernel/bitmap.h"
#include "list.h"

enum pool_flags {
    PF_KERNEL = 1,
    PF_USER = 2
};

#define PG_P_1 1 // PDE / PTE 是否存在
#define PG_P_0 0
#define PG_RW_R 0
#define PG_RW_W 2
#define PG_US_S 0 // 系统级
#define PG_US_U 4 // 用户级

// 虚拟地址
struct virtual_addr {
    struct bitmap vaddr_bitmap; // 虚拟地址用到的位图结构
    uint32_t vaddr_start; // 虚拟地址起始地址
};

// 内存块
struct mem_block {
    struct list_elem free_elem;
};
// 内存块描述符
struct mem_block_desc {
    uint32_t block_size; // 内存块大小
    uint32_t blocks_per_arena; // arena可容纳mem_block的数量
    struct list free_list;
};

#define DESC_CNT 7 // 内存块描述符个数

extern struct pool kernel_pool, user_pool;
void mem_init();
void* get_kernel_pages(uint32_t pg_cnt);
void* get_user_pages(uint32_t pg_cnt);
void* malloc_page(enum pool_flags pf, uint32_t pg_cnt);
uint32_t addr_v2p(uint32_t vaddr);
void malloc_init();
uint32_t* pte_ptr(uint32_t vaddr);
uint32_t* pde_ptr(uint32_t vaddr);
void* get_a_page(enum pool_flags pf, uint32_t vaddr);
void* get_user_pages(uint32_t pg_cnt);
void block_desc_init(struct mem_block_desc* desc_array);
void* sys_malloc(uint32_t size);
void mfree_page(enum pool_flags pf, void* _vaddr, uint32_t pg_cnt);
void pfree(uint32_t pg_phy_addr);
void sys_free(void* ptr);
#endif