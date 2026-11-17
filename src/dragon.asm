%include "common.inc"

global dragon_dead, dragon_hp, crystal_gone, dragon_new, dragon_enter
global dragon_update, dragon_draw, dragon_hud, dragon_attack, d_state, d_pos, d_swoop_t
global dragon_shot, dragon_won, dragon_respawn, d_perch_t, dragon_rounds, d_heal, try_buf, d_roar_t

extern pos, vel, yaw, syaw, cyaw, pitch, dt, game_mode, set_difficulty
extern dimension, player_damage, knock_x, knock_z, world_set, meta_set
extern hud_message, ent_spawn, sel_slot, inv, tool_of, eff_time, eye_h
extern sound_keep, sound_keep_at, cur_pcx, cur_pcz, fig_parts, fig_tint
extern hud_rect, hud_text_center, win_w, save_meta, end_pillars, player_dead
extern world_raycast, world_get, meta_del
extern glPushMatrix, glPopMatrix, glTranslatef, glRotatef, glScalef
extern glEnable, glDisable, glBegin, glEnd, glVertex3f, glColor4f, glLineWidth

GL_CULL_FACE    equ 0x0B44
GL_TEXTURE_2D   equ 0x0DE1
GL_ALPHA_TEST   equ 0x0BC0
GL_LINES        equ 1

ST_CIRCLE   equ 0
ST_SWOOP    equ 1
ST_RETURN   equ 2
ST_TOPERCH  equ 3
ST_PERCH    equ 4
ST_DYING    equ 5
ST_GONE     equ 6

section .rodata
align 4
f_zero:     dd 0.0
f_half:     dd 0.5
f_one:      dd 1.0
f_two:      dd 2.0
f_three:    dd 3.0
f_hp_n:     dd 350.0                ; health: normal (and peaceful)
f_hp_h:     dd 550.0                ; hard
f_radius:   dd 38.0                 ; the circle round the middle
f_omega:    dd 0.33                 ; radians a second round it
f_fly:      dd 13.0                 ; speeds, nodes a second: circling,
f_dive:     dd 21.0                 ; swooping,
f_climb:    dd 15.0                 ; climbing back,
f_land:     dd 10.0                 ; coming down to perch
f_steer:    dd 2.5                  ; how fast it turns to where it goes
f_strike:   dd 12.25                ; 3.5 nodes (squared): close enough to hit
f_heal:     dd 8.0                  ; health a second from a crystal
f_heal_all: dd 9.0                  ; each, when all heal it (below half health)
f_perround: dd 20.0                 ; more health for each time it came back
f_reach2:   dd 2304.0               ; crystals reach 48 nodes (squared)
f_swoop0:   dd 5.0                  ; a swoop every 5 .. 10 s
f_swoopr:   dd 5.0
f_perch0:   dd 12.0                 ; to the perch every 12 .. 20 s,
f_perchr:   dd 8.0
f_perchper: dd 8.0                  ; and 8 s more for each crystal left
f_rifle:    dd 6.0                  ; a rifle round's damage (as on a mob)
f_far:      dd 1000.0
f_perchfor: dd 10.0                 ; seconds sitting there
f_roar:     dd 10.0                 ; a roar every 10 s
f_swooplim: dd 5.0                  ; a swoop gives up after this
f_dying:    dd 4.0
f_rise:     dd 3.0
f_knock:    dd 12.0
f_up:       dd 7.0
f_hurtt:    dd 0.4
f_flap:     dd 4.5                  ; wing beats (radians a second)
f_flapdeg:  dd 28.0
f_swept:    dd 12.0                 ; wings in a swoop
f_folded:   dd -45.0                ; and sitting
f_rad2deg:  dd 57.29578
f_maxpitch: dd 60.0
f_minpitch: dd -60.0
f_eighth:   dd 0.125
f_spin:     dd 90.0                 ; crystals turn (degrees a second)
f_crystal_r2: dd 1.44               ; clicking a crystal: within 1.2 nodes
f_dragon_r2: dd 12.25               ; the dragon: within 3.5 nodes of its body
f_reach:    dd 5.5                  ; how far the player hits
f_dreach:   dd 7.5                  ; (the dragon is big)
f_blast2:   dd 25.0                 ; a crystal's bang: within 5 nodes
f_inv65536: dd 1.52587891e-5
f_bar_w:    dd 400.0
f_bar_y0:   dd 24.0
f_bar_y1:   dd 34.0
f_name_y:   dd 6.0
f_try_y:    dd 40.0
f_scale2:   dd 2.0
f_beam:     dd 4.0
f_cry_y:    dd 2.7                  ; a crystal's middle over its pillar top
f_perch_y:  dd 6.5                  ; the dragon's middle over the island top
f_circle_y: dd 28.0
f_strength: dd 1.4
f_round:    dd 0.5
s_dragon:   db "DRAGON", 0
s_dead:     db "THE DRAGON IS DEAD - THE WAY HOME IS OPEN", 0
s_back:     db "THE DRAGON IS BACK ON ITS ISLAND", 0
s_st:       db "ST TRY", 0
s_nd:       db "ND TRY", 0
s_rd:       db "RD TRY", 0
s_th:       db "TH TRY", 0

; the model, in 1/8 nodes, its front toward +z, the middle of the body at 0
%macro FPART 9
    dd %1, %2, %3, %4, %5, %6
    db %7, %8, %9, 0
    dd 0
%endmacro
BLK equ 22                          ; black
DGR equ 44                          ; dark grey
m_body:
    FPART  -6.0, -5.0, -14.0,   6.0,  5.0,  14.0,  BLK, BLK, BLK + 4   ; body
    FPART  -5.0, -6.0, -12.0,   5.0, -5.0,  12.0,  DGR, DGR, DGR       ; belly
    FPART  -1.0,  5.0, -10.0,   1.0,  8.0,  -6.0,  60, 210, 90        ; spikes
    FPART  -1.0,  5.0,  -2.0,   1.0,  8.0,   2.0,  60, 210, 90
    FPART  -1.0,  5.0,   6.0,   1.0,  8.0,  10.0,  60, 210, 90
    FPART  -3.0, -2.0,  14.0,   3.0,  4.0,  26.0,  BLK, BLK, BLK + 4   ; neck
    FPART  -1.0,  4.0,  17.0,   1.0,  6.0,  20.0,  60, 210, 90
    FPART  -1.0,  4.0,  22.0,   1.0,  6.0,  25.0,  60, 210, 90
    FPART  -5.0, -2.0,  26.0,   5.0,  5.0,  36.0,  BLK, BLK, BLK + 4   ; head
    FPART  -3.0, -1.0,  36.0,   3.0,  3.0,  43.0,  BLK, BLK, BLK + 4   ; snout
    FPART  -3.0, -4.0,  28.0,   3.0, -1.0,  42.0,  DGR, DGR, DGR       ; jaw
    FPART  -5.5,  2.0,  32.0,  -4.5,  4.0,  35.0,  90, 255, 120       ; eyes
    FPART   4.5,  2.0,  32.0,   5.5,  4.0,  35.0,  90, 255, 120
    FPART  -4.0,  5.0,  27.0,  -2.0,  8.0,  29.0,  DGR, DGR, DGR       ; horns
    FPART   2.0,  5.0,  27.0,   4.0,  8.0,  29.0,  DGR, DGR, DGR
    FPART  -4.0, -3.0, -26.0,   4.0,  3.0, -14.0,  BLK, BLK, BLK + 4   ; tail
    FPART  -3.0, -2.0, -38.0,   3.0,  2.0, -26.0,  BLK, BLK, BLK + 4
    FPART  -2.0, -1.5, -50.0,   2.0,  1.5, -38.0,  BLK, BLK, BLK + 4
    FPART  -0.7,  3.0, -24.0,   0.7,  5.0, -20.0,  60, 210, 90
    FPART  -0.7,  2.0, -34.0,   0.7,  4.0, -30.0,  60, 210, 90
    FPART  -7.0,-12.0,   6.0,  -4.0, -5.0,  10.0,  DGR, DGR, DGR       ; legs
    FPART   4.0,-12.0,   6.0,   7.0, -5.0,  10.0,  DGR, DGR, DGR
    FPART  -7.0,-12.0, -10.0,  -4.0, -5.0,  -6.0,  DGR, DGR, DGR
    FPART   4.0,-12.0, -10.0,   7.0, -5.0,  -6.0,  DGR, DGR, DGR
M_BODY_N equ ($ - m_body) / 32
; a wing from its shoulder toward +x (the other is the same mirrored)
m_wing:
    FPART   0.0, -1.0,  -2.0,  36.0,  1.0,   2.0,  DGR, DGR, DGR       ; bone
    FPART   0.0, -0.5, -18.0,  34.0,  0.5,  -2.0,  24, 52, 32          ; membrane
    FPART  30.0, -0.6, -12.0,  42.0,  0.6,   0.0,  24, 52, 32
    FPART  34.0, -1.0,  -1.0,  44.0,  1.0,   1.0,  60, 210, 90        ; claw
M_WING_N equ ($ - m_wing) / 32
; an end crystal: a bright core inside the twelve edges of a cube
m_core:
    FPART  -2.0, -2.0, -2.0,   2.0,  2.0,  2.0,  110, 255, 140
M_CORE_N equ ($ - m_core) / 32
m_frame:
    FPART  -4.0,  -4.0,  -4.0,   4.0,  -3.5,  -3.5,  220, 240, 225
    FPART  -4.0,  -4.0,   3.5,   4.0,  -3.5,   4.0,  220, 240, 225
    FPART  -4.0,   3.5,  -4.0,   4.0,   4.0,  -3.5,  220, 240, 225
    FPART  -4.0,   3.5,   3.5,   4.0,   4.0,   4.0,  220, 240, 225
    FPART  -4.0,  -4.0,  -4.0,  -3.5,   4.0,  -3.5,  220, 240, 225
    FPART  -4.0,  -4.0,   3.5,  -3.5,   4.0,   4.0,  220, 240, 225
    FPART   3.5,  -4.0,  -4.0,   4.0,   4.0,  -3.5,  220, 240, 225
    FPART   3.5,  -4.0,   3.5,   4.0,   4.0,   4.0,  220, 240, 225
    FPART  -4.0,  -4.0,  -4.0,  -3.5,  -3.5,   4.0,  220, 240, 225
    FPART  -4.0,   3.5,  -4.0,  -3.5,   4.0,   4.0,  220, 240, 225
    FPART   3.5,  -4.0,  -4.0,   4.0,  -3.5,   4.0,  220, 240, 225
    FPART   3.5,   3.5,  -4.0,   4.0,   4.0,   4.0,  220, 240, 225
M_FRAME_N equ ($ - m_frame) / 32

section .data
align 4
d_state:    dd ST_GONE
d_swoop_t:  dd 6.0
d_perch_t:  dd 45.0
d_roar_t:   dd 2.0
d_seed:     dd 0x51ED270B

section .bss
alignb 4
dragon_dead: resd 1                 ; saved: 1 once killed
dragon_hp:  resd 1                  ; saved: health left (0: not yet met)
crystal_gone: resd 1                ; saved: crystals broken (a bit each)
dragon_won: resd 1                  ; saved: 1 once the rifle has dropped
dragon_rounds: resd 1               ; saved: times it was brought back
rbuf:       resd 6
d_max:      resd 1
d_pos:      resd 3                  ; the middle of its body
d_vel:      resd 3
d_yaw:      resd 1                  ; degrees, its front from +z
d_pitch:    resd 1                  ; degrees, nose down
d_t:        resd 1                  ; time left in this state
d_hurt:     resd 1
d_flap:     resd 1
d_angle:    resd 1                  ; round its circle
d_heal:     resd 5                  ; the crystals healing it, or -1
try_buf:    resb 16
d_spin:     resd 1
d_tgt:      resd 3                  ; where it flies to
d_speed:    resd 1
tmp:        resd 8

section .text

; 0 .. 1 in xmm0
d_rand:
    imul eax, [d_seed], 1103515245
    add eax, 12345
    mov [d_seed], eax
    shr eax, 16
    cvtsi2ss xmm0, eax
    mulss xmm0, [f_inv65536]
    ret

; xmm0 = atan2(xmm0 y, xmm1 x) in degrees
atan2_deg:
    sub rsp, 8
    movss [rsp], xmm0
    movss [rsp + 4], xmm1
    fld dword [rsp]
    fld dword [rsp + 4]
    fpatan
    fstp dword [rsp]
    movss xmm0, [rsp]
    mulss xmm0, [f_rad2deg]
    add rsp, 8
    ret

; void dragon_new(void) - a new world: the dragon is there, unhurt
dragon_new:
    xor eax, eax
    mov [dragon_dead], eax
    mov [dragon_hp], eax
    mov [crystal_gone], eax
    mov [dragon_won], eax
    mov [dragon_rounds], eax
    mov dword [d_state], ST_GONE
    ret

; void dragon_enter(void) - a dimension was entered (or a world loaded):
; on the island the dragon comes back, circling, unless it is dead
dragon_enter:
    mov dword [d_state], ST_GONE
    cmp dword [dimension], 2
    jne .out
    cmp dword [dragon_dead], 0
    jne .out
    call max_hp
    movss xmm1, [dragon_hp]
    comiss xmm1, [f_zero]
    jbe .full
    comiss xmm1, xmm0
    jbe .kept
.full:
    movss [dragon_hp], xmm0
.kept:
    mov dword [d_state], ST_CIRCLE
    mov dword [d_angle], 0
    mov dword [d_hurt], 0
    mov dword [d_vel], 0
    mov dword [d_vel + 4], 0
    mov dword [d_vel + 8], 0
    call circle_point
    mov eax, [d_tgt]
    mov [d_pos], eax
    mov eax, [d_tgt + 4]
    mov [d_pos + 4], eax
    mov eax, [d_tgt + 8]
    mov [d_pos + 8], eax
    mov dword [d_swoop_t], 0x40c00000   ; 6 s
    sub rsp, 8
    call perch_delay
    movss [d_perch_t], xmm0
    mov dword [d_roar_t], 0x40000000    ; it roars 2 s after you come
    add rsp, 8
.out:
    ret

; xmm0 = seconds to its next perch: the fewer crystals, the sooner
perch_delay:
    call d_rand
    mulss xmm0, [f_perchr]
    addss xmm0, [f_perch0]
    xor ecx, ecx
    xor edx, edx
.l:
    bt dword [crystal_gone], ecx
    jc .g
    inc edx
.g:
    inc ecx
    cmp ecx, END_PILLARS
    jb .l
    cvtsi2ss xmm1, edx
    mulss xmm1, [f_perchper]
    addss xmm0, xmm1
    ret

; void dragon_respawn(void) - a dragon portal was built in the nether: a
; dead dragon comes back, unhurt, its crystals too
dragon_respawn:
    cmp dword [dragon_dead], 0
    je .r
    sub rsp, 8
    xor eax, eax
    mov [dragon_dead], eax
    mov [dragon_hp], eax
    mov [crystal_gone], eax
    inc dword [dragon_rounds]       ; 20 more health each time
    lea rdi, [s_back]
    call hud_message
    add rsp, 8
.r:
    ret

; pool_clear - while the dragon lives the way home is shut: an exit portal
; left in the pool from an earlier fight goes (once its chunk is there)
pool_clear:
    ENTER_FN 16
    mov r12d, -2
.z:
    mov r13d, -2
.x:
    mov eax, r12d
    imul eax, eax
    mov ecx, r13d
    imul ecx, ecx
    add eax, ecx
    jz .n
    cmp eax, 5
    jg .n
    mov edi, r13d
    mov esi, END_TOP
    mov edx, r12d
    call world_get
    cmp eax, W_SHAPE
    jne .n
    mov edi, r13d
    mov esi, END_TOP
    mov edx, r12d
    call meta_del
    mov edi, r13d
    mov esi, END_TOP
    mov edx, r12d
    mov ecx, B_AIR
    call world_set
.n:
    inc r13d
    cmp r13d, 2
    jle .x
    inc r12d
    cmp r12d, 2
    jle .z
    LEAVE_FN

; xmm0 = the dragon's full health on this difficulty
max_hp:
    movss xmm0, [f_hp_n]
    cmp dword [set_difficulty], 2
    jne .n
    movss xmm0, [f_hp_h]
.n:
    cvtsi2ss xmm1, dword [dragon_rounds]
    mulss xmm1, [f_perround]
    addss xmm0, xmm1
    movss [d_max], xmm0
    ret

; d_tgt = the point of its circle at d_angle
circle_point:
    sub rsp, 8
    fld dword [d_angle]
    fsincos
    fstp dword [rsp]                ; cos
    fstp dword [rsp + 4]            ; sin
    movss xmm0, [rsp]
    mulss xmm0, [f_radius]
    movss [d_tgt], xmm0
    movss xmm0, [rsp + 4]
    mulss xmm0, [f_radius]
    movss [d_tgt + 8], xmm0
    mov eax, END_TOP
    cvtsi2ss xmm0, eax
    addss xmm0, [f_circle_y]
    movss [d_tgt + 4], xmm0
    add rsp, 8
    ret

; crystal_at(edi i) -> xmm0, xmm1, xmm2 its middle
crystal_at:
    imul eax, edi, 20
    lea rcx, [end_pillars]
    add rcx, rax
    cvtsi2ss xmm0, dword [rcx]
    addss xmm0, [f_half]
    mov eax, [rcx + 12]
    add eax, END_TOP + 2
    cvtsi2ss xmm1, eax
    addss xmm1, [f_cry_y]
    subss xmm1, [f_two]
    cvtsi2ss xmm2, dword [rcx + 4]
    addss xmm2, [f_half]
    ret

; xmm0 = squared distance from (xmm0, xmm1, xmm2) to rdi -> 3 floats
dist2:
    subss xmm0, [rdi]
    mulss xmm0, xmm0
    subss xmm1, [rdi + 4]
    mulss xmm1, xmm1
    subss xmm2, [rdi + 8]
    mulss xmm2, xmm2
    addss xmm0, xmm1
    addss xmm0, xmm2
    ret

; void dragon_update(void) - once a frame
dragon_update:
    cmp dword [dimension], 2
    jne .ret
    cmp dword [d_state], ST_GONE
    je .ret
    ENTER_FN 32
    call pool_clear
    ; a roar every 10 s (heard all over the island)
    cmp dword [d_state], ST_DYING
    je .noroar
    movss xmm0, [d_roar_t]
    subss xmm0, [dt]
    movss [d_roar_t], xmm0
    comiss xmm0, [f_zero]
    ja .noroar
    addss xmm0, [f_roar]
    movss [d_roar_t], xmm0
    SFX S_ROAR, 70, 100
.noroar:
    call max_hp
    movss xmm1, [dragon_hp]
    minss xmm1, xmm0
    movss [dragon_hp], xmm1
    movss xmm0, [d_hurt]
    subss xmm0, [dt]
    maxss xmm0, [f_zero]
    movss [d_hurt], xmm0
    movss xmm0, [d_spin]
    movss xmm1, [dt]
    mulss xmm1, [f_spin]
    addss xmm0, xmm1
    movss [d_spin], xmm0
    movss xmm0, [d_flap]
    movss xmm1, [dt]
    mulss xmm1, [f_flap]
    addss xmm0, xmm1
    movss [d_flap], xmm0
    ; the two nearest crystals in reach heal it
    mov eax, -1
    lea rdi, [d_heal]
    mov ecx, 5
    rep stosd
    mov eax, [f_reach2]
    mov [rsp], eax                  ; nearest so far
    mov [rsp + 4], eax              ; and the next
    xor ebx, ebx
.c:
    bt dword [crystal_gone], ebx
    jc .cn
    mov edi, ebx
    call crystal_at
    lea rdi, [d_pos]
    call dist2
    comiss xmm0, [rsp + 4]
    jae .cn
    comiss xmm0, [rsp]
    jb .c1
    movss [rsp + 4], xmm0           ; the second nearest
    mov [d_heal + 4], ebx
    jmp .cn
.c1:
    mov eax, [rsp]                  ; the nearest; the old one is second
    mov [rsp + 4], eax
    mov eax, [d_heal]
    mov [d_heal + 4], eax
    movss [rsp], xmm0
    mov [d_heal], ebx
.cn:
    inc ebx
    cmp ebx, END_PILLARS
    jb .c
    cmp dword [d_state], ST_DYING
    je .states
    movss xmm2, [f_heal]
    ; below half its health every crystal left heals it, wherever it is
    movss xmm0, [d_max]
    mulss xmm0, [f_half]
    comiss xmm0, [dragon_hp]
    jbe .count
    movss xmm2, [f_heal_all]
    xor ebx, ebx
.all:
    mov eax, -1
    bt dword [crystal_gone], ebx
    jc .alln
    mov eax, ebx
.alln:
    lea rcx, [d_heal]
    mov [rcx + rbx*4], eax
    inc ebx
    cmp ebx, END_PILLARS
    jb .all
.count:
    xor ecx, ecx                    ; how many heal it
    xor ebx, ebx
.cc:
    lea rax, [d_heal]
    cmp dword [rax + rbx*4], 0
    jl .ccn
    inc ecx
.ccn:
    inc ebx
    cmp ebx, 5
    jb .cc
    test ecx, ecx
    jz .states
    cvtsi2ss xmm0, ecx
    mulss xmm0, xmm2
    mulss xmm0, [dt]
    addss xmm0, [dragon_hp]
    minss xmm0, [d_max]
    movss [dragon_hp], xmm0
.states:
    mov eax, [d_state]
    cmp eax, ST_SWOOP
    je .swoop
    cmp eax, ST_RETURN
    je .return
    cmp eax, ST_TOPERCH
    je .toperch
    cmp eax, ST_PERCH
    je .perch
    cmp eax, ST_DYING
    je .dying
    ; circling: round and round; now and then a swoop, or down to perch
    movss xmm0, [dt]
    mulss xmm0, [f_omega]
    addss xmm0, [d_angle]
    movss [d_angle], xmm0
    call circle_point
    mov eax, [f_fly]
    mov [d_speed], eax
    movss xmm0, [d_perch_t]
    subss xmm0, [dt]
    movss [d_perch_t], xmm0
    comiss xmm0, [f_zero]
    ja .noperch
    mov dword [d_state], ST_TOPERCH
    jmp .move
.noperch:
    movss xmm0, [d_swoop_t]
    subss xmm0, [dt]
    movss [d_swoop_t], xmm0
    comiss xmm0, [f_zero]
    ja .move
    cmp dword [player_dead], 0
    jne .move
    mov dword [d_state], ST_SWOOP
    mov eax, [f_swooplim]
    mov [d_t], eax
    jmp .move
.swoop:
    ; down at the player; close enough: strike, and away
    mov eax, [pos]
    mov [d_tgt], eax
    movss xmm0, [pos + 4]
    addss xmm0, [f_one]
    movss [d_tgt + 4], xmm0
    mov eax, [pos + 8]
    mov [d_tgt + 8], eax
    mov eax, [f_dive]
    mov [d_speed], eax
    movss xmm0, [d_pos]
    movss xmm1, [d_pos + 4]
    movss xmm2, [d_pos + 8]
    lea rdi, [d_tgt]
    call dist2
    comiss xmm0, [f_strike]
    ja .notyet
    call strike
    jmp .back
.notyet:
    movss xmm0, [d_t]
    subss xmm0, [dt]
    movss [d_t], xmm0
    comiss xmm0, [f_zero]
    ja .move
.back:
    mov dword [d_state], ST_RETURN
    call d_rand
    mulss xmm0, [f_swoopr]
    addss xmm0, [f_swoop0]
    movss [d_swoop_t], xmm0
    jmp .move
.return:
    ; up to its circle again
    call circle_point
    mov eax, [f_climb]
    mov [d_speed], eax
    movss xmm0, [d_pos]
    movss xmm1, [d_pos + 4]
    movss xmm2, [d_pos + 8]
    lea rdi, [d_tgt]
    call dist2
    comiss xmm0, [f_strike + 0]
    mov eax, 64
    cvtsi2ss xmm1, eax
    comiss xmm0, xmm1
    ja .move
    mov dword [d_state], ST_CIRCLE
    jmp .move
.toperch:
    ; down onto the middle column, slowing as it comes
    call perch_point
    movss xmm0, [d_pos]
    movss xmm1, [d_pos + 4]
    movss xmm2, [d_pos + 8]
    lea rdi, [d_tgt]
    call dist2
    sqrtss xmm0, xmm0
    movss xmm1, xmm0
    mulss xmm1, [f_one]
    addss xmm1, [f_one]
    minss xmm1, [f_land]
    movss [d_speed], xmm1
    comiss xmm0, [f_one]
    ja .move
    mov dword [d_state], ST_PERCH
    mov eax, [f_perchfor]
    mov [d_t], eax
    jmp .sit
.perch:
    movss xmm0, [d_t]
    subss xmm0, [dt]
    movss [d_t], xmm0
    comiss xmm0, [f_zero]
    ja .sit
    mov dword [d_state], ST_RETURN  ; up and away
    call perch_delay
    movss [d_perch_t], xmm0
    call d_rand
    mulss xmm0, [f_swoopr]
    addss xmm0, [f_swoop0]
    movss [d_swoop_t], xmm0
    jmp .move
.sit:
    call perch_point
    mov eax, [d_tgt]
    mov [d_pos], eax
    mov eax, [d_tgt + 4]
    mov [d_pos + 4], eax
    mov eax, [d_tgt + 8]
    mov [d_pos + 8], eax
    xor eax, eax
    mov [d_vel], eax
    mov [d_vel + 4], eax
    mov [d_vel + 8], eax
    mov [d_pitch], eax
    movss xmm0, [pos]               ; it looks at the player
    subss xmm0, [d_pos]
    movss xmm1, [pos + 8]
    subss xmm1, [d_pos + 8]
    call atan2_deg
    movss [d_yaw], xmm0
    jmp .out
.dying:
    movss xmm0, [dt]
    mulss xmm0, [f_rise]
    addss xmm0, [d_pos + 4]
    movss [d_pos + 4], xmm0
    mov eax, [f_hurtt]
    mov [d_hurt], eax
    movss xmm0, [d_t]
    subss xmm0, [dt]
    movss [d_t], xmm0
    comiss xmm0, [f_zero]
    ja .out
    call dragon_die
    jmp .out
.move:
    ; turn toward where it goes, at its speed
    movss xmm0, [d_tgt]
    subss xmm0, [d_pos]
    movss xmm1, [d_tgt + 4]
    subss xmm1, [d_pos + 4]
    movss xmm2, [d_tgt + 8]
    subss xmm2, [d_pos + 8]
    movaps xmm3, xmm0
    mulss xmm3, xmm3
    movaps xmm4, xmm1
    mulss xmm4, xmm4
    addss xmm3, xmm4
    movaps xmm4, xmm2
    mulss xmm4, xmm4
    addss xmm3, xmm4
    sqrtss xmm3, xmm3
    maxss xmm3, [f_half]
    movss xmm4, [d_speed]
    divss xmm4, xmm3
    mulss xmm0, xmm4
    mulss xmm1, xmm4
    mulss xmm2, xmm4                ; the velocity it wants
    movss xmm5, [dt]
    mulss xmm5, [f_steer]
    minss xmm5, [f_one]
    xor ecx, ecx
.v:
    lea rax, [d_vel]
    movss xmm6, [rax + rcx*4]
    cmp ecx, 1
    jne .v0
    movaps xmm7, xmm1
    jmp .v1
.v0:
    movaps xmm7, xmm0
    cmp ecx, 2
    jne .v1
    movaps xmm7, xmm2
.v1:
    subss xmm7, xmm6
    mulss xmm7, xmm5
    addss xmm6, xmm7
    movss [rax + rcx*4], xmm6
    mulss xmm6, [dt]
    lea rax, [d_pos]
    addss xmm6, [rax + rcx*4]
    movss [rax + rcx*4], xmm6
    inc ecx
    cmp ecx, 3
    jb .v
    ; it faces the way it flies, its nose down as it dives
    movss xmm0, [d_vel]
    movss xmm1, [d_vel + 8]
    call atan2_deg
    movss [d_yaw], xmm0
    movss xmm1, [d_vel]
    mulss xmm1, xmm1
    movss xmm2, [d_vel + 8]
    mulss xmm2, xmm2
    addss xmm1, xmm2
    sqrtss xmm1, xmm1
    xorps xmm0, xmm0
    subss xmm0, [d_vel + 4]
    call atan2_deg
    minss xmm0, [f_maxpitch]
    maxss xmm0, [f_minpitch]
    movss [d_pitch], xmm0
.out:
    LEAVE_FN
.ret:
    ret

; d_tgt = where it sits: over the middle column
perch_point:
    mov dword [d_tgt], 0x3f000000           ; 0.5
    mov dword [d_tgt + 8], 0x3f000000
    mov eax, END_TOP
    cvtsi2ss xmm0, eax
    addss xmm0, [f_perch_y]
    movss [d_tgt + 4], xmm0
    ret

; strike - it hits the player: 4 hearts (hard 6) before armour, and throws
; them back
strike:
    sub rsp, 8
    movss xmm0, [d_vel]
    mulss xmm0, xmm0
    movss xmm1, [d_vel + 8]
    mulss xmm1, xmm1
    addss xmm0, xmm1
    sqrtss xmm0, xmm0
    maxss xmm0, [f_half]
    movss xmm1, [f_knock]
    divss xmm1, xmm0
    movss xmm2, [d_vel]
    mulss xmm2, xmm1
    movss [knock_x], xmm2
    movss xmm2, [d_vel + 8]
    mulss xmm2, xmm1
    movss [knock_z], xmm2
    mov eax, [f_up]
    mov [vel + 4], eax
    movss xmm0, [pos]
    movss xmm1, [pos + 4]
    movss xmm2, [pos + 8]
    SFX_AT S_HIT, 120, 70
    mov edi, 8
    cmp dword [set_difficulty], 2
    jne .d
    mov edi, 12
.d:
    call player_damage
    add rsp, 8
    ret

; dragon_die - gone: the way home opens in the pool, the rifle drops
; locals: [0] dx, [4] dz
dragon_die:
    ENTER_FN 16
    mov dword [dragon_dead], 1
    mov dword [d_state], ST_GONE
    mov dword [d_heal], -1
    mov r12d, -2
.dz:
    mov r13d, -2
.dx:
    mov eax, r12d
    imul eax, eax
    mov ecx, r13d
    imul ecx, ecx
    add eax, ecx
    jz .n                           ; the column
    cmp eax, 5
    jg .n
    mov edi, r13d
    mov esi, END_TOP
    mov edx, r12d
    mov ecx, 0x80 | 1 | (2 << 1)    ; a green portal, flat, the way home
    call meta_set
    mov ecx, W_SHAPE
    call world_set
.n:
    inc r13d
    cmp r13d, 2
    jle .dx
    inc r12d
    cmp r12d, 2
    jle .dz
    ; the rifle, by the column (only for the first win)
    cmp dword [dragon_won], 0
    jne .norifle
    mov dword [dragon_won], 1
    mov dword [rsp], 0x3f000000
    movss xmm0, [rsp]
    mov eax, END_TOP + 6
    cvtsi2ss xmm1, eax
    mov eax, 2
    cvtsi2ss xmm2, eax
    addss xmm2, xmm0
    xorps xmm3, xmm3
    movss xmm4, [f_two]
    xorps xmm5, xmm5
    mov edi, I_RIFLE | (1 << 8)
    call ent_spawn
.norifle:
    movss xmm0, [d_pos]
    movss xmm1, [d_pos + 4]
    movss xmm2, [d_pos + 8]
    SFX_AT S_EXPLODE, 120, 50
    lea rdi, [s_dead]
    call hud_message
    call save_meta
    LEAVE_FN

; int dragon_attack(void) - a left click: a crystal in reach breaks; the
; dragon in reach is hit like a mob. 1 if something was hit.
; int dragon_shot(float xmm0 range) - a rifle round flies that far (to the
; first solid block): it breaks the first crystal or hits the dragon on its
; way. 1 if it did.
; locals: [0] eye x, y, z, [12] dir x, y, z, [24] best t, [28] what (-1,
; 0-4 a crystal, 5 the dragon), [32] cos pitch, [36] sin pitch, [44] 1 for
; a round, [48] how far it goes
dragon_attack:
    xor edi, edi
    movss xmm0, [f_dreach]
    jmp dragon_ray
dragon_shot:
    mov edi, 1
dragon_ray:
    cmp dword [dimension], 2
    jne .no
    ENTER_FN 64
    mov [rsp + 44], edi
    movss [rsp + 48], xmm0
    movss xmm0, [pos]
    movss [rsp], xmm0
    movss xmm0, [pos + 4]
    addss xmm0, [eye_h]
    movss [rsp + 4], xmm0
    movss xmm0, [pos + 8]
    movss [rsp + 8], xmm0
    fld dword [pitch]
    fsincos
    fstp dword [rsp + 32]
    fstp dword [rsp + 36]
    movss xmm0, [syaw]
    mulss xmm0, [rsp + 32]
    movss [rsp + 12], xmm0
    xorps xmm0, xmm0
    subss xmm0, [rsp + 36]
    movss [rsp + 16], xmm0
    movss xmm1, [cyaw]
    mulss xmm1, [rsp + 32]
    xorps xmm0, xmm0
    subss xmm0, xmm1
    movss [rsp + 20], xmm0
    mov dword [rsp + 28], -1
    ; a hand stops at the first block in the way (a cage round a crystal);
    ; a round was stopped already
    cmp dword [rsp + 44], 0
    jne .lim
    movss xmm0, [rsp]
    movss xmm1, [rsp + 4]
    movss xmm2, [rsp + 8]
    movss xmm3, [rsp + 12]
    movss xmm4, [rsp + 16]
    movss xmm5, [rsp + 20]
    movss xmm6, [rsp + 48]
    lea rdi, [rbuf]
    call world_raycast
    test eax, eax
    jz .lim
    xorps xmm7, xmm7                ; where the ray enters that block
    xor ecx, ecx
.e:
    lea rax, [rbuf]
    cvtsi2ss xmm0, dword [rax + rcx*4]
    movss xmm1, [rsp + 12 + rcx*4]
    comiss xmm1, [f_zero]
    ja .ep
    jb .en
    jmp .enext
.en:
    addss xmm0, [f_one]
.ep:
    subss xmm0, [rsp + rcx*4]
    divss xmm0, xmm1
    maxss xmm7, xmm0
.enext:
    inc ecx
    cmp ecx, 3
    jb .e
    minss xmm7, [rsp + 48]
    movss [rsp + 48], xmm7
.lim:
    mov eax, [rsp + 48]
    mov [rsp + 24], eax
    ; the crystals
    xor ebx, ebx
.c:
    bt dword [crystal_gone], ebx
    jc .cn
    mov edi, ebx
    call crystal_at
    movss xmm3, [f_reach]
    cmp dword [rsp + 44], 0
    je .cr
    movss xmm3, [f_far]
.cr:
    movss xmm4, [f_crystal_r2]
    mov esi, ebx
    call ray_ball
.cn:
    inc ebx
    cmp ebx, END_PILLARS
    jb .c
    ; the dragon, while it is about (not dying)
    cmp dword [d_state], ST_DYING
    jae .judge
    movss xmm0, [d_pos]
    movss xmm1, [d_pos + 4]
    movss xmm2, [d_pos + 8]
    movss xmm3, [f_far]
    movss xmm4, [f_dragon_r2]
    mov esi, 5
    call ray_ball
.judge:
    mov eax, [rsp + 28]
    test eax, eax
    js .none
    cmp eax, 5
    je .dragon
    ; a crystal breaks with a bang (and the dragon will perch sooner)
    bts dword [crystal_gone], eax
    push rax
    push rax
    call perch_delay
    minss xmm0, [d_perch_t]
    movss [d_perch_t], xmm0
    pop rax
    pop rax
    mov edi, eax
    call crystal_at
    movss [rsp + 32], xmm0
    movss [rsp + 36], xmm1
    movss [rsp + 40], xmm2
    SFX_AT S_EXPLODE, 110, 90
    lea rdi, [pos]
    movss xmm0, [rsp + 32]
    movss xmm1, [rsp + 36]
    movss xmm2, [rsp + 40]
    call dist2
    comiss xmm0, [f_blast2]
    ja .done
    mov edi, 6
    call player_damage
    jmp .done
.dragon:
    movss xmm0, [f_rifle]
    cmp dword [rsp + 44], 0
    jne .dmg
    call melee
.dmg:
    movss xmm1, [dragon_hp]
    subss xmm1, xmm0
    movss [dragon_hp], xmm1
    mov eax, [f_hurtt]
    mov [d_hurt], eax
    movss xmm0, [d_pos]
    movss xmm1, [d_pos + 4]
    movss xmm2, [d_pos + 8]
    SFX_AT S_HIT, 120, 60
    movss xmm0, [dragon_hp]
    comiss xmm0, [f_zero]
    ja .done
    mov dword [dragon_hp], 0
    mov dword [d_state], ST_DYING
    mov eax, [f_dying]
    mov [d_t], eax
.done:
    mov eax, 1
    LEAVE_FN
.none:
    xor eax, eax
    LEAVE_FN
.no:
    xor eax, eax
    ret

; ray_ball(xmm0..2 centre, xmm3 reach, xmm4 radius squared, esi what) -
; inside dragon_attack: the view ray passes within the radius nearer than
; the best so far: take it ([rsp + 8 ...] is dragon_attack's frame)
ray_ball:
    lea rax, [rsp + 8]
    subss xmm0, [rax]
    subss xmm1, [rax + 4]
    subss xmm2, [rax + 8]
    movaps xmm5, xmm0
    mulss xmm5, [rax + 12]
    movaps xmm6, xmm1
    mulss xmm6, [rax + 16]
    addss xmm5, xmm6
    movaps xmm6, xmm2
    mulss xmm6, [rax + 20]
    addss xmm5, xmm6                ; t along the ray
    comiss xmm5, [f_zero]
    jbe .out
    comiss xmm5, xmm3
    ja .out
    comiss xmm5, [rax + 24]
    jae .out
    mulss xmm0, xmm0
    mulss xmm1, xmm1
    mulss xmm2, xmm2
    addss xmm0, xmm1
    addss xmm0, xmm2
    movaps xmm6, xmm5
    mulss xmm6, xmm6
    subss xmm0, xmm6                ; its distance from the ray, squared
    comiss xmm0, xmm4
    ja .out
    movss [rax + 24], xmm5
    mov [rax + 28], esi
.out:
    ret

; xmm0 = the damage of the held item, as on a mob: sword 3 + tier, axe
; 2 + tier, pickaxe 1 + tier, shovel the tier, else 1; a beacon's strength
; 40% more
melee:
    sub rsp, 8
    mov eax, [sel_slot]
    lea rcx, [inv]
    movzx edi, byte [rcx + rax*4]
    call tool_of                    ; ecx kind, eax tier
    mov edx, 1
    cmp ecx, 4
    jne .d1
    lea edx, [rax + 3]
.d1:
    cmp ecx, 2
    jne .d2
    lea edx, [rax + 2]
.d2:
    cmp ecx, 1
    jne .d3
    lea edx, [rax + 1]
.d3:
    cmp ecx, 3
    jne .d4
    mov edx, eax
.d4:
    cvtsi2ss xmm0, edx
    movss xmm1, [eff_time + 4]
    comiss xmm1, [f_zero]
    jbe .out
    mulss xmm0, [f_strength]
.out:
    add rsp, 8
    ret

; void dragon_draw(void) - in node units round the player's chunk (as the
; boats): the crystals, their beam, the dragon
dragon_draw:
    cmp dword [dimension], 2
    jne .ret
    ENTER_FN 32
    mov edi, GL_CULL_FACE
    call glDisable PLT
    mov edi, GL_TEXTURE_2D
    call glDisable PLT
    mov edi, GL_ALPHA_TEST
    call glDisable PLT
    xor ebx, ebx
.c:
    bt dword [crystal_gone], ebx
    jc .cn
    call glPushMatrix PLT
    mov edi, ebx
    call crystal_at
    call to_view
    call glTranslatef PLT
    movss xmm0, [d_spin]
    xorps xmm1, xmm1
    movss xmm2, [f_one]
    xorps xmm3, xmm3
    call glRotatef PLT
    movss xmm0, [f_eighth]
    movaps xmm1, xmm0
    movaps xmm2, xmm0
    call glScalef PLT
    lea rdi, [m_frame]
    mov esi, M_FRAME_N
    call fig_parts
    movss xmm0, [d_spin]
    addss xmm0, xmm0
    movss xmm1, [f_one]
    movss xmm2, [f_one]
    xorps xmm3, xmm3
    call glRotatef PLT
    lea rdi, [m_core]
    mov esi, M_CORE_N
    call fig_parts
    call glPopMatrix PLT
.cn:
    inc ebx
    cmp ebx, END_PILLARS
    jb .c
    cmp dword [d_state], ST_GONE
    je .done
    ; the healing beams
    movss xmm0, [f_beam]
    call glLineWidth PLT
    mov edi, GL_LINES
    call glBegin PLT
    mov dword [rsp + 16], 0x3ecccccd        ; 0.4
    movss xmm0, [rsp + 16]
    movss xmm1, [f_one]
    movss xmm2, [rsp + 16]
    movss xmm3, [f_one]
    call glColor4f PLT
    xor r12d, r12d
.beam:
    lea rax, [d_heal]
    mov edi, [rax + r12*4]
    test edi, edi
    js .bn
    call crystal_at
    call to_view
    call glVertex3f PLT
    movss xmm0, [d_pos]
    movss xmm1, [d_pos + 4]
    movss xmm2, [d_pos + 8]
    call to_view
    call glVertex3f PLT
.bn:
    inc r12d
    cmp r12d, 5
    jb .beam
    call glEnd PLT
    movss xmm0, [f_one]
    call glLineWidth PLT
    movss xmm0, [f_one]
    movaps xmm1, xmm0
    movaps xmm2, xmm0
    movaps xmm3, xmm0
    call glColor4f PLT
.nobeam:
    ; the dragon: red while hurt
    mov eax, 256
    mov ecx, 256
    movss xmm0, [d_hurt]
    comiss xmm0, [f_zero]
    jbe .tint
    mov ecx, 90
.tint:
    mov [fig_tint], eax
    mov [fig_tint + 4], ecx
    mov [fig_tint + 8], ecx
    call glPushMatrix PLT
    movss xmm0, [d_pos]
    movss xmm1, [d_pos + 4]
    movss xmm2, [d_pos + 8]
    call to_view
    call glTranslatef PLT
    movss xmm0, [d_yaw]
    xorps xmm1, xmm1
    movss xmm2, [f_one]
    xorps xmm3, xmm3
    call glRotatef PLT
    movss xmm0, [d_pitch]
    movss xmm1, [f_one]
    xorps xmm2, xmm2
    xorps xmm3, xmm3
    call glRotatef PLT
    movss xmm0, [f_eighth]
    movaps xmm1, xmm0
    movaps xmm2, xmm0
    call glScalef PLT
    lea rdi, [m_body]
    mov esi, M_BODY_N
    call fig_parts
    ; the wings: beating in flight, swept back in a swoop, folded sitting
    call wing_angle
    movss [rsp + 12], xmm0
    xor r12d, r12d
.w:
    call glPushMatrix PLT
    mov eax, 6
    test r12d, r12d
    jz .wr
    neg eax
.wr:
    cvtsi2ss xmm0, eax
    mov eax, 4
    cvtsi2ss xmm1, eax
    cvtsi2ss xmm2, eax
    call glTranslatef PLT
    test r12d, r12d
    jz .wm
    mov eax, -1
    cvtsi2ss xmm0, eax
    movss xmm1, [f_one]
    movss xmm2, [f_one]
    call glScalef PLT               ; the left one: mirrored
.wm:
    movss xmm0, [rsp + 12]
    xorps xmm1, xmm1
    xorps xmm2, xmm2
    movss xmm3, [f_one]
    call glRotatef PLT
    lea rdi, [m_wing]
    mov esi, M_WING_N
    call fig_parts
    call glPopMatrix PLT
    inc r12d
    cmp r12d, 2
    jb .w
    call glPopMatrix PLT
    mov dword [fig_tint], 256
    mov dword [fig_tint + 4], 256
    mov dword [fig_tint + 8], 256
.done:
    mov edi, GL_CULL_FACE
    call glEnable PLT
    LEAVE_FN
.ret:
    ret

; xmm0 = the wings' angle (degrees, up from level)
wing_angle:
    sub rsp, 8
    movss xmm0, [f_folded]
    cmp dword [d_state], ST_PERCH
    je .out
    movss xmm0, [f_swept]
    cmp dword [d_state], ST_SWOOP
    je .out
    fld dword [d_flap]
    fsin
    fstp dword [rsp]
    movss xmm0, [rsp]
    mulss xmm0, [f_flapdeg]
.out:
    add rsp, 8
    ret

; xmm0..2 world -> round the player's chunk
to_view:
    mov eax, [cur_pcx]
    shl eax, 4
    cvtsi2ss xmm3, eax
    subss xmm0, xmm3
    mov eax, [cur_pcz]
    shl eax, 4
    cvtsi2ss xmm3, eax
    subss xmm2, xmm3
    ret

; void dragon_hud(void) - on the island while it lives: its name and its
; health along the top
dragon_hud:
    cmp dword [dimension], 2
    jne .ret
    cmp dword [d_state], ST_GONE
    je .ret
    ENTER_FN 16
    movss xmm0, [f_name_y]
    movss xmm1, [f_scale2]
    lea rdi, [s_dragon]
    mov esi, 0xffffffff
    call hud_text_center
    cvtsi2ss xmm0, dword [win_w]
    subss xmm0, [f_bar_w]
    mulss xmm0, [f_half]
    movss [rsp], xmm0
    movaps xmm2, xmm0
    addss xmm2, [f_bar_w]
    movss xmm1, [f_bar_y0]
    movss xmm3, [f_bar_y1]
    mov edi, 0xc0101010
    call hud_rect
    movss xmm0, [dragon_hp]
    divss xmm0, [d_max]
    maxss xmm0, [f_zero]
    mulss xmm0, [f_bar_w]
    addss xmm0, [rsp]
    movaps xmm2, xmm0
    movss xmm0, [rsp]
    movss xmm1, [f_bar_y0]
    movss xmm3, [f_bar_y1]
    mov edi, 0xff40c850             ; green
    call hud_rect
    ; after it was brought back: which try this is ("2ND TRY")
    mov eax, [dragon_rounds]
    test eax, eax
    jz .out
    inc eax
    call try_text
    movss xmm0, [f_try_y]
    movss xmm1, [f_scale2]
    lea rdi, [try_buf]
    mov esi, 0xffc8e8c8
    call hud_text_center
.out:
    LEAVE_FN
.ret:
    ret

; try_text(eax n) - try_buf = "<n>ST TRY" (ND, RD, TH as English has it)
try_text:
    mov r8d, eax
    lea rdi, [try_buf + 15]
    mov byte [rdi], 0
    mov ecx, 10
.d:
    xor edx, edx
    div ecx
    add dl, '0'
    dec rdi
    mov [rdi], dl
    test eax, eax
    jnz .d
    lea rsi, [try_buf]
.cp:                                ; to the front
    mov al, [rdi]
    mov [rsi], al
    inc rdi
    inc rsi
    test al, al
    jnz .cp
    dec rsi
    mov eax, r8d                    ; the suffix
    xor edx, edx
    mov ecx, 100
    div ecx
    mov eax, edx
    lea rcx, [s_th]
    cmp eax, 11
    jb .u
    cmp eax, 13
    jbe .put
.u:
    xor edx, edx
    mov r9d, 10
    div r9d
    cmp edx, 1
    jne .n2
    lea rcx, [s_st]
.n2:
    cmp edx, 2
    jne .n3
    lea rcx, [s_nd]
.n3:
    cmp edx, 3
    jne .put
    lea rcx, [s_rd]
.put:
    mov al, [rcx]
    mov [rsi], al
    inc rcx
    inc rsi
    test al, al
    jnz .put
    ret

NOEXECSTACK
