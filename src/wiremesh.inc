extern wire_conn, meta_get

section .rodata
wm_h2d:     db 0, 1, 4, 5           ; side +x -x +z -z -> direction
wire_arms:                          ; dust toward +x, -x, +z, -z
    db 5,0,3, 8,1,5, 0,0
    db 0,0,3, 3,1,5, 0,0
    db 3,0,5, 5,1,8, 0,0
    db 3,0,0, 5,1,3, 0,0
wire_ups:                           ; and up the block on that side
    db 7,1,3, 8,8,5, 0,0
    db 0,1,3, 1,8,5, 0,0
    db 3,1,7, 5,8,8, 0,0
    db 3,1,0, 5,8,1, 0,0
rail_rot:   db 0, 2, 0, 0, 2, 2, 0, 2, 1, 3
shape_tile: db 16, 151, 152, 0      ; oak, birch, dark oak planks, stone
rail_slope: db 0, 0, 1, 2, 3, 4, 0, 0, 0, 0
align 4
wm_dirs:    dd 1,0,0, -1,0,0, 0,1,0, 0,-1,0, 0,0,1, 0,0,-1

section .bss
alignb 4
wb_box:     resb 8                  ; x0 y0 z0 x1 y1 z1
wb_tile:    resb 8                  ; tile of the +X -X +Y -Y +Z -Z face
wb_rot:     resd 1                  ; top texture turned to face +x, -x, +z, -z
wb_voff:    resd 1                  ; added to v on the sides (texels)
wb_stick:   resd 1                  ; 1 + the tile column a post's sides start at
wb_skip:    resd 1                  ; faces left out (a bit each)
wb_glow:    resd 1                  ; drawn at full brightness
wb_slope:   resd 1                  ; top rises toward +x (1), -x, +z, -z (4)

section .text

%macro WBOX 6
    mov dword [wb_box], (%1) | ((%2) << 8) | ((%3) << 16) | ((%4) << 24)
    mov word [wb_box + 4], (%5) | ((%6) << 8)
%endmacro

; set_tiles: eax on the four sides, ecx on top and bottom
set_tiles:
    mov [wb_tile], al
    mov [wb_tile + 1], al
    mov [wb_tile + 4], al
    mov [wb_tile + 5], al
    mov [wb_tile + 2], cl
    mov [wb_tile + 3], cl
    ret

; rot6: turn wb_box, laid out facing +x, to face direction eax
rot6:
    movzx r8d, byte [wb_box]
    movzx r9d, byte [wb_box + 1]
    movzx r10d, byte [wb_box + 2]
    movzx r11d, byte [wb_box + 3]
    movzx ecx, byte [wb_box + 4]
    movzx edx, byte [wb_box + 5]
    cmp eax, 1
    je .nx
    cmp eax, 2
    je .py
    cmp eax, 3
    je .ny
    cmp eax, 4
    je .pz
    cmp eax, 5
    je .nz
    ret
.nx:                                ; x' = 8 - x, z' = 8 - z
    mov eax, 8
    sub eax, r11d
    mov [wb_box], al
    mov eax, 8
    sub eax, r8d
    mov [wb_box + 3], al
    mov eax, 8
    sub eax, edx
    mov [wb_box + 2], al
    mov eax, 8
    sub eax, r10d
    mov [wb_box + 5], al
    ret
.py:                                ; x and y change places
    mov [wb_box], r9b
    mov [wb_box + 1], r8b
    mov [wb_box + 3], cl
    mov [wb_box + 4], r11b
    ret
.ny:                                ; and y' = 8 - y
    mov [wb_box], r9b
    mov [wb_box + 3], cl
    mov eax, 8
    sub eax, r11d
    mov [wb_box + 1], al
    mov eax, 8
    sub eax, r8d
    mov [wb_box + 4], al
    ret
.pz:                                ; x' = 8 - z, z' = x
    mov eax, 8
    sub eax, edx
    mov [wb_box], al
    mov eax, 8
    sub eax, r10d
    mov [wb_box + 3], al
    mov [wb_box + 2], r8b
    mov [wb_box + 5], r11b
    ret
.nz:                                ; x' = z, z' = 8 - x
    mov [wb_box], r10b
    mov [wb_box + 3], dl
    mov eax, 8
    sub eax, r11d
    mov [wb_box + 2], al
    mov eax, 8
    sub eax, r8d
    mov [wb_box + 5], al
    ret

; wbox: the box wb_box in the node at fb_o*, lit by fb_light, textured by
; where each point is in the node (2 texels per 1/8 node), into the +Y bin
; locals: [0] x, [4] y, [8] z of the corner
wbox:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 16
    lea r12, [wb_box]
    xor r13d, r13d                  ; face +X -X +Y -Y +Z -Z
.f:
    bt dword [wb_skip], r13d
    jc .fn
    mov eax, [n_bin + 8]
    cmp eax, MESH_BIN_CAP - 4
    ja .out
    imul eax, r13d, FR_SIZE
    lea r14, [faces]
    add r14, rax
    mov eax, [fb_light]
    mov ecx, eax
    and eax, 15
    shr ecx, 4
    cmp dword [wb_glow], 0
    je .lc
    mov ecx, 15
.lc:
    movzx edx, byte [r14 + 1]
    call light_colour
    mov r15d, eax
    mov eax, [n_bin + 8]
    lea rdi, [surf_bins + 2 * MESH_BIN_CAP * VERT_SIZE]
    shl rax, 4
    add rdi, rax
    add dword [n_bin + 8], 4
    xor ebx, ebx                    ; corner
.c:
    lea rax, [rbx + rbx*2]
    lea rsi, [r14 + 2 + rax]
    FBC 0, 0
    FBC 1, 4
    FBC 2, 8
    cmp r13d, 2
    jne .flat
    mov eax, [wb_slope]
    test eax, eax
    jz .flat
    mov ecx, [rsp]                  ; the top rises along x or z
    cmp eax, 3
    jb .sx
    mov ecx, [rsp + 8]
.sx:
    test eax, 1
    jnz .sup
    neg ecx
    add ecx, 8
.sup:
    add [rsp + 4], ecx
.flat:
    mov eax, [rsp]
    add eax, [fb_ox]
    mov [rdi], ax
    mov eax, [rsp + 4]
    add eax, [fb_oy]
    mov [rdi + 2], ax
    mov eax, [rsp + 8]
    add eax, [fb_oz]
    mov [rdi + 4], ax
    mov word [rdi + 6], 0
    cmp r13d, 2
    jb .ux
    cmp r13d, 4
    jb .uy
    mov eax, [rsp]                  ; z faces: u along x
    movzx edx, byte [r12]
    jmp .side
.ux:
    mov eax, [rsp + 8]              ; x faces: u along z
    movzx edx, byte [r12 + 2]
.side:
    mov ecx, 8
    sub ecx, [rsp + 4]
    shl ecx, 1
    add ecx, [wb_voff]
    cmp dword [wb_stick], 0
    je .plain
    sub eax, edx                    ; a post: from its own edge
    shl eax, 1
    add eax, [wb_stick]
    dec eax
    jmp .uv
.plain:
    shl eax, 1
    jmp .uv
.uy:
    mov eax, [rsp]
    shl eax, 1                      ; X
    mov ecx, [rsp + 8]
    shl ecx, 1                      ; Z
    mov edx, [wb_rot]
    test edx, edx
    jz .uv
    cmp edx, 1
    jne .r2
    neg eax
    add eax, 16
    neg ecx
    add ecx, 16
    jmp .uv
.r2:
    cmp edx, 2
    jne .r3
    xchg eax, ecx                   ; u = Z, v = 16 - X
    neg ecx
    add ecx, 16
    jmp .uv
.r3:
    xchg eax, ecx                   ; u = 16 - Z, v = X
    neg eax
    add eax, 16
.uv:
    lea rdx, [wb_tile]
    movzx edx, byte [rdx + r13]
    mov esi, edx
    and edx, 15
    shl edx, 7
    lea eax, [rax + rdx + 16]
    mov [rdi + 8], ax
    shr esi, 4
    shl esi, 7
    lea ecx, [rcx + rsi + 16]
    mov [rdi + 10], cx
    mov [rdi + 12], r15d
    add rdi, VERT_SIZE
    inc ebx
    cmp ebx, 4
    jb .c
.fn:
    inc r13d
    cmp r13d, 6
    jb .f
.out:
    add rsp, 16
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; emit_part(lx edi, yi esi, lz edx, block ecx, light byte r8d): a bluestone
; part or a rail
; locals: [0], [4] the part's state
emit_part:
    ENTER_FN 16
    mov [fb_light], r8d
    mov ebx, ecx
    lea eax, [rdi*8]
    mov [fb_ox], eax
    add edi, [m_wx]
    mov r12d, edi                   ; world x
    lea eax, [rsi + WORLD_YMIN]
    mov r13d, eax
    shl eax, 3
    mov [fb_oy], eax
    lea eax, [rdx*8]
    mov [fb_oz], eax
    add edx, [m_wz]
    mov r14d, edx
    xor eax, eax
    mov [wb_rot], eax
    mov [wb_voff], eax
    mov [wb_stick], eax
    mov [wb_skip], eax
    mov [wb_glow], eax
    mov [wb_slope], eax
    cmp ebx, W_TORCH
    jb .wire
    cmp ebx, W_LEVER
    jb .torch
    cmp ebx, W_BUTTON
    jb .lever
    cmp ebx, W_PLATE
    jb .button
    cmp ebx, W_REPEATER
    jb .plate
    cmp ebx, W_COMPARATOR
    jb .rep
    cmp ebx, W_LAMP
    jb .comp
    cmp ebx, W_PISTON
    jb .out
    cmp ebx, W_PHEAD
    jb .piston
    cmp ebx, W_RAIL
    jb .head
    cmp ebx, W_PRAIL
    jb .rail
    cmp ebx, W_DOOR
    jb .prail
    cmp ebx, W_TRAP
    jb .door
    cmp ebx, W_END
    jb .trap
    cmp ebx, W_SHAPE
    je .shape
    jmp .out

.wire:
    mov eax, 125
    cmp ebx, W_WIRE
    je .w_tile
    mov eax, 126
    mov dword [wb_glow], 1
.w_tile:
    mov ecx, eax
    call set_tiles
    mov edi, r12d
    mov esi, r13d
    mov edx, r14d
    call wire_conn
    mov [rsp], eax
    ; the arms: all four for a lone dot, both ways for a line
    and eax, 15
    jnz .w_some
    mov eax, 15
    jmp .w_arms
.w_some:
    test eax, 12
    jnz .w_z
    mov eax, 3
    jmp .w_arms
.w_z:
    test eax, 3
    jnz .w_arms
    mov eax, 12
.w_arms:
    mov [rsp + 4], eax
    WBOX 3,0,3, 5,1,5
    call wbox
    xor r15d, r15d
.w_arm:
    bt dword [rsp + 4], r15d
    jnc .w_next
    lea rax, [wire_arms]
    mov rcx, [rax + r15*8]
    mov [wb_box], rcx
    call wbox
    lea eax, [r15 + 4]
    bt dword [rsp], eax
    jnc .w_next
    lea rax, [wire_ups]
    mov rcx, [rax + r15*8]
    mov [wb_box], rcx
    call wbox
.w_next:
    inc r15d
    cmp r15d, 4
    jb .w_arm
    jmp .out

.torch:
    lea eax, [rbx - W_TORCH]
    mov r15d, eax
    shr r15d, 1
    mov ecx, 125
    mov edx, 3
    test eax, 1
    jz .t_set
    mov ecx, 126
    mov edx, 9
    mov dword [wb_glow], 1
.t_set:
    mov [wb_stick], edx
    mov eax, 127
    call set_tiles
    test r15d, r15d
    jnz .t_wall
    WBOX 4,0,4, 5,5,5
    call wbox
    jmp .out
.t_wall:
    mov dword [wb_voff], 4
    WBOX 7,2,4, 8,7,5
.turn_h:                            ; turn to side r15d - 1 and draw
    lea rax, [wm_h2d]
    movzx eax, byte [rax + r15 - 1]
    call rot6
    call wbox
    jmp .out

.lever:
    lea eax, [rbx - W_LEVER]
    mov r15d, eax
    shr r15d, 1
    and eax, 1
    mov [rsp], eax
    mov eax, 15
    mov ecx, 15
    call set_tiles
    test r15d, r15d
    jnz .l_wall
    WBOX 2,0,3, 6,1,5
    call wbox
    mov dword [wb_stick], 13
    mov eax, 127
    mov ecx, 15
    call set_tiles
    WBOX 2,1,4, 3,6,5
    cmp dword [rsp], 0
    je .l_draw
    WBOX 5,1,4, 6,6,5
.l_draw:
    call wbox
    jmp .out
.l_wall:
    WBOX 7,2,3, 8,6,5
    lea rax, [wm_h2d]
    movzx eax, byte [rax + r15 - 1]
    call rot6
    call wbox
    mov dword [wb_stick], 13
    mov eax, 127
    mov ecx, 15
    call set_tiles
    mov dword [wb_voff], 4          ; up: off
    WBOX 6,4,4, 7,8,5
    cmp dword [rsp], 0
    je .turn_h
    mov dword [wb_voff], -4         ; down: on
    WBOX 6,0,4, 7,4,5
    jmp .turn_h

.button:
    lea eax, [rbx - W_BUTTON]
    mov r15d, eax
    shr r15d, 1
    inc r15d
    mov [rsp], eax
    xor eax, eax
    xor ecx, ecx
    call set_tiles
    WBOX 6,3,3, 8,5,5
    test dword [rsp], 1
    jz .turn_h
    WBOX 7,3,3, 8,5,5
    jmp .turn_h

.plate:
    xor eax, eax
    test ebx, 1
    jz .pl_set
    mov eax, 38
.pl_set:
    mov ecx, eax
    call set_tiles
    WBOX 1,0,1, 7,1,7
    call wbox
    jmp .out

.rep:
    lea eax, [rbx - W_REPEATER]
    mov r15d, eax
    shr r15d, 1
    and eax, 1
    mov [rsp], eax
    mov [wb_rot], r15d
    mov eax, 38
    mov ecx, 134
    call set_tiles
    WBOX 0,0,0, 8,1,8
    call wbox
    inc r15d
    call .nub_tiles
    WBOX 6,1,4, 7,3,5
    lea rax, [wm_h2d]
    movzx eax, byte [rax + r15 - 1]
    call rot6
    call wbox
    ; the second post: further back the longer the delay
    mov edi, r12d
    mov esi, r13d
    mov edx, r14d
    call meta_get
    and eax, 3
    mov ecx, 4
    sub ecx, eax
    WBOX 0,1,4, 0,3,5
    mov [wb_box], cl
    inc ecx
    mov [wb_box + 3], cl
    jmp .turn_h

.nub_tiles:                         ; lit ([rsp + 8] here: the caller's [rsp])
    mov eax, 125
    mov dword [wb_glow], 0
    cmp dword [rsp + 8], 0
    je .nt
    mov eax, 126
    mov dword [wb_glow], 1
.nt:
    mov ecx, eax
    jmp set_tiles

.comp:
    lea eax, [rbx - W_COMPARATOR]
    mov r15d, eax
    shr r15d, 1
    and eax, 1
    mov [rsp], eax
    mov [wb_rot], r15d
    mov eax, 38
    mov ecx, 135
    call set_tiles
    WBOX 0,0,0, 8,1,8
    call wbox
    inc r15d
    call .nub_tiles
    WBOX 1,1,2, 2,3,3
    lea rax, [wm_h2d]
    movzx eax, byte [rax + r15 - 1]
    call rot6
    call wbox
    WBOX 1,1,5, 2,3,6
    lea rax, [wm_h2d]
    movzx eax, byte [rax + r15 - 1]
    call rot6
    call wbox
    ; the front post is lit when it subtracts
    mov edi, r12d
    mov esi, r13d
    mov edx, r14d
    call meta_get
    shr eax, 4
    and eax, 1
    mov [rsp], eax
    call .nub_tiles
    WBOX 6,1,4, 7,2,5
    jmp .turn_h

.piston:
    lea eax, [rbx - W_PISTON]
    mov edx, 132                    ; its face: wood, or slime on a sticky one
    cmp eax, 12
    jb .p_plain
    sub eax, 12
    mov edx, 133
.p_plain:
    mov r15d, eax
    shr r15d, 1
    and eax, 1
    mov [rsp], eax
    mov dword [wb_tile], 0x83838383 ; 131 all round
    mov word [wb_tile + 4], 0x8383
    lea rax, [wb_tile]
    mov [rax + r15], dl
    mov ecx, r15d
    xor ecx, 1
    mov byte [rax + rcx], 15
    cmp dword [rsp], 0
    jne .p_out
    WBOX 0,0,0, 8,8,8
    call wbox
    jmp .out
.p_out:
    WBOX 0,0,0, 6,8,8
    mov eax, r15d
    call rot6
    call wbox
    mov dword [wb_tile], 0x84848484 ; the rod
    mov word [wb_tile + 4], 0x8484
    WBOX 6,3,3, 8,5,5
    mov eax, r15d
    call rot6
    call wbox
    jmp .out

.head:
    lea r15d, [rbx - W_PHEAD]
    ; sticky if the piston behind it is
    mov eax, r15d
    xor eax, 1
    lea rax, [rax + rax*2]
    lea rcx, [wm_dirs]
    lea rax, [rcx + rax*4]
    mov edi, [rax]
    add edi, r12d
    mov esi, [rax + 4]
    add esi, r13d
    mov edx, [rax + 8]
    add edx, r14d
    call world_get
    mov edx, 132
    sub eax, W_SPISTON
    cmp eax, 11
    ja .h_face
    mov edx, 133
.h_face:
    mov dword [wb_tile], 0x84848484
    mov word [wb_tile + 4], 0x8484
    lea rax, [wb_tile]
    mov [rax + r15], dl
    WBOX 6,0,0, 8,8,8
    mov eax, r15d
    call rot6
    call wbox
    WBOX 0,3,3, 6,5,5
    mov eax, r15d
    call rot6
    call wbox
    jmp .out

.door:
    lea r15d, [rbx - W_DOOR]
    mov edi, r12d
    mov esi, r13d
    mov edx, r14d
    cmp r15d, 2
    jb .d_low
    dec esi                         ; kept with the lower half
.d_low:
    call meta_get
    mov [rsp], eax
    mov ecx, 141                    ; wood, bottom
    test eax, 16
    jz .d_wood
    mov ecx, 143
.d_wood:
    cmp r15d, 2
    jb .d_tile
    inc ecx                         ; the top, with its window
.d_tile:
    mov eax, ecx
    call set_tiles
    WBOX 7,0,0, 8,8,8               ; shut: the panel on its side
    test r15d, 1
    jz .d_turn
    WBOX 0,0,0, 8,8,1               ; open: along the hinge
    test dword [rsp], 4
    jz .d_turn
    WBOX 0,0,7, 8,8,8
.d_turn:
    mov eax, [rsp]
    and eax, 3
    lea rcx, [wm_h2d]
    movzx eax, byte [rcx + rax]
    call rot6
    call wbox
    jmp .out

.trap:
    mov edi, r12d
    mov esi, r13d
    mov edx, r14d
    call meta_get
    mov [rsp], eax
    mov eax, 145
    test dword [rsp], 16
    jz .t_wood
    mov eax, 146
.t_wood:
    mov ecx, eax
    call set_tiles
    test ebx, 1
    jnz .t_open
    WBOX 0,0,0, 8,1,8
    test dword [rsp], 4
    jz .t_draw
    WBOX 0,7,0, 8,8,8
.t_draw:
    call wbox
    jmp .out
.t_open:                            ; up against its hinge side
    WBOX 7,0,0, 8,8,8
    jmp .d_turn

.shape:                             ; slab, stairs or chest (wire.asm: the bits)
    mov edi, r12d
    mov esi, r13d
    mov edx, r14d
    call meta_get
    mov [rsp], eax
    test eax, 0x80
    jnz .portal
    test eax, 0x40
    jnz .chest
    shr eax, 4
    and eax, 3
    lea rcx, [shape_tile]
    movzx eax, byte [rcx + rax]
    mov ecx, eax
    call set_tiles
    WBOX 0,0,0, 8,4,8
    test dword [rsp], 4
    jz .s_low
    WBOX 0,4,0, 8,8,8
.s_low:
    call wbox
    test dword [rsp], 8
    jz .out
    WBOX 4,4,0, 8,8,8               ; stairs: the back, laid out climbing to +x
    test dword [rsp], 4
    jz .s_back
    WBOX 4,0,0, 8,4,8
.s_back:
    jmp .d_turn
.portal:                            ; green: across x, across z or flat
    mov eax, 156
    mov ecx, 156
    call set_tiles
    mov dword [wb_glow], 1
    mov eax, [rsp]
    shr eax, 1
    and eax, 3
    WBOX 0,0,3, 8,8,5
    test eax, eax
    jz .p_draw
    WBOX 3,0,0, 5,8,8
    cmp eax, 1
    je .p_draw
    WBOX 0,5,0, 8,6,8
.p_draw:
    call wbox
    jmp .out
.chest:
    mov eax, 154
    mov ecx, 155
    call set_tiles
    mov eax, [rsp]
    and eax, 3
    lea rcx, [wm_h2d]
    movzx eax, byte [rcx + rax]
    lea rcx, [wb_tile]
    mov byte [rcx + rax], 153       ; the front, with the latch
    WBOX 0,0,0, 8,7,8
    call wbox
    jmp .out

.rail:
    lea r15d, [rbx - W_RAIL]
    mov eax, 136
    cmp r15d, 6
    jb .r_draw
    mov eax, 137
    jmp .r_draw
.prail:
    lea eax, [rbx - W_PRAIL]
    mov r15d, eax
    shr r15d, 1
    and eax, 1
    add eax, 138
.r_draw:
    mov [wb_tile + 2], al
    mov dword [wb_skip], 0x3b       ; only the top
    lea rax, [rail_rot]
    movzx eax, byte [rax + r15]
    mov [wb_rot], eax
    lea rax, [rail_slope]
    movzx eax, byte [rax + r15]
    mov [wb_slope], eax
    WBOX 0,0,0, 8,1,8
    call wbox
.out:
    LEAVE_FN
