%include "common.inc"

global invui_frame, invui_close, invui_open, cur_furnace, dye_in, dye_out, dye_color
global palette, palette_n, palette_top, invui_qpress
global book_tick, book_clear, book_rebuild, book_seen, book_open, book_fill, book_known
global book_list, book_n, book_ghost, panel_x, panel_y

extern state, mouse_x, mouse_y, mouse_click, win_w, win_h, game_mode
extern inv, cursor, craft_grid, craft_out, craft_size, craft_update
extern craft_take, craft_return, item_stack, item_name, item_valid
extern furnaces, smelt_result, fuel_time
extern hud_rect, hud_text, hud_item, hud_begin, draw_figure
extern resume_game, sel_slot, mouse_wheel, tool_info, dye_rgb, inv_add_slot
extern drop_slot, armor, armor_piece, throw_item, keys, bind_drop, dt, menu_lmb
extern cur_chest, recipes, hud_message, body_water, body_lava
extern beacon_sel, beacon_status, effect_icon, meta_get, meta_set, sound_keep

SLOT_PX     equ 36                  ; slot size on screen
SLOT_STEP   equ 40
PANEL_W     equ 9 * SLOT_STEP + 16
PANEL_H     equ 344
ROWS_Y      equ 168                 ; main rows (hotbar 8 below them)
SB_X        equ 9 * SLOT_STEP + 12  ; creative scroll bar: x, top, size
SB_Y        equ 36
SB_W        equ 16
SB_H        equ 6 * SLOT_STEP - 4
SB_MINTHUMB equ 24
BOOK_W      equ 5 * SLOT_STEP + 16  ; the recipe book's panel
BOOK_COLS   equ 5
BOOK_ROWS   equ 6
RC_SIZE     equ 16                  ; items.asm recipe rows
FU_IN       equ 12
FU_FUEL     equ 16
FU_OUT      equ 20
FU_BURN     equ 24
FU_BURNMAX  equ 28
FU_COOK     equ 32
FU_SIZE     equ 48

section .rodata
align 4
f_two:      dd 2.0
f_four:     dd 4.0
f_slot:     dd 36.0
f_step:     dd 40.0
f_half:     dd 0.5
f_smelt:    dd 10.0
f_zero:     dd 0.0
f_34:       dd 34.0
f_onehalf:  dd 1.5
f_fig:      dd 4.0                  ; player figure scale (pixels per unit)
f_tipline:  dd 20.0
f_qhold:    dd 0.4                  ; holding Q this long throws the stack
f_never:    dd -1.0e9
s_inventory: db "INVENTORY", 0
s_crafting: db "CRAFTING", 0
s_furnace:  db "FURNACE", 0
s_dyemaker: db "DYE MAKER", 0
s_flower:   db "FLOWER", 0
s_colour:   db "PICK A COLOUR", 0
s_creative: db "CREATIVE ITEMS  (WHEEL OR BAR)", 0
s_hint:     db "E / ESC: CLOSE", 0
s_invlabel: db "INVENTORY", 0
s_chest:    db "CHEST", 0
s_recipes:  db "RECIPES", 0
s_beacon:   db "BEACON", 0
s_bc_on:    db "FULL PYRAMID - PICK ITS POWER", 0
s_bc_small: db "NEEDS A 4 LAYER PYRAMID FOR A POWER", 0
s_bc_sky:   db "NEEDS THE SKY ABOVE IT", 0
s_bc_wait:  db "LOOKING AT THE PYRAMID...", 0
s_bc_reach: db "WORKS 15 BLOCKS AROUND IT", 0
s_bc_names: db "REGEN", 0, "STRENGTH", 0, "SPEED", 0
s_newrec:   db "NEW RECIPES - SEE THE RECIPE BOOK", 0
s_prev:     db "<", 0
s_next:     db ">", 0
s_none:     db "PICK THINGS UP", 0
s_none2:    db "TO LEARN RECIPES", 0

section .bss
alignb 4
cur_furnace: resd 1                 ; furnace index for the furnace screen
panel_x:    resd 1                  ; panel origin (pixels)
panel_y:    resd 1
hover_slot: resq 1                  ; slot under the mouse (for tooltips)
hover_kind: resd 1
q_held:     resd 1                  ; Q is down (its first press handled)
sb_drag:    resd 1                  ; dragging the creative scroll bar
q_time:     resd 1                  ; seconds it has been held
palette:    resb 256                ; creative item list
palette_n:  resd 1
palette_top: resd 1                 ; first row shown (scrolls with the wheel)
tip_buf:    resb 64                 ; second tooltip line (tools)
dye_in:     resd 1                  ; dye maker: the flower slot
dye_out:    resd 1                  ; and what it makes
dye_color:  resd 1                  ; the colour picked (0-15)
panel_shift: resd 1                 ; the panel moved right (the recipe book open)
book_seen:  resb 32                 ; items the player has had (a bit each)
book_known: resb 64                 ; recipes unlocked (a bit per recipe)
book_open:  resd 1
book_page:  resd 1
book_n:     resd 1
book_list:  resq 512                ; the recipes shown (one per thing made)
book_ghost: resq 1                  ; a recipe shown faded in the empty grid
book_tip:   resd 1                  ; the hovered entry, for its tooltip
page_text:  resb 16

section .text

; void invui_open(int screen) - GS_INVENTORY / GS_CRAFT / GS_FURNACE
invui_open:
    mov [state], edi
    mov dword [craft_size], 2
    cmp edi, GS_CRAFT
    jne .s
    mov dword [craft_size], 3
.s:
    mov dword [craft_out], 0
    jmp dye_update

; void invui_close(void) - return the crafting grid, the dye maker's flower
; and the cursor stack
invui_close:
    sub rsp, 8
    mov edi, [dye_in]
    test edi, edi
    jz .noflower
    mov dword [dye_in], 0
    call inv_add_slot
    test eax, eax
    jz .noflower
    mov edi, eax
    call drop_slot
.noflower:
    mov dword [dye_out], 0
    call craft_return
    call resume_game
    add rsp, 8
    ret

; dye_update - the dye maker's output: a dye of the picked colour when a
; flower is in
dye_update:
    xor eax, eax
    movzx ecx, byte [dye_in]
    cmp ecx, B_FLOWER_Y
    je .flower
    cmp ecx, B_FLOWER_R
    jne .set
.flower:
    mov eax, [dye_color]
    add eax, I_DYE | (1 << 8)
.set:
    mov [dye_out], eax
    ret

; ---------------------------------------------------------------------------
; slot(x, y in xmm0/1 relative to the panel, rdi -> slot dword, esi kind)
; kind: 0 normal, 1 output (take only), 2 creative (pick a fresh stack),
; 3 + piece: an armour slot (helmet, chestplate, leggings, boots)
; Draws the slot and its item and handles a click on it.
; locals: [0] x, [4] y, [8] slot ptr, [16] kind
slot:
    ENTER_FN 32
    cvtsi2ss xmm2, dword [panel_x]
    addss xmm0, xmm2
    cvtsi2ss xmm2, dword [panel_y]
    addss xmm1, xmm2
    movss [rsp], xmm0
    movss [rsp + 4], xmm1
    mov [rsp + 8], rdi
    mov [rsp + 16], esi
    ; hover?
    xor ebx, ebx
    cvtsi2ss xmm2, dword [mouse_x]
    cvtsi2ss xmm3, dword [mouse_y]
    comiss xmm2, xmm0
    jb .nh
    comiss xmm3, xmm1
    jb .nh
    movaps xmm4, xmm0
    addss xmm4, [f_slot]
    comiss xmm2, xmm4
    ja .nh
    movaps xmm4, xmm1
    addss xmm4, [f_slot]
    comiss xmm3, xmm4
    ja .nh
    mov ebx, 1
    mov rax, [rsp + 8]
    mov [hover_slot], rax
    mov eax, [rsp + 16]
    mov [hover_kind], eax
.nh:
    ; sunken frame: dark top-left edge, white bottom-right, grey inside
%macro SRECT 5                      ; dx0, dy0, dx1, dy1 (memory), colour
    movss xmm0, [rsp]
    addss xmm0, %1
    movss xmm1, [rsp + 4]
    addss xmm1, %2
    movss xmm2, [rsp]
    addss xmm2, %3
    movss xmm3, [rsp + 4]
    addss xmm3, %4
    mov edi, %5
    call hud_rect
%endmacro
    SRECT [f_zero], [f_zero], [f_slot], [f_slot], 0xff373737
    SRECT [f_two], [f_two], [f_slot], [f_slot], 0xffffffff
    mov r12d, 0xff8b8b8b
    test ebx, ebx
    jz .f
    mov r12d, 0xffc5c5c5
.f:
    SRECT [f_two], [f_two], [f_34], [f_34], r12d
    ; item
    mov rax, [rsp + 8]
    mov edi, [rax]
    test edi, edi
    jz .click
    movss xmm0, [rsp]
    addss xmm0, [f_two]
    movss xmm1, [rsp + 4]
    addss xmm1, [f_two]
    movss xmm2, [f_slot]
    subss xmm2, [f_four]
    mov esi, 1                      ; with count
    cmp dword [rsp + 16], 2
    jne .draw
    xor esi, esi                    ; creative palette: no count
.draw:
    call hud_item
.click:
    test ebx, ebx
    jz .out
    mov eax, [mouse_click]
    test eax, eax
    jz .out
    mov dword [mouse_click], 0
    mov r12, [rsp + 8]              ; slot
    cmp dword [rsp + 16], 1
    je .output
    cmp dword [rsp + 16], 2
    je .creative
    ja .armor
    cmp eax, 3
    je .right
    ; ---- left click
    mov eax, [cursor]
    mov ecx, [r12]
    test eax, eax
    jnz .l_have
    mov [cursor], ecx               ; pick up
    mov dword [r12], 0
    jmp .changed
.l_have:
    test ecx, ecx
    jnz .l_both
    mov [r12], eax                  ; put down
    mov dword [cursor], 0
    jmp .changed
.l_both:
    cmp al, cl
    jne .swap
    ; same item: merge as much as fits
    movzx edi, al
    call item_stack
    mov edx, eax                    ; limit
    movzx ecx, byte [r12 + 1]
    sub edx, ecx                    ; room
    jle .swap
    movzx eax, byte [cursor + 1]
    cmp eax, edx
    jbe .mfit
    mov eax, edx
.mfit:
    add [r12 + 1], al
    sub [cursor + 1], al
    jnz .changed
    mov dword [cursor], 0
    jmp .changed
.swap:
    mov eax, [cursor]
    mov ecx, [r12]
    mov [r12], eax
    mov [cursor], ecx
    jmp .changed
    ; ---- right click
.right:
    mov eax, [cursor]
    mov ecx, [r12]
    test eax, eax
    jnz .r_have
    test ecx, ecx
    jz .out
    ; take half (rounded up)
    movzx edx, byte [r12 + 1]
    mov eax, edx
    inc eax
    shr eax, 1                      ; taken
    sub edx, eax                    ; left
    mov ecx, [r12]
    and ecx, 0xffff00ff
    mov r8d, eax
    shl r8d, 8
    or r8d, ecx
    mov [cursor], r8d
    test edx, edx
    jz .r_all
    mov [r12 + 1], dl
    jmp .changed
.r_all:
    mov dword [r12], 0
    jmp .changed
.r_have:
    test ecx, ecx
    jz .r_one_new
    cmp al, cl
    jne .out
    movzx edi, al
    call item_stack
    movzx ecx, byte [r12 + 1]
    cmp ecx, eax
    jae .out
    inc byte [r12 + 1]
    jmp .r_dec
.r_one_new:
    and eax, 0xffff00ff
    or eax, 1 << 8
    mov [r12], eax
.r_dec:
    dec byte [cursor + 1]
    jnz .changed
    mov dword [cursor], 0
    jmp .changed
    ; ---- crafting output: take the result
.output:
    mov ecx, [r12]
    test ecx, ecx
    jz .out
    mov eax, [cursor]
    test eax, eax
    jz .o_take
    cmp al, cl
    jne .out
    movzx edi, al
    call item_stack
    movzx edx, byte [cursor + 1]
    mov ecx, [r12]
    shr ecx, 8
    and ecx, 0xff
    add edx, ecx
    cmp edx, eax
    ja .out
    mov [cursor + 1], dl
    jmp .o_used
.o_take:
    mov [cursor], ecx
.o_used:
    lea rax, [dye_out]
    cmp r12, rax
    jne .notdye
    dec byte [dye_in + 1]           ; a dye uses up one flower
    jnz .dyeleft
    mov dword [dye_in], 0
.dyeleft:
    call dye_update
    jmp .out
.notdye:
    lea rax, [craft_out]
    cmp r12, rax
    jne .fu_out
    call craft_take
    jmp .out
.fu_out:
    mov dword [r12], 0              ; furnace output slot
    jmp .out
    ; ---- armour slot: either button takes the piece off, or puts on the
    ; piece on the mouse (swapping) when it is the right kind
.armor:
    mov eax, [cursor]
    test eax, eax
    jz .a_swap
    movzx edi, al
    call armor_piece
    add eax, 3
    cmp eax, [rsp + 16]
    jne .out
.a_swap:
    mov eax, [cursor]
    mov ecx, [r12]
    mov [r12], eax
    mov [cursor], ecx
    jmp .out
    ; ---- creative palette: a full stack of the item
.creative:
    movzx edi, byte [r12]
    push rdi
    sub rsp, 8
    call item_stack
    add rsp, 8
    pop rdi
    shl eax, 8
    or eax, edi
    mov [cursor], eax
    jmp .out
.changed:
    call craft_update
    call dye_update
.out:
    LEAVE_FN

; slot_grid(x, y relative, columns ecx, rows r8d, rdi first slot, esi kind)
; locals: [0] x0, [4] y0, [8] row, [12] col, [16] slot ptr, [24] kind,
;         [28] columns, [32] rows
slot_grid:
    ENTER_FN 48
    movss [rsp], xmm0
    movss [rsp + 4], xmm1
    mov [rsp + 16], rdi
    mov [rsp + 24], esi
    mov [rsp + 28], ecx
    mov [rsp + 32], r8d
    xor r12d, r12d                  ; row
.r:
    cmp r12d, [rsp + 32]
    jae .out
    xor r13d, r13d                  ; column
.c:
    cmp r13d, [rsp + 28]
    jae .rn
    cvtsi2ss xmm0, r13d
    mulss xmm0, [f_step]
    addss xmm0, [rsp]
    cvtsi2ss xmm1, r12d
    mulss xmm1, [f_step]
    addss xmm1, [rsp + 4]
    mov eax, r12d
    imul eax, [rsp + 28]
    add eax, r13d
    mov rdi, [rsp + 16]
    lea rdi, [rdi + rax*4]
    mov esi, [rsp + 24]
    call slot
    inc r13d
    jmp .c
.rn:
    inc r12d
    jmp .r
.out:
    LEAVE_FN

; the player's 36 slots: main 3 rows then the hotbar, at panel y = edi
inventory_rows:
    ENTER_FN 0
    mov r12d, edi
    mov eax, 8
    cvtsi2ss xmm0, eax
    cvtsi2ss xmm1, r12d
    mov ecx, 9
    mov r8d, 3
    lea rdi, [inv + 9 * 4]
    xor esi, esi
    call slot_grid
    mov eax, 8
    cvtsi2ss xmm0, eax
    lea eax, [r12 + 3 * SLOT_STEP + 8]
    cvtsi2ss xmm1, eax
    mov ecx, 9
    mov r8d, 1
    lea rdi, [inv]
    xor esi, esi
    call slot_grid
    LEAVE_FN

; panel of edi x esi pixels centred on screen with title rdx
panel:
    ENTER_FN 16
    mov r12d, edi
    mov r13d, esi
    mov r14, rdx
    mov eax, [win_w]
    sub eax, r12d
    sar eax, 1
    add eax, [panel_shift]
    mov [panel_x], eax
    mov eax, [win_h]
    sub eax, r13d
    sar eax, 1
    mov [panel_y], eax
    ; dim the world, then the panel
    xorps xmm0, xmm0
    xorps xmm1, xmm1
    cvtsi2ss xmm2, dword [win_w]
    cvtsi2ss xmm3, dword [win_h]
    mov edi, 0x90000000
    call hud_rect
    ; raised panel: black outline, white top-left edge, dark bottom-right
    mov eax, -2
    mov ecx, -2
    lea edx, [r12 + 2]
    lea r8d, [r13 + 2]
    mov r9d, 0xff000000
    call prect
    xor eax, eax
    xor ecx, ecx
    mov edx, r12d
    mov r8d, r13d
    mov r9d, 0xffffffff
    call prect
    mov eax, 4
    mov ecx, 4
    mov edx, r12d
    mov r8d, r13d
    mov r9d, 0xff555555
    call prect
    mov eax, 4
    mov ecx, 4
    lea edx, [r12 - 4]
    lea r8d, [r13 - 4]
    mov r9d, 0xffc6c6c6
    call prect
    test r14, r14
    jz .notitle
    mov eax, 12
    mov ecx, 10
    mov rdi, r14
    call label
.notitle:
    LEAVE_FN

; prect(eax x0, ecx y0, edx x1, r8d y1 panel relative, r9d colour)
prect:
    sub rsp, 8
    add eax, [panel_x]
    cvtsi2ss xmm0, eax
    add ecx, [panel_y]
    cvtsi2ss xmm1, ecx
    add edx, [panel_x]
    cvtsi2ss xmm2, edx
    add r8d, [panel_y]
    cvtsi2ss xmm3, r8d
    mov edi, r9d
    call hud_rect
    add rsp, 8
    ret

; label(eax x, ecx y panel relative, rdi text): dark grey, scale 2
label:
    sub rsp, 8
    add eax, [panel_x]
    add ecx, [panel_y]
    cvtsi2ss xmm0, eax
    cvtsi2ss xmm1, ecx
    movss xmm2, [f_two]
    mov esi, 0xff404040
    call hud_text
    add rsp, 8
    ret

; the stack on the mouse and the name of the hovered item
cursor_and_tip:
    ENTER_FN 16
    mov edi, [cursor]
    test edi, edi
    jz .tip
    cvtsi2ss xmm0, dword [mouse_x]
    mov eax, 16
    cvtsi2ss xmm2, eax
    mulss xmm2, [f_half]
    subss xmm0, xmm2
    cvtsi2ss xmm1, dword [mouse_y]
    subss xmm1, xmm2
    mov eax, 32
    cvtsi2ss xmm2, eax
    mov esi, 1
    call hud_item
    jmp .out
.tip:
    mov rax, [hover_slot]
    test rax, rax
    jz .out
    mov r13d, [rax]                 ; the slot
    movzx eax, byte [rax]
    test eax, eax
    jz .out
    lea rcx, [item_name]
    mov rdi, [rcx + rax*8]
    test rdi, rdi
    jz .out
    mov r12, rdi
    ; tools get a second line: extra damage and durability left
    mov edi, r13d
    lea rsi, [tip_buf]
    mov edx, 64
    call tool_info
    mov r13d, eax                   ; its length (0: none)
    cvtsi2ss xmm0, dword [mouse_x]
    mov eax, 14
    cvtsi2ss xmm1, eax
    addss xmm0, xmm1
    cvtsi2ss xmm1, dword [mouse_y]
    mov eax, 18
    cvtsi2ss xmm2, eax
    subss xmm1, xmm2
    ; background plate
    movss [rsp], xmm0
    movss [rsp + 4], xmm1
    mov rcx, r12
    xor eax, eax
.len:
    cmp byte [rcx + rax], 0
    je .ld
    inc eax
    jmp .len
.ld:
    cmp eax, r13d
    cmovl eax, r13d                 ; as wide as the longer line
    imul eax, eax, 12
    add eax, 8
    cvtsi2ss xmm2, eax
    addss xmm2, xmm0
    movaps xmm3, xmm1
    mov eax, 20
    test r13d, r13d
    jz .h1
    mov eax, 40
.h1:
    cvtsi2ss xmm4, eax
    addss xmm3, xmm4
    subss xmm0, [f_four]
    subss xmm1, [f_two]
    mov edi, 0xf0100010
    call hud_rect
    movss xmm0, [rsp]
    movss xmm1, [rsp + 4]
    movss xmm2, [f_two]
    mov rdi, r12
    mov esi, 0xffffffff
    call hud_text
    test r13d, r13d
    jz .out
    movss xmm0, [rsp]
    movss xmm1, [rsp + 4]
    addss xmm1, [f_tipline]
    movss xmm2, [f_two]
    lea rdi, [tip_buf]
    mov esi, 0xffffd080             ; light blue
    call hud_text
.out:
    LEAVE_FN

; build the creative palette: every holdable item once
build_palette:
    xor ecx, ecx                    ; id
    xor edx, edx                    ; count
.p:
    push rcx
    push rdx
    mov edi, ecx
    call item_valid
    pop rdx
    pop rcx
    test eax, eax
    jz .n
    cmp ecx, I_EGG_SHEEP
    je .n                           ; listed after the zombie egg instead
    cmp ecx, I_BEACONCORE
    je .n                           ; only from wither skeletons
    lea eax, [rcx - I_EGG_WITHER]
    cmp eax, I_EGG_GIANT - I_EGG_WITHER
    jbe .n
    lea rax, [palette]
    mov [rax + rdx], cl
    inc edx
    cmp ecx, I_EGG_ZOMBIE
    jne .n
    mov byte [rax + rdx], I_EGG_SHEEP     ; the later eggs with the others
    mov byte [rax + rdx + 1], I_EGG_WITHER
    mov byte [rax + rdx + 2], I_EGG_SLIME
    mov byte [rax + rdx + 3], I_EGG_GHAST
    mov byte [rax + rdx + 4], I_EGG_GIANT
    add edx, 5
.n:
    inc ecx
    cmp ecx, 256
    jb .p
    mov [palette_n], edx
    ret

; ---------------------------------------------------------------------------
; void invui_frame(void) - the open screen
; locals: [0] slot dword scratch for the palette (9 x 6 + 1)
invui_frame:
    ENTER_FN 256
    call q_hold
    call hud_begin                  ; the HUD drawn before leaves blending off
    mov qword [hover_slot], 0
    ; the recipe book: survival, the inventory and the crafting table
    mov dword [panel_shift], 0
    cmp dword [game_mode], 0
    jne .noshift
    mov eax, [state]
    cmp eax, GS_INVENTORY
    je .shift
    cmp eax, GS_CRAFT
    jne .noshift
.shift:
    cmp dword [book_open], 0
    je .noshift
    mov dword [panel_shift], BOOK_W / 2 + 4
.noshift:
    mov eax, [state]
    cmp eax, GS_FURNACE
    je .furnace
    cmp eax, GS_DYE
    je .dyemaker
    cmp eax, GS_CHEST
    je .chest
    cmp eax, GS_BEACON
    je .beacon
    cmp dword [game_mode], 0
    jne .creative
    cmp eax, GS_CRAFT
    je .craft

    ; ---- survival inventory: the player on the left, 2x2 crafting
    mov edi, PANEL_W
    mov esi, PANEL_H
    xor edx, edx
    call panel
    ; the armour slots down the left side
    xor r12d, r12d
.arm:
    mov eax, 8
    cvtsi2ss xmm0, eax
    imul eax, r12d, SLOT_STEP
    add eax, 8
    cvtsi2ss xmm1, eax
    lea rdi, [armor]
    lea rdi, [rdi + r12*4]
    lea esi, [r12 + 3]
    call slot
    inc r12d
    cmp r12d, 4
    jb .arm
    ; dark box with the player, the head following the mouse
    mov eax, 52
    mov ecx, 8
    mov edx, 160
    mov r8d, 164
    mov r9d, 0xff000000
    call prect
    mov eax, 54
    mov ecx, 10
    mov edx, 158
    mov r8d, 162
    mov r9d, 0xff2c2c2c
    call prect
    mov eax, [panel_x]
    add eax, 106
    cvtsi2ss xmm0, eax
    mov eax, [panel_y]
    add eax, 154
    cvtsi2ss xmm1, eax
    movss xmm2, [f_fig]
    mov eax, [mouse_x]
    sub eax, [panel_x]
    sub eax, 106
    cvtsi2ss xmm3, eax
    mov eax, [mouse_y]
    sub eax, [panel_y]
    sub eax, 46                     ; eye height
    cvtsi2ss xmm4, eax
    call draw_figure
    mov eax, 180
    mov ecx, 22
    lea rdi, [s_crafting]
    call label
    mov eax, 180                    ; the grid is stored 3 wide
    cvtsi2ss xmm0, eax
    mov eax, 46
    cvtsi2ss xmm1, eax
    mov ecx, 2
    mov r8d, 1
    lea rdi, [craft_grid]
    xor esi, esi
    call slot_grid
    mov eax, 180
    cvtsi2ss xmm0, eax
    mov eax, 46 + SLOT_STEP
    cvtsi2ss xmm1, eax
    mov ecx, 2
    mov r8d, 1
    lea rdi, [craft_grid + 12]
    xor esi, esi
    call slot_grid
    mov eax, 304
    cvtsi2ss xmm0, eax
    mov eax, 66
    cvtsi2ss xmm1, eax
    lea rdi, [craft_out]
    mov esi, 1
    call slot
    mov eax, 264
    mov ecx, 75
    call arrow
    mov edi, ROWS_Y
    call inventory_rows
    mov eax, 304
    mov ecx, 108
    call book_button
    call book_draw
    jmp .done

    ; ---- crafting table: 3x3
.craft:
    mov edi, PANEL_W
    mov esi, PANEL_H
    lea rdx, [s_crafting]
    call panel
    mov eax, 60
    cvtsi2ss xmm0, eax
    mov eax, 30
    cvtsi2ss xmm1, eax
    mov ecx, 3
    mov r8d, 3
    lea rdi, [craft_grid]
    xor esi, esi
    call slot_grid
    mov eax, 196
    mov ecx, 79
    call arrow
    mov eax, 244
    cvtsi2ss xmm0, eax
    mov eax, 70
    cvtsi2ss xmm1, eax
    lea rdi, [craft_out]
    mov esi, 1
    call slot
    mov eax, 12
    mov ecx, 151
    lea rdi, [s_invlabel]
    call label
    mov edi, ROWS_Y
    call inventory_rows
    mov eax, 14
    mov ecx, 70
    call book_button
    call book_draw
    jmp .done

    ; ---- furnace
.furnace:
    mov edi, PANEL_W
    mov esi, PANEL_H
    lea rdx, [s_furnace]
    call panel
    mov eax, [cur_furnace]
    imul eax, eax, FU_SIZE
    lea rbx, [furnaces]
    add rbx, rax
    mov eax, 120
    cvtsi2ss xmm0, eax
    mov eax, 30
    cvtsi2ss xmm1, eax
    lea rdi, [rbx + FU_IN]
    xor esi, esi
    call slot
    mov eax, 120
    cvtsi2ss xmm0, eax
    mov eax, 110
    cvtsi2ss xmm1, eax
    lea rdi, [rbx + FU_FUEL]
    xor esi, esi
    call slot
    mov eax, 256
    cvtsi2ss xmm0, eax
    mov eax, 70
    cvtsi2ss xmm1, eax
    lea rdi, [rbx + FU_OUT]
    mov esi, 1
    call slot
    ; flame: fuel left
    movss xmm0, [rbx + FU_BURN]
    movss xmm1, [rbx + FU_BURNMAX]
    mov eax, 106
    mov ecx, 80
    mov edx, 0xff2080ff
    call bar
    ; arrow: cooking progress
    movss xmm0, [rbx + FU_COOK]
    movss xmm1, [f_smelt]
    mov eax, 180
    mov ecx, 84
    mov edx, 0xffffffff
    call bar
    mov eax, 12
    mov ecx, 151
    lea rdi, [s_invlabel]
    call label
    mov edi, ROWS_Y
    call inventory_rows
    jmp .done

    ; ---- dye maker: a flower, a colour from the 4 x 4 swatches, a dye
.dyemaker:
    mov edi, PANEL_W
    mov esi, PANEL_H
    lea rdx, [s_dyemaker]
    call panel
    mov eax, 18
    mov ecx, 54
    lea rdi, [s_flower]
    call label
    mov eax, 30
    cvtsi2ss xmm0, eax
    mov eax, 76
    cvtsi2ss xmm1, eax
    lea rdi, [dye_in]
    xor esi, esi
    call slot
    mov eax, 254
    mov ecx, 85
    call arrow
    mov eax, 304
    cvtsi2ss xmm0, eax
    mov eax, 76
    cvtsi2ss xmm1, eax
    lea rdi, [dye_out]
    mov esi, 1
    call slot
    xor r12d, r12d                  ; colour
.sw:
    ; swatch i at (100 + 32 (i % 4), 30 + 32 (i / 4)), 28 square
    mov eax, r12d
    and eax, 3
    shl eax, 5
    add eax, 100
    mov r13d, eax                   ; x (panel)
    mov eax, r12d
    shr eax, 2
    shl eax, 5
    add eax, 30
    mov r14d, eax                   ; y
    ; picked: a white frame, else dark
    mov r9d, 0xff303030
    cmp r12d, [dye_color]
    jne .frame
    mov r9d, 0xffffffff
.frame:
    mov eax, r13d
    mov ecx, r14d
    lea edx, [r13 + 28]
    lea r8d, [r14 + 28]
    call prect
    imul eax, r12d, 3
    lea rcx, [dye_rgb]
    add rcx, rax
    movzx r9d, byte [rcx + 2]       ; 0xAABBGGRR
    shl r9d, 8
    movzx eax, byte [rcx + 1]
    or r9d, eax
    shl r9d, 8
    movzx eax, byte [rcx]
    or r9d, eax
    or r9d, 0xff000000
    lea eax, [r13 + 3]
    lea ecx, [r14 + 3]
    lea edx, [r13 + 25]
    lea r8d, [r14 + 25]
    call prect
    ; a click picks it
    mov eax, [mouse_x]
    sub eax, [panel_x]
    sub eax, r13d
    cmp eax, 28
    jae .swn
    mov eax, [mouse_y]
    sub eax, [panel_y]
    sub eax, r14d
    cmp eax, 28
    jae .swn
    cmp dword [mouse_click], 1
    jne .swn
    mov dword [mouse_click], 0
    mov [dye_color], r12d
    call dye_update
.swn:
    inc r12d
    cmp r12d, 16
    jb .sw
    mov eax, 12
    mov ecx, 151
    lea rdi, [s_invlabel]
    call label
    mov edi, ROWS_Y
    call inventory_rows
    jmp .done

    ; ---- chest: its 27 slots over the inventory
.chest:
    mov edi, PANEL_W
    mov esi, PANEL_H
    lea rdx, [s_chest]
    call panel
    mov rdi, [cur_chest]
    test rdi, rdi
    jz .chest_inv
    mov eax, 8
    cvtsi2ss xmm0, eax
    mov eax, 30
    cvtsi2ss xmm1, eax
    mov ecx, 9
    mov r8d, 3
    xor esi, esi
    call slot_grid
.chest_inv:
    mov eax, 12
    mov ecx, 151
    lea rdi, [s_invlabel]
    call label
    mov edi, ROWS_Y
    call inventory_rows
    jmp .done

    ; ---- beacon: its state, and a button for each power
.beacon:
    mov edi, PANEL_W
    mov esi, 250
    lea rdx, [s_beacon]
    call panel
    mov edi, [beacon_sel]
    mov esi, [beacon_sel + 4]
    mov edx, [beacon_sel + 8]
    call beacon_status
    lea rdi, [s_bc_wait]
    test eax, eax
    js .bc_say
    lea rdi, [s_bc_small]
    cmp eax, 4
    jb .bc_say
    lea rdi, [s_bc_sky]
    test ecx, ecx
    jz .bc_say
    lea rdi, [s_bc_on]
.bc_say:
    mov eax, 12
    mov ecx, 36
    call small
    mov edi, [beacon_sel]
    mov esi, [beacon_sel + 4]
    mov edx, [beacon_sel + 8]
    call meta_get
    and eax, 3
    mov [rsp + 64], eax             ; the power picked
    xor r12d, r12d
.bc_btn:
    imul r13d, r12d, 122
    add r13d, 12                    ; x
    mov r14d, 60                    ; y
    lea eax, [r12 + 1]
    mov r9d, 0xff373737             ; frame: gold round the one picked
    cmp eax, [rsp + 64]
    jne .bc_f
    mov r9d, 0xff30c0f0
.bc_f:
    mov eax, r13d
    mov ecx, r14d
    lea edx, [r13 + 106]
    lea r8d, [r14 + 140]
    call prect
    ; inside: lighter under the mouse; a click picks it (again: none)
    mov r15d, 0xff8b8b8b
    mov eax, [mouse_x]
    sub eax, [panel_x]
    sub eax, r13d
    cmp eax, 106
    jae .bc_in
    mov eax, [mouse_y]
    sub eax, [panel_y]
    sub eax, r14d
    cmp eax, 140
    jae .bc_in
    mov r15d, 0xffa8a8a8
    cmp dword [mouse_click], 1
    jne .bc_in
    mov dword [mouse_click], 0
    lea ecx, [r12 + 1]
    cmp ecx, [rsp + 64]
    jne .bc_pick
    xor ecx, ecx
.bc_pick:
    mov [rsp + 64], ecx
    mov edi, [beacon_sel]
    mov esi, [beacon_sel + 4]
    mov edx, [beacon_sel + 8]
    call meta_set
    SFX S_CLICK, 80, 100
.bc_in:
    lea eax, [r13 + 4]
    lea ecx, [r14 + 4]
    lea edx, [r13 + 102]
    lea r8d, [r14 + 136]
    mov r9d, r15d
    call prect
    lea eax, [r13 + 21]             ; the picture, 8 x 8 pixels
    add eax, [panel_x]
    cvtsi2ss xmm0, eax
    lea eax, [r14 + 14]
    add eax, [panel_y]
    cvtsi2ss xmm1, eax
    mov eax, 8
    cvtsi2ss xmm2, eax
    lea edi, [r12 + 1]
    call effect_icon
    lea rdi, [s_bc_names]           ; its name (the r12-th of them)
    mov ecx, r12d
.bc_nm:
    test ecx, ecx
    jz .bc_name
.bc_skip:
    inc rdi
    cmp byte [rdi - 1], 0
    jne .bc_skip
    dec ecx
    jmp .bc_nm
.bc_name:
    lea eax, [r13 + 10]
    lea ecx, [r14 + 100]
    call small
    inc r12d
    cmp r12d, 3
    jb .bc_btn
    mov eax, 12
    mov ecx, 216
    lea rdi, [s_bc_reach]
    call small
    jmp .done

    ; ---- creative: every item, then the hotbar
.creative:
    cmp dword [palette_n], 0
    jne .pal
    call build_palette
.pal:
    mov edi, PANEL_W + SB_W + 8     ; room for the scroll bar
    mov esi, 7 * SLOT_STEP + 60
    lea rdx, [s_creative]
    call panel
    ; the wheel scrolls rows; at most 6 rows show
    mov eax, [palette_top]
    add eax, [mouse_wheel]
    mov dword [mouse_wheel], 0
    mov ecx, [palette_n]
    add ecx, 8
    mov r8d, 9
    push rax
    mov eax, ecx
    xor edx, edx
    div r8d                         ; rows
    mov ecx, eax
    pop rax
    sub ecx, 6
    cmp eax, ecx
    cmovg eax, ecx
    xor ecx, ecx
    cmp eax, ecx
    cmovl eax, ecx
    mov [palette_top], eax
    call scroll_bar                 ; (drag it: no wheel needed)
    mov eax, [palette_top]
    imul r13d, eax, 9               ; first item shown
    xor r12d, r12d
.pi:
    lea eax, [r12 + r13]
    cmp eax, [palette_n]
    jae .phot
    cmp r12d, 54
    jae .phot
    lea rcx, [palette]
    movzx eax, byte [rcx + rax]
    mov [rsp + r12*4], eax
    mov eax, r12d
    xor edx, edx
    mov ecx, 9
    div ecx
    imul edx, edx, SLOT_STEP
    add edx, 8
    cvtsi2ss xmm0, edx
    imul eax, eax, SLOT_STEP
    add eax, 36
    cvtsi2ss xmm1, eax
    lea rdi, [rsp + r12*4]
    mov esi, 2
    call slot
    inc r12d
    jmp .pi
.phot:
    mov eax, 8
    cvtsi2ss xmm0, eax
    mov eax, 6 * SLOT_STEP + 44
    cvtsi2ss xmm1, eax
    mov ecx, 9
    mov r8d, 1
    lea rdi, [inv]
    xor esi, esi
    call slot_grid
.done:
    call cursor_and_tip
    LEAVE_FN

; ---------------------------------------------------------------------------
; the recipe book
;
; Every item the player has had is noted (book_seen); a recipe is unlocked
; once any of its ingredients has been seen (getting into water unlocks the
; boat). In survival the inventory and the crafting table have a book
; button: the book lists the things the unlocked recipes make, green when
; the inventory holds what they need, red when not. Clicking a green one
; puts its ingredients in the grid; a red one shows faded in the empty grid.

; void book_clear(void) - a new world: nothing seen
book_clear:
    lea rdi, [book_seen]
    xor eax, eax
    mov ecx, 32 + 64
    rep stosb
    mov qword [book_ghost], 0
    mov dword [book_page], 0
    ret

; eax = 1 if item edi unlocks recipe rsi: it is an ingredient (birch or
; dark oak planks count for oak). Planks and sticks are in nearly
; everything, so, as in Minecraft, they unlock only what is made of wood
; alone - planks what has no sticks in it, sticks the rest (the wooden
; tools): the stone pickaxe comes with cobblestone, the bed with wool. The
; boat comes with water.
; locals in registers: r8 match, r9 sticks in it, r10 something not wood
uses:
    cmp byte [rsi + 2], I_BOAT
    je .boat
    movzx ecx, byte [rsi]
    movzx eax, byte [rsi + 1]
    imul ecx, eax
    xor edx, edx
    xor r8d, r8d
    xor r9d, r9d
    xor r10d, r10d
.c:
    cmp edx, ecx
    jae .judge
    movzx eax, byte [rsi + 4 + rdx]
    test eax, eax
    jz .n
    cmp eax, I_STICK
    jne .notstick
    mov r9d, 1
    jmp .match
.notstick:
    cmp eax, B_PLANKS
    je .match
    cmp eax, I_BIRCHPLANKS
    je .match
    cmp eax, I_DARKPLANKS
    je .match
    mov r10d, 1                     ; not wood
.match:
    cmp eax, edi
    je .yes1
    cmp eax, B_PLANKS
    jne .n
    cmp edi, I_BIRCHPLANKS
    je .yes1
    cmp edi, I_DARKPLANKS
    jne .n
.yes1:
    mov r8d, 1
.n:
    inc edx
    jmp .c
.judge:
    xor eax, eax
    test r8d, r8d
    jz .out
    cmp edi, I_STICK
    je .wood
    cmp edi, B_PLANKS
    je .planks
    cmp edi, I_BIRCHPLANKS
    je .planks
    cmp edi, I_DARKPLANKS
    jne .yes
.planks:
    test r9d, r9d                   ; planks: not what needs sticks
    jnz .out
.wood:
    test r10d, r10d                 ; wood alone
    jnz .out
.yes:
    mov eax, 1
.out:
    ret
.boat:
    xor eax, eax
    cmp edi, B_WATER
    jne .out
    mov eax, 1
    ret

; int unlock_by(int item) - unlock the recipes it is used in: how many new
unlock_by:
    push rbx
    push r12
    push r13
    mov r12d, edi
    xor r13d, r13d                  ; new
    xor ebx, ebx                    ; recipe number
    lea rsi, [recipes]
.r:
    cmp byte [rsi], 0
    je .out
    cmp ebx, 512
    jae .out
    bt dword [book_known], ebx
    jc .next
    mov edi, r12d
    call uses
    test eax, eax
    jz .next
    bts dword [book_known], ebx
    inc r13d
.next:
    add rsi, RC_SIZE
    inc ebx
    jmp .r
.out:
    mov eax, r13d
    pop r13
    pop r12
    pop rbx
    ret

; book_note(edi item) - the player has it: unlock what it is used in
book_note:
    test edi, edi
    jz .out
    and edi, 0xff
    bts dword [book_seen], edi
    jc .out
    sub rsp, 8
    call unlock_by
    add rsp, 8
    test eax, eax
    jz .out
    cmp dword [game_mode], 0
    jne .out
    sub rsp, 8
    lea rdi, [s_newrec]
    call hud_message
    add rsp, 8
.out:
    ret

; void book_rebuild(void) - after loading: unlock again from what was seen
book_rebuild:
    push rbx
    xor ebx, ebx
.i:
    bt dword [book_seen], ebx
    jnc .n
    mov edi, ebx
    call unlock_by
.n:
    inc ebx
    cmp ebx, 256
    jb .i
    pop rbx
    ret

; void book_tick(void) - every frame: what is in the inventory, and water
book_tick:
    push rbx
    xor ebx, ebx
.i:
    lea rax, [inv]
    movzx edi, byte [rax + rbx*4]
    call book_note
    inc ebx
    cmp ebx, 36
    jb .i
    movzx edi, byte [cursor]
    call book_note
    cmp dword [body_water], 0
    je .out
    cmp dword [body_lava], 0
    jne .out
    mov edi, B_WATER
    call book_note
.out:
    pop rbx
    ret

; eax = how many of item edi the inventory and the grid hold (planks:
; all three woods)
have_count:
    xor eax, eax
    lea rsi, [inv]
    mov ecx, 36
    call .sum
    lea rsi, [craft_grid]
    mov ecx, 9
    call .sum
    ret
.sum:
    movzx edx, byte [rsi]
    cmp edx, edi
    je .add
    cmp edi, B_PLANKS
    jne .s
    cmp edx, I_BIRCHPLANKS
    je .add
    cmp edx, I_DARKPLANKS
    jne .s
.add:
    movzx edx, byte [rsi + 1]
    add eax, edx
.s:
    add rsi, 4
    dec ecx
    jnz .sum
    ret

; eax = 1 if the inventory (and grid) hold everything recipe rbx needs
; locals: [0] cells, [4] cell
can_make:
    push r12
    push r13
    push r14
    movzx r12d, byte [rbx]
    movzx eax, byte [rbx + 1]
    imul r12d, eax
    xor r13d, r13d
.c:
    cmp r13d, r12d
    jae .yes
    movzx edi, byte [rbx + 4 + r13]
    test edi, edi
    jz .n
    ; how many cells want it
    xor r14d, r14d
    xor ecx, ecx
.k:
    cmp ecx, r12d
    jae .kd
    cmp [rbx + 4 + rcx], dil
    jne .kn
    inc r14d
.kn:
    inc ecx
    jmp .k
.kd:
    call have_count
    cmp eax, r14d
    jb .no
.n:
    inc r13d
    jmp .c
.yes:
    mov eax, 1
    jmp .out
.no:
    xor eax, eax
.out:
    pop r14
    pop r13
    pop r12
    ret

; eax = an item taken out of the inventory for a cell wanting edi (planks:
; any wood), 0 if there is none
take_one:
    lea rsi, [inv]
    mov ecx, 36
.f:
    movzx eax, byte [rsi]
    cmp eax, edi
    je .got
    cmp edi, B_PLANKS
    jne .n
    cmp eax, I_BIRCHPLANKS
    je .got
    cmp eax, I_DARKPLANKS
    je .got
.n:
    add rsi, 4
    dec ecx
    jnz .f
    xor eax, eax
    ret
.got:
    dec byte [rsi + 1]
    jnz .left
    mov dword [rsi], 0
.left:
    ret

; void book_fill(rdi recipe) - its ingredients from the inventory into the
; grid (what was in the grid goes back first)
book_fill:
    ENTER_FN 16
    mov rbx, rdi
    call craft_return
    movzx r12d, byte [rbx]          ; w
    movzx r13d, byte [rbx + 1]      ; h
    xor r14d, r14d                  ; row
.r:
    cmp r14d, r13d
    jae .done
    xor r15d, r15d                  ; column
.c:
    cmp r15d, r12d
    jae .rn
    mov eax, r14d
    imul eax, r12d
    add eax, r15d
    movzx edi, byte [rbx + 4 + rax]
    test edi, edi
    jz .cn
    call take_one
    test eax, eax
    jz .cn
    or eax, 1 << 8
    lea ecx, [r14 + r14*2]
    add ecx, r15d
    lea rdx, [craft_grid]
    mov [rdx + rcx*4], eax
.cn:
    inc r15d
    jmp .c
.rn:
    inc r14d
    jmp .r
.done:
    call craft_update
    LEAVE_FN

; book_button(eax x, ecx y panel relative) - the green book: opens and
; closes the recipe book (survival only)
book_button:
    cmp dword [game_mode], 0
    jne .out
    push rbx
    push r12
    push r13
    mov r12d, eax
    mov r13d, ecx
    mov eax, r12d
    mov ecx, r13d
    lea edx, [r12 + 28]
    lea r8d, [r13 + 28]
    mov r9d, 0xff373737
    call prect
    lea eax, [r12 + 2]
    lea ecx, [r13 + 2]
    lea edx, [r12 + 26]
    lea r8d, [r13 + 26]
    mov r9d, 0xff8b8b8b
    cmp dword [book_open], 0
    je .bg
    mov r9d, 0xffc5c5c5
.bg:
    call prect
    lea eax, [r12 + 6]              ; the book: a green cover, pages, a spine
    lea ecx, [r13 + 5]
    lea edx, [r12 + 22]
    lea r8d, [r13 + 23]
    mov r9d, 0xff2c7a2c
    call prect
    lea eax, [r12 + 9]
    lea ecx, [r13 + 7]
    lea edx, [r12 + 21]
    lea r8d, [r13 + 21]
    mov r9d, 0xffe8f0f0
    call prect
    lea eax, [r12 + 9]
    lea ecx, [r13 + 7]
    lea edx, [r12 + 11]
    lea r8d, [r13 + 21]
    mov r9d, 0xff1c4c1c
    call prect
    ; a click toggles it
    mov eax, [mouse_x]
    sub eax, [panel_x]
    sub eax, r12d
    cmp eax, 28
    jae .done
    mov eax, [mouse_y]
    sub eax, [panel_y]
    sub eax, r13d
    cmp eax, 28
    jae .done
    cmp dword [mouse_click], 1
    jne .done
    mov dword [mouse_click], 0
    xor dword [book_open], 1
.done:
    pop r13
    pop r12
    pop rbx
.out:
    ret

; the list of recipes to show: unlocked, fitting the grid, one per thing
book_build:
    push rbx
    push r12
    push r13
    xor r12d, r12d                  ; listed
    xor ebx, ebx
    lea rsi, [recipes]
.r:
    cmp byte [rsi], 0
    je .out
    cmp ebx, 512
    jae .out
    bt dword [book_known], ebx
    jnc .n
    movzx eax, byte [rsi]
    cmp eax, [craft_size]
    ja .n
    movzx eax, byte [rsi + 1]
    cmp eax, [craft_size]
    ja .n
    ; the same thing made already listed?
    mov al, [rsi + 2]
    xor ecx, ecx
.d:
    cmp ecx, r12d
    jae .add
    lea rdx, [book_list]
    mov rdx, [rdx + rcx*8]
    cmp [rdx + 2], al
    je .n
    inc ecx
    jmp .d
.add:
    lea rdx, [book_list]
    mov [rdx + r12*8], rsi
    inc r12d
.n:
    add rsi, RC_SIZE
    inc ebx
    jmp .r
.out:
    mov [book_n], r12d
    pop r13
    pop r12
    pop rbx
    ret

; book_draw - the book's panel left of the screen's panel, its page of
; entries, the page arrows; and the faded recipe in an empty grid
; locals: [0] entry, [4] x, [8] y, [16] recipe, [24] pages
book_draw:
    cmp dword [game_mode], 0
    jne .ret
    ENTER_FN 48
    call book_ghost_draw
    cmp dword [book_open], 0
    je .out
    call book_build
    ; the panel
    mov eax, -BOOK_W - 6
    mov ecx, -2
    mov edx, -4
    mov r8d, PANEL_H + 2
    mov r9d, 0xff000000
    call prect
    mov eax, -BOOK_W - 4
    xor ecx, ecx
    mov edx, -6
    mov r8d, PANEL_H
    mov r9d, 0xffffffff
    call prect
    mov eax, -BOOK_W
    mov ecx, 4
    mov edx, -6
    mov r8d, PANEL_H
    mov r9d, 0xff555555
    call prect
    mov eax, -BOOK_W
    mov ecx, 4
    mov edx, -10
    mov r8d, PANEL_H - 4
    mov r9d, 0xffc6c6c6
    call prect
    mov eax, -BOOK_W + 8
    mov ecx, 10
    lea rdi, [s_recipes]
    call label
    cmp dword [book_n], 0
    jne .some
    mov eax, -BOOK_W + 8
    mov ecx, 60
    lea rdi, [s_none]
    call small
    mov eax, -BOOK_W + 8
    mov ecx, 76
    lea rdi, [s_none2]
    call small
    jmp .out
.some:
    ; pages
    mov eax, [book_n]
    add eax, BOOK_COLS * BOOK_ROWS - 1
    xor edx, edx
    mov ecx, BOOK_COLS * BOOK_ROWS
    div ecx
    mov [rsp + 24], eax
    mov ecx, [book_page]
    dec eax
    cmp ecx, eax
    cmovg ecx, eax
    mov [book_page], ecx
    ; the entries of this page
    xor r12d, r12d
.e:
    cmp r12d, BOOK_COLS * BOOK_ROWS
    jae .arrows
    mov eax, [book_page]
    imul eax, eax, BOOK_COLS * BOOK_ROWS
    add eax, r12d
    cmp eax, [book_n]
    jae .arrows
    lea rcx, [book_list]
    mov rbx, [rcx + rax*8]
    mov eax, r12d
    xor edx, edx
    mov ecx, BOOK_COLS
    div ecx
    imul edx, edx, SLOT_STEP
    add edx, -BOOK_W + 4
    mov r13d, edx                   ; x
    imul eax, eax, SLOT_STEP
    add eax, 30
    mov r14d, eax                   ; y
    call can_make
    mov r15d, eax
    mov r9d, 0xff3030a0             ; red: something missing
    test r15d, r15d
    jz .col
    mov r9d, 0xff38a038             ; green: it can be made
.col:
    ; brighter under the mouse
    mov eax, [mouse_x]
    sub eax, [panel_x]
    sub eax, r13d
    cmp eax, SLOT_PX
    jae .nh
    mov eax, [mouse_y]
    sub eax, [panel_y]
    sub eax, r14d
    cmp eax, SLOT_PX
    jae .nh
    or r9d, 0x00404040
    movzx eax, byte [rbx + 2]
    mov [book_tip], eax
    lea rax, [book_tip]
    mov [hover_slot], rax
    cmp dword [mouse_click], 1
    jne .nh
    mov dword [mouse_click], 0
    mov qword [book_ghost], rbx
    test r15d, r15d
    jz .nh
    mov qword [book_ghost], 0
    mov rdi, rbx
    push r9
    sub rsp, 8
    call book_fill
    add rsp, 8
    pop r9
.nh:
    mov eax, r13d
    mov ecx, r14d
    lea edx, [r13 + SLOT_PX]
    lea r8d, [r14 + SLOT_PX]
    call prect
    mov eax, r13d
    add eax, [panel_x]
    add eax, 2
    cvtsi2ss xmm0, eax
    mov eax, r14d
    add eax, [panel_y]
    add eax, 2
    cvtsi2ss xmm1, eax
    movss xmm2, [f_slot]
    subss xmm2, [f_four]
    movzx edi, byte [rbx + 2]
    movzx eax, byte [rbx + 3]
    shl eax, 8
    or edi, eax                     ; what it makes, and how many
    mov esi, 1
    call hud_item
    inc r12d
    jmp .e
.arrows:
    cmp dword [rsp + 24], 1
    jbe .out
    ; "<  2/3  >"
    mov eax, -BOOK_W + 8
    mov ecx, PANEL_H - 40
    mov edx, -1
    call page_arrow
    mov eax, -40
    mov ecx, PANEL_H - 40
    mov edx, 1
    call page_arrow
    lea rdi, [page_text]
    mov eax, [book_page]
    inc eax
    call put_num
    mov byte [rdi], '/'
    inc rdi
    mov eax, [rsp + 24]
    call put_num
    mov byte [rdi], 0
    mov eax, -(BOOK_W / 2) - 30
    mov ecx, PANEL_H - 34
    lea rdi, [page_text]
    call label
.out:
    LEAVE_FN
.ret:
    ret

; put_num(eax 0-99) at rdi, rdi moves on
put_num:
    cmp eax, 10
    jb .one
    xor edx, edx
    mov ecx, 10
    div ecx
    add al, '0'
    mov [rdi], al
    inc rdi
    mov eax, edx
.one:
    add al, '0'
    mov [rdi], al
    inc rdi
    ret

; page_arrow(eax x, ecx y panel relative, edx -1 back / 1 on)
page_arrow:
    push rbx
    push r12
    push r13
    mov r12d, eax
    mov r13d, ecx
    mov ebx, edx
    lea edx, [r12 + 28]
    lea r8d, [r13 + 24]
    mov r9d, 0xff8b8b8b
    call prect
    lea eax, [r12 + 8]
    lea ecx, [r13 + 4]
    lea rdi, [s_prev]
    test ebx, ebx
    js .t
    lea rdi, [s_next]
.t:
    call label
    mov eax, [mouse_x]
    sub eax, [panel_x]
    sub eax, r12d
    cmp eax, 28
    jae .out
    mov eax, [mouse_y]
    sub eax, [panel_y]
    sub eax, r13d
    cmp eax, 24
    jae .out
    cmp dword [mouse_click], 1
    jne .out
    mov dword [mouse_click], 0
    add [book_page], ebx
    cmp dword [book_page], 0
    jge .out
    mov dword [book_page], 0
.out:
    pop r13
    pop r12
    pop rbx
    ret

; small(eax x, ecx y panel relative, rdi text): dark grey, scale 1.5
small:
    sub rsp, 8
    add eax, [panel_x]
    add ecx, [panel_y]
    cvtsi2ss xmm0, eax
    cvtsi2ss xmm1, ecx
    movss xmm2, [f_onehalf]
    mov esi, 0xff404040
    call hud_text
    add rsp, 8
    ret

; the recipe clicked but not makeable, faded in the grid while it is empty
book_ghost_draw:
    mov rax, [book_ghost]
    test rax, rax
    jz .ret
    ENTER_FN 16
    mov rbx, rax
    ; only while the grid is empty, and if it fits
    lea rax, [craft_grid]
    xor ecx, ecx
.g:
    cmp dword [rax + rcx*4], 0
    jne .gone
    inc ecx
    cmp ecx, 9
    jb .g
    movzx eax, byte [rbx]
    cmp eax, [craft_size]
    ja .gone
    movzx eax, byte [rbx + 1]
    cmp eax, [craft_size]
    ja .gone
    ; where the grid is on this screen
    mov dword [rsp], 180
    mov dword [rsp + 4], 46
    cmp dword [craft_size], 3
    jne .at
    mov dword [rsp], 60
    mov dword [rsp + 4], 30
.at:
    xor r12d, r12d                  ; row
.r:
    movzx eax, byte [rbx + 1]
    cmp r12d, eax
    jae .out
    xor r13d, r13d
.c:
    movzx eax, byte [rbx]
    cmp r13d, eax
    jae .rn
    imul ecx, r12d, 0
    movzx ecx, byte [rbx]
    imul ecx, r12d
    add ecx, r13d
    movzx edi, byte [rbx + 4 + rcx]
    test edi, edi
    jz .cn
    imul eax, r13d, SLOT_STEP
    add eax, [rsp]
    add eax, [panel_x]
    add eax, 2
    mov r14d, eax
    cvtsi2ss xmm0, eax
    imul eax, r12d, SLOT_STEP
    add eax, [rsp + 4]
    add eax, [panel_y]
    add eax, 2
    mov r15d, eax
    cvtsi2ss xmm1, eax
    movss xmm2, [f_slot]
    subss xmm2, [f_four]
    or edi, 1 << 8
    xor esi, esi
    call hud_item
    cvtsi2ss xmm0, r14d             ; faded: grey over it
    cvtsi2ss xmm1, r15d
    lea eax, [r14 + 32]
    cvtsi2ss xmm2, eax
    lea eax, [r15 + 32]
    cvtsi2ss xmm3, eax
    mov edi, 0xa08b8b8b
    call hud_rect
.cn:
    inc r13d
    jmp .c
.rn:
    inc r12d
    jmp .r
.gone:
    mov qword [book_ghost], 0
.out:
    LEAVE_FN
.ret:
    ret

; q_target -> rax: the stack Q throws from: the mouse's, else the slot
; under the mouse (not an output or the creative palette); 0 if none
q_target:
    lea rax, [cursor]
    cmp dword [rax], 0
    jne .out
    mov rax, [hover_slot]
    test rax, rax
    jz .out
    cmp dword [rax], 0
    je .none
    mov ecx, [hover_kind]
    cmp ecx, 0
    je .out
    cmp ecx, 3
    jae .out
.none:
    xor eax, eax
.out:
    ret

; void invui_qpress(void) - the drop key went down: throw one item
invui_qpress:
    cmp dword [q_held], 0
    jne .out                        ; key repeat while held
    mov dword [q_held], 1
    mov dword [q_time], 0
    push rbx
    call q_target
    test rax, rax
    jz .done
    mov rbx, rax
    mov edi, [rbx]
    and edi, 0xffff00ff
    or edi, 1 << 8
    dec byte [rbx + 1]
    jnz .thrown
    mov dword [rbx], 0
.thrown:
    call throw_item
    call craft_update
    call dye_update
.done:
    pop rbx
.out:
    ret

; q_hold - while the drop key stays down: after a moment the rest of the
; stack goes too (once per press)
q_hold:
    sub rsp, 8
    mov eax, [bind_drop]
    lea rcx, [keys]
    cmp byte [rcx + rax], 0
    jne .down
    mov dword [q_held], 0
    jmp .out
.down:
    cmp dword [q_held], 0
    je .out
    movss xmm0, [q_time]
    addss xmm0, [dt]
    movss [q_time], xmm0
    comiss xmm0, [f_qhold]
    jb .out
    mov eax, [f_never]
    mov [q_time], eax
    call q_target
    test rax, rax
    jz .out
    mov edi, [rax]
    mov dword [rax], 0
    call throw_item
    call craft_update
    call dye_update
.out:
    add rsp, 8
    ret

; scroll_bar - the creative list's scroll bar right of the items: a thumb
; as tall as the share of rows showing; clicking the bar or dragging the
; thumb (left button held) moves the list, for trackpads with no wheel
; r12 rows that cannot show (0..), r13 thumb height, r14 thumb top
scroll_bar:
    push r12
    push r13
    push r14
    mov eax, [palette_n]
    add eax, 8
    xor edx, edx
    mov ecx, 9
    div ecx                         ; rows
    mov r13d, SB_H                  ; thumb: the whole bar
    mov r14d, SB_Y
    mov r12d, eax
    sub r12d, 6                     ; rows that cannot show
    jle .nothumb
    mov ecx, eax
    mov eax, SB_H * 6
    xor edx, edx
    div ecx                         ; thumb: 6 / rows of the bar
    cmp eax, SB_MINTHUMB
    jge .t
    mov eax, SB_MINTHUMB
.t:
    mov r13d, eax
    ; the button held: started on the bar, or already dragging
    cmp dword [menu_lmb], 0
    jne .held
    mov dword [sb_drag], 0
    jmp .place
.held:
    mov ecx, [mouse_y]
    sub ecx, [panel_y]
    cmp dword [sb_drag], 0
    jne .move
    mov eax, [mouse_x]
    sub eax, [panel_x]
    sub eax, SB_X
    cmp eax, SB_W
    jae .place
    lea edx, [rcx - SB_Y]
    cmp edx, SB_H
    jae .place
    mov dword [sb_drag], 1
    mov dword [mouse_click], 0      ; (not a click on anything else)
.move:
    ; the thumb's middle follows the pointer: top row =
    ; (pointer - bar top - thumb / 2) x hidden rows / room, rounded
    mov eax, r13d
    shr eax, 1
    sub ecx, SB_Y
    sub ecx, eax
    imul ecx, r12d
    mov r8d, SB_H
    sub r8d, r13d                   ; room the thumb moves in
    mov eax, r8d
    shr eax, 1
    add eax, ecx
    cdq
    idiv r8d
    test eax, eax
    jns .lo
    xor eax, eax
.lo:
    cmp eax, r12d
    jle .hi
    mov eax, r12d
.hi:
    mov [palette_top], eax
.place:
    ; the thumb where the list is
    mov eax, SB_H
    sub eax, r13d
    imul eax, [palette_top]
    xor edx, edx
    div r12d
    lea r14d, [rax + SB_Y]
    jmp .draw
.nothumb:
    xor r12d, r12d
.draw:
    ; the bar: sunken dark, the thumb raised light
    mov eax, SB_X
    mov ecx, SB_Y
    mov edx, SB_X + SB_W
    mov r8d, SB_Y + SB_H
    mov r9d, 0xff373737
    call prect
    mov eax, SB_X + 1
    lea ecx, [r14 + 1]
    mov edx, SB_X + SB_W - 1
    lea r8d, [r14 + r13 - 1]
    mov r9d, 0xffffffff
    call prect
    mov eax, SB_X + 3
    lea ecx, [r14 + 3]
    mov edx, SB_X + SB_W - 1
    lea r8d, [r14 + r13 - 1]
    mov r9d, 0xff555555
    call prect
    mov eax, SB_X + 3
    lea ecx, [r14 + 3]
    mov edx, SB_X + SB_W - 3
    lea r8d, [r14 + r13 - 3]
    mov r9d, 0xffc6c6c6
    call prect
    pop r14
    pop r13
    pop r12
    ret

; arrow between grid and output: eax x, ecx y (panel relative, 32 x 18)
arrow:
    push rbx
    push r12
    sub rsp, 8
    mov ebx, eax
    mov r12d, ecx
%macro AREC 4                       ; x0, y0, x1, y1 offsets
    lea eax, [rbx + %1]
    lea ecx, [r12 + %2]
    lea edx, [rbx + %3]
    lea r8d, [r12 + %4]
    mov r9d, 0xff8b8b8b
    call prect
%endmacro
    AREC 0, 6, 20, 12
    AREC 20, 0, 24, 18
    AREC 24, 3, 28, 15
    AREC 28, 6, 32, 12
    add rsp, 8
    pop r12
    pop rbx
    ret

; progress bar: xmm0 value of xmm1, at panel (eax, ecx), colour edx,
; 64 x 8 pixels
bar:
    sub rsp, 24
    add eax, [panel_x]
    add ecx, [panel_y]
    mov [rsp], eax
    mov [rsp + 4], ecx
    mov [rsp + 8], edx
    xorps xmm2, xmm2
    comiss xmm1, xmm2
    jbe .empty
    divss xmm0, xmm1
    jmp .frac
.empty:
    xorps xmm0, xmm0
.frac:
    mov eax, 64
    cvtsi2ss xmm2, eax
    mulss xmm0, xmm2
    movss [rsp + 12], xmm0
    cvtsi2ss xmm0, dword [rsp]
    cvtsi2ss xmm1, dword [rsp + 4]
    movaps xmm2, xmm0
    mov eax, 64
    cvtsi2ss xmm3, eax
    addss xmm2, xmm3
    movaps xmm3, xmm1
    addss xmm3, [f_four]
    addss xmm3, [f_four]
    mov edi, 0xff505050
    call hud_rect
    cvtsi2ss xmm0, dword [rsp]
    cvtsi2ss xmm1, dword [rsp + 4]
    movaps xmm2, xmm0
    addss xmm2, [rsp + 12]
    movaps xmm3, xmm1
    addss xmm3, [f_four]
    addss xmm3, [f_four]
    mov edi, [rsp + 8]
    call hud_rect
    add rsp, 24
    ret

NOEXECSTACK
