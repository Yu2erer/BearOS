TI_GDT equ 0
RPL0 equ 0
SELECTOR_VIDEO equ (0x0003 << 3) + TI_GDT + RPL0

section .data
    put_int_buffer dq 0 ; 8字节数字到字符转换缓冲区 ASCII是1字节
[bits 32]
section .text
; put_int 用小端字节序的数字转成ASCII后倒置
global put_int
put_int:
    pushad
    mov ebp, esp
    mov eax, [ebp + 36] ; 返回地址+pushad 8个4字节
    mov edx, eax
    mov edi, 7 ; 缓冲区最后1字节
    mov ecx, 8 ; 8个数字
    mov ebx, put_int_buffer
.16based_4bits:
    and edx, 0x0000000f
    cmp edx, 9 ; 大过9就是十六进制
    jg .is_A2F
    add edx, '0'
    jmp .store
.is_A2F:
    sub edx, 10 ; 十六进制数字先-10再加字母的ASCII
    add edx, 'A'
.store:
    mov [ebx + edi], dl ; edi 此时为7 意味着倒着存
    dec edi
    shr eax, 4
    mov edx, eax
    loop .16based_4bits
.ready_to_print:
    inc edi ; -1 + 1 = 0
.skip_prefix_0:
    cmp edi, 8 ; 判断是否是全是0
    je .full0
.go_on_skip:
    mov cl, [put_int_buffer + edi]
    inc edi
    cmp cl, '0'
    je .skip_prefix_0
    dec edi
    jmp .put_each_num
.full0:
    mov cl, '0'
.put_each_num:
    push ecx
    call put_char
    add esp, 4
    inc edi
    mov cl, [put_int_buffer + edi]
    cmp edi, 8 ; 判断8个数字是否都完成
    jl .put_each_num
    popad
    ret
    
section .text
; put_str 用 put_char打印以0字符结尾的字符串
global put_str
put_str:
    push ebx
    push ecx
    xor ecx, ecx
    mov ebx, [esp + 12]
.goon:
    mov cl, [ebx]
    cmp cl, 0x0 ; 字符串尾
    jz .str_over
    push ecx ; 为 put_char传递参数
    call put_char
    add esp, 4 ; 覆盖掉栈空间
    inc ebx
    jmp .goon
.str_over:
    pop ecx
    pop ebx
    ret

section .text
; 将栈中字符写入光标所在处
global put_char
put_char:
    pushad ; 备份所有32位通用寄存器
    mov ax, SELECTOR_VIDEO
    mov gs, ax ; 防止 gs 被更改 设置为视频段选择子 更重要的是操作显存是属于内核的事情

    ; 获取光标位置
    mov dx, 0x03d4 ; Address Register 寄存器
    mov al, 0x0e ; 光标位置的高8位寄存器
    out dx, al
    mov dx, 0x03d5 ; Data Register 寄存器读数据
    in al, dx
    mov ah, al

    ; 获得光标位置低8位
    mov dx, 0x03d4
    mov al, 0x0f ; 光标位置低8位寄存器
    out dx, al
    mov dx, 0x03d5
    in al, dx

    mov bx, ax ; 存下光标
    mov ecx, [esp + 36] ; 待打印第一个字符 pushad 压入8个通用寄存器 4*8=32 再加返回地址4位

    cmp cl, 0xd ; LF 换行0xa CR 0xd 回车
    jz .is_carriage_return
    cmp cl, 0xa
    jz .is_line_feed

    cmp cl, 0x8 ; backspace
    jz .is_backspace

    jmp .put_other

.is_backspace:
    dec bx
    shl bx, 1 ; bx*2
    mov byte [gs:bx], 0x20 ; 补上空格
    inc bx
    mov byte [gs:bx], 0x07
    shr bx, 1
    jmp .set_cursor

.put_other:
    shl bx, 1
    mov byte [gs:bx], cl
    inc bx
    mov byte [gs:bx], 0x07 ; 字符属性
    shr bx, 1
    inc bx
    cmp bx, 2000 ; 看看是不是写到末尾了
    jl .set_cursor

.is_line_feed:
.is_carriage_return:
    xor dx, dx
    mov ax, bx
    mov si, 80 ; 一行80个字符
    div si
    sub bx, dx
.is_carriage_return_end:
    add bx, 80
    cmp bx, 2000
.is_line_feed_end:
    jl .set_cursor

; 1~24 移到 0~23
.roll_screen:
    cld
    mov ecx, 960 ; (2000-80)*2/4
    mov esi, 0xc00b80a0 ; 第1行首
    mov edi, 0xc00b8000 ; 第0行首
    rep movsd
    ; 最后一行清空
    mov ebx, 3840
    mov ecx, 80
.cls:
    mov word [gs:ebx], 0x0720
    add ebx, 2
    loop .cls
    mov bx, 1920 ; 光标置首
.set_cursor:
    ; 设置光标位置高8位
    mov dx, 0x03d4
    mov al, 0x0e
    out dx, al
    mov dx, 0x03d5
    mov al, bh
    out dx, al
    ; 设置光标位置低8位
    mov dx, 0x03d4
    mov al, 0x0f
    out dx, al
    mov dx, 0x03d5
    mov al, bl
    out dx, al
.put_char_done:
    popad
    ret

global set_cursor
set_cursor:
    pushad
    mov bx, [esp + 36]

    mov dx, 0x03d4
    mov al, 0x0e
    out dx, al
    mov dx, 0x03d5
    mov al, bh
    out dx, al

    mov dx, 0x03d4
    mov al, 0x0f
    out dx, al
    mov dx, 0x03d5
    mov al, bl
    out dx, al
    popad
    ret