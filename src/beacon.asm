%include "common.inc"

global beacon_clear, beacon_update, beacon_draw, beacons, beacon_count
global eff_time, beacon_hud, effect_icon, beacon_status, beacon_open, beacon_sel

extern dt, world_get, block_flags, wool_rgb, cur_pcx, cur_pcz, pos
extern mesh_beacons, mesh_beacon_n
extern meta_get, game_mode, hp, player_dead, hud_rect, win_w, invui_open
extern glPushMatrix, glPopMatrix, glTranslatef, glRotatef, glBegin, glEnd
extern glVertex3f, glColor4f, glEnable, glDisable, glBlendFunc, glDepthMask

GL_QUADS        equ 7
GL_BLEND        equ 0x0BE2
GL_CULL_FACE    equ 0x0B44
GL_TEXTURE_2D   equ 0x0DE1
GL_ALPHA_TEST   equ 0x0BC0
GL_SRC_ALPHA    equ 0x0302
GL_ONE_MINUS_SRC_ALPHA equ 0x0303

MAX_BEACONS equ 32
MAX_SEGS    equ 5
BC_X        equ 0                   ; the beacon node (world coordinates)
BC_Y        equ 4
BC_Z        equ 8
BC_ON       equ 12                  ; 1 = the beam shines
BC_NSEG     equ 16
BC_SEG      equ 20                  ; MAX_SEGS x (u32 start y, u8 r, g, b, 0)
BC_LEVEL    equ 60                  ; layers of pyramid under it (0-4)
BC_SIZE     equ 64
BEAM_TOP    equ 320                 ; world y the beam is drawn up to
BEAM_RANGE  equ 320                 ; not drawn further away than this

section .rodata
align 4
f_inner:    dd 0.2                  ; half widths of the core and the glow
f_outer:    dd 0.3
f_ina:      dd 0.85                 ; their opacity
f_outa:     dd 0.25
f_inv255:   dd 0.0039215686
f_half:     dd 0.5
f_spin:     dd 40.0                 ; degrees a second
f_360:      dd 360.0
f_one:      dd 1.0
f_piece:    dd 16.0
f_zero:     dd 0.0
f_reach2:   dd 225.0                ; 15 nodes, squared
f_linger:   dd 3.0
f_regen:    dd 2.0                  ; half hearts a second
f_badge:    dd 30.0
f_bscale:   dd 3.0
f_badgea:   dd 4.0
; effect pictures, 8 x 8: 0 clear, 1 main colour, 2 dark, 3 light, 4 brown
fx_heart:
    db 0,1,1,0,1,1,0,0
    db 1,3,3,1,1,1,1,0
    db 1,3,1,1,1,1,1,0
    db 1,1,1,1,1,1,1,0
    db 0,1,1,1,1,1,0,0
    db 0,0,1,1,1,0,0,0
    db 0,0,0,1,0,0,0,0
    db 0,0,0,0,0,0,0,0
fx_sword:
    db 0,0,0,0,0,0,3,3
    db 0,0,0,0,0,3,1,3
    db 0,0,0,0,3,1,3,0
    db 0,4,0,3,1,3,0,0
    db 0,0,4,1,3,0,0,0
    db 0,0,4,4,0,0,0,0
    db 0,4,0,0,4,0,0,0
    db 4,0,0,0,0,0,0,0
fx_boots:
    db 0,1,1,1,0,0,0,0
    db 0,1,3,1,0,0,0,0
    db 0,1,3,1,0,0,0,0
    db 0,1,1,1,1,0,0,0
    db 0,1,1,1,1,1,0,0
    db 0,1,1,1,1,1,1,0
    db 0,2,2,2,2,2,2,0
    db 0,0,0,0,0,0,0,0
; colours (0xAABBGGRR) of codes 1-4 for each: regeneration, strength, speed
fx_cols:
    dd 0xff2828e0, 0xff101090, 0xffa0a0ff, 0xff28506e
    dd 0xffc8c8c8, 0xff707070, 0xffffffff, 0xff28506e
    dd 0xfff0c050, 0xff905010, 0xfffff0b0, 0xff28506e

section .bss
alignb 16
beacons:      resb MAX_BEACONS * BC_SIZE
beacon_count: resd 1
check_next:   resd 1                ; the beacon checked next frame
spin:         resd 1
b_y0:         resd 1                ; the column beam_box draws
b_y1:         resd 1
b_w:          resd 1
eff_time:     resd 3                ; regeneration, strength, speed: seconds left
regen_acc:    resd 1
beacon_sel:   resd 3                ; the beacon whose screen is open

section .text

; void beacon_clear(void) - leaving a world or dimension
beacon_clear:
    mov dword [beacon_count], 0
    mov dword [mesh_beacon_n], 0
    mov dword [check_next], 0
    ret

; beacon_add(edi x, esi y, edx z) - into the list unless already there
beacon_add:
    lea rax, [beacons]
    xor ecx, ecx
.f:
    cmp ecx, [beacon_count]
    jae .new
    cmp [rax + BC_X], edi
    jne .n
    cmp [rax + BC_Y], esi
    jne .n
    cmp [rax + BC_Z], edx
    je .out
.n:
    add rax, BC_SIZE
    inc ecx
    jmp .f
.new:
    cmp ecx, MAX_BEACONS
    jae .out
    inc dword [beacon_count]
    mov [rax + BC_X], edi
    mov [rax + BC_Y], esi
    mov [rax + BC_Z], edx
    mov dword [rax + BC_ON], 0
    mov dword [rax + BC_NSEG], 0
    mov dword [rax + BC_LEVEL], 0
.out:
    ret

; void beacon_update(void) - take the mesher's notes, check one beacon;
; the effects of the beacons in reach
beacon_update:
    ENTER_FN 0
    call beacon_effects
.notes:
    mov eax, [mesh_beacon_n]
    test eax, eax
    jz .check
    dec eax
    mov [mesh_beacon_n], eax
    imul eax, eax, 12
    lea rcx, [mesh_beacons]
    mov edi, [rcx + rax]
    mov esi, [rcx + rax + 4]
    mov edx, [rcx + rax + 8]
    call beacon_add
    jmp .notes
.check:
    movss xmm0, [spin]
    movss xmm1, [dt]
    mulss xmm1, [f_spin]
    addss xmm0, xmm1
    comiss xmm0, [f_360]
    jb .sp
    subss xmm0, [f_360]
.sp:
    movss [spin], xmm0
    mov eax, [check_next]
    cmp eax, [beacon_count]
    jb .one
    xor eax, eax
    cmp eax, [beacon_count]
    je .out
.one:
    lea ecx, [rax + 1]
    mov [check_next], ecx
    imul eax, eax, BC_SIZE
    lea rbx, [beacons]
    add rbx, rax
    call beacon_check
.out:
    LEAVE_FN

; is_base(eax block) - ZF set (je) when it is iron, gold or diamond block
%macro IS_BASE 0
    cmp eax, B_IRONBLOCK
    je %%y
    cmp eax, B_GOLDBLOCK
    je %%y
    cmp eax, B_DIAMONDBLOCK
%%y:
%endmacro

; beacon_check - rbx beacon: still there? the base, the sky, the colours
; locals: [0] dx, [4] dz, [8] y, [12] colour (r, g, b, has colour)
beacon_check:
    ENTER_FN 16
    mov edi, [rbx + BC_X]
    mov esi, [rbx + BC_Y]
    mov edx, [rbx + BC_Z]
    call world_get
    cmp eax, B_BEACON
    jne .remove
    mov dword [rbx + BC_ON], 0
    mov dword [rbx + BC_LEVEL], 0
    ; the 3x3 layer under it
    mov dword [rsp], -1
.bx:
    mov dword [rsp + 4], -1
.bz:
    mov edi, [rbx + BC_X]
    add edi, [rsp]
    mov esi, [rbx + BC_Y]
    dec esi
    mov edx, [rbx + BC_Z]
    add edx, [rsp + 4]
    call world_get
    IS_BASE
    jne .out
    inc dword [rsp + 4]
    cmp dword [rsp + 4], 1
    jle .bz
    inc dword [rsp]
    cmp dword [rsp], 1
    jle .bx
    ; how many layers: each the next size wider, one lower
    mov dword [rbx + BC_LEVEL], 1
    mov r12d, 2
.layer:
    mov r13d, r12d
    neg r13d                        ; dx
.lx:
    mov r14d, r12d
    neg r14d                        ; dz
.lz:
    mov edi, [rbx + BC_X]
    add edi, r13d
    mov esi, [rbx + BC_Y]
    sub esi, r12d
    mov edx, [rbx + BC_Z]
    add edx, r14d
    call world_get
    IS_BASE
    jne .layers
    inc r14d
    cmp r14d, r12d
    jle .lz
    inc r13d
    cmp r13d, r12d
    jle .lx
    mov [rbx + BC_LEVEL], r12d
    inc r12d
    cmp r12d, 4
    jle .layer
.layers:
    ; up the column: white until the first stained glass
    mov dword [rbx + BC_NSEG], 1
    mov eax, [rbx + BC_Y]
    inc eax
    mov [rbx + BC_SEG], eax
    mov dword [rbx + BC_SEG + 4], 0x00ffffff
    mov dword [rsp + 12], 0x00ffffff
    mov [rsp + 8], eax
.up:
    cmp dword [rsp + 8], WORLD_H + WORLD_YMIN
    jge .clear
    mov edi, [rbx + BC_X]
    mov esi, [rsp + 8]
    mov edx, [rbx + BC_Z]
    call world_get
    lea ecx, [rax - B_SGLASS]
    cmp ecx, 15
    jbe .glass
    lea rcx, [block_flags]
    test byte [rcx + rax], F_OPAQUE
    jnz .out                        ; no sky: no beam
    jmp .next
.glass:
    lea rdx, [wool_rgb]
    lea ecx, [rcx + rcx*2]
    add rdx, rcx
    ; the new colour: this pane's, or half the old one and half this
    xor r8d, r8d
.ch:
    movzx eax, byte [rdx + r8]
    test byte [rsp + 15], 1
    jz .first
    movzx ecx, byte [rsp + 12 + r8]
    add eax, ecx
    shr eax, 1
.first:
    mov [rsp + 12 + r8], al
    inc r8d
    cmp r8d, 3
    jb .ch
    mov byte [rsp + 15], 1
    ; a segment from here (or recolour the last one if it starts here)
    mov ecx, [rbx + BC_NSEG]
    dec ecx
    mov eax, [rsp + 8]
    cmp [rbx + BC_SEG + rcx*8], eax
    je .recolour
    inc ecx
    cmp ecx, MAX_SEGS
    jae .recolour_last
    mov [rbx + BC_SEG + rcx*8], eax
    inc dword [rbx + BC_NSEG]
.recolour:
    mov eax, [rsp + 12]
    and eax, 0x00ffffff
    mov [rbx + BC_SEG + rcx*8 + 4], eax
    jmp .next
.recolour_last:
    dec ecx
    jmp .recolour
.next:
    inc dword [rsp + 8]
    jmp .up
.clear:
    mov dword [rbx + BC_ON], 1
.out:
    LEAVE_FN
.remove:
    ; the last one takes its place
    mov eax, [beacon_count]
    dec eax
    mov [beacon_count], eax
    imul eax, eax, BC_SIZE
    lea rsi, [beacons]
    add rsi, rax
    mov rdi, rbx
    mov ecx, BC_SIZE / 8
    rep movsq
    jmp .out

; beacon_effects - the timers run down; each full beacon with the sky over
; it and an effect picked gives it while the player is within 15 nodes;
; regeneration heals in survival
beacon_effects:
    push rbx
    push r12
    sub rsp, 8
    xor ecx, ecx
.t:
    lea rax, [eff_time]
    movss xmm0, [rax + rcx*4]
    subss xmm0, [dt]
    maxss xmm0, [f_zero]
    movss [rax + rcx*4], xmm0
    inc ecx
    cmp ecx, 3
    jb .t
    xor r12d, r12d
.b:
    cmp r12d, [beacon_count]
    jae .regen
    imul eax, r12d, BC_SIZE
    lea rbx, [beacons]
    add rbx, rax
    cmp dword [rbx + BC_ON], 0
    je .n
    cmp dword [rbx + BC_LEVEL], 4
    jb .n
    cvtsi2ss xmm0, dword [rbx + BC_X]
    addss xmm0, [f_half]
    subss xmm0, [pos]
    mulss xmm0, xmm0
    cvtsi2ss xmm1, dword [rbx + BC_Z]
    addss xmm1, [f_half]
    subss xmm1, [pos + 8]
    mulss xmm1, xmm1
    addss xmm0, xmm1
    comiss xmm0, [f_reach2]
    ja .n
    mov edi, [rbx + BC_X]
    mov esi, [rbx + BC_Y]
    mov edx, [rbx + BC_Z]
    call meta_get
    and eax, 3
    jz .n
    lea rcx, [eff_time]
    mov edx, [f_linger]
    mov [rcx + rax*4 - 4], edx
.n:
    inc r12d
    jmp .b
.regen:
    movss xmm0, [eff_time]
    comiss xmm0, [f_zero]
    jbe .noregen
    cmp dword [game_mode], 0
    jne .noregen
    cmp dword [player_dead], 0
    jne .noregen
    cmp dword [hp], 20
    jge .noregen
    movss xmm0, [dt]
    mulss xmm0, [f_regen]
    addss xmm0, [regen_acc]
    movss [regen_acc], xmm0
    comiss xmm0, [f_one]
    jb .out
    subss xmm0, [f_one]
    movss [regen_acc], xmm0
    inc dword [hp]
    jmp .out
.noregen:
    mov dword [regen_acc], 0
.out:
    add rsp, 8
    pop r12
    pop rbx
    ret

; int beacon_status(x, y, z) - eax its layers (0-4), ecx 1 with the sky
; over it; eax -1 when it is not known yet
beacon_status:
    lea rax, [beacons]
    xor ecx, ecx
.f:
    cmp ecx, [beacon_count]
    jae .no
    cmp [rax + BC_X], edi
    jne .n
    cmp [rax + BC_Y], esi
    jne .n
    cmp [rax + BC_Z], edx
    jne .n
    mov ecx, [rax + BC_ON]
    mov eax, [rax + BC_LEVEL]
    ret
.n:
    add rax, BC_SIZE
    inc ecx
    jmp .f
.no:
    mov eax, -1
    xor ecx, ecx
    ret

; void beacon_open(x, y, z) - right click on a beacon: its screen
beacon_open:
    sub rsp, 8
    mov [beacon_sel], edi
    mov [beacon_sel + 4], esi
    mov [beacon_sel + 8], edx
    call beacon_add                 ; (a new one is checked at once)
    mov edi, GS_BEACON
    call invui_open
    add rsp, 8
    ret

; void effect_icon(int effect 1-3, float x, y, pixel size) - its picture
; locals: [0] x, [4] y, [8] size, [16] picture, [24] colours, [32] i
effect_icon:
    ENTER_FN 48
    movss [rsp], xmm0
    movss [rsp + 4], xmm1
    movss [rsp + 8], xmm2
    dec edi
    and edi, 3
    cmp edi, 2
    jbe .k
    xor edi, edi
.k:
    lea rax, [fx_heart]
    lea rcx, [rax + rdi*8]
    shl edi, 3                      ; 64 bytes each
    lea rax, [rax + rdi*8]
    mov rbx, rax
    lea rax, [fx_cols]
    shl edi, 1                      ; 16 bytes of colours each
    add rax, rdi
    mov r12, rax
    xor r13d, r13d
.p:
    movzx eax, byte [rbx + r13]
    test eax, eax
    jz .n
    mov r14d, [r12 + rax*4 - 4]
    mov eax, r13d
    and eax, 7
    cvtsi2ss xmm0, eax
    mulss xmm0, [rsp + 8]
    addss xmm0, [rsp]
    mov eax, r13d
    shr eax, 3
    cvtsi2ss xmm1, eax
    mulss xmm1, [rsp + 8]
    addss xmm1, [rsp + 4]
    movaps xmm2, xmm0
    addss xmm2, [rsp + 8]
    movaps xmm3, xmm1
    addss xmm3, [rsp + 8]
    mov edi, r14d
    call hud_rect
.n:
    inc r13d
    cmp r13d, 64
    jb .p
    LEAVE_FN

; void beacon_hud(void) - the effects on the player, top right: a badge
; each, the picture on it
beacon_hud:
    ENTER_FN 16
    xor r12d, r12d                  ; effect
    xor r13d, r13d                  ; badges drawn
.e:
    lea rax, [eff_time]
    movss xmm0, [rax + r12*4]
    comiss xmm0, [f_zero]
    jbe .n
    inc r13d
    cvtsi2ss xmm0, dword [win_w]
    cvtsi2ss xmm1, r13d
    mulss xmm1, [f_badge]
    subss xmm0, xmm1
    subss xmm0, [f_badgea]
    movss [rsp], xmm0
    movss xmm1, [f_badgea]
    movaps xmm2, xmm0
    addss xmm2, [f_badge]
    subss xmm2, [f_badgea]
    movss xmm3, [f_badge]
    mov edi, 0x90000000
    call hud_rect
    movss xmm0, [rsp]
    addss xmm0, [f_badgea]
    movss xmm1, [f_badgea]
    addss xmm1, [f_badgea]
    movss xmm2, [f_bscale]
    lea edi, [r12 + 1]
    call effect_icon
.n:
    inc r12d
    cmp r12d, 3
    jb .e
    LEAVE_FN

; void beacon_draw(void) - the beams, in node units round the player's
; chunk (as the mobs): a bright core and a faint glow, turning slowly
; locals: [12] alpha, [16] segment,
;         [20] beacon, [24] r, [28] g, [32] b, [36] pass
beacon_draw:
    ENTER_FN 48
    cmp dword [beacon_count], 0
    je .out
    mov edi, GL_CULL_FACE
    call glDisable PLT
    mov edi, GL_TEXTURE_2D
    call glDisable PLT
    mov edi, GL_ALPHA_TEST
    call glDisable PLT
    mov edi, GL_BLEND
    call glEnable PLT
    mov edi, GL_SRC_ALPHA
    mov esi, GL_ONE_MINUS_SRC_ALPHA
    call glBlendFunc PLT
    xor edi, edi
    call glDepthMask PLT
    mov dword [rsp + 20], 0
.b:
    mov eax, [rsp + 20]
    cmp eax, [beacon_count]
    jae .done
    imul eax, eax, BC_SIZE
    lea rbx, [beacons]
    add rbx, rax
    cmp dword [rbx + BC_ON], 0
    je .bnext
    ; far away: not drawn
    cvtsi2ss xmm0, dword [rbx + BC_X]
    subss xmm0, [pos]
    cvtsi2ss xmm1, dword [rbx + BC_Z]
    subss xmm1, [pos + 8]
    mulss xmm0, xmm0
    mulss xmm1, xmm1
    addss xmm0, xmm1
    mov eax, BEAM_RANGE * BEAM_RANGE
    cvtsi2ss xmm1, eax
    comiss xmm0, xmm1
    ja .bnext
    call glPushMatrix PLT
    mov eax, [cur_pcx]
    shl eax, 4
    mov ecx, [rbx + BC_X]
    sub ecx, eax
    cvtsi2ss xmm0, ecx
    addss xmm0, [f_half]
    mov eax, [cur_pcz]
    shl eax, 4
    mov ecx, [rbx + BC_Z]
    sub ecx, eax
    cvtsi2ss xmm2, ecx
    addss xmm2, [f_half]
    xorps xmm1, xmm1
    call glTranslatef PLT
    movss xmm0, [spin]
    xorps xmm1, xmm1
    movss xmm2, [f_one]
    xorps xmm3, xmm3
    call glRotatef PLT
    mov dword [rsp + 36], 0
.pass:
    mov eax, [f_inner]
    mov ecx, [f_ina]
    cmp dword [rsp + 36], 0
    je .pw
    mov eax, [f_outer]
    mov ecx, [f_outa]
.pw:
    mov [b_w], eax
    mov [rsp + 12], ecx
    mov edi, GL_QUADS
    call glBegin PLT
    mov dword [rsp + 16], 0
.s:
    mov eax, [rsp + 16]
    cmp eax, [rbx + BC_NSEG]
    jae .s_done
    cvtsi2ss xmm0, dword [rbx + BC_SEG + rax*8]
    movss [b_y0], xmm0
    mov ecx, BEAM_TOP
    inc eax
    cmp eax, [rbx + BC_NSEG]
    jae .top
    mov ecx, [rbx + BC_SEG + rax*8]
.top:
    cvtsi2ss xmm0, ecx
    movss [b_y1], xmm0
    mov eax, [rsp + 16]
    lea r12, [rbx + BC_SEG + rax*8 + 4]
    xor ecx, ecx
.rgb:
    movzx edx, byte [r12 + rcx]
    cvtsi2ss xmm0, edx
    mulss xmm0, [f_inv255]
    movss [rsp + 24 + rcx*4], xmm0
    inc ecx
    cmp ecx, 3
    jb .rgb
    movss xmm0, [rsp + 24]
    movss xmm1, [rsp + 28]
    movss xmm2, [rsp + 32]
    movss xmm3, [rsp + 12]
    call glColor4f PLT
    call beam_box
    inc dword [rsp + 16]
    jmp .s
.s_done:
    call glEnd PLT
    inc dword [rsp + 36]
    cmp dword [rsp + 36], 2
    jb .pass
    call glPopMatrix PLT
.bnext:
    inc dword [rsp + 20]
    jmp .b
.done:
    mov edi, 1
    call glDepthMask PLT
    mov edi, GL_BLEND
    call glDisable PLT
    mov edi, GL_TEXTURE_2D
    call glEnable PLT
    mov edi, GL_ALPHA_TEST
    call glEnable PLT
    mov edi, GL_CULL_FACE
    call glEnable PLT
.out:
    LEAVE_FN

; beam_box - the four sides of a square column, half width b_w from y
; b_y0 to b_y1 (inside glBegin), in pieces 16 nodes tall so the fog, worked
; out at the corners, fades it right
; locals: [0] side, [4] piece bottom, [8] piece top
beam_box:
    ENTER_FN 16
    movss xmm0, [b_y0]
    movss [rsp + 4], xmm0
.piece:
    movss xmm0, [rsp + 4]
    comiss xmm0, [b_y1]
    jae .out
    addss xmm0, [f_piece]
    minss xmm0, [b_y1]
    movss [rsp + 8], xmm0
    mov dword [rsp], 0
.side:
    mov eax, [rsp]
    call corner_xz
    movss xmm1, [rsp + 4]
    call glVertex3f PLT
    mov eax, [rsp]
    inc eax
    and eax, 3
    call corner_xz
    movss xmm1, [rsp + 4]
    call glVertex3f PLT
    mov eax, [rsp]
    inc eax
    and eax, 3
    call corner_xz
    movss xmm1, [rsp + 8]
    call glVertex3f PLT
    mov eax, [rsp]
    call corner_xz
    movss xmm1, [rsp + 8]
    call glVertex3f PLT
    inc dword [rsp]
    cmp dword [rsp], 4
    jb .side
    movss xmm0, [rsp + 8]
    movss [rsp + 4], xmm0
    jmp .piece
.out:
    LEAVE_FN

; corner_xz(eax corner 0-3) -> xmm0 x, xmm2 z: (-w,-w) (w,-w) (w,w) (-w,w)
corner_xz:
    movss xmm0, [b_w]
    movaps xmm2, xmm0
    xorps xmm3, xmm3
    subss xmm3, xmm0                ; -w
    test eax, eax
    jz .mm
    cmp eax, 1
    je .pm
    cmp eax, 2
    je .out                         ; (w, w)
    movaps xmm0, xmm3               ; 3: (-w, w)
    ret
.mm:
    movaps xmm0, xmm3
    movaps xmm2, xmm3
    ret
.pm:
    movaps xmm2, xmm3               ; (w, -w)
.out:
    ret

NOEXECSTACK
