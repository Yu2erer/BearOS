%include "boot.inc"
SECTION loader vstart=LOADER_BASE_ADDR
    LOADER_STACK_TOP equ LOADER_BASE_ADDR

; 构建 GDT 及内部描述符
    GDT_BASE: dd 0x00000000
                dd 0x00000000
    CODE_DESC: dd 0x0000FFFF
                dd DESC_CODE_HIGH4
    DATA_STACK_DESC: dd 0x0000FFFF
                        dd DESC_DATA_HIGH4
    VIDEO_DESC: dd 0x80000007  ; 0xbffff - 0xb8000 / 4k = 0x7
                    dd DESC_VIDEO_HIGH4 
    GDT_SIZE equ $ - GDT_BASE
    GDT_LIMIT equ GDT_SIZE - 1
    times 60 dq 0 ; 预留 60个 描述符空位
    ; 选择子
    SELECTOR_CODE equ (0x0001 << 3) + TI_GDT + RPL0
    SELECTOR_DATA equ (0x0002 << 3) + TI_GDT + RPL0
    SELECTOR_VIDEO equ (0x0003 << 3) + TI_GDT + RPL0

    total_mem_bytes dd 0 ; 这里偏移前面是 0x200 实际位置再0xb00	 
    ; GDT 指针
    gdt_ptr dw GDT_LIMIT
                dd GDT_BASE
                
    ; 手工对齐至0x300:total_mem_bytes 4 + 6 + 244 + 2 = 256 = 0x100
    ards_buf times 244 db 0
    ards_nr dw 0 ; ARDS结构体数量

loader_start:
; int 15h eax = 0000E820h ebx=0 edx=534D4150h ('SMAP') 获取内存布局
   xor ebx, ebx
   mov edx, 0x534d4150
   mov di, ards_buf	      ; ARDS结构缓冲区
.e820_mem_get_loop:
   mov eax, 0x0000e820	      ; eax会变0x534d4150 重置
   mov ecx, 20		      ; ARDS地址范围描述符结构大小是20字节
   int 0x15
   jc .e820_failed_so_try_e801   ; CF 为1则有错
   add di, cx		      ; di增加20字节指向缓冲区中新的ARDS结构位置
   inc word [ards_nr]	      ; ARDS数量
   cmp ebx, 0		      ; 若ebx为0 且 cf不为1 已是最后一个
   jnz .e820_mem_get_loop

   mov cx, [ards_nr]
   mov ebx, ards_buf
   xor edx, edx
.find_max_mem_area: ; 无须判断type是否为1,最大的内存块一定是可被使用
   mov eax, [ebx] ; BaseAddrLow
   add eax, [ebx+8] ; LengthAddrLow
   add ebx, 20 ; 指向缓冲区中下一个ARDS结构
   cmp edx, eax		      
; 冒泡排序 找出最大
   jge .next_ards
   mov edx, eax
.next_ards:
   loop .find_max_mem_area
   jmp .mem_get_ok
.e820_failed_so_try_e801:
; int 15h ax = E801h 获取内存大小,最大支持4G 
; AX=CX KB低15MB BX=DX 64KB
   mov ax,0xe801
   int 0x15
   jc .e801_failed_so_try88
; 1.先算出低15M的内存
   mov cx,0x400 ; 1k
   mul cx 
   shl edx,16
   and eax,0x0000FFFF ; 清空高4位
   or edx,eax
   add edx, 0x100000 ; 要加为扩展isa的预留内存 内存空洞的1MB
   mov esi,edx
;2 再算16MB以上
   xor eax,eax
   mov ax,bx		
   mov ecx, 0x10000	; 64KB
   mul ecx
   add esi,eax ; 最大4G 32位eax足够了 edx为0
   mov edx,esi
   jmp .mem_get_ok
; int 15h ah = 0x88 获取内存大小,只能获取64M之内
.e801_failed_so_try88: 
   mov ah, 0x88
   int 0x15
   jc .error_hlt
   and eax,0x0000FFFF

   mov cx, 0x400 ; 单位 kb
   mul cx
   shl edx, 16 ; 把dx移到高16位
   or edx, eax ; 把积的低16位组合到edx,为32位的积
   add edx,0x100000 ; 0x88子功能只会返回1MB以上的内存,故实际内存大小要加上1MB

.mem_get_ok:
   mov [total_mem_bytes], edx

;-------------准备进入保护模式-----------------
    ; 打开 A20
    in al, 0x92
    or al, 0000_0010b
    out 0x92, al
    ; 加载 GDT
    lgdt [gdt_ptr]
    ; CR0 第0 PE 置1
    mov eax, cr0
    or eax, 0x00000001
    mov cr0, eax
    
    jmp dword SELECTOR_CODE:p_mode_start   ; 刷新流水线
.error_hlt:
    hlt ; 失败了 挂起
[bits 32]
p_mode_start:
    mov ax, SELECTOR_DATA
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov esp, LOADER_STACK_TOP
    mov ax, SELECTOR_VIDEO
    mov gs, ax

; -------------------在分页之前加载 kernel--------------------
    mov eax, KERNEL_START_SECTOR ; kernel扇区号
    mov ebx, KERNEL_BIN_BASE_ADDR
    mov ecx, 200 ; 200个扇区
    call rd_disk_m_32

    ; 创建页目录及页表
    call setup_page

    ; 将描述符地址及偏移量dump存入gdt_ptr
    sgdt [gdt_ptr]

    ; GDT VIDEO 段描述符段基址+0xc0000000
    ; VIDEO 是第三个段描述符 一个描述符8字节 24=0x18 +4 高4字节 是段基址的31~24
    mov ebx, [gdt_ptr+2]
    or dword [ebx+0x18+4], 0xc0000000
    add dword [gdt_ptr+2], 0xc0000000 ; gdt+0xc0000000 使其成为内核所在高地址
    ; 将栈指针映射到内核地址
    add esp, 0xc0000000
    ; 将页目录地址给cr3
    mov eax, PAGE_DIR_TABLE_POS
    mov cr3, eax
    ; 打开 cr0 PG位 31位
    mov eax, cr0
    or eax, 0x80000000
    mov cr0, eax
    ; 开启分页后 用GDT新的地址重新加载
    lgdt [gdt_ptr]
    mov byte [gs:160], 'N'
    jmp SELECTOR_CODE:enter_kernel ; 清空流水线
enter_kernel:
    call kernel_init
    mov esp, 0xc009f000
    jmp KERNEL_ENTRY_POINT
; ---------------将 kernel的segment拷贝到编译的地址-----------------
kernel_init:
    xor eax, eax
    xor ebx, ebx ; PROGRAM HEADER ADDRESS
    xor ecx, ecx ; e_phnum
    xor edx, edx ; e_phentSize

    mov dx, [KERNEL_BIN_BASE_ADDR + 42] ; e_phentsize
    mov ebx, [KERNEL_BIN_BASE_ADDR + 28] ; e_phoff program header 在文件中偏移
    add ebx, KERNEL_BIN_BASE_ADDR
    mov cx, [KERNEL_BIN_BASE_ADDR + 44] ; e_phnum
.each_segment:
    cmp byte [ebx + 0], PT_NULL
    je .PTNULL
    
    push dword [ebx + 16] ; 压入参数(dst 目的地址, src 源地址, size)
    mov eax, [ebx + 4] ; p_offset
    add eax, KERNEL_BIN_BASE_ADDR ; eax 为该段物理地址
    push eax
    push dword [ebx + 8] ; p_vaddr
    call mem_cpy ; 段复制

    add esp, 12 ; 强行清理栈
.PTNULL:
    add ebx, edx
    loop .each_segment
    ret
; mem_cpy(dst, src, size)
mem_cpy:
    cld ; clean direction CFlags DF置0 自动加上搬运字节大小
    push ebp
    mov ebp, esp
    push ecx
    mov edi, [ebp + 8] ; dst
    mov esi, [ebp + 12] ; src
    mov ecx, [ebp + 16] ; size
    rep movsb ; 逐字节拷贝
    pop ecx
    pop ebp
    ret

; ---------------创建页目录及页表--------------
setup_page:
    ; 页目录空间清0 1024*4
    mov ecx, 4096
    mov esi, 0
.clear_page_dir:
    mov byte [PAGE_DIR_TABLE_POS+esi], 0
    inc esi
    loop .clear_page_dir
.create_pde: ; 创建 页目录项 PDE PAGE DIRECTORY ENTRY
    mov eax, PAGE_DIR_TABLE_POS
    add eax, 0x1000
    mov ebx, eax ; ebx 暂存第一个页表位置
    or eax, PG_US_U | PG_RW_W | PG_P ; 属性7 111

    mov [PAGE_DIR_TABLE_POS+0x0], eax ; 第一个页目录项
    mov [PAGE_DIR_TABLE_POS+0xc00], eax ; 0xc0/4 = 768个页表所占用目录项 3G边界的第一个页内存项

    sub eax, 0x1000
    mov [PAGE_DIR_TABLE_POS+4092], eax ; 页目录项最后一个指向页目录表本身 4字节要-4

    mov ecx, 256 ; 这里只创建了 低端1M 创建页表项 PTE
    mov esi, 0
    mov edx, PG_US_U | PG_RW_W | PG_P ; 0x000007
.create_pte:
    mov [ebx+esi*4], edx
    inc esi
    add edx, 0x1000 ; 绕过一个4kb内存
    loop .create_pte

    mov eax, PAGE_DIR_TABLE_POS
    add eax, 0x2000 ; 第二个页表位置
    or eax, PG_US_U | PG_RW_W | PG_P
    mov ebx, PAGE_DIR_TABLE_POS
    mov ecx, 254
    mov esi, 769 ; 769~1022
.create_kernel_pde:
    mov [ebx+esi*4], eax
    inc esi
    add eax, 0x1000
    loop .create_kernel_pde
    ret

; 读取硬盘N个扇区
rd_disk_m_32:
    mov esi, eax
    mov di, cx
    ; 写入扇区数
    mov dx, 0x1f2
    mov al, cl
    out dx, al
    mov eax, esi
    ; LBA 7~0 写入起始扇区
    inc dx
    out dx, al
    ; LBA 15~8
    inc dx
    mov cl, 8
    shr eax, cl
    out dx, al
    ; LBA 23~16
    inc dx
    shr eax, cl
    out dx, al
    ; LBA 27~24
    inc dx
    shr eax, cl
    and al, 0x0f ; 清空高4位
    or al, 0xe0 ; 设置 7~4位 1110 LBA模式
    out dx, al
    ; 0x1f7 写入 0x20读
    inc dx
    mov al, 0x20
    out dx, al
.not_ready:
    nop
    in al, dx
    and al, 0x88 ; 3位表示已准备好 7位表示硬盘忙
    cmp al, 0x08
    jnz .not_ready

    mov ax, di
    mov dx, 256 ; 一次读入一个2字节 512/2=256*扇区个数=循环次数
    mul dx
    mov cx, ax
    mov dx, 0x1f0
.go_on_read:
    in ax, dx
    mov [ebx], ax
    add ebx, 2 ; 16位情况下 扇区数过大 会导致 栈被覆盖
    loop .go_on_read
    ret