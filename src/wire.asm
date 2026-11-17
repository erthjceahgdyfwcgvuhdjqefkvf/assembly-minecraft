%include "common.inc"

global wire_reset, wire_new, wire_update, wire_hook, wire_click, wire_use_item
global wire_save, wire_load, wire_conn, meta_get, meta_set, meta_del
global w_indirect, ev_around, ev_push, wire_held, look_h, in_cell, wkind
global door_drop, dig_alias, cur_chest

extern world_get, world_set, world_poke, block_flags, dt, pos, game_mode
extern eye_h
extern target, syaw, cyaw, pitch, mobs, mob_count, drop_block, tnt_ignite
extern sound_keep, sound_keep_at, world_dir, snprintf, fopen, fclose, fread, fwrite
extern rail_event, rail_use_item
extern dimension, ent_spawn, invui_open, invui_close, state
extern book_seen, book_clear, book_rebuild
extern raining, weather_timer, weather_reset, rain_level

K_WIRE      equ 1
K_TORCH     equ 2
K_LEVER     equ 3
K_BUTTON    equ 4
K_PLATE     equ 5
K_REPEATER  equ 6
K_COMPARATOR equ 7
K_LAMP      equ 8
K_PISTON    equ 9
K_HEAD      equ 10
K_RAIL      equ 11
K_PRAIL     equ 12
K_BLOCK     equ 13
K_TNT       equ 14
K_GATE      equ 15
K_DOOR      equ 16                  ; a door's lower half
K_DOORTOP   equ 17
K_TRAP      equ 18
K_SHAPE     equ 19                  ; a slab, stairs or a chest

META_CAP    equ 65536               ; entries (a power of two)
OLD_META    equ 4096                ; in a VXB1 file
MAX_CHESTS  equ 256
CH_X        equ 0
CH_Y        equ 4                   ; (+ 512 in the nether)
CH_Z        equ 8
CH_USED     equ 12
CH_SLOTS    equ 16                  ; 27 slot dwords
CH_SIZE     equ 128
EV_CAP      equ 8192
SC_CAP      equ 1024
MB_SIZE     equ 96                  ; mobs.asm record: x, y, z at 4, 8, 12
PUSH_MAX    equ 12

section .rodata
align 8
step_table:
    dq part_step.out, part_step.wire, part_step.torch, part_step.out
    dq part_step.button, part_step.plate, part_step.repeater
    dq part_step.comparator, part_step.lamp, part_step.piston
    dq part_step.out, part_step.out, part_step.prail, part_step.out
    dq part_step.tnt, part_step.gate
    dq part_step.door, part_step.doortop, part_step.trap, part_step.out
align 4
dirs:       dd 1,0,0, -1,0,0, 0,1,0, 0,-1,0, 0,0,1, 0,0,-1
f_tick:     dd 0.05
f_tickmax:  dd 0.2
f_zero:     dd 0.0
f_half:     dd 0.5
f_one:      dd 1.0
f_fuse:     dd 4.0
f_w:        dd 0.3                  ; the player: half as wide, and as tall
f_h:        dd 1.75
f_feet:     dd 0.05
f_eye:      dd 1.6
f_steep:    dd 0.9                  ; looking this far up or down (radians)
f_nsteep:   dd -0.9
h2d:        db 0, 1, 4, 5           ; side +x -x +z -z -> direction
; what kind of part each block id is
wkind:
    times B_GATE_X db 0
    times 4 db K_GATE
    times B_TNT - B_GATEOPEN_Z - 1 db 0
    db K_TNT
    times B_BLUEBLOCK - B_TNT - 1 db 0
    db K_BLOCK
    times 16 db K_WIRE
    times 10 db K_TORCH
    times 10 db K_LEVER
    times 8 db K_BUTTON
    times 2 db K_PLATE
    times 8 db K_REPEATER
    times 8 db K_COMPARATOR
    times 2 db K_LAMP
    times 24 db K_PISTON
    times 6 db K_HEAD
    times 10 db K_RAIL
    times 12 db K_PRAIL
    times 2 db K_DOOR
    times 2 db K_DOORTOP
    times 2 db K_TRAP
    times 4 db 0                    ; birch and dark oak
    db K_SHAPE
    db 0
s_file:     db "%s/cwire.bin", 0
s_wb:       db "wb", 0
s_rb:       db "rb", 0
magic:      db "VXB2"
magic1:     db "VXB1"
magic_rc:   db "RCP1"
magic_wt:   db "WTH1"

section .bss
alignb 16
meta:       resb META_CAP * 16      ; x, y, z, value (byte), used (byte: 1,
                                    ; 2 forgotten); y + 512 in the nether
packed:     resb META_CAP * 16      ; saving and loading
chests:     resb MAX_CHESTS * CH_SIZE
cur_chest:  resq 1                  ; the slots of the chest on the screen
file_count: resd 1
ev_buf:     resd EV_CAP * 4         ; x, y, z, flag
sc_buf:     resd SC_CAP * 4         ; x, y, z, tick it is due
ev_head:    resd 1
ev_tail:    resd 1
sc_n:       resd 1
gt:         resd 1                  ; ticks since the world started
tick_acc:   resd 1
wire_gives: resd 1                  ; 0 while dust works out its own signal
wcond:      resb 256                ; blocks that pass power on
path:       resb 512
file_magic: resd 1

section .text

; edi, esi, edx = (r12, r13, r14) + direction %1 (a 64-bit register; rax lost)
%macro NPOS 1
    lea rax, [%1 + %1*2]
    lea rdx, [dirs]
    lea rax, [rdx + rax*4]
    mov edi, [rax]
    add edi, r12d
    mov esi, [rax + 4]
    add esi, r13d
    mov edx, [rax + 8]
    add edx, r14d
%endmacro
%macro HERE 0
    mov edi, r12d
    mov esi, r13d
    mov edx, r14d
%endmacro
%macro PUSH5 0
    push rbx
    push r12
    push r13
    push r14
    push r15
%endmacro
%macro POP5 0
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
%endmacro
; a sound from the middle of node (r12, r13, r14)
%macro SND 3
    cvtsi2ss xmm0, r12d
    addss xmm0, [f_half]
    cvtsi2ss xmm1, r13d
    addss xmm1, [f_half]
    cvtsi2ss xmm2, r14d
    addss xmm2, [f_half]
    SFX_AT %1, %2, %3
%endmacro

; ---------------------------------------------------------------------------
; the table of values by position

; rax = the entry of (edi, esi, edx) (ecx 1) or the free one it would take
; (ecx 0); rax 0 when the table is full. Keeps edi, esi, edx.
meta_find:
    mov r10d, [dimension]
    shl r10d, 9
    add r10d, esi
; the same with y (and the dimension) in r10d
meta_find_raw:
    imul eax, edi, 73856093
    imul ecx, r10d, 19349663
    xor eax, ecx
    imul ecx, edx, 83492791
    xor eax, ecx
    mov r8d, META_CAP
    xor r11d, r11d                  ; the first forgotten entry passed
.p:
    and eax, META_CAP - 1
    mov ecx, eax
    shl ecx, 4
    lea r9, [meta]
    add r9, rcx
    cmp byte [r9 + 13], 0
    je .empty
    cmp byte [r9 + 13], 1
    jne .gone
    cmp [r9], edi
    jne .next
    cmp [r9 + 4], r10d
    jne .next
    cmp [r9 + 8], edx
    jne .next
    mov rax, r9
    mov ecx, 1
    ret
    jmp .next
.gone:                              ; a forgotten entry: a new one may go here
    test r11, r11
    jnz .next
    mov r11, r9
.next:
    inc eax
    dec r8d
    jnz .p
    mov rax, r11
    xor ecx, ecx
    ret
.empty:
    mov rax, r9
    test r11, r11
    cmovnz rax, r11
    xor ecx, ecx
    ret

; int meta_get(int x, int y, int z) - 0 when nothing was ever kept there
meta_get:
    call meta_find
    test ecx, ecx
    jz .none
    movzx eax, byte [rax + 12]
    ret
.none:
    xor eax, eax
    ret

; void meta_del(int x, int y, int z) - forget the value kept there
meta_del:
    call meta_find
    test ecx, ecx
    jz .out
    mov byte [rax + 13], 2
.out:
    ret

; void meta_set(int x, int y, int z, int value)
meta_set:
    push rcx
    call meta_find
    pop rcx
meta_store:
    test rax, rax
    jz .out
    mov [rax], edi
    mov [rax + 4], r10d
    mov [rax + 8], edx
    mov [rax + 12], cl
    mov byte [rax + 13], 1
.out:
    ret

; meta_put_raw(edi x, r10d y as kept, edx z, ecx value) - loading
meta_put_raw:
    push rcx
    call meta_find_raw
    pop rcx
    jmp meta_store

; ---------------------------------------------------------------------------
; the two lists

; sched(edi x, esi y, edx z, ecx ticks from now) - unless one is waiting
sched:
    lea r8, [sc_buf]
    mov r9d, [sc_n]
    xor eax, eax
.s:
    cmp eax, r9d
    jae .add
    mov r10d, eax
    shl r10d, 4
    cmp [r8 + r10], edi
    jne .n
    cmp [r8 + r10 + 4], esi
    jne .n
    cmp [r8 + r10 + 8], edx
    je .out
.n:
    inc eax
    jmp .s
.add:
    cmp r9d, SC_CAP
    jae .out
    shl r9d, 4
    mov [r8 + r9], edi
    mov [r8 + r9 + 4], esi
    mov [r8 + r9 + 8], edx
    add ecx, [gt]
    mov [r8 + r9 + 12], ecx
    inc dword [sc_n]
.out:
    ret

; void ev_push(int x, int y, int z, int flag) - "something beside you
; changed", if a part is there (flag 1: it was a bluestone part)
ev_push:
    PUSH5
    mov r12d, edi
    mov r13d, esi
    mov r14d, edx
    mov ebx, ecx
    call world_get
    lea rcx, [wkind]
    cmp byte [rcx + rax], 0
    je .out
    mov eax, [ev_tail]
    lea rdx, [ev_buf]
    ; the same node twice running: once is enough
    cmp eax, [ev_head]
    je .new
    lea ecx, [rax - 1]
    and ecx, EV_CAP - 1
    shl ecx, 4
    cmp [rdx + rcx], r12d
    jne .new
    cmp [rdx + rcx + 4], r13d
    jne .new
    cmp [rdx + rcx + 8], r14d
    jne .new
    or [rdx + rcx + 12], ebx
    jmp .out
.new:
    lea ecx, [rax + 1]
    and ecx, EV_CAP - 1
    cmp ecx, [ev_head]
    je .out                         ; full
    mov [ev_tail], ecx
    shl eax, 4
    mov [rdx + rax], r12d
    mov [rdx + rax + 4], r13d
    mov [rdx + rax + 8], r14d
    mov [rdx + rax + 12], ebx
.out:
    POP5
    ret

; void ev_around(int x, int y, int z, int flag) - the six nodes next to it
ev_around:
    PUSH5
    mov r12d, edi
    mov r13d, esi
    mov r14d, edx
    mov r15d, ecx
    xor ebx, ebx
.n:
    NPOS rbx
    mov ecx, r15d
    call ev_push
    inc ebx
    cmp ebx, 6
    jb .n
    POP5
    ret

; ev_around2(x, y, z) - those and the ones next to them (power through a
; block reaches two nodes away)
ev_around2:
    ENTER_FN 16
    mov r12d, edi
    mov r13d, esi
    mov r14d, edx
    xor ebx, ebx
.n:
    NPOS rbx
    mov [rsp], edi
    mov [rsp + 4], esi
    mov [rsp + 8], edx
    mov ecx, 1
    call ev_push
    xor r15d, r15d
.m:
    mov eax, ebx
    xor eax, 1
    cmp eax, r15d
    je .mn                          ; (back to the middle)
    lea rax, [r15 + r15*2]
    lea rdx, [dirs]
    lea rax, [rdx + rax*4]
    mov edi, [rax]
    add edi, [rsp]
    mov esi, [rax + 4]
    add esi, [rsp + 4]
    mov edx, [rax + 8]
    add edx, [rsp + 8]
    mov ecx, 1
    call ev_push
.mn:
    inc r15d
    cmp r15d, 6
    jb .m
    inc ebx
    cmp ebx, 6
    jb .n
    LEAVE_FN

; ---------------------------------------------------------------------------
; power

; int w_emit(x, y, z, d, strong) - the power the part at (x, y, z) sends
; toward direction d: all of it (strong 0) or only what goes into a block
w_emit:
    PUSH5
    mov r12d, edi
    mov r13d, esi
    mov r14d, edx
    mov r15d, ecx
    mov ebx, r8d
    call world_get
    cmp eax, B_BLUEBLOCK
    jb .zero
    jne .part
    test ebx, ebx
    jnz .zero
.full:
    mov eax, 15
    jmp .out
.part:
    lea rcx, [wkind]
    movzx ecx, byte [rcx + rax]
    cmp ecx, K_WIRE
    je .wire
    cmp ecx, K_TORCH
    je .torch
    cmp ecx, K_LEVER
    je .lever
    cmp ecx, K_BUTTON
    je .button
    cmp ecx, K_PLATE
    je .plate
    cmp ecx, K_REPEATER
    je .rep
    cmp ecx, K_COMPARATOR
    je .comp
.zero:
    xor eax, eax
.out:
    POP5
    ret
.wire:
    cmp dword [wire_gives], 0
    je .zero
    sub eax, W_WIRE
    jz .zero
    cmp r15d, 3
    je .out                         ; the block it lies on
    cmp r15d, 2
    je .zero
    mov ebx, eax
    HERE
    call wire_conn
    and eax, 15
    jz .lvl                         ; a lone dot: all four sides
    ; else only where it points: on from the side it comes from, if it
    ; does not turn
    mov ecx, r15d
    cmp ecx, 2
    jb .h
    sub ecx, 2
.h:
    mov edx, ecx
    xor edx, 1
    bt eax, edx
    jnc .zero
    mov edx, 0x0c
    cmp ecx, 2
    jb .perp
    mov edx, 0x03
.perp:
    test eax, edx
    jnz .zero
.lvl:
    mov eax, ebx
    jmp .out
.torch:
    sub eax, W_TORCH
    test eax, 1
    jz .zero
    shr eax, 1
    test ebx, ebx
    jz .tweak
    cmp r15d, 2                     ; strongly: only the block above
    je .full
    jmp .zero
.tweak:
    call .hold
    cmp ecx, r15d                   ; not the block it is on
    je .zero
    jmp .full
.button:
    sub eax, W_BUTTON
    add eax, 2                      ; (k = side + 1)
    jmp .switch
.lever:
    sub eax, W_LEVER
.switch:
    test eax, 1
    jz .zero
    shr eax, 1
    test ebx, ebx
    jz .full
    call .hold
    cmp ecx, r15d                   ; strongly: the block it is on
    je .full
    jmp .zero
.plate:
    test eax, 1
    jz .zero
    test ebx, ebx
    jz .full
    cmp r15d, 3
    je .full
    jmp .zero
.rep:
    sub eax, W_REPEATER
    test eax, 1
    jz .zero
    shr eax, 1
    lea rcx, [h2d]
    movzx ecx, byte [rcx + rax]
    cmp ecx, r15d
    je .full
    jmp .zero
.comp:
    sub eax, W_COMPARATOR
    shr eax, 1
    lea rcx, [h2d]
    movzx ecx, byte [rcx + rax]
    cmp ecx, r15d
    jne .zero
    HERE
    call meta_get
    and eax, 15
    jmp .out
.hold:                              ; k in eax -> ecx the direction it holds on
    mov ecx, 3
    test eax, eax
    jz .hr
    lea rcx, [h2d]
    movzx ecx, byte [rcx + rax - 1]
.hr:
    ret

; int strong_into(x, y, z) - the strong power pushed into the node
strong_into:
    PUSH5
    mov r12d, edi
    mov r13d, esi
    mov r14d, edx
    xor ebx, ebx
    xor r15d, r15d
.n:
    NPOS rbx
    mov ecx, ebx
    xor ecx, 1
    mov r8d, 1
    call w_emit
    cmp eax, r15d
    cmova r15d, eax
    inc ebx
    cmp ebx, 6
    jb .n
    mov eax, r15d
    POP5
    ret

; int power_from(x, y, z, n) - the power the node gets from its neighbour
; in direction n: through it if it is a solid block, else what it sends
power_from:
    PUSH5
    mov r12d, edi
    mov r13d, esi
    mov r14d, edx
    mov ebx, ecx
    NPOS rbx
    mov r12d, edi
    mov r13d, esi
    mov r14d, edx
    call world_get
    lea rcx, [wcond]
    cmp byte [rcx + rax], 0
    je .weak
    HERE
    call strong_into
    jmp .out
.weak:
    HERE
    mov ecx, ebx
    xor ecx, 1
    xor r8d, r8d
    call w_emit
.out:
    POP5
    ret

; int w_indirect(x, y, z) - the most power the node gets from any side
w_indirect:
    PUSH5
    mov r12d, edi
    mov r13d, esi
    mov r14d, edx
    xor ebx, ebx
    xor r15d, r15d
.n:
    HERE
    mov ecx, ebx
    call power_from
    cmp eax, r15d
    cmova r15d, eax
    cmp r15d, 15
    jae .done
    inc ebx
    cmp ebx, 6
    jb .n
.done:
    mov eax, r15d
    POP5
    ret

; is_link(edi block, esi side) -> eax 1 if dust joins up with it
is_link:
    lea rcx, [wkind]
    movzx eax, byte [rcx + rdi]
    cmp eax, K_REPEATER
    je .rep
    cmp eax, K_BLOCK
    je .yes
    dec eax
    cmp eax, K_COMPARATOR - 1
    jbe .yes
    xor eax, eax
    ret
.rep:                               ; only at its two ends
    lea eax, [rdi - W_REPEATER]
    shr eax, 1
    xor eax, esi
    test eax, 2
    jnz .no
.yes:
    mov eax, 1
    ret
.no:
    xor eax, eax
    ret

; int wire_conn(x, y, z) - the sides (+x -x +z -z, bits 0-3) the dust at
; (x, y, z) joins on; bits 4-7: it climbs the block on that side
; locals: [0] mask, [4] the node above passes power, [8] neighbour
wire_conn:
    ENTER_FN 16
    mov r12d, edi
    mov r13d, esi
    mov r14d, edx
    mov dword [rsp], 0
    inc esi
    call world_get
    lea rcx, [wcond]
    movzx eax, byte [rcx + rax]
    mov [rsp + 4], eax
    xor ebx, ebx
.h:
    lea rax, [h2d]
    movzx r15d, byte [rax + rbx]
    NPOS r15
    call world_get
    mov [rsp + 8], eax
    mov edi, eax
    mov esi, ebx
    call is_link
    test eax, eax
    jnz .yes
    mov eax, [rsp + 8]
    lea rcx, [wcond]
    cmp byte [rcx + rax], 0
    jne .tryup
    ; nothing solid there: dust one node down joins
    NPOS r15
    dec esi
    call world_get
    sub eax, W_WIRE
    cmp eax, 15
    jbe .yes
    jmp .next
.tryup:
    cmp dword [rsp + 4], 0
    jne .next
    NPOS r15
    inc esi
    call world_get
    sub eax, W_WIRE
    cmp eax, 15
    ja .next
    lea eax, [rbx + 4]
    bts dword [rsp], eax
.yes:
    bts dword [rsp], ebx
.next:
    inc ebx
    cmp ebx, 4
    jb .h
    mov eax, [rsp]
    LEAVE_FN

; wire_recalc(x, y, z) - the dust's signal: what powers it, or one less
; than the strongest dust it joins
; locals: [0] signal now, [4] best, [8] above passes power, [12] neighbour
%macro CONSIDER 0                   ; eax a block: dust one stronger than best?
    sub eax, W_WIRE
    cmp eax, 15
    ja %%no
    dec eax
    cmp eax, [rsp + 4]
    jle %%no
    mov [rsp + 4], eax
%%no:
%endmacro
wire_recalc:
    ENTER_FN 16
    mov r12d, edi
    mov r13d, esi
    mov r14d, edx
    call world_get
    sub eax, W_WIRE
    mov [rsp], eax
    mov dword [wire_gives], 0
    HERE
    call w_indirect
    mov dword [wire_gives], 1
    mov [rsp + 4], eax
    cmp eax, 15
    jae .have
    HERE
    inc esi
    call world_get
    lea rcx, [wcond]
    movzx eax, byte [rcx + rax]
    mov [rsp + 8], eax
    xor ebx, ebx
.h:
    lea rax, [h2d]
    movzx r15d, byte [rax + rbx]
    NPOS r15
    call world_get
    mov [rsp + 12], eax
    CONSIDER
    mov eax, [rsp + 12]
    lea rcx, [wcond]
    cmp byte [rcx + rax], 0
    je .down
    cmp dword [rsp + 8], 0
    jne .next
    NPOS r15
    inc esi
    call world_get
    CONSIDER
    jmp .next
.down:
    NPOS r15
    dec esi
    call world_get
    CONSIDER
.next:
    inc ebx
    cmp ebx, 4
    jb .h
.have:
    mov ecx, [rsp + 4]
    cmp ecx, [rsp]
    je .out
    add ecx, W_WIRE
    HERE
    call world_poke
    HERE
    call ev_around2
.out:
    LEAVE_FN

; rep_input(x, y, z, side it faces) -> the signal at its back
rep_input:
    PUSH5
    mov r12d, edi
    mov r13d, esi
    mov r14d, edx
    mov ebx, ecx
    xor ebx, 1
    lea rax, [h2d]
    movzx ebx, byte [rax + rbx]
    HERE
    mov ecx, ebx
    call power_from
    mov r15d, eax
    cmp eax, 15
    jae .out
    NPOS rbx                        ; dust behind it counts wherever it points
    call world_get
    sub eax, W_WIRE
    cmp eax, 15
    ja .out
    cmp eax, r15d
    cmova r15d, eax
.out:
    mov eax, r15d
    POP5
    ret

; rep_locked(x, y, z, side it faces) -> 1 if a lit repeater points into
; its side
rep_locked:
    PUSH5
    mov r12d, edi
    mov r13d, esi
    mov r14d, edx
    mov r15d, ecx
    xor r15d, 2
    mov ebx, 2
.s:
    lea rax, [h2d]
    movzx ecx, byte [rax + r15]
    NPOS rcx
    call world_get
    lea ecx, [rax - W_REPEATER]
    cmp ecx, 7
    ja .n
    test ecx, 1
    jz .n
    shr ecx, 1
    mov edx, r15d
    xor edx, 1
    cmp ecx, edx
    jne .n
    mov eax, 1
    jmp .out
.n:
    xor r15d, 1
    dec ebx
    jnz .s
    xor eax, eax
.out:
    POP5
    ret

; comp_calc(x, y, z, side it faces, r8d mode | signal) -> its new signal
; locals: [0] mode, [4] back, [8] side, [12] sides left
comp_calc:
    ENTER_FN 16
    mov r12d, edi
    mov r13d, esi
    mov r14d, edx
    mov ebx, ecx
    mov [rsp], r8d
    call rep_input
    mov [rsp + 4], eax
    mov dword [rsp + 8], 0
    mov r15d, ebx
    xor r15d, 2
    mov dword [rsp + 12], 2
.s:
    lea rax, [h2d]
    movzx ebx, byte [rax + r15]
    NPOS rbx
    call world_get
    lea ecx, [rax - W_WIRE]
    cmp ecx, 15
    jbe .lv
    mov ecx, 15
    cmp eax, B_BLUEBLOCK
    je .lv
    NPOS rbx                        ; a repeater or comparator pointing in
    mov ecx, ebx
    xor ecx, 1
    mov r8d, 1
    call w_emit
    mov ecx, eax
.lv:
    cmp ecx, [rsp + 8]
    jbe .n
    mov [rsp + 8], ecx
.n:
    xor r15d, 1
    dec dword [rsp + 12]
    jnz .s
    mov eax, [rsp + 4]
    mov ecx, [rsp + 8]
    test dword [rsp], 16
    jz .cmp
    sub eax, ecx                    ; subtract
    jns .out
    xor eax, eax
    jmp .out
.cmp:
    cmp eax, ecx                    ; compare: all or nothing
    jae .out
    xor eax, eax
.out:
    LEAVE_FN

; ---------------------------------------------------------------------------
; what parts hold on to

; part_hold(edi block) -> eax the direction of the block it stands or
; hangs on, -1 for whole blocks
part_hold:
    lea rcx, [wkind]
    movzx eax, byte [rcx + rdi]
    cmp eax, K_TORCH
    je .tk
    cmp eax, K_LEVER
    je .lk
    cmp eax, K_BUTTON
    je .bt
    cmp eax, K_WIRE
    je .down
    cmp eax, K_PLATE
    je .down
    cmp eax, K_REPEATER
    je .down
    cmp eax, K_COMPARATOR
    je .down
    cmp eax, K_RAIL
    je .down
    cmp eax, K_PRAIL
    je .down
    cmp eax, K_DOOR
    je .down
    mov eax, -1
    ret
.down:
    mov eax, 3
    ret
.tk:
    lea eax, [rdi - W_TORCH]
    jmp .k
.lk:
    lea eax, [rdi - W_LEVER]
.k:
    shr eax, 1
    jz .down
    lea rcx, [h2d]
    movzx eax, byte [rcx + rax - 1]
    ret
.bt:
    lea eax, [rdi - W_BUTTON]
    shr eax, 1
    lea rcx, [h2d]
    movzx eax, byte [rcx + rax]
    ret

; int wire_held(x, y, z, d) - 1 if the node in direction d is a full
; solid block
wire_held:
    PUSH5
    mov r12d, edi
    mov r13d, esi
    mov r14d, edx
    movsxd rbx, ecx
    NPOS rbx
    call world_get
    lea rcx, [block_flags]
    movzx eax, byte [rcx + rax]
    and eax, F_SOLID | F_OPAQUE
    cmp eax, F_SOLID | F_OPAQUE
    sete al
    movzx eax, al
    POP5
    ret

; ---------------------------------------------------------------------------
; part_step(x, y, z, flag, mode) - the part at (x, y, z) looks at what it
; should be: mode 0 after a change beside it (flag 1: a bluestone part
; changed), mode 1 when its tick comes
; locals: [0] flag, [4] mode, [8] kind, [12] direction it holds on,
;         [16], [20] scratch
part_step:
    ENTER_FN 48
    mov r12d, edi
    mov r13d, esi
    mov r14d, edx
    mov [rsp], ecx
    mov [rsp + 4], r8d
    call world_get
    mov r15d, eax
    lea rcx, [wkind]
    movzx eax, byte [rcx + rax]
    test eax, eax
    jz .out
    mov [rsp + 8], eax
    mov edi, r15d
    call part_hold
    mov [rsp + 12], eax
    test eax, eax
    js .held
    mov ecx, eax
    HERE
    call wire_held
    test eax, eax
    jnz .held
    ; nothing to stand or hang on: it comes off
    cmp dword [game_mode], 0
    jne .gone
    mov edi, r15d
    mov esi, r12d
    mov edx, r13d
    mov ecx, r14d
    call drop_block
.gone:
    HERE
    xor ecx, ecx
    call world_set
    jmp .out
.held:
    mov eax, [rsp + 8]
    lea rcx, [step_table]
    jmp [rcx + rax*8]

.wire:
    HERE
    call wire_recalc
    jmp .out

.torch:                             ; lit unless the block it is on has power
    mov ecx, [rsp + 12]
    HERE
    call power_from
    test eax, eax
    setz al
    movzx eax, al
    mov ecx, r15d
    and ecx, 1
    cmp eax, ecx
    je .out
    cmp dword [rsp + 4], 0
    jne .torch_flip
    HERE
    mov ecx, 2
    call sched
    jmp .out
.torch_flip:
    mov ecx, r15d
    xor ecx, 1
    HERE
    call world_poke
    HERE
    mov ecx, 1
    call ev_around
    HERE
    inc esi
    mov ecx, 1
    call ev_around
    jmp .out

.button:                            ; its tick: it springs back
    cmp dword [rsp + 4], 0
    je .out
    test r15d, 1
    jz .out
.release:
    mov ecx, r15d
    and ecx, ~1
    HERE
    call world_poke
    HERE
    mov ecx, 1
    call ev_around
    movsxd rbx, dword [rsp + 12]
    NPOS rbx
    mov ecx, 1
    call ev_around
    SND S_CLICK, 60, 80
    jmp .out

.plate:                             ; its tick: up again once nobody is on it
    cmp dword [rsp + 4], 0
    je .out
    test r15d, 1
    jz .out
    HERE
    call occupied
    test eax, eax
    jz .release
    HERE
    mov ecx, 20
    call sched
    jmp .out

.repeater:
    lea ebx, [r15 - W_REPEATER]
    shr ebx, 1
    mov ecx, ebx
    HERE
    call rep_locked
    test eax, eax
    jnz .out
    mov ecx, ebx
    HERE
    call rep_input
    test eax, eax
    setnz al
    movzx eax, al
    mov [rsp + 16], eax             ; should be on
    mov ecx, r15d
    and ecx, 1
    cmp dword [rsp + 4], 0
    jne .rep_tick
    cmp eax, ecx
    je .out
.rep_wait:
    HERE
    call meta_get
    and eax, 3
    lea ecx, [rax*2 + 2]
    call sched
    jmp .out
.rep_tick:
    test ecx, ecx
    jz .rep_on
    test eax, eax
    jnz .out
    jmp .rep_flip
.rep_on:                            ; it goes on even if the pulse has gone,
    cmp dword [rsp + 16], 0         ; and off again a delay later
    jne .rep_flip
    HERE
    call meta_get
    and eax, 3
    lea ecx, [rax*2 + 2]
    call sched
.rep_flip:
    mov ecx, r15d
    xor ecx, 1
    HERE
    call world_poke
.rep_tell:
    HERE
    mov ecx, 1
    call ev_around
    lea rax, [h2d]
    movzx ebx, byte [rax + rbx]
    NPOS rbx
    mov ecx, 1
    call ev_around
    jmp .out

.comparator:
    lea ebx, [r15 - W_COMPARATOR]
    shr ebx, 1
    HERE
    call meta_get
    mov [rsp + 20], eax
    mov r8d, eax
    mov ecx, ebx
    HERE
    call comp_calc
    mov [rsp + 16], eax
    mov ecx, [rsp + 20]
    and ecx, 15
    cmp eax, ecx
    jne .comp_ch
    test eax, eax
    setnz al
    movzx eax, al
    mov ecx, r15d
    and ecx, 1
    cmp eax, ecx
    je .out
.comp_ch:
    cmp dword [rsp + 4], 0
    jne .comp_tick
    HERE
    mov ecx, 2
    call sched
    jmp .out
.comp_tick:
    mov ecx, [rsp + 20]
    and ecx, 16
    or ecx, [rsp + 16]
    HERE
    call meta_set
    mov ecx, r15d
    and ecx, ~1
    cmp dword [rsp + 16], 0
    je .comp_put
    or ecx, 1
.comp_put:
    HERE
    call world_poke
    jmp .rep_tell

.lamp:                              ; on at once, off after 4 ticks
    HERE
    call w_indirect
    test eax, eax
    setnz al
    movzx eax, al
    mov ecx, r15d
    and ecx, 1
    cmp eax, ecx
    je .out
    test eax, eax
    jz .lamp_off
    HERE
    mov ecx, W_LAMP + 1
    call world_set
    jmp .out
.lamp_off:
    cmp dword [rsp + 4], 0
    jne .lamp_dark
    HERE
    mov ecx, 4
    call sched
    jmp .out
.lamp_dark:
    HERE
    mov ecx, W_LAMP
    call world_set
    jmp .out

.tnt:
    HERE
    call w_indirect
    test eax, eax
    jz .out
    HERE
    xor ecx, ecx
    call world_set
    HERE
    movss xmm0, [f_fuse]
    call tnt_ignite
    jmp .out

.gate:                              ; power opens it, losing it shuts it
    cmp dword [rsp], 0
    je .out
    HERE
    call w_indirect
    test eax, eax
    setnz al
    movzx eax, al
    xor ecx, ecx
    cmp r15d, B_GATEOPEN_X
    setae cl
    cmp eax, ecx
    je .out
    lea ecx, [r15 + 2]
    test eax, eax
    jnz .gate_set
    lea ecx, [r15 - 2]
.gate_set:
    HERE
    call world_set
    SND S_TICK_WOOD, 80, 115
    jmp .out

.prail:
    HERE
    mov ecx, r15d
    call rail_event
    jmp .out

.doortop:                           ; the lower half sees to both
    HERE
    dec esi
    call world_get
    sub eax, W_DOOR
    cmp eax, 1
    jbe .dt_ok
    HERE                            ; no lower half: it goes
    xor ecx, ecx
    call world_set
    jmp .out
.dt_ok:
    dec r13d
.door:                              ; power to either half opens it
    HERE
    call w_indirect
    mov ebx, eax
    HERE
    inc esi
    call w_indirect
    or ebx, eax
    jmp .powered
.trap:
    HERE
    call w_indirect
    mov ebx, eax
.powered:
    ; it moves only when its power comes or goes: a door opened by hand
    ; stays open till then
    test ebx, ebx
    setnz bl
    movzx ebx, bl
    HERE
    call meta_get
    mov [rsp + 16], eax
    shr eax, 3
    and eax, 1
    cmp eax, ebx
    je .out
    mov ecx, [rsp + 16]
    xor ecx, 8
    HERE
    call meta_set
    HERE
    call world_get
    and eax, 1
    cmp eax, ebx
    je .out
    HERE
    call door_flip
    jmp .out

.piston:
    lea ebx, [r15 - W_PISTON]
    cmp ebx, 12
    jb .p_dir
    sub ebx, 12
.p_dir:
    shr ebx, 1
    mov ecx, ebx
    HERE
    call piston_powered
    mov ecx, r15d
    and ecx, 1
    cmp eax, ecx
    je .out
    cmp dword [rsp + 4], 0
    jne .p_act
    HERE
    mov ecx, 2
    call sched
    jmp .out
.p_act:
    mov ecx, ebx
    mov r8d, r15d
    HERE
    test eax, eax
    jz .p_in
    call piston_out
    jmp .out
.p_in:
    call piston_in
.out:
    LEAVE_FN

; ---------------------------------------------------------------------------
; pistons

; piston_powered(x, y, z, the way it faces) -> 1 with power from any side
; but its face, or to the node above it (as if that were the piston)
piston_powered:
    ENTER_FN 16
    mov r12d, edi
    mov r13d, esi
    mov r14d, edx
    mov [rsp], ecx
    xor ebx, ebx
.a:
    cmp ebx, [rsp]
    je .an
    HERE
    mov ecx, ebx
    call power_from
    test eax, eax
    jnz .yes
.an:
    inc ebx
    cmp ebx, 6
    jb .a
    inc r13d
    xor ebx, ebx
.b:
    cmp ebx, 3
    je .bn
    HERE
    mov ecx, ebx
    call power_from
    test eax, eax
    jnz .yes
.bn:
    inc ebx
    cmp ebx, 6
    jb .b
    xor eax, eax
    LEAVE_FN
.yes:
    mov eax, 1
    LEAVE_FN

; p_fixed(edi block) -> 1 for what a piston cannot move
p_fixed:
    mov eax, 1
    cmp edi, B_OBSIDIAN
    je .out
    cmp edi, B_BEDROCK
    je .out
    cmp edi, B_UNKNOWN
    je .out
    cmp edi, B_FURNACE
    je .out
    cmp edi, B_FURNACE_LIT
    je .out
    cmp edi, B_BEACON
    je .out
    cmp edi, B_PORTAL
    je .out
    cmp edi, B_BED_FOOT
    je .out
    cmp edi, B_BED_HEAD
    je .out
    lea rcx, [wkind]
    movzx ecx, byte [rcx + rdi]
    cmp ecx, K_HEAD
    je .out
    cmp ecx, K_DOOR                 ; doors, trapdoors, slabs, stairs and
    jb .notdoor                     ; chests stay put
    cmp ecx, K_SHAPE
    jbe .out
.notdoor:
    cmp ecx, K_PISTON
    jne .free
    test edi, 1
    jnz .out
.free:
    xor eax, eax
.out:
    ret

; int in_cell(x, y, z) - 1 if the player's body is in the node
in_cell:
    cvtsi2ss xmm0, edi
    movss xmm1, [pos]
    movaps xmm2, xmm1
    addss xmm1, [f_w]
    subss xmm2, [f_w]
    comiss xmm0, xmm1
    jae .no
    addss xmm0, [f_one]
    comiss xmm0, xmm2
    jbe .no
    cvtsi2ss xmm0, esi
    movss xmm1, [pos + 4]
    movaps xmm2, xmm1
    addss xmm1, [f_h]
    comiss xmm0, xmm1
    jae .no
    addss xmm0, [f_one]
    comiss xmm0, xmm2
    jbe .no
    cvtsi2ss xmm0, edx
    movss xmm1, [pos + 8]
    movaps xmm2, xmm1
    addss xmm1, [f_w]
    subss xmm2, [f_w]
    comiss xmm0, xmm1
    jae .no
    addss xmm0, [f_one]
    comiss xmm0, xmm2
    jbe .no
    mov eax, 1
    ret
.no:
    xor eax, eax
    ret

; locals of piston_out / piston_in: [0] direction, [4] block, [8] blocks to
; push, [12] step, [16] dx, [20] dy, [24] dz, [28] a block
%macro QPOS 0                       ; edi, esi, edx = eax steps out from it
    mov edi, eax
    imul edi, [rsp + 16]
    add edi, r12d
    mov esi, eax
    imul esi, [rsp + 20]
    add esi, r13d
    mov edx, eax
    imul edx, [rsp + 24]
    add edx, r14d
%endmacro
%macro PISTON_ENTER 0
    ENTER_FN 48
    mov r12d, edi
    mov r13d, esi
    mov r14d, edx
    mov [rsp], ecx
    mov [rsp + 4], r8d
    lea rax, [rcx + rcx*2]
    lea rdx, [dirs]
    lea rax, [rdx + rax*4]
    mov ecx, [rax]
    mov [rsp + 16], ecx
    mov ecx, [rax + 4]
    mov [rsp + 20], ecx
    mov ecx, [rax + 8]
    mov [rsp + 24], ecx
%endmacro

; piston_out(x, y, z, direction, block) - push what is in front (up to 12
; blocks in a row) one node on and put the head out
piston_out:
    PISTON_ENTER
    mov dword [rsp + 8], 0
    mov dword [rsp + 12], 1
.walk:
    mov eax, [rsp + 12]
    QPOS
    call world_get
    mov [rsp + 28], eax
    test eax, eax
    jz .go
    mov edi, eax
    call p_fixed
    test eax, eax
    jnz .out                        ; stuck
    mov eax, [rsp + 28]
    lea rcx, [block_flags]
    test byte [rcx + rax], F_SOLID
    jz .soft
    inc dword [rsp + 8]
    cmp dword [rsp + 8], PUSH_MAX
    ja .out
    inc dword [rsp + 12]
    jmp .walk
.soft:
    ; a plant, torch, dust or liquid in the way gives
    test byte [rcx + rax], F_LIQUID
    jnz .go
    cmp dword [game_mode], 0
    jne .go
    mov eax, [rsp + 12]
    QPOS
    mov ecx, edx
    mov edx, esi
    mov esi, edi
    mov edi, [rsp + 28]
    call drop_block
.go:
    mov ebx, [rsp + 8]              ; from the far end
.mv:
    test ebx, ebx
    jz .head
    mov eax, ebx
    QPOS
    call world_get
    mov [rsp + 28], eax
    lea eax, [rbx + 1]
    QPOS
    mov ecx, [rsp + 28]
    call world_set
    dec ebx
    jmp .mv
.head:
    mov eax, 1
    QPOS
    mov ecx, [rsp]
    add ecx, W_PHEAD
    call world_set
    HERE
    mov ecx, [rsp + 4]
    or ecx, 1
    call world_set
    ; the player is pushed along
    mov ebx, [rsp + 8]
    inc ebx
.shove:
    mov eax, ebx
    QPOS
    call in_cell
    test eax, eax
    jnz .moved
    dec ebx
    jnz .shove
    jmp .snd
.moved:
    cvtsi2ss xmm0, dword [rsp + 16]
    addss xmm0, [pos]
    movss [pos], xmm0
    cvtsi2ss xmm0, dword [rsp + 20]
    addss xmm0, [pos + 4]
    movss [pos + 4], xmm0
    cvtsi2ss xmm0, dword [rsp + 24]
    addss xmm0, [pos + 8]
    movss [pos + 8], xmm0
.snd:
    SND S_TICK_STONE, 90, 60
.out:
    LEAVE_FN

; piston_in(x, y, z, direction, block) - the head comes back; a sticky one
; brings the block in front of it
piston_in:
    PISTON_ENTER
    HERE
    mov ecx, [rsp + 4]
    and ecx, ~1
    call world_set
    mov eax, 1
    QPOS
    call world_get
    mov ecx, [rsp]
    add ecx, W_PHEAD
    cmp eax, ecx
    jne .out
    cmp dword [rsp + 4], W_SPISTON
    jb .plain
    mov eax, 2
    QPOS
    call world_get
    mov [rsp + 28], eax
    test eax, eax
    jz .plain
    lea rcx, [block_flags]
    test byte [rcx + rax], F_SOLID
    jz .plain
    mov edi, eax
    call p_fixed
    test eax, eax
    jnz .plain
    mov eax, 1
    QPOS
    mov ecx, [rsp + 28]
    call world_set
    mov eax, 2
    QPOS
    xor ecx, ecx
    call world_set
    jmp .snd
.plain:
    mov eax, 1
    QPOS
    xor ecx, ecx
    call world_set
.snd:
    SND S_TICK_STONE, 80, 70
.out:
    LEAVE_FN

; ---------------------------------------------------------------------------
; pressure plates

; FLOORF dst32, src xmm, tmp xmm - true floor
%macro FLOORF 3
    cvttss2si %1, %2
    cvtsi2ss %3, %1
    comiss %3, %2
    jbe %%ok
    dec %1
%%ok:
%endmacro

; eax, ecx, edx = the node the feet at xmm0, xmm1, xmm2 are in
feet_cell:
    FLOORF eax, xmm0, xmm3
    addss xmm1, [f_feet]
    FLOORF ecx, xmm1, xmm3
    FLOORF edx, xmm2, xmm3
    ret

; occupied(x, y, z) -> 1 if the player or a mob stands in the node
occupied:
    PUSH5
    mov r12d, edi
    mov r13d, esi
    mov r14d, edx
    movss xmm0, [pos]
    movss xmm1, [pos + 4]
    movss xmm2, [pos + 8]
    call feet_cell
    cmp eax, r12d
    jne .mobs
    cmp ecx, r13d
    jne .mobs
    cmp edx, r14d
    je .yes
.mobs:
    xor ebx, ebx
    lea r15, [mobs]
.m:
    cmp ebx, [mob_count]
    jae .no
    movss xmm0, [r15 + 4]
    movss xmm1, [r15 + 8]
    movss xmm2, [r15 + 12]
    call feet_cell
    cmp eax, r12d
    jne .mn
    cmp ecx, r13d
    jne .mn
    cmp edx, r14d
    je .yes
.mn:
    add r15, MB_SIZE
    inc ebx
    jmp .m
.no:
    xor eax, eax
    POP5
    ret
.yes:
    mov eax, 1
    POP5
    ret

; step_on(x, y, z) - feet in the node: a plate there goes down
step_on:
    PUSH5
    mov r12d, edi
    mov r13d, esi
    mov r14d, edx
    call world_get
    cmp eax, W_PLATE
    jne .out
    HERE
    mov ecx, W_PLATE + 1
    call world_poke
    HERE
    mov ecx, 1
    call ev_around
    HERE
    dec esi
    mov ecx, 1
    call ev_around
    HERE
    mov ecx, 20
    call sched
    SND S_CLICK, 60, 90
.out:
    POP5
    ret

plates_step:
    PUSH5
    movss xmm0, [pos]
    movss xmm1, [pos + 4]
    movss xmm2, [pos + 8]
    call feet_cell
    mov edi, eax
    mov esi, ecx
    call step_on
    xor ebx, ebx
    lea r15, [mobs]
.m:
    cmp ebx, [mob_count]
    jae .out
    movss xmm0, [r15 + 4]
    movss xmm1, [r15 + 8]
    movss xmm2, [r15 + 12]
    call feet_cell
    mov edi, eax
    mov esi, ecx
    call step_on
    add r15, MB_SIZE
    inc ebx
    jmp .m
.out:
    POP5
    ret

; ---------------------------------------------------------------------------
; the clock

; one tick: plates, then every part whose time has come
game_tick:
    PUSH5
    inc dword [gt]
    call plates_step
    xor ebx, ebx
.s:
    cmp ebx, [sc_n]
    jae .done
    mov eax, ebx
    shl eax, 4
    lea rcx, [sc_buf]
    add rcx, rax
    mov eax, [rcx + 12]
    cmp eax, [gt]
    ja .next
    mov r12d, [rcx]
    mov r13d, [rcx + 4]
    mov r14d, [rcx + 8]
    mov eax, [sc_n]                 ; the last one takes its place
    dec eax
    mov [sc_n], eax
    shl eax, 4
    lea rdx, [sc_buf]
    movdqu xmm0, [rdx + rax]
    movdqu [rcx], xmm0
    HERE
    xor ecx, ecx
    mov r8d, 1
    call part_step
    jmp .s
.next:
    inc ebx
    jmp .s
.done:
    POP5
    ret

; work off the queued events (a part that changes queues more)
wire_run:
    PUSH5
    mov ebx, 6000
.r:
    mov eax, [ev_head]
    cmp eax, [ev_tail]
    je .done
    lea ecx, [rax + 1]
    and ecx, EV_CAP - 1
    mov [ev_head], ecx
    shl eax, 4
    lea rcx, [ev_buf]
    add rcx, rax
    mov edi, [rcx]
    mov esi, [rcx + 4]
    mov edx, [rcx + 8]
    mov ecx, [rcx + 12]
    xor r8d, r8d
    call part_step
    dec ebx
    jnz .r
.done:
    POP5
    ret

; void wire_update(void) - once a frame
wire_update:
    PUSH5
    movss xmm0, [tick_acc]
    addss xmm0, [dt]
    minss xmm0, [f_tickmax]
    movss [tick_acc], xmm0
    call wire_run
.t:
    movss xmm0, [tick_acc]
    comiss xmm0, [f_tick]
    jb .out
    subss xmm0, [f_tick]
    movss [tick_acc], xmm0
    call game_tick
    call wire_run
    jmp .t
.out:
    POP5
    ret

; void wire_reset(void) - a world begins: nothing queued
wire_reset:
    mov dword [ev_head], 0
    mov dword [ev_tail], 0
    mov dword [sc_n], 0
    mov dword [gt], 0
    mov dword [tick_acc], 0
    mov dword [wire_gives], 1
    ; blocks power goes through: solid, light-tight, and not the block of
    ; bluestone (a source) or what is not loaded
    lea rsi, [block_flags]
    lea rdi, [wcond]
    xor ecx, ecx
.c:
    movzx eax, byte [rsi + rcx]
    and eax, F_SOLID | F_OPAQUE
    cmp eax, F_SOLID | F_OPAQUE
    sete al
    mov [rdi + rcx], al
    inc ecx
    cmp ecx, 256
    jb .c
    mov byte [rdi + B_BLUEBLOCK], 0
    mov byte [rdi + B_UNKNOWN], 0
    ret

; void wire_new(void) - a new world: no values kept
wire_new:
    lea rdi, [meta]
    xor eax, eax
    mov ecx, META_CAP * 16
    rep stosb
    lea rdi, [chests]
    mov ecx, MAX_CHESTS * CH_SIZE
    rep stosb
    mov qword [cur_chest], 0
    sub rsp, 8
    call book_clear
    call weather_reset
    add rsp, 8
    ret

; ---------------------------------------------------------------------------
; void wire_hook(int x, int y, int z, int old, int new) - world_set changed
; a node
; locals: [0] kind before, [4] kind now, [8] a direction
wire_hook:
    ENTER_FN 16
    mov r12d, edi
    mov r13d, esi
    mov r14d, edx
    mov r15d, ecx
    mov ebx, r8d
    cmp r15d, ebx
    je .out
    cmp r15d, B_BEACON
    jne .notbeacon
    HERE
    call meta_del                   ; a beacon gone: its effect is forgotten
.notbeacon:
    lea rcx, [wkind]
    movzx eax, byte [rcx + r15]
    movzx edx, byte [rcx + rbx]
    mov [rsp], eax
    mov [rsp + 4], edx
    or eax, edx
    jnz .part
    HERE
    xor ecx, ecx
    call ev_around
    jmp .out
.part:
    HERE
    mov ecx, 1
    call ev_push
    HERE
    call ev_around2
    ; a part that kept a value by position is gone: forget it
    mov eax, [rsp]
    cmp eax, [rsp + 4]
    je .kept
    cmp eax, K_REPEATER
    je .forget
    cmp eax, K_COMPARATOR
    je .forget
    cmp eax, K_DOOR
    je .forget
    cmp eax, K_TRAP
    je .forget
    cmp eax, K_SHAPE
    jne .kept
    HERE                            ; a chest spills what it held
    call chest_spill
.forget:
    HERE
    call meta_del
.kept:
    ; a door's two halves go together
    cmp dword [rsp], K_DOOR
    jne .ndlow
    cmp dword [rsp + 4], K_DOOR
    je .out
    HERE
    inc esi
    call world_get
    sub eax, W_DOOR + 2
    cmp eax, 1
    ja .out
    HERE
    inc esi
    xor ecx, ecx
    call world_set
    jmp .out
.ndlow:
    cmp dword [rsp], K_DOORTOP
    jne .ndtop
    cmp dword [rsp + 4], K_DOORTOP
    je .out
    HERE
    dec esi
    call world_get
    sub eax, W_DOOR
    cmp eax, 1
    ja .out
    HERE
    dec esi
    xor ecx, ecx
    call world_set
    jmp .out
.ndtop:
    ; a piston and its head go together
    cmp dword [rsp], K_PISTON
    jne .nbase
    test r15d, 1
    jz .out
    cmp dword [rsp + 4], K_PISTON
    je .out
    lea ebx, [r15 - W_PISTON]
    cmp ebx, 12
    jb .bd
    sub ebx, 12
.bd:
    shr ebx, 1
    NPOS rbx
    call world_get
    lea ecx, [rbx + W_PHEAD]
    cmp eax, ecx
    jne .out
    NPOS rbx
    xor ecx, ecx
    call world_set
    jmp .out
.nbase:
    cmp dword [rsp], K_HEAD
    jne .out
    cmp dword [rsp + 4], K_HEAD
    je .out
    lea eax, [r15 - W_PHEAD]
    mov [rsp + 8], eax
    xor eax, 1
    mov ebx, eax
    NPOS rbx
    mov r12d, edi
    mov r13d, esi
    mov r14d, edx
    call world_get
    mov r15d, eax
    lea rcx, [wkind]
    cmp byte [rcx + rax], K_PISTON
    jne .out
    test eax, 1
    jz .out
    sub eax, W_PISTON
    cmp eax, 12
    jb .hd
    sub eax, 12
.hd:
    shr eax, 1
    cmp eax, [rsp + 8]
    jne .out
    HERE
    xor ecx, ecx
    call world_set
    cmp dword [game_mode], 0
    jne .out
    mov edi, r15d
    mov esi, r12d
    mov edx, r13d
    mov ecx, r14d
    call drop_block
.out:
    LEAVE_FN

; ---------------------------------------------------------------------------
; int wire_click(int block, int x, int y, int z) - right click on a part:
; a lever flips, a button goes in, a repeater's delay steps on, a
; comparator changes mode. 1 if the click was used.
wire_click:
    ENTER_FN 16
    mov r15d, edi
    mov r12d, esi
    mov r13d, edx
    mov r14d, ecx
    lea rcx, [wkind]
    movzx eax, byte [rcx + r15]
    cmp eax, K_LEVER
    je .lever
    cmp eax, K_BUTTON
    je .button
    cmp eax, K_REPEATER
    je .rep
    cmp eax, K_COMPARATOR
    je .comp
    cmp eax, K_DOOR
    je .door
    cmp eax, K_TRAP
    je .door
    cmp eax, K_SHAPE
    je .shape
    cmp eax, K_DOORTOP
    jne .none
    dec r13d
.door:                              ; wood opens by hand, iron only by power
    HERE
    call meta_get
    test eax, 16
    jnz .none
    HERE
    call door_flip
    jmp .yes
.shape:                             ; a chest opens
    HERE
    call meta_get
    test eax, 0x40
    jz .none
    HERE
    call chest_get
    test rax, rax
    jz .none
    add rax, CH_SLOTS
    mov [cur_chest], rax
    mov edi, GS_CHEST
    call invui_open
    SND S_TICK_WOOD, 70, 80
    jmp .yes
.none:
    xor eax, eax
    LEAVE_FN
.button:
    test r15d, 1
    jnz .press
    or r15d, 1
    jmp .switch
.lever:
    xor r15d, 1
.switch:
    HERE
    mov ecx, r15d
    call world_poke
    HERE
    mov ecx, 1
    call ev_around
    mov edi, r15d
    call part_hold
    movsxd rbx, eax
    NPOS rbx
    mov ecx, 1
    call ev_around
    SND S_CLICK, 70, 100
.press:
    lea rcx, [wkind]
    cmp byte [rcx + r15], K_BUTTON
    jne .yes
    HERE
    mov ecx, 20
    call sched
    jmp .yes
.rep:
    HERE
    call meta_get
    inc eax
    and eax, 3
    mov ecx, eax
    call meta_set
    jmp .redraw
.comp:
    HERE
    call meta_get
    xor eax, 16
    mov ecx, eax
    call meta_set
    HERE
    mov ecx, 1
    call ev_push
.redraw:
    HERE
    mov ecx, r15d
    call world_poke
    SND S_CLICK, 60, 130
.yes:
    mov eax, 1
    LEAVE_FN

; int look_h(void) - the side the player looks toward: 0 +x, 1 -x, 2 +z, 3 -z
look_h:
    movss xmm0, [syaw]
    movss xmm1, [cyaw]
    movaps xmm2, xmm0
    mulss xmm2, xmm2
    movaps xmm3, xmm1
    mulss xmm3, xmm3
    comiss xmm2, xmm3
    jbe .z
    xor eax, eax
    comiss xmm0, [f_zero]
    ja .out
    mov eax, 1
    ret
.z:
    mov eax, 3
    comiss xmm1, [f_zero]
    ja .out
    mov eax, 2
.out:
    ret

; int wire_use_item(int item) - right click with a bluestone part in the
; hand: put it in the free node in front of the block looked at. 1 if it
; was placed.
; locals: [0] direction of the block clicked, [4] block to put
wire_use_item:
    ENTER_FN 16
    mov ebx, edi
    cmp ebx, I_RAIL
    jb .mine
    cmp ebx, I_DOOR
    jae .mine
    call rail_use_item
    LEAVE_FN
.mine:
    mov r12d, [target + 12]
    mov r13d, [target + 16]
    mov r14d, [target + 20]
    HERE
    call world_get
    test eax, eax
    jnz .no
    ; which way the clicked block lies
    xor r15d, r15d
.d:
    NPOS r15
    cmp edi, [target]
    jne .dn
    cmp esi, [target + 4]
    jne .dn
    cmp edx, [target + 8]
    je .found
.dn:
    inc r15d
    cmp r15d, 6
    jb .d
    jmp .no
.found:
    mov [rsp], r15d
    cmp ebx, I_DOOR
    jae .doorish
    cmp ebx, I_DUST
    je .dust
    cmp ebx, I_PLATE
    je .plate
    cmp ebx, I_BTORCH
    je .torch
    cmp ebx, I_LEVER
    je .lever
    cmp ebx, I_BUTTON
    je .button
    cmp ebx, I_REPEATER
    je .rep
    cmp ebx, I_COMPARATOR
    je .comp
    cmp ebx, I_LAMP
    je .lamp
    jmp .piston
.doorish:
    cmp ebx, I_OAKSTAIRS
    jae .shaped
    lea eax, [rbx - I_DOOR]
    and eax, 1
    shl eax, 4
    mov [rsp + 8], eax              ; iron
    HERE
    call in_cell
    test eax, eax
    jnz .no
    cmp ebx, I_TRAPDOOR
    jae .trapdoor
    ; a door: two free nodes on a solid block
    HERE
    inc esi
    call world_get
    test eax, eax
    jnz .no
    HERE
    inc esi
    call in_cell
    test eax, eax
    jnz .no
    HERE
    mov ecx, 3
    call wire_held
    test eax, eax
    jz .no
    ; the panel on the near side; the hinge on the left, unless a door with
    ; its hinge on the left is there already (a double door)
    call look_h
    xor eax, 1
    or [rsp + 8], eax
    lea rcx, [door_left]
    movzx eax, byte [rcx + rax]
    lea rcx, [h2d]
    movzx eax, byte [rcx + rax]
    NPOS rax
    mov [rsp + 12], edi
    mov [rsp + 4], esi
    mov r15d, edx
    call world_get
    sub eax, W_DOOR
    cmp eax, 1
    ja .lefthinge
    mov edi, [rsp + 12]
    mov esi, [rsp + 4]
    mov edx, r15d
    call meta_get
    mov ecx, [rsp + 8]
    xor ecx, eax
    test ecx, 3
    jnz .lefthinge                  ; facing another way
    test eax, 4
    jnz .hinged
.lefthinge:
    or dword [rsp + 8], 4
.hinged:
    HERE
    mov ecx, [rsp + 8]
    call meta_set
    HERE
    mov ecx, W_DOOR
    call world_set
    HERE
    inc esi
    mov ecx, W_DOOR + 2
    call world_set
    jmp .placed
.trapdoor:
    ; against the block above: the top half of the node; on a block: the
    ; bottom; on a side: the half that was clicked
    mov eax, 1
    cmp r15d, 2
    je .half
    xor eax, eax
    cmp r15d, 3
    je .half
    call trap_top
.half:
    shl eax, 2
    or [rsp + 8], eax
    call look_h                     ; hinged on the far side
    or [rsp + 8], eax
    HERE
    mov ecx, [rsp + 8]
    call meta_set
    HERE
    mov ecx, W_TRAP
    call world_set
.placed:
    SND S_TICK_WOOD, 85, 78
    mov eax, 1
    LEAVE_FN
.shaped:
    lea rcx, [shape_bits]
    movzx eax, byte [rcx + rbx - I_OAKSTAIRS]
    mov [rsp + 8], eax
    cmp ebx, I_CHEST
    je .chestput
    cmp ebx, I_STONESLAB
    jb .stairput
    ; a slab on the top of a lower half slab of the same (or under an
    ; upper one): a whole block
    mov edi, [target]
    mov esi, [target + 4]
    mov edx, [target + 8]
    call world_get
    cmp eax, W_SHAPE
    jne .slabput
    mov edi, [target]
    mov esi, [target + 4]
    mov edx, [target + 8]
    call meta_get
    mov ecx, eax
    and ecx, 0x78
    cmp ecx, [rsp + 8]
    jne .slabput
    cmp r15d, 3
    jne .under
    test eax, 4
    jnz .slabput
    jmp .merge
.under:
    cmp r15d, 2
    jne .slabput
    test eax, 4
    jz .slabput
.merge:
    shr eax, 4
    and eax, 3
    lea rcx, [full_block]
    movzx ecx, byte [rcx + rax]
    mov edi, [target]
    mov esi, [target + 4]
    mov edx, [target + 8]
    call world_set
    jmp .shapesnd
.slabput:
    HERE
    call in_cell
    test eax, eax
    jnz .no
    call .whichhalf
    shl eax, 2
    or [rsp + 8], eax
    jmp .shapeput
.stairput:
    HERE
    call in_cell
    test eax, eax
    jnz .no
    call .whichhalf
    shl eax, 2
    or [rsp + 8], eax
    call look_h                     ; it climbs the way the player looks
    or [rsp + 8], eax
    jmp .shapeput
.chestput:
    HERE
    call in_cell
    test eax, eax
    jnz .no
    call look_h                     ; its front toward the player
    xor eax, 1
    or [rsp + 8], eax
.shapeput:
    HERE
    mov ecx, [rsp + 8]
    call meta_set
    HERE
    mov ecx, W_SHAPE
    call world_set
.shapesnd:
    mov eax, [rsp + 8]
    and eax, 0x70
    cmp eax, 0x30
    je .stonesnd
    SND S_TICK_WOOD, 85, 78
    mov eax, 1
    LEAVE_FN
.stonesnd:
    SND S_TICK_STONE, 85, 90
    mov eax, 1
    LEAVE_FN
.whichhalf:                         ; eax 1: the upper half of the node
    mov eax, 1                      ; (under a block, or the top of a side)
    cmp r15d, 2
    je .hret
    xor eax, eax
    cmp r15d, 3
    je .hret
    sub rsp, 8
    call trap_top
    add rsp, 8
.hret:
    ret
.dust:
    mov dword [rsp + 4], W_WIRE
    jmp .floor
.plate:
    mov dword [rsp + 4], W_PLATE
    jmp .floor
.rep:
    mov dword [rsp + 4], W_REPEATER
    jmp .facing
.comp:
    mov dword [rsp + 4], W_COMPARATOR
.facing:
    call look_h
    add eax, eax
    add [rsp + 4], eax
    HERE
    xor ecx, ecx
    call meta_set
.floor:
    HERE
    mov ecx, 3
    call wire_held
    test eax, eax
    jz .no
    jmp .put
.torch:
    mov dword [rsp + 4], W_TORCH + 1
    jmp .onblock
.lever:
    mov dword [rsp + 4], W_LEVER
.onblock:
    cmp r15d, 2
    je .no                          ; not under a block
    cmp r15d, 3
    je .hold
.wall:
    mov eax, r15d
    cmp eax, 2
    jb .wk
    sub eax, 2
.wk:
    lea eax, [rax*2 + 2]
    add [rsp + 4], eax
    jmp .hold
.button:
    mov dword [rsp + 4], W_BUTTON - 2
    cmp r15d, 2
    je .no
    cmp r15d, 3
    je .no
    jmp .wall
.hold:
    HERE
    mov ecx, r15d
    call wire_held
    test eax, eax
    jz .no
    jmp .put
.lamp:
    mov dword [rsp + 4], W_LAMP
    jmp .body
.piston:
    ; its face toward the player; up or down when they look steeply
    mov eax, W_PISTON
    cmp ebx, I_SPISTON
    jne .pk
    mov eax, W_SPISTON
.pk:
    mov [rsp + 4], eax
    mov eax, 2
    movss xmm0, [pitch]
    comiss xmm0, [f_steep]
    ja .pd
    mov eax, 3
    comiss xmm0, [f_nsteep]
    jb .pd
    call look_h
    xor eax, 1
    lea rcx, [h2d]
    movzx eax, byte [rcx + rax]
.pd:
    add eax, eax
    add [rsp + 4], eax
.body:
    HERE
    call in_cell
    test eax, eax
    jnz .no
.put:
    HERE
    mov ecx, [rsp + 4]
    call world_set
    SND S_TICK_STONE, 80, 120
    mov eax, 1
    LEAVE_FN
.no:
    xor eax, eax
    LEAVE_FN

; ---------------------------------------------------------------------------
; doors and trapdoors
;
; Kept by position (the door's lower half): bits 0-1 the side its panel
; lies on when shut (door) or its hinge is on (trapdoor), +x -x +z -z;
; bit 2 the hinge on the left (door) or the top half of the node
; (trapdoor); bit 3 it had power last time; bit 4 iron.

; void door_flip(int x, int y, int z) - open or shut the door whose lower
; half (or the trapdoor) is at (x, y, z)
door_flip:
    PUSH5
    mov r12d, edi
    mov r13d, esi
    mov r14d, edx
    call world_get
    mov ebx, eax
    lea ecx, [rax - W_DOOR]
    cmp ecx, W_END - W_DOOR - 1
    ja .out
    mov ecx, ebx
    xor ecx, 1
    HERE
    call world_poke
    cmp ebx, W_TRAP
    jae .snd
    HERE
    inc esi
    call world_get
    lea ecx, [rax - W_DOOR - 2]
    cmp ecx, 1
    ja .snd
    mov ecx, eax
    xor ecx, 1
    HERE
    inc esi
    call world_poke
.snd:
    HERE
    call meta_get
    test eax, 16
    jnz .iron
    SND S_TICK_WOOD, 80, 112
    jmp .out
.iron:
    SND S_TICK_METAL, 80, 90
.out:
    POP5
    ret

; int door_drop(int block, int x, int y, int z) - the item a door or
; trapdoor half gives, as a slot dword
door_drop:
    cmp edi, W_SHAPE
    je shape_drop
    push rbx
    lea ebx, [rdi - W_DOOR]
    mov edi, esi
    mov esi, edx
    mov edx, ecx
    cmp ebx, 2
    jb .low
    cmp ebx, 4
    jae .low
    dec esi                         ; the upper half: kept below
.low:
    call meta_get
    shr eax, 4
    and eax, 1
    add eax, I_DOOR
    cmp ebx, 4
    jb .item
    add eax, 2
.item:
    or eax, 1 << 8
    pop rbx
    ret

; door_left: the side to the left of someone facing a door whose panel is
; on side p (they stand on that side, looking in)
door_left:  db 2, 3, 1, 0

; trap_top -> eax 1 if the click on the side face toward r15 (from the
; cell r12, r13, r14) hit its upper half
trap_top:
    sub rsp, 24
    fld dword [pitch]
    fsincos
    fstp dword [rsp]                ; cos
    fstp dword [rsp + 4]            ; sin
    cmp r15d, 2
    jb .x
    movss xmm3, [cyaw]              ; along z: -cyaw cos
    mulss xmm3, [rsp]
    xorps xmm0, xmm0
    subss xmm0, xmm3
    movss xmm3, xmm0
    cvtsi2ss xmm1, r14d
    movss xmm2, [pos + 8]
    jmp .plane
.x:
    movss xmm3, [syaw]
    mulss xmm3, [rsp]
    cvtsi2ss xmm1, r12d
    movss xmm2, [pos]
.plane:
    test r15d, 1
    jnz .near
    addss xmm1, [f_one]             ; +x / +z: the far side of the cell
.near:
    subss xmm1, xmm2
    divss xmm1, xmm3                ; t along the view
    xorps xmm0, xmm0
    subss xmm0, [rsp + 4]
    mulss xmm0, xmm1
    addss xmm0, [pos + 4]
    addss xmm0, [eye_h]
    cvtsi2ss xmm1, r13d
    subss xmm0, xmm1
    xor eax, eax
    comiss xmm0, [f_half]
    setae al
    add rsp, 24
    ret

; slab, stairs and chest: kept by position: bits 0-1 the way (stairs:
; the side it climbs to; chest: its front), bit 2 the upper half, bit 3
; stairs, bits 4-5 oak, birch, dark oak, stone, bit 6 a chest.
; Bit 7: a green portal instead (portal.asm): bit 0 the way home, bits 1-2
; standing across x (0) or z (1), or lying flat (2)
shape_bits: db 0x08, 0x18, 0x28, 0x30, 0x00, 0x10, 0x20, 0x40
full_block: db B_PLANKS, W_BIRCHPLANKS, W_DARKPLANKS, B_STONE
stair_item: db I_OAKSTAIRS, I_BIRCHSTAIRS, I_DARKSTAIRS, I_OAKSTAIRS
slab_item:  db I_OAKSLAB, I_BIRCHSLAB, I_DARKSLAB, I_STONESLAB

; shape_drop(edi block, esi x, edx y, ecx z) - its item, a slot dword
shape_drop:
    sub rsp, 8
    mov edi, esi
    mov esi, edx
    mov edx, ecx
    call meta_get
    add rsp, 8
    test eax, 0x80
    jnz .nothing                    ; a green portal
    mov ecx, I_CHEST
    test eax, 0x40
    jnz .item
    mov edx, eax
    shr edx, 4
    and edx, 3
    lea rcx, [slab_item]
    test eax, 8
    jz .slab
    lea rcx, [stair_item]
.slab:
    movzx ecx, byte [rcx + rdx]
.item:
    lea eax, [rcx + (1 << 8)]
    ret
.nothing:
    xor eax, eax
    ret

; int dig_alias(int block, int x, int y, int z) - what the node digs,
; sounds and breaks like: a slab or stairs its material, a chest planks
dig_alias:
    mov eax, edi
    cmp edi, W_SHAPE
    jne .out
    sub rsp, 8
    mov edi, esi
    mov esi, edx
    mov edx, ecx
    call meta_get
    add rsp, 8
    mov ecx, eax
    mov eax, B_PORTAL               ; a green portal: not dug (as a portal)
    test ecx, 0x80
    jnz .out
    mov eax, B_PLANKS
    test ecx, 0x40
    jnz .out
    shr ecx, 4
    and ecx, 3
    lea rax, [full_block]
    movzx eax, byte [rax + rcx]
.out:
    ret

; rax = the chest record at (edi, esi, edx) or 0
chest_find:
    mov r10d, [dimension]
    shl r10d, 9
    add r10d, esi
    lea rax, [chests]
    xor ecx, ecx
.c:
    cmp dword [rax + CH_USED], 0
    je .n
    cmp [rax + CH_X], edi
    jne .n
    cmp [rax + CH_Y], r10d
    jne .n
    cmp [rax + CH_Z], edx
    je .out
.n:
    add rax, CH_SIZE
    inc ecx
    cmp ecx, MAX_CHESTS
    jb .c
    xor eax, eax
.out:
    ret

; rax = the chest record at (edi, esi, edx), a new empty one if there is
; none; 0 when there are too many
chest_get:
    call chest_find
    test rax, rax
    jnz .out
    lea rax, [chests]
    xor ecx, ecx
.c:
    cmp dword [rax + CH_USED], 0
    je .new
    add rax, CH_SIZE
    inc ecx
    cmp ecx, MAX_CHESTS
    jb .c
    xor eax, eax
    ret
.new:
    mov r8, rax
    push rdi
    lea rdi, [rax]
    xor eax, eax
    mov ecx, CH_SIZE / 4
    rep stosd
    pop rdi
    mov rax, r8
    mov [rax + CH_X], edi
    mov [rax + CH_Y], r10d
    mov [rax + CH_Z], edx
    mov dword [rax + CH_USED], 1
.out:
    ret

; chest_spill(x, y, z) - the chest there is gone: what it held drops
chest_spill:
    PUSH5
    mov r12d, edi
    mov r13d, esi
    mov r14d, edx
    call chest_find
    test rax, rax
    jz .out
    mov rbx, rax
    lea rax, [rbx + CH_SLOTS]
    cmp rax, [cur_chest]
    jne .spill
    mov qword [cur_chest], 0
    cmp dword [state], GS_CHEST
    jne .spill
    call invui_close
.spill:
    xor r15d, r15d
.s:
    mov edi, [rbx + CH_SLOTS + r15*4]
    test edi, edi
    jz .sn
    cvtsi2ss xmm0, r12d
    addss xmm0, [f_half]
    cvtsi2ss xmm1, r13d
    addss xmm1, [f_half]
    cvtsi2ss xmm2, r14d
    addss xmm2, [f_half]
    xorps xmm3, xmm3
    movss xmm4, [f_one]
    xorps xmm5, xmm5
    call ent_spawn
.sn:
    inc r15d
    cmp r15d, 27
    jb .s
    mov dword [rbx + CH_USED], 0
.out:
    POP5
    ret

; ---------------------------------------------------------------------------
; the kept values, in cwire.bin beside the chunks

; rax = FILE* of the current world's file opened with mode rdi, or 0
open_file:
    push rbx
    mov rbx, rdi
    xor eax, eax
    cmp byte [world_dir], 0
    je .out
    lea rdi, [path]
    mov esi, 512
    lea rdx, [s_file]
    lea rcx, [world_dir]
    xor eax, eax
    call snprintf PLT
    lea rdi, [path]
    mov rsi, rbx
    call fopen PLT
.out:
    pop rbx
    ret

; cwire.bin: "VXB2", how many kept values, those (16 bytes each), how
; many chests, those (CH_SIZE each). "VXB1" files hold the old table whole.
wire_save:
    push rbx
    push r12
    sub rsp, 8
    lea rdi, [s_wb]
    call open_file
    test rax, rax
    jz .out
    mov rbx, rax
    lea rdi, [magic]
    mov esi, 1
    mov edx, 4
    mov rcx, rbx
    call fwrite PLT
    ; the values in use, packed
    lea rsi, [meta]
    lea rdi, [packed]
    xor r12d, r12d
    mov ecx, META_CAP
.m:
    cmp byte [rsi + 13], 1
    jne .mn
    movdqu xmm0, [rsi]
    movdqu [rdi], xmm0
    add rdi, 16
    inc r12d
.mn:
    add rsi, 16
    dec ecx
    jnz .m
    call .count
    lea rdi, [packed]
    mov esi, 16
    mov edx, r12d
    mov rcx, rbx
    call fwrite PLT
    ; the chests in use
    lea rsi, [chests]
    lea rdi, [packed]
    xor r12d, r12d
    mov ecx, MAX_CHESTS
.c:
    cmp dword [rsi + CH_USED], 0
    je .cn
    push rcx
    push rsi
    mov ecx, CH_SIZE
    rep movsb
    pop rsi
    pop rcx
    inc r12d
.cn:
    add rsi, CH_SIZE
    dec ecx
    jnz .c
    call .count
    lea rdi, [packed]
    mov esi, CH_SIZE
    mov edx, r12d
    mov rcx, rbx
    call fwrite PLT
    ; the recipe book: the items the player has had
    lea rdi, [magic_rc]
    mov esi, 1
    mov edx, 4
    mov rcx, rbx
    call fwrite PLT
    lea rdi, [book_seen]
    mov esi, 1
    mov edx, 32
    mov rcx, rbx
    call fwrite PLT
    ; the weather: raining, and how long till it turns
    lea rdi, [magic_wt]
    mov esi, 1
    mov edx, 4
    mov rcx, rbx
    call fwrite PLT
    lea rdi, [raining]
    mov esi, 4
    mov edx, 1
    mov rcx, rbx
    call fwrite PLT
    lea rdi, [weather_timer]
    mov esi, 4
    mov edx, 1
    mov rcx, rbx
    call fwrite PLT
    mov rdi, rbx
    call fclose PLT
.out:
    add rsp, 8
    pop r12
    pop rbx
    ret
.count:                             ; write r12d
    sub rsp, 8
    mov [file_count], r12d
    lea rdi, [file_count]
    mov esi, 4
    mov edx, 1
    mov rcx, rbx
    call fwrite PLT
    add rsp, 8
    ret

wire_load:
    push rbx
    push r12
    push r13
    call wire_new
    lea rdi, [s_rb]
    call open_file
    test rax, rax
    jz .out
    mov rbx, rax
    lea rdi, [file_magic]
    mov esi, 1
    mov edx, 4
    mov rcx, rbx
    call fread PLT
    mov eax, [file_magic]
    cmp eax, [magic1]
    je .old
    cmp eax, [magic]
    jne .close
    call .count
    mov edx, eax
    lea rdi, [packed]
    mov esi, 16
    mov rcx, rbx
    call fread PLT                  ; eax = how many came
    mov r12d, eax
    call .put
    call .count
    cmp eax, MAX_CHESTS
    jbe .cfit
    mov eax, MAX_CHESTS
.cfit:
    mov edx, eax
    lea rdi, [chests]
    mov esi, CH_SIZE
    mov rcx, rbx
    call fread PLT
    mov dword [file_magic], 0
    lea rdi, [file_magic]
    mov esi, 1
    mov edx, 4
    mov rcx, rbx
    call fread PLT
    mov eax, [file_magic]
    cmp eax, [magic_rc]
    jne .close
    lea rdi, [book_seen]
    mov esi, 1
    mov edx, 32
    mov rcx, rbx
    call fread PLT
    call book_rebuild
    mov dword [file_magic], 0
    lea rdi, [file_magic]
    mov esi, 1
    mov edx, 4
    mov rcx, rbx
    call fread PLT
    mov eax, [file_magic]
    cmp eax, [magic_wt]
    jne .close
    lea rdi, [raining]
    mov esi, 4
    mov edx, 1
    mov rcx, rbx
    call fread PLT
    lea rdi, [weather_timer]
    mov esi, 4
    mov edx, 1
    mov rcx, rbx
    call fread PLT
    and dword [raining], 1
    cvtsi2ss xmm0, dword [raining]
    movss [rain_level], xmm0
    jmp .close
.old:                               ; the whole old table, overworld
    lea rdi, [packed]
    mov esi, 16
    mov edx, OLD_META
    mov rcx, rbx
    call fread PLT
    mov r12d, eax
    call .put
.close:
    mov rdi, rbx
    call fclose PLT
.out:
    pop r13
    pop r12
    pop rbx
    ret
.count:                             ; eax = a count read from the file
    sub rsp, 8
    mov dword [file_count], 0
    lea rdi, [file_count]
    mov esi, 4
    mov edx, 1
    mov rcx, rbx
    call fread PLT
    mov eax, [file_count]
    cmp eax, META_CAP
    jbe .cok
    xor eax, eax
.cok:
    add rsp, 8
    ret
.put:                               ; r12d entries in packed into the table
    sub rsp, 8
    lea r13, [packed]
.p:
    test r12d, r12d
    jz .pd
    cmp byte [r13 + 13], 1
    jne .pn
    mov edi, [r13]
    mov r10d, [r13 + 4]
    mov edx, [r13 + 8]
    movzx ecx, byte [r13 + 12]
    call meta_put_raw
.pn:
    add r13, 16
    dec r12d
    jmp .p
.pd:
    add rsp, 8
    ret

NOEXECSTACK
