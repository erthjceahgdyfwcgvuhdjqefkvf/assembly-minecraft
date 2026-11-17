%include "common.inc"

global pos, vel, yaw, pitch, syaw, cyaw, on_ground, flying, eye_water
global game_mode, hp, breath, sel_slot, target_hit, spawn_pos
global target, dig_stage, player_dead, hurt_flash, spawn_guard
global player_new, player_spawn, update_look, update_player, update_target
global update_digging, update_survival, player_use, drop_selected, player_hurt
global toggle_fly, select_slot, sprinting, wall_hit, knock_x, knock_z, spawn_bed
global player_damage, throw_item, drop_block, pop_above, crouching, eye_h
global body_water, body_lava, player_set_mode

extern keys, dt, acc_x, acc_y, grabbed, lmb_down, warp_center, set_mouse
extern world_get, world_set, world_raycast, block_flags
extern inv, inv_clear, dig_time, can_harvest, block_drop, tool_wear
extern ent_spawn, ent_drop_all, furnace_add, furnace_find, furnace_remove
extern item_valid, invui_open, cur_furnace
extern bind_fwd, bind_back, bind_left, bind_right, bind_jump, bind_down
extern bind_sprint
extern mob_attack, food_heal, mob_spawn, game_rand, mob_feed
extern world_time, sunlight, mobs, mob_count, hud_message
extern armor, armor_piece, armor_wear, riding, boat_use, boat_place, boat_attack
extern bucket_use, flint_use, portal_break, dimension, rifle_fire
extern sound_keep, sound_block, sound_step, hand_swing, fx_burst
extern wire_click, wire_use_item, door_drop, dig_alias, node_boxes
extern eff_time, beacon_open, portal_item, dragon_attack

MODE_SURVIVAL   equ 0
MOB_TYPE_OFF    equ 0               ; mobs.asm record: type, x at 4, z at 12
MOB_RECORD      equ 96
MODE_CREATIVE   equ 1
MAX_HP          equ 20
MAX_BREATH      equ 10
STACK_MAX       equ 99

section .data
align 4
pos:        dd 8.5, 80.0, 8.5
vel:        dd 0.0, 0.0, 0.0
lo_off:     dd -0.3, 0.0, -0.3
hi_off:     dd 0.3, 1.7, 0.3
hp:         dd MAX_HP
breath:     dd MAX_BREATH
dig_stage:  dd -1
sel_slot:   dd 0
w_tap_t:    dd 9.0                  ; seconds since W was last pressed
eye_h:      dd 1.6                  ; the eyes above the feet (lower crouching)

section .rodata
align 16
f_absmask:  dd 0x7fffffff, 0, 0, 0
f_zero:     dd 0.0
f_one:      dd 1.0
f_half:     dd 0.5
f_five:     dd 5.0
f_eye:      dd 1.6
f_sens:     dd 0.0006               ; per mouse-speed step
f_pitchmax: dd 1.55
f_pitchmin: dd -1.55
f_pi:       dd 3.14159265
f_2pi:      dd 6.28318531
f_grav:     dd 26.0
f_wgrav:    dd 10.0
f_maxfall:  dd -55.0
f_wmaxfall: dd -3.0
f_jump:     dd 8.4
f_swim:     dd 4.0
f_wclimb:   dd 6.5
f_walk:     dd 4.3
f_speedfx:  dd 1.3                  ; a beacon's speed
f_crouch:   dd 0.2                  ; crouching: a fifth of the walking speed
f_ledge:    dd 0.6                  ; crouching: no stepping off a drop deeper
f_eyecr:    dd 1.3                  ; eye height crouching
f_eyerate:  dd 12.0
f_sprint:   dd 6.5
f_fly:      dd 12.0
f_flyfast:  dd 30.0
f_wslow:    dd 0.6
f_kfade:    dd 5.0                  ; knockback fades at this rate
f_atkcool:  dd 0.5                  ; seconds between hits while held
f_dusk:     dd 0.45                 ; darker than this: time to sleep
f_day_len:  dd 1200.0
f_monster2: dd 64.0                 ; no sleeping with a zombie within 8 nodes
bed_dirs:   db 1,0, -1,0, 0,1, 0,-1
s_daysleep: db "YOU CAN ONLY SLEEP AT NIGHT", 0
s_nethersleep: db "YOU CAN'T SLEEP IN THE NETHER", 0
s_monsters: db "YOU MAY NOT REST NOW, MONSTERS ARE NEARBY", 0
s_morning:  db "GOOD MORNING - YOU WILL RESPAWN AT THIS BED", 0
f_dtap:     dd 0.3                  ; seconds between W taps to sprint
f_substep:  dd 0.4
f_eps:      dd 0.0001
f_step:     dd 0.55                 ; walking up onto a slab or stairs
f_eighth:   dd 0.125
f_big:      dd 1.0e9
f_skin:     dd 0.001
f_reach:    dd 5.0
f_neg100:   dd -100.0
f_safefall: dd 13.0                 ; landing speed that starts to hurt
f_falldmg:  dd 0.8                  ; damage per node/s above that
f_bounce:   dd -0.8                 ; slime block: speed kept going back up
f_bouncemin: dd -3.0                ; landing slower than this just stops
f_landsnd:  dd -5.5                 ; landing this fast is heard
f_landhard: dd -11.0                ; .. and this fast lands with a thump
f_under:    dd 0.2
wall_dirs:  db -1,0, 1,0, 0,-1, 0,1  ; x, z of the four blocks beside a node
f_digsnd:   dd 0.24                 ; seconds between digging taps
f_cdig:     dd 0.25                 ; creative dig repeat
f_tbreath:  dd 1.0
f_trefill:  dd 0.5
f_tregen:   dd 6.0
f_hurtflash: dd 0.35
f_burn:     dd 4.0                  ; seconds on fire after leaving lava
f_feet:     dd 0.1

f_throw:    dd 6.0
f_up:       dd 2.0
f_mid:      dd 0.5

section .bss
alignb 4
yaw:        resd 1
pitch:      resd 1
syaw:       resd 1
cyaw:       resd 1
on_ground:  resd 1
flying:     resd 1
eye_water:  resd 1
body_water: resd 1
body_lava:  resd 1
lava_t:     resd 1                  ; time in lava toward the next hurt
burn_t:     resd 1                  ; on fire: seconds left
wall_hit:   resd 1                  ; walked into a wall last frame
sprinting:  resd 1                  ; W double-tapped, until W is let go
crouching:  resd 1                  ; the sneak key held, on foot
w_prev:     resd 1
game_mode:  resd 1
player_dead: resd 1
spawn_guard: resd 1                 ; seconds no hit lands (just arrived on the island)
hurt_flash: resd 1
target_hit: resd 1
target:     resd 6
dig_pos:    resd 3
dig_progress: resd 1
dig_cool:   resd 1
dig_snd:    resd 1                  ; until the next digging tap
knock_x:    resd 1                  ; knockback (nodes/s), fading
knock_z:    resd 1
atk_cool:   resd 1                  ; until the next hit on a mob
atk_hold:   resd 1                  ; 1 = this click hit a mob: no digging
t_breath:   resd 1
t_regen:    resd 1
spawn_pos:  resd 3                  ; where this world's player (re)spawns
spawn_bed:  resd 1                  ; 1 = spawn_pos is a bed node (slept in)
col_limit:  resd 1                  ; collide: where the box may go on the axis
col_top:    resd 1                  ; the top of the highest box hit
col_cell:   resd 3                  ; a node hit
col_buf:    resb 16                 ; node_boxes' boxes

section .text

; FLOORF dst32, src xmm, tmp xmm - true floor
%macro FLOORF 3
    cvttss2si %1, %2
    cvtsi2ss %3, %1
    comiss %3, %2
    jbe %%ok
    dec %1
%%ok:
%endmacro

; int player_set_mode(int mode) - creative (1) or survival (0) from now on,
; from a clean start: not flying, nothing half dug, still, full health and
; breath, not on fire. 0 if it was that already.
player_set_mode:
    xor eax, eax
    cmp edi, 1
    ja .out                         ; nothing but 0 and 1
    cmp edi, [game_mode]
    je .out
    mov [game_mode], edi
    xor eax, eax
    mov [flying], eax
    mov [sprinting], eax
    mov [crouching], eax
    mov [vel], eax
    mov [vel + 4], eax
    mov [vel + 8], eax
    mov [knock_x], eax
    mov [knock_z], eax
    mov [dig_progress], eax
    mov [dig_cool], eax
    mov [dig_snd], eax
    mov [atk_hold], eax
    mov [burn_t], eax
    mov [lava_t], eax
    mov [hurt_flash], eax
    mov dword [dig_stage], -1
    mov dword [hp], MAX_HP
    mov dword [breath], MAX_BREATH
    mov eax, 1
.out:
    ret

; void player_new(int mode) - fresh inventory for a new world
player_new:
    sub rsp, 8
    mov [game_mode], edi
    mov dword [flying], 0
    mov dword [sel_slot], 0
    call inv_clear                  ; both modes start with nothing
    add rsp, 8
    ret

; void player_spawn(void) - stand on the highest solid node at the spawn
; column (spawn_pos x, z)
player_spawn:
    ENTER_FN 0
    mov dword [riding], 0
    mov dword [burn_t], 0
    ; slept in a bed that is still there: on top of it
    cmp dword [spawn_bed], 0
    je .column
    mov edi, [spawn_pos]
    mov esi, [spawn_pos + 4]
    mov edx, [spawn_pos + 8]
    call world_get
    cmp eax, B_BED_FOOT
    je .bed
    cmp eax, B_BED_HEAD
    je .bed
    mov dword [spawn_bed], 0        ; the bed is gone
.column:
    mov ebx, 191
.s:
    mov edi, [spawn_pos]
    mov esi, ebx
    mov edx, [spawn_pos + 8]
    call world_get
    cmp eax, B_UNKNOWN
    je .next
    lea rcx, [block_flags]
    test byte [rcx + rax], F_SOLID
    jnz .found
.next:
    dec ebx
    cmp ebx, WORLD_YMIN
    jg .s
.found:
    inc ebx
    cvtsi2ss xmm0, ebx
    jmp .place
.bed:
    cvtsi2ss xmm0, dword [spawn_pos + 4]
    addss xmm0, [f_half]            ; a bed is half a node tall
.place:
    movss [pos + 4], xmm0
    cvtsi2ss xmm0, dword [spawn_pos]
    addss xmm0, [f_mid]
    movss [pos], xmm0
    cvtsi2ss xmm0, dword [spawn_pos + 8]
    addss xmm0, [f_mid]
    movss [pos + 8], xmm0
    xor eax, eax
    mov [vel], eax
    mov [vel + 4], eax
    mov [vel + 8], eax
    mov dword [hp], MAX_HP
    mov dword [breath], MAX_BREATH
    mov [player_dead], eax
    mov [hurt_flash], eax
    mov [dig_progress], eax
    mov dword [dig_stage], -1
    LEAVE_FN

; void player_hurt(int damage)
player_hurt:
    cmp dword [game_mode], MODE_SURVIVAL
    jne .out
    test edi, edi
    jle .out
    sub [hp], edi
    SFX S_HURT, 100, 100
    mov eax, [f_hurtflash]
    mov [hurt_flash], eax
    cmp dword [hp], 0
    jg .out
    mov dword [hp], 0
    cmp dword [player_dead], 0
    jne .out
    mov dword [player_dead], 1
    mov dword [riding], 0           ; out of any boat
    sub rsp, 8
    call ent_drop_all
    add rsp, 8
.out:
    ret

; void player_damage(int damage) - a hit armour helps against (mobs,
; falling): less of it gets through and the armour wears
player_damage:
    cmp dword [game_mode], MODE_SURVIVAL
    jne .out
    movss xmm0, [spawn_guard]       ; just arrived: nothing hurts yet
    comiss xmm0, [f_zero]
    ja .out
    test edi, edi
    jle .out
    sub rsp, 8
    call armor_wear
    add rsp, 8
    mov edi, eax
    test edi, edi
    jnz player_hurt
    mov eax, [f_hurtflash]          ; all of it stopped: still a flash
    mov [hurt_flash], eax
.out:
    ret

; void toggle_fly(void) - creative only
toggle_fly:
    cmp dword [game_mode], MODE_CREATIVE
    jne .out
    xor dword [flying], 1
    mov dword [vel + 4], 0
.out:
    ret

; void select_slot(int slot)
select_slot:
    mov [sel_slot], edi
    mov dword [dig_progress], 0
    ret

update_look:
    ENTER_FN 0
    cmp dword [grabbed], 0
    je .out
    mov eax, [acc_x]
    or eax, [acc_y]
    jz .out
    cvtsi2ss xmm7, dword [set_mouse]
    mulss xmm7, [f_sens]
    cvtsi2ss xmm0, dword [acc_x]
    mulss xmm0, xmm7
    addss xmm0, [yaw]
    comiss xmm0, [f_pi]
    jbe .y1
    subss xmm0, [f_2pi]
.y1:
    movss xmm1, [f_pi]
    xorps xmm2, xmm2
    subss xmm2, xmm1
    comiss xmm0, xmm2
    jae .y2
    addss xmm0, [f_2pi]
.y2:
    movss [yaw], xmm0
    cvtsi2ss xmm0, dword [acc_y]
    mulss xmm0, xmm7
    addss xmm0, [pitch]
    minss xmm0, [f_pitchmax]
    maxss xmm0, [f_pitchmin]
    movss [pitch], xmm0
    mov dword [acc_x], 0
    mov dword [acc_y], 0
    call warp_center
.out:
    LEAVE_FN

; eax = block at float position (xmm0, xmm1, xmm2)
block_at:
    sub rsp, 8
    FLOORF edi, xmm0, xmm3
    FLOORF esi, xmm1, xmm3
    FLOORF edx, xmm2, xmm3
    call world_get
    add rsp, 8
    ret

; collide(edi axis, esi sign: 1 moving +, -1 moving -, 0 only looking) -
; the player's box at pos against the shapes of the nodes round it
; (node_boxes): eax 1 if it is inside one; col_limit how far it may go on
; the axis, col_top the top of the highest box, col_cell a node hit
; locals: [0..23] cells (x0 x1 y0 y1 z0 z1), [24] cell x, y, z, [40] axis,
;         [44] sign, [48] box min x y z, [60] box max, [72] box, [76] boxes
collide:
    ENTER_FN 80
    mov [rsp + 40], edi
    mov [rsp + 44], esi
    mov dword [col_limit], 0x4e6e6b28   ; 1e9
    test esi, esi
    jns .lim
    mov dword [col_limit], 0xce6e6b28   ; -1e9
.lim:
    mov dword [col_top], 0xce6e6b28
    xor ebx, ebx                    ; (hit)
    xor ecx, ecx
.range:
    lea rax, [pos]
    movss xmm0, [rax + rcx*4]
    movaps xmm1, xmm0
    lea rax, [lo_off]
    addss xmm0, [rax + rcx*4]
    lea rax, [hi_off]
    addss xmm1, [rax + rcx*4]
    subss xmm1, [f_eps]
    FLOORF eax, xmm0, xmm2
    mov [rsp + rcx*8], eax
    FLOORF eax, xmm1, xmm2
    mov [rsp + rcx*8 + 4], eax
    inc ecx
    cmp ecx, 3
    jb .range
    dec dword [rsp + 8]             ; a fence below reaches up
    mov r13d, [rsp + 8]
.ly:
    mov r14d, [rsp + 16]
.lz:
    mov r15d, [rsp]
.lx:
    mov [rsp + 24], r15d
    mov [rsp + 28], r13d
    mov [rsp + 32], r14d
    mov edi, r15d
    mov esi, r13d
    mov edx, r14d
    lea rcx, [col_buf]
    call node_boxes
    mov [rsp + 76], eax
    mov dword [rsp + 72], 0
.box:
    mov eax, [rsp + 72]
    cmp eax, [rsp + 76]
    jae .nx
    lea rax, [rax + rax*2]
    lea r12, [col_buf]
    lea r12, [r12 + rax*2]
    xor ecx, ecx
.ax:
    movzx eax, byte [r12 + rcx]
    cvtsi2ss xmm0, eax
    mulss xmm0, [f_eighth]
    cvtsi2ss xmm1, dword [rsp + 24 + rcx*4]
    addss xmm0, xmm1
    movss [rsp + 48 + rcx*4], xmm0  ; min
    movzx eax, byte [r12 + rcx + 3]
    cvtsi2ss xmm2, eax
    mulss xmm2, [f_eighth]
    addss xmm2, xmm1
    movss [rsp + 60 + rcx*4], xmm2  ; max
    ; overlap with the player's box?
    lea rax, [pos]
    movss xmm3, [rax + rcx*4]
    movaps xmm4, xmm3
    lea rax, [hi_off]
    addss xmm3, [rax + rcx*4]
    lea rax, [lo_off]
    addss xmm4, [rax + rcx*4]
    cmp ecx, [rsp + 40]
    je .exact                       ; along the move: any overlap counts
    subss xmm3, [f_eps]             ; across it: touching is not a hit
    addss xmm4, [f_eps]
    jmp .cmp
.exact:
    cmp ecx, 1
    jne .cmp
    cmp dword [rsp + 44], 0
    jge .cmp
    subss xmm4, [f_eps]             ; coming down: resting on it counts
.cmp:
    comiss xmm0, xmm3
    jae .bn
    comiss xmm2, xmm4
    jbe .bn
    inc ecx
    cmp ecx, 3
    jb .ax
    ; a hit
    mov ebx, 1
    mov eax, [rsp + 24]
    mov [col_cell], eax
    mov eax, [rsp + 28]
    mov [col_cell + 4], eax
    mov eax, [rsp + 32]
    mov [col_cell + 8], eax
    movss xmm0, [rsp + 64]
    maxss xmm0, [col_top]
    movss [col_top], xmm0
    mov ecx, [rsp + 40]
    cmp dword [rsp + 44], 0
    je .bn
    jl .neg
    movss xmm0, [rsp + 48 + rcx*4]  ; up to its near side
    lea rax, [hi_off]
    subss xmm0, [rax + rcx*4]
    subss xmm0, [f_skin]
    minss xmm0, [col_limit]
    movss [col_limit], xmm0
    jmp .bn
.neg:
    movss xmm0, [rsp + 60 + rcx*4]
    lea rax, [lo_off]
    subss xmm0, [rax + rcx*4]
    cmp ecx, 1
    je .negy                        ; standing on it: exactly on top
    addss xmm0, [f_skin]
.negy:
    maxss xmm0, [col_limit]
    movss [col_limit], xmm0
.bn:
    inc dword [rsp + 72]
    jmp .box
.nx:
    inc r15d
    cmp r15d, [rsp + 4]
    jle .lx
    inc r14d
    cmp r14d, [rsp + 20]
    jle .lz
    inc r13d
    cmp r13d, [rsp + 12]
    jle .ly
    mov eax, ebx
    LEAVE_FN

; move_axis(edi axis, xmm0 delta) - move, and stop against the shapes of
; the nodes (whole blocks, fences 1.5 high, beds, slabs, stairs). Walking
; into something no more than half a node high steps up onto it.
; locals: [0] delta, [4] y before a step
move_axis:
    ENTER_FN 16
    mov r12d, edi
    movss [rsp], xmm0
    lea rbx, [pos]
    movss xmm1, [rbx + r12*4]
    addss xmm1, xmm0
    movss [rbx + r12*4], xmm1
    ; crouching on the ground: not off the edge of a drop deeper than a slab
    cmp r12d, 1
    je .noedge
    cmp dword [crouching], 0
    je .noedge
    cmp dword [on_ground], 0
    je .noedge
    mov eax, [pos + 4]
    mov [rsp + 4], eax
    movss xmm0, [pos + 4]
    subss xmm0, [f_ledge]
    movss [pos + 4], xmm0
    mov edi, 1
    xor esi, esi
    call collide                    ; anything under the feet there?
    mov ecx, [rsp + 4]
    mov [pos + 4], ecx
    test eax, eax
    jnz .noedge
    lea rbx, [pos]
    movss xmm1, [rbx + r12*4]
    subss xmm1, [rsp]
    movss [rbx + r12*4], xmm1
    lea rax, [vel]
    mov dword [rax + r12*4], 0
    LEAVE_FN
.noedge:
    mov edi, r12d
    call .sign
    call collide
    test eax, eax
    jz .free
    ; a step up?
    cmp r12d, 1
    je .blocked
    cmp dword [on_ground], 0
    je .blocked
    movss xmm0, [col_top]
    subss xmm0, [pos + 4]
    comiss xmm0, [f_zero]
    jbe .blocked
    comiss xmm0, [f_step]
    ja .blocked
    mov eax, [pos + 4]
    mov [rsp + 4], eax
    mov eax, [col_top]
    mov [pos + 4], eax
    mov edi, 1
    xor esi, esi
    call collide
    test eax, eax
    jz .free                        ; room up there: it stepped
    mov eax, [rsp + 4]
    mov [pos + 4], eax
    mov edi, r12d
    call .sign
    call collide
.blocked:
    mov r15d, [col_cell]
    mov r13d, [col_cell + 4]
    mov r14d, [col_cell + 8]
    lea rbx, [pos]
    movss xmm1, [col_limit]
    movss xmm0, [rsp]
    comiss xmm0, [f_zero]
    ja .stop_at
    cmp r12d, 1
    je .floor
.stop_at:
    movss [rbx + r12*4], xmm1
    jmp .stop
.free:
    LEAVE_FN
.sign:                              ; esi = the sign of the delta
    mov esi, 1
    movss xmm0, [rsp + 8]
    comiss xmm0, [f_zero]
    ja .sg
    mov esi, -1
.sg:
    ret
.floor:
    movss [rbx + 4], xmm1
    mov dword [on_ground], 1
    ; a slime block throws the player back up (and takes the fall)
    mov edi, r15d
    mov esi, r13d
    mov edx, r14d
    call world_get
    cmp eax, B_SLIME
    jne .hard
    cmp dword [flying], 0
    jne .stop
    movss xmm0, [vel + 4]
    comiss xmm0, [f_bouncemin]
    jae .stop                       ; too slow: just land
    mulss xmm0, [f_bounce]
    movss [vel + 4], xmm0
    SFX S_BLOP, 90, 80
    jmp .stopped
.hard:
    ; fall damage from the landing speed
    cmp dword [flying], 0
    jne .stop
    ; coming down from a jump or a drop is heard: a thud on what is there
    movss xmm0, [vel + 4]
    comiss xmm0, [f_landsnd]
    ja .soft
    mov edi, eax
    mov esi, 2
    movss xmm0, [pos]
    movss xmm1, [pos + 4]
    movss xmm2, [pos + 8]
    call sound_block
    movss xmm0, [vel + 4]
    comiss xmm0, [f_landhard]
    ja .soft
    SFX S_LAND, 90, 100
.soft:
    movss xmm0, [vel + 4]
    xorps xmm1, xmm1
    subss xmm1, xmm0
    subss xmm1, [f_safefall]
    comiss xmm1, [f_zero]
    jbe .stop
    mulss xmm1, [f_falldmg]
    cvttss2si edi, xmm1
    call player_damage
.stop:
    lea rax, [vel]
    mov dword [rax + r12*4], 0
    cmp r12d, 1
    je .stopped
    mov dword [wall_hit], 1
.stopped:
    LEAVE_FN

; locals: [0] wish x, [4] wish z, [8] speed, [12] substep dt
update_player:
    ENTER_FN 32
    fld dword [yaw]
    fsincos
    fstp dword [cyaw]
    fstp dword [syaw]
    ; the eyes go down a little crouching, up again standing
    movss xmm0, [f_eye]
    cmp dword [crouching], 0
    je .eyeto
    movss xmm0, [f_eyecr]
.eyeto:
    subss xmm0, [eye_h]
    movss xmm1, [dt]
    mulss xmm1, [f_eyerate]
    minss xmm1, [f_one]
    mulss xmm0, xmm1
    addss xmm0, [eye_h]
    movss [eye_h], xmm0
    ; in a boat: the boat moves the player (boat.asm)
    cmp dword [riding], 0
    je .afoot
    xor eax, eax
    mov [vel], eax
    mov [vel + 4], eax
    mov [vel + 8], eax
    mov [eye_water], eax
    mov [body_water], eax
    mov [flying], eax
    mov [crouching], eax
    mov dword [on_ground], 1
    jmp .out
.afoot:
    lea rbx, [keys]
; KEY reg32, reg64, binding: reg = 1 while the bound key is held
%macro KEY 3
    mov %1, [%3]
    movzx %1, byte [rbx + %2]
%endmacro
    KEY eax, rax, bind_fwd
    KEY ecx, rcx, bind_back
    sub eax, ecx
    cvtsi2ss xmm0, eax              ; forward
    KEY eax, rax, bind_right
    KEY ecx, rcx, bind_left
    sub eax, ecx
    cvtsi2ss xmm1, eax              ; right
    movss xmm2, [syaw]
    mulss xmm2, xmm0
    movss xmm3, [cyaw]
    mulss xmm3, xmm1
    addss xmm2, xmm3                ; wx = s*f + c*r
    movss xmm3, [syaw]
    mulss xmm3, xmm1
    movss xmm4, [cyaw]
    mulss xmm4, xmm0
    subss xmm3, xmm4                ; wz = s*r - c*f
    movaps xmm4, xmm2
    mulss xmm4, xmm4
    movaps xmm5, xmm3
    mulss xmm5, xmm3
    addss xmm4, xmm5
    sqrtss xmm4, xmm4
    comiss xmm4, [f_zero]
    jbe .nonorm
    divss xmm2, xmm4
    divss xmm3, xmm4
.nonorm:
    movss [rsp], xmm2
    movss [rsp + 4], xmm3
    movss xmm0, [pos]
    movss xmm1, [pos + 4]
    addss xmm1, [f_half]
    movss xmm2, [pos + 8]
    call block_at
    xor r12d, r12d
    lea rcx, [block_flags]
    test byte [rcx + rax], F_LIQUID
    setnz r12b                      ; r12 = body in water
    cmp r12d, [body_water]
    jbe .nosplash
    cmp dword [vel + 4], 0xC0000000 ; going in, falling at 2 nodes/s or more
    jb .nosplash
    SFX S_SPLASH, 90, 100
.nosplash:
    mov [body_water], r12d
    ; lava at the body or round the feet
    lea ecx, [rax - B_LAVA]
    cmp ecx, B_LFLOW3 - B_LAVA
    setbe cl
    movzx ecx, cl
    cmp eax, B_FIRE
    jne .bodyset
    mov ecx, 2                      ; standing in fire
.bodyset:
    mov [body_lava], ecx
    movss xmm0, [pos]
    movss xmm1, [pos + 4]
    addss xmm1, [f_feet]
    movss xmm2, [pos + 8]
    call block_at
    cmp eax, B_FIRE
    jne .feetlava
    cmp dword [body_lava], 0
    jne .nolavafeet
    mov dword [body_lava], 2
    jmp .nolavafeet
.feetlava:
    lea ecx, [rax - B_LAVA]
    cmp ecx, B_LFLOW3 - B_LAVA
    ja .nolavafeet
    mov dword [body_lava], 1
.nolavafeet:
    movss xmm0, [pos]
    movss xmm1, [pos + 4]
    addss xmm1, [f_eye]
    movss xmm2, [pos + 8]
    call block_at
    xor ecx, ecx
    lea rdx, [block_flags]
    test byte [rdx + rax], F_LIQUID
    setnz cl
    lea edx, [rax - B_LAVA]
    cmp edx, B_LFLOW3 - B_LAVA
    ja .eyeset
    mov ecx, 2                      ; the eyes in lava
.eyeset:
    mov [eye_water], ecx

    lea rbx, [keys]
    ; double-tap forward: sprint until it is released
    movss xmm0, [w_tap_t]
    addss xmm0, [dt]
    KEY eax, rax, bind_fwd
    test eax, eax
    jnz .w_down
    mov dword [sprinting], 0
    jmp .w_tapped
.w_down:
    cmp dword [w_prev], 0
    jne .w_tapped
    comiss xmm0, [f_dtap]
    jae .w_first
    mov dword [sprinting], 1
.w_first:
    xorps xmm0, xmm0
.w_tapped:
    movss [w_tap_t], xmm0
    mov [w_prev], eax
    mov ecx, [bind_sprint]
    mov eax, [sprinting]
    or al, [rbx + rcx]
    mov r13d, eax                   ; r13 = sprint (Ctrl or double-tap)
    ; only creative flies
    cmp dword [game_mode], MODE_CREATIVE
    je .canfly
    mov dword [flying], 0
.canfly:
    mov dword [crouching], 0
    cmp dword [flying], 0
    je .walk
    movss xmm0, [f_fly]
    test r13d, r13d
    jz .f1
    movss xmm0, [f_flyfast]
.f1:
    movss [rsp + 8], xmm0
    KEY eax, rax, bind_jump
    KEY ecx, rcx, bind_down
    sub eax, ecx
    cvtsi2ss xmm1, eax
    mulss xmm1, xmm0
    movss [vel + 4], xmm1
    jmp .horiz
.walk:
    ; crouching: the sneak key, out of the water; slow, and no sprinting
    KEY eax, rax, bind_down
    test r12d, r12d
    jz .cr
    xor eax, eax
.cr:
    mov [crouching], eax
    movss xmm0, [f_walk]
    test eax, eax
    jz .notcr
    mulss xmm0, [f_crouch]
    jmp .w1
.notcr:
    test r13d, r13d
    jz .w1
    movss xmm0, [f_sprint]
.w1:
    ; a beacon's speed: 30% faster
    movss xmm1, [eff_time + 8]
    comiss xmm1, [f_zero]
    jbe .nospeed
    mulss xmm0, [f_speedfx]
.nospeed:
    test r12d, r12d
    jz .w2
    mulss xmm0, [f_wslow]
.w2:
    movss [rsp + 8], xmm0
    movss xmm1, [vel + 4]
    movss xmm2, [dt]
    test r12d, r12d
    jz .air
    mulss xmm2, [f_wgrav]
    subss xmm1, xmm2
    maxss xmm1, [f_wmaxfall]
    mov ecx, [bind_jump]
    cmp byte [rbx + rcx], 0
    je .vy
    movss xmm1, [f_swim]
    ; at the surface against a bank: climb out (a stronger kick, like
    ; Minecraft's, enough to lift the feet over a block at water level)
    cmp dword [wall_hit], 0
    je .vy
    cmp dword [eye_water], 0
    jne .vy
    movss xmm1, [f_wclimb]
    jmp .vy
.air:
    mulss xmm2, [f_grav]
    subss xmm1, xmm2
    maxss xmm1, [f_maxfall]
    mov ecx, [bind_jump]
    cmp byte [rbx + rcx], 0
    je .vy
    cmp dword [on_ground], 0
    je .vy
    movss xmm1, [f_jump]
.vy:
    movss [vel + 4], xmm1
.horiz:
    ; knockback from a hit adds on, fading out
    movss xmm1, [f_one]
    movss xmm2, [f_kfade]
    mulss xmm2, [dt]
    subss xmm1, xmm2
    maxss xmm1, [f_zero]
    movss xmm2, [knock_x]
    mulss xmm2, xmm1
    movss [knock_x], xmm2
    movss xmm2, [knock_z]
    mulss xmm2, xmm1
    movss [knock_z], xmm2
    movss xmm0, [rsp]
    mulss xmm0, [rsp + 8]
    addss xmm0, [knock_x]
    movss [vel], xmm0
    movss xmm0, [rsp + 4]
    mulss xmm0, [rsp + 8]
    addss xmm0, [knock_z]
    movss [vel + 8], xmm0
    mov dword [on_ground], 0
    mov dword [wall_hit], 0         ; set again by move_axis on a wall

    ; substeps so nothing moves more than 0.4 nodes per step
    movss xmm0, [vel]
    andps xmm0, [f_absmask]
    movss xmm1, [vel + 4]
    andps xmm1, [f_absmask]
    maxss xmm0, xmm1
    movss xmm1, [vel + 8]
    andps xmm1, [f_absmask]
    maxss xmm0, xmm1
    mulss xmm0, [dt]
    divss xmm0, [f_substep]
    cvttss2si eax, xmm0
    inc eax
    cvtsi2ss xmm1, eax
    movss xmm0, [dt]
    divss xmm0, xmm1
    movss [rsp + 12], xmm0
    mov r13d, eax
.sub:
    mov edi, 1
    movss xmm0, [vel + 4]
    mulss xmm0, [rsp + 12]
    call move_axis
    xor edi, edi
    movss xmm0, [vel]
    mulss xmm0, [rsp + 12]
    call move_axis
    mov edi, 2
    movss xmm0, [vel + 8]
    mulss xmm0, [rsp + 12]
    call move_axis
    dec r13d
    jnz .sub

    ; steps: walking on the ground is heard, by what it is
    cmp dword [on_ground], 0
    je .nostep
    cmp dword [wall_hit], 0
    jne .nostep
    cmp dword [body_water], 0
    jne .nostep
    movss xmm0, [pos]
    movss xmm1, [pos + 4]
    subss xmm1, [f_under]
    movss xmm2, [pos + 8]
    call block_at
    mov edi, eax
    movss xmm0, [vel]
    mulss xmm0, xmm0
    movss xmm1, [vel + 8]
    mulss xmm1, xmm1
    addss xmm0, xmm1
    sqrtss xmm0, xmm0
    mulss xmm0, [dt]
    call sound_step
.nostep:

    ; fell out of the world
    movss xmm0, [pos + 4]
    comiss xmm0, [f_neg100]
    jae .out
    mov edi, MAX_HP
    call player_hurt
    cmp dword [game_mode], MODE_CREATIVE
    jne .out
    call player_spawn
.out:
    LEAVE_FN

; void update_survival(void) - breath, drowning, regeneration
update_survival:
    ENTER_FN 0
    movss xmm0, [hurt_flash]
    subss xmm0, [dt]
    maxss xmm0, [f_zero]
    movss [hurt_flash], xmm0
    movss xmm0, [spawn_guard]
    subss xmm0, [dt]
    maxss xmm0, [f_zero]
    movss [spawn_guard], xmm0
    cmp dword [game_mode], MODE_SURVIVAL
    jne .out
    ; lava: 4 damage every half second, and on fire for 4 s after
    cmp dword [body_lava], 0
    je .nolava
    mov eax, [f_burn]
    mov [burn_t], eax
    movss xmm0, [lava_t]
    addss xmm0, [dt]
    movss [lava_t], xmm0
    comiss xmm0, [f_half]
    jb .breath
    subss xmm0, [f_half]
    movss [lava_t], xmm0
    mov edi, 4                      ; lava 2 hearts, fire half a heart
    cmp dword [body_lava], 2
    jne .lavahit
    mov edi, 1
.lavahit:
    call player_damage
    jmp .breath
.nolava:
    mov eax, [f_half]               ; stepping in hurts at once
    mov [lava_t], eax
    cmp dword [body_water], 0
    je .burning
    mov dword [burn_t], 0           ; water puts the fire out
.burning:
    movss xmm1, [burn_t]
    comiss xmm1, [f_zero]
    jbe .breath
    movaps xmm0, xmm1
    subss xmm0, [dt]
    movss [burn_t], xmm0
    cvttss2si eax, xmm1
    cvttss2si ecx, xmm0
    cmp eax, ecx
    je .breath
    mov edi, 1                      ; 1 a second while burning
    call player_hurt
.breath:
    movss xmm0, [t_breath]
    addss xmm0, [dt]
    movss [t_breath], xmm0
    cmp dword [eye_water], 1        ; only water takes the breath
    jne .air
    comiss xmm0, [f_tbreath]
    jb .regen
    subss xmm0, [f_tbreath]
    movss [t_breath], xmm0
    cmp dword [breath], 0
    je .drown
    dec dword [breath]
    jmp .regen
.drown:
    mov edi, 2
    call player_hurt
    jmp .regen
.air:
    comiss xmm0, [f_trefill]
    jb .regen
    subss xmm0, [f_trefill]
    movss [t_breath], xmm0
    cmp dword [breath], MAX_BREATH
    jae .regen
    inc dword [breath]
.regen:
    movss xmm0, [t_regen]
    addss xmm0, [dt]
    movss [t_regen], xmm0
    comiss xmm0, [f_tregen]
    jb .out
    subss xmm0, [f_tregen]
    movss [t_regen], xmm0
    cmp dword [hp], MAX_HP
    jae .out
    cmp dword [breath], 0
    je .out
    cmp dword [player_dead], 0
    jne .out
    inc dword [hp]
.out:
    LEAVE_FN

; eye position into xmm0..2
eye_pos:
    movss xmm0, [pos]
    movss xmm1, [pos + 4]
    addss xmm1, [eye_h]
    movss xmm2, [pos + 8]
    ret

update_target:
    ENTER_FN 32
    fld dword [pitch]
    fsincos
    fstp dword [rsp]
    fstp dword [rsp + 4]
    movss xmm3, [syaw]
    mulss xmm3, [rsp]
    xorps xmm4, xmm4
    subss xmm4, [rsp + 4]
    xorps xmm5, xmm5
    movss xmm6, [cyaw]
    mulss xmm6, [rsp]
    subss xmm5, xmm6
    call eye_pos
    movss xmm6, [f_reach]
    lea rdi, [target]
    call world_raycast
    mov [target_hit], eax
    LEAVE_FN

; item id held in the selected hotbar slot -> eax
held_item:
    mov eax, [sel_slot]
    lea rcx, [inv]
    movzx eax, byte [rcx + rax*4]
    ret

; Hold the left button to dig. Survival: takes the block's dig time for the
; held tool, shows crack stages, drops the block as an item; creative:
; instant, repeating while held, no drops.
; locals: [0] block, [4] held item
update_digging:
    ENTER_FN 16
    ; the rifle shoots instead (and never digs)
    call held_item
    cmp eax, I_RIFLE
    jne .notgun
    call rifle_fire
    jmp .reset
.notgun:
    movss xmm0, [atk_cool]
    subss xmm0, [dt]
    maxss xmm0, [f_zero]
    movss [atk_cool], xmm0
    cmp dword [lmb_down], 0
    je .released
    ; a mob in the way is hit instead of digging (every 0.5 s while held)
    comiss xmm0, [f_zero]
    ja .hitting
    call dragon_attack              ; (the island: a crystal, or the dragon)
    test eax, eax
    jnz .struck
    call mob_attack
    test eax, eax
    jnz .struck
    call boat_attack
    test eax, eax
    jz .hitting
.struck:
    mov eax, [f_atkcool]
    mov [atk_cool], eax
    mov dword [atk_hold], 1
    mov dword [hand_swing], 0x3f800000
.hitting:
    cmp dword [atk_hold], 0
    jne .reset
    cmp dword [target_hit], 0
    je .reset
    ; new target?
    mov eax, [target]
    cmp eax, [dig_pos]
    jne .newpos
    mov eax, [target + 4]
    cmp eax, [dig_pos + 4]
    jne .newpos
    mov eax, [target + 8]
    cmp eax, [dig_pos + 8]
    je .same
.newpos:
    mov eax, [target]
    mov [dig_pos], eax
    mov eax, [target + 4]
    mov [dig_pos + 4], eax
    mov eax, [target + 8]
    mov [dig_pos + 8], eax
    mov dword [dig_progress], 0
.same:
    ; the hand swings for as long as it digs
    cmp dword [hand_swing], 0
    jne .swinging
    mov dword [hand_swing], 0x3f800000
.swinging:
    mov edi, [target]
    mov esi, [target + 4]
    mov edx, [target + 8]
    call world_get
    mov [rsp], eax
    mov edi, eax
    mov esi, [target]
    mov edx, [target + 4]
    mov ecx, [target + 8]
    call dig_alias
    mov [rsp + 8], eax              ; what it digs like
    call held_item
    mov [rsp + 4], eax
    cmp dword [game_mode], MODE_CREATIVE
    jne .survival
    movss xmm0, [dig_cool]
    subss xmm0, [dt]
    movss [dig_cool], xmm0
    comiss xmm0, [f_zero]
    ja .out
    mov eax, [f_cdig]
    mov [dig_cool], eax
    jmp .break
.survival:
    mov edi, [rsp + 8]
    mov esi, [rsp + 4]
    call dig_time
    comiss xmm0, [f_zero]
    jb .reset                       ; cannot be dug (bedrock, water)
    movss xmm1, xmm0                ; seconds needed
    movss xmm0, [dig_progress]
    addss xmm0, [dt]
    movss [dig_progress], xmm0
    comiss xmm0, xmm1
    jae .dug
    divss xmm0, xmm1
    mulss xmm0, [f_five]
    cvttss2si eax, xmm0
    mov [dig_stage], eax
    ; a tap now and then while it is being dug
    movss xmm0, [dig_snd]
    subss xmm0, [dt]
    movss [dig_snd], xmm0
    comiss xmm0, [f_zero]
    ja .out
    mov eax, [f_digsnd]
    mov [dig_snd], eax
    mov edi, [rsp + 8]
    xor esi, esi
    call target_sound
    mov edi, [rsp + 8]
    mov esi, 3
    call target_bits
    jmp .out
.dug:
    ; the drop falls out of the middle of the node
    mov edi, [rsp + 8]
    mov esi, [rsp + 4]
    call can_harvest
    test eax, eax
    jz .wear
    mov edi, [rsp]
    mov esi, [target]
    mov edx, [target + 4]
    mov ecx, [target + 8]
    call drop_block
.wear:
    mov edi, [sel_slot]
    call tool_wear
.break:
    mov edi, [rsp + 8]
    mov esi, 1
    call target_sound
    mov edi, [rsp + 8]
    mov esi, 14
    call target_bits
    ; a furnace spills what is inside it
    mov eax, [rsp]
    cmp eax, B_FURNACE
    je .furnace
    cmp eax, B_FURNACE_LIT
    jne .set
.furnace:
    mov edi, [target]
    mov esi, [target + 4]
    mov edx, [target + 8]
    call furnace_remove
.set:
    mov edi, [target]
    mov esi, [target + 4]
    mov edx, [target + 8]
    xor ecx, ecx
    call world_set
    ; a plant or torch on top comes off with it
    mov edi, [target]
    mov esi, [target + 4]
    mov edx, [target + 8]
    call pop_above
    mov edi, [target]
    mov esi, [target + 4]
    mov edx, [target + 8]
    call pop_walls
    ; a portal next to it goes when its frame is broken
    mov edi, [target]
    mov esi, [target + 4]
    mov edx, [target + 8]
    call portal_break
    ; a bed is two nodes: the other half goes too
    mov ecx, [rsp]
    cmp ecx, B_BED_FOOT
    jb .notbed
    cmp ecx, B_BED_HEAD
    ja .notbed
    xor ecx, B_BED_FOOT ^ B_BED_HEAD ; the other half
    mov edi, [target]
    mov esi, [target + 4]
    mov edx, [target + 8]
    call bed_partner_remove
.notbed:
    mov dword [target_hit], 0
    mov dword [dig_progress], 0
    mov dword [dig_stage], -1
    jmp .out
.released:
    mov dword [atk_hold], 0
.reset:
    mov dword [dig_progress], 0
    mov dword [dig_cool], 0
    mov dword [dig_stage], -1
    mov dword [dig_snd], 0
.out:
    LEAVE_FN

; target_bits(edi block, esi how many) - bits of the block looked at fly off
target_bits:
    sub rsp, 8
    mov r8d, esi
    mov esi, [target]
    mov edx, [target + 4]
    mov ecx, [target + 8]
    call fx_burst
    add rsp, 8
    ret

; target_sound(edi block, esi kind) - the sound of the block looked at
; (kind: 0 a dig tap, 1 breaking)
target_sound:
    sub rsp, 8
    cvtsi2ss xmm0, dword [target]
    addss xmm0, [f_half]
    cvtsi2ss xmm1, dword [target + 4]
    addss xmm1, [f_half]
    cvtsi2ss xmm2, dword [target + 8]
    addss xmm2, [f_half]
    call sound_block
    add rsp, 8
    ret

; drop_block(edi block, esi x, edx y, ecx z) - what breaking it gives,
; out of the middle of the node: its drop (gravel: flint 1 in 10), plus
; seeds from tall grass (1 in 8) and ripe wheat (0-3), more carrots from
; ripe carrots (1-3)
drop_block:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov ebx, edi
    mov r12d, esi
    mov r13d, edx
    mov r14d, ecx
    ; a door or trapdoor: wood or iron, as it was put down
    lea eax, [rbx - W_DOOR]
    cmp eax, W_END - W_DOOR - 1
    ja .notdoor
    mov edi, ebx
    mov esi, r12d
    mov edx, r13d
    mov ecx, r14d
    call door_drop
    test eax, eax
    jz .out                         ; (a green portal: nothing)
    mov edi, eax
    call .spawn
    jmp .out
.notdoor:
    ; gravel gives flint 1 time in 10
    cmp ebx, B_GRAVEL
    jne .normal
    call game_rand
    shr eax, 8
    xor edx, edx
    mov ecx, 10
    div ecx
    test edx, edx
    jnz .normal
    mov edi, I_FLINT | (1 << 8)
    call .spawn
    jmp .out
.normal:
    mov edi, ebx
    call block_drop
    test eax, eax
    jz .extra
    mov edi, eax
    call .spawn
.extra:
    call game_rand
    shr eax, 8
    mov r15d, eax
    cmp ebx, B_TALLGRASS
    jne .wheat
    test r15d, 7
    jnz .out
    mov edi, I_SEEDS | (1 << 8)
    call .spawn
    jmp .out
.wheat:
    cmp ebx, B_WHEAT7
    jne .carrot
    and r15d, 3
    jz .out
    mov edi, r15d
    shl edi, 8
    or edi, I_SEEDS
    call .spawn
    jmp .out
.carrot:
    cmp ebx, B_CARROT3
    jne .out
    mov eax, r15d
    xor edx, edx
    mov ecx, 3
    div ecx
    lea edi, [rdx + 1]
    shl edi, 8
    or edi, I_CARROT
    call .spawn
.out:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
.spawn:                             ; edi slot (called inside drop_block)
    cvtsi2ss xmm0, r12d
    addss xmm0, [f_mid]
    cvtsi2ss xmm1, r13d
    addss xmm1, [f_mid]
    cvtsi2ss xmm2, r14d
    addss xmm2, [f_mid]
    xorps xmm3, xmm3
    movss xmm4, [f_up]
    xorps xmm5, xmm5
    jmp ent_spawn

; pop_above(edi x, esi y, edx z) - the node at (x, y, z) went: a torch or
; plant standing on it breaks (and drops in survival)
pop_above:
    push rbx
    push r12
    push r13
    mov ebx, edi
    lea r12d, [rsi + 1]
    mov r13d, edx
    mov esi, r12d
    call world_get
    lea rcx, [block_flags]
    test byte [rcx + rax], F_CROSS
    jz .out
    cmp eax, B_TORCH_WALL
    je .out                         ; it hangs on a wall, not on this
    cmp eax, W_FIRST
    jae .out                        ; bluestone parts see to themselves
    push rax
    sub rsp, 8
    mov edi, ebx
    mov esi, r12d
    mov edx, r13d
    xor ecx, ecx
    call world_set
    add rsp, 8
    pop rdi
    cmp dword [game_mode], MODE_SURVIVAL
    jne .out
    mov esi, ebx
    mov edx, r12d
    mov ecx, r13d
    call drop_block
.out:
    pop r13
    pop r12
    pop rbx
    ret

; pop_walls(edi x, esi y, edx z) - the node was dug away: a wall torch
; beside it with no other block to hold on to comes off
; locals: [0] x, [4] y, [8] z, [12] the torch's x, [16] z
pop_walls:
    ENTER_FN 32
    mov [rsp], edi
    mov [rsp + 4], esi
    mov [rsp + 8], edx
    xor r12d, r12d
.t:
    lea rax, [wall_dirs]
    movsx edi, byte [rax + r12*2]
    add edi, [rsp]
    mov [rsp + 12], edi
    movsx edx, byte [rax + r12*2 + 1]
    add edx, [rsp + 8]
    mov [rsp + 16], edx
    mov esi, [rsp + 4]
    call world_get
    cmp eax, B_TORCH_WALL
    jne .next
    xor r13d, r13d
.hold:
    lea rax, [wall_dirs]
    movsx edi, byte [rax + r13*2]
    add edi, [rsp + 12]
    movsx edx, byte [rax + r13*2 + 1]
    add edx, [rsp + 16]
    mov esi, [rsp + 4]
    call world_get
    lea rcx, [block_flags]
    movzx eax, byte [rcx + rax]
    and eax, F_SOLID | F_FENCE
    cmp eax, F_SOLID
    je .next                        ; still held
    inc r13d
    cmp r13d, 4
    jb .hold
    mov edi, [rsp + 12]
    mov esi, [rsp + 4]
    mov edx, [rsp + 16]
    xor ecx, ecx
    call world_set
    cmp dword [game_mode], MODE_SURVIVAL
    jne .next
    mov edi, B_TORCH_WALL
    mov esi, [rsp + 12]
    mov edx, [rsp + 4]
    mov ecx, [rsp + 16]
    call drop_block
.next:
    inc r12d
    cmp r12d, 4
    jb .t
    LEAVE_FN

; bed_partner_remove(edi x, esi y, edx z, ecx other half) - the bed half
; next to (x, y, z) goes (no drop: the half that was broken drops the bed)
bed_partner_remove:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov ebx, edi
    mov r12d, esi
    mov r13d, edx
    mov r14d, ecx
    xor r15d, r15d                  ; neighbour 0-3: +x -x +z -z
.n:
    lea rax, [bed_dirs]
    movsx edi, byte [rax + r15*2]
    add edi, ebx
    mov esi, r12d
    movsx edx, byte [rax + r15*2 + 1]
    add edx, r13d
    call world_get
    cmp eax, r14d
    jne .next
    lea rax, [bed_dirs]
    movsx edi, byte [rax + r15*2]
    add edi, ebx
    mov esi, r12d
    movsx edx, byte [rax + r15*2 + 1]
    add edx, r13d
    xor ecx, ecx
    call world_set
    jmp .out
.next:
    inc r15d
    cmp r15d, 4
    jb .n
.out:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; try_sleep(edi x, esi y, edx z) - right click on a bed: only at night and
; with no zombie within 8 nodes; the night passes and the player will
; respawn at this bed
try_sleep:
    push rbx
    push r12
    push r13
    mov ebx, edi
    mov r12d, esi
    mov r13d, edx
    lea rdi, [s_nethersleep]
    cmp dword [dimension], 0
    jne .say
    movss xmm0, [sunlight]
    comiss xmm0, [f_dusk]
    jb .night
    lea rdi, [s_daysleep]
.say:
    call hud_message
    jmp .out
.night:
    xor ecx, ecx
    lea rdx, [mobs]
.m:
    cmp ecx, [mob_count]
    jae .safe
    cmp dword [rdx + MOB_TYPE_OFF], 3
    jne .mn
    movss xmm0, [rdx + 4]
    subss xmm0, [pos]
    mulss xmm0, xmm0
    movss xmm1, [rdx + 12]
    subss xmm1, [pos + 8]
    mulss xmm1, xmm1
    addss xmm0, xmm1
    comiss xmm0, [f_monster2]
    jae .mn
    lea rdi, [s_monsters]
    call hud_message
    jmp .out
.mn:
    add rdx, MOB_RECORD
    inc ecx
    jmp .m
.safe:
    ; morning: the start of the next day
    movss xmm0, [world_time]
    divss xmm0, [f_day_len]
    cvttss2si eax, xmm0
    inc eax
    cvtsi2ss xmm0, eax
    mulss xmm0, [f_day_len]
    movss [world_time], xmm0
    mov [spawn_pos], ebx
    mov [spawn_pos + 4], r12d
    mov [spawn_pos + 8], r13d
    mov dword [spawn_bed], 1
    lea rdi, [s_morning]
    call hud_message
.out:
    pop r13
    pop r12
    pop rbx
    ret

; take one of the held item (survival)
use_one:
    cmp dword [game_mode], MODE_SURVIVAL
    jne .out
    mov eax, [sel_slot]
    lea rcx, [inv]
    lea rcx, [rcx + rax*4]
    dec byte [rcx + 1]
    jnz .out
    mov dword [rcx], 0
.out:
    ret

; void player_use(void) - right click: open a crafting table or furnace,
; otherwise place the held block in the empty cell before the target
; (unless that would be inside the player)
player_use:
    ENTER_FN 16
    ; armour in the hand: put it on (swapping with the piece worn), unless
    ; the click is on a block that opens or moves (table, furnace, bed, gate)
    call held_item
    mov edi, eax
    call armor_piece
    test eax, eax
    js .notarmor
    mov r12d, eax
    cmp dword [target_hit], 0
    je .wear
    mov edi, [target]
    mov esi, [target + 4]
    mov edx, [target + 8]
    call world_get
    lea ecx, [rax - B_CRAFTTABLE]
    cmp ecx, B_FURNACE_LIT - B_CRAFTTABLE
    jbe .notarmor
    lea ecx, [rax - B_GATE_X]
    cmp ecx, B_GATEOPEN_Z - B_GATE_X
    jbe .notarmor
    lea ecx, [rax - B_BED_FOOT]
    cmp ecx, B_DYEMAKER - B_BED_FOOT
    jbe .notarmor
.wear:
    mov eax, r12d
    mov ecx, [sel_slot]
    lea rdx, [inv]
    lea rdx, [rdx + rcx*4]
    lea r8, [armor]
    mov r9d, [r8 + rax*4]
    mov r10d, [rdx]
    mov [r8 + rax*4], r10d
    mov [rdx], r9d
    jmp .out
.notarmor:
    ; a boat in front: get in; a boat in the hand: put it down
    call boat_use
    test eax, eax
    jnz .out
    call held_item
    cmp eax, I_BOAT
    jne .feed
    call boat_place
    test eax, eax
    jz .out
    call use_one
    jmp .out
.feed:
    ; buckets (milk a cow, take or pour water and lava); flint and steel on TNT
    call bucket_use
    test eax, eax
    jnz .out
    call flint_use
    test eax, eax
    jnz .out
    ; wheat or a carrot on a cow or pig: feed it (love, or a baby grows)
    call mob_feed
    test eax, eax
    jnz .out
    ; seeds or a carrot on top of farmland: plant it (before eating)
    cmp dword [target_hit], 0
    je .food
    call held_item
    mov r12d, B_WHEAT0
    cmp eax, I_SEEDS
    je .plant
    mov r12d, B_CARROT0
    cmp eax, I_CARROT
    jne .food
.plant:
    mov edi, [target]
    mov esi, [target + 4]
    mov edx, [target + 8]
    call world_get
    cmp eax, B_FARMLAND
    jne .food
    mov eax, [target + 16]          ; the top face: the cell above
    dec eax
    cmp eax, [target + 4]
    jne .food
    mov eax, [target + 12]
    cmp eax, [target]
    jne .food
    mov edi, [target + 12]
    mov esi, [target + 16]
    mov edx, [target + 20]
    call world_get
    test eax, eax
    jnz .food
    mov edi, [target + 12]
    mov esi, [target + 16]
    mov edx, [target + 20]
    mov ecx, r12d
    call world_set
    SFX S_TICK_CLOTH, 80, 100
    call use_one
    jmp .out
.food:
    ; food: eat one to get health back (survival, when hurt)
    call held_item
    mov edi, eax
    call food_heal
    test eax, eax
    jz .use
    cmp dword [game_mode], MODE_SURVIVAL
    jne .use
    cmp dword [hp], MAX_HP
    jge .use
    add eax, [hp]
    mov ecx, MAX_HP
    cmp eax, ecx
    cmovg eax, ecx
    mov [hp], eax
    SFX S_EAT, 100, 100
    mov dword [hand_swing], 0x3f800000
    mov eax, [sel_slot]
    lea rcx, [inv]
    lea rcx, [rcx + rax*4]
    dec byte [rcx + 1]
    jnz .out
    mov dword [rcx], 0
    jmp .out
.use:
    cmp dword [target_hit], 0
    je .out
    ; spawn egg: its mob appears in the free cell in front of the block
    call held_item
    mov edi, 4                      ; sheep
    cmp eax, I_EGG_SHEEP
    je .egg
    mov edi, 5                      ; wither skeleton
    cmp eax, I_EGG_WITHER
    je .egg
    mov edi, 6                      ; big slime
    cmp eax, I_EGG_SLIME
    je .egg
    mov edi, 9                      ; ghast
    cmp eax, I_EGG_GHAST
    je .egg
    mov edi, 10                     ; giant
    cmp eax, I_EGG_GIANT
    je .egg
    cmp eax, I_EGG_PIG
    jb .noegg
    cmp eax, I_EGG_ZOMBIE
    ja .noegg
    lea edi, [rax - I_EGG_PIG + 1]
.egg:
    cvtsi2ss xmm0, dword [target + 12]
    addss xmm0, [f_half]
    cvtsi2ss xmm1, dword [target + 16]
    cvtsi2ss xmm2, dword [target + 20]
    addss xmm2, [f_half]
    call mob_spawn
    test eax, eax
    js .out                         ; too many mobs
    SFX S_POP, 80, 80
    cmp dword [game_mode], MODE_SURVIVAL
    jne .out                        ; creative keeps the egg
    mov eax, [sel_slot]
    lea rcx, [inv]
    lea rcx, [rcx + rax*4]
    dec byte [rcx + 1]
    jnz .out
    mov dword [rcx], 0
    jmp .out
.noegg:
    mov edi, [target]
    mov esi, [target + 4]
    mov edx, [target + 8]
    call world_get
    ; crouching with something in the hand: it is put down against the
    ; block, which is not opened or used
    cmp dword [crouching], 0
    je .opens
    mov ebx, eax
    call held_item
    test eax, eax
    mov eax, ebx
    jnz .placeonly
.opens:
    ; a lever, button, repeater or comparator answers the click
    cmp eax, W_FIRST
    jb .nopart
    cmp eax, B_UNKNOWN
    jae .nopart
    mov r12d, eax
    mov edi, eax
    mov esi, [target]
    mov edx, [target + 4]
    mov ecx, [target + 8]
    call wire_click
    test eax, eax
    jz .waspart
    mov dword [hand_swing], 0x3f800000
    jmp .out
.waspart:
    mov eax, r12d
.nopart:
    cmp eax, B_CRAFTTABLE
    je .table
    cmp eax, B_FURNACE
    je .furnace
    cmp eax, B_FURNACE_LIT
    je .furnace
    cmp eax, B_BED_FOOT
    je .sleep
    cmp eax, B_BED_HEAD
    je .sleep
    cmp eax, B_DYEMAKER
    je .dyemaker
    cmp eax, B_BEACON
    je .beacon
    ; a fence gate opens or closes
    lea ecx, [rax - B_GATE_X]
    cmp ecx, B_GATEOPEN_Z - B_GATE_X
    jbe .gate
.placeonly:
    mov ebx, eax                    ; target block
    call held_item
    mov r12d, eax
    test r12d, r12d
    jz .out
    ; a hoe turns grass or dirt with air above into farmland
    lea ecx, [r12 - I_HOE]
    cmp ecx, 3
    ja .nohoe
    cmp ebx, B_GRASS
    je .till
    cmp ebx, B_DIRT
    je .till
    cmp ebx, B_DRYGRASS
    je .till
    cmp ebx, B_SNOWDIRT
    jne .out
.till:
    mov edi, [target]
    mov esi, [target + 4]
    inc esi
    mov edx, [target + 8]
    call world_get
    test eax, eax
    jnz .out
    mov edi, [target]
    mov esi, [target + 4]
    mov edx, [target + 8]
    mov ecx, B_FARMLAND
    call world_set
    SFX S_TICK_DIRT, 85, 85
    mov dword [hand_swing], 0x3f800000
    cmp dword [game_mode], MODE_SURVIVAL
    jne .out
    mov edi, [sel_slot]
    call tool_wear
    jmp .out
.nohoe:
    cmp r12d, I_BED
    je .placebed
    cmp r12d, I_DRAGONPORTAL        ; in the nether: the frame of a portal
    jne .notdp
    call portal_item
    test eax, eax
    jz .out
    mov dword [target_hit], 0
    jmp .used
.notdp:
    ; birch and dark oak logs and planks: their blocks
    lea eax, [r12 - I_BIRCHLOG]
    cmp eax, I_DARKPLANKS - I_BIRCHLOG
    ja .notwood
    add r12d, ITEM_TO_W
    jmp .wood
.notwood:
    ; bluestone parts, rails, minecarts, doors, stairs, slabs and chests
    lea eax, [r12 - I_DUST]
    cmp eax, I_CHEST - I_DUST
    ja .notpart
    mov edi, r12d
    call wire_use_item
    test eax, eax
    jz .out
    mov dword [target_hit], 0
    jmp .used
.notpart:
    cmp r12d, I_FIRST
    jae .out                        ; items are not placed
    mov edi, r12d
    call item_valid
    test eax, eax
    jz .out
.wood:
    xor ebx, ebx
.ax:
    lea rax, [target]
    mov eax, [rax + 12 + rbx*4]
    cvtsi2ss xmm0, eax
    movss xmm1, xmm0
    addss xmm1, [f_one]
    lea rax, [pos]
    movss xmm2, [rax + rbx*4]
    movaps xmm3, xmm2
    lea rax, [lo_off]
    addss xmm2, [rax + rbx*4]
    lea rax, [hi_off]
    addss xmm3, [rax + rbx*4]
    comiss xmm0, xmm3
    jae .place
    comiss xmm2, xmm1
    jae .place
    inc ebx
    cmp ebx, 3
    jb .ax
    lea rcx, [block_flags]
    test byte [rcx + r12], F_SOLID
    jnz .out                        ; would trap the player
.place:
    ; a gate goes across the way the player looks
    cmp r12d, B_GATE_X
    jne .placeit
    movss xmm0, [syaw]
    andps xmm0, [f_absmask]
    movss xmm1, [cyaw]
    andps xmm1, [f_absmask]
    mov ecx, B_GATE_X
    comiss xmm0, xmm1
    jbe .gateset
    mov ecx, B_GATE_Z               ; looking along x: the gate spans z
.gateset:
    mov edi, [target + 12]
    mov esi, [target + 16]
    mov edx, [target + 20]
    call world_set
    SFX S_TICK_WOOD, 85, 78
    jmp .used
.placeit:
    ; a torch: standing on top of a block, leaning from its side, never
    ; hung under one
    cmp r12d, B_TORCH
    jne .putit
    mov eax, [target + 16]
    cmp eax, [target + 4]
    jl .out
    je .walltorch
    mov edi, [target]
    mov esi, [target + 4]
    mov edx, [target + 8]
    call world_get
    lea rcx, [block_flags]
    test byte [rcx + rax], F_SOLID
    jz .out                         ; (not on a plant or another torch)
    jmp .putit
.walltorch:
    mov edi, [target]
    mov esi, [target + 4]
    mov edx, [target + 8]
    call world_get
    lea rcx, [block_flags]
    movzx eax, byte [rcx + rax]
    and eax, F_SOLID | F_FENCE
    cmp eax, F_SOLID
    jne .out
    mov r12d, B_TORCH_WALL
.putit:
    mov edi, [target + 12]
    mov esi, [target + 16]
    mov edx, [target + 20]
    mov ecx, r12d
    call world_set
    mov edi, r12d
    mov esi, 2
    cvtsi2ss xmm0, dword [target + 12]
    cvtsi2ss xmm1, dword [target + 16]
    cvtsi2ss xmm2, dword [target + 20]
    call sound_block
    mov dword [target_hit], 0
    cmp r12d, B_FURNACE
    jne .used
    mov edi, [target + 12]
    mov esi, [target + 16]
    mov edx, [target + 20]
    call furnace_add
.used:
    mov dword [hand_swing], 0x3f800000
    cmp dword [game_mode], MODE_SURVIVAL
    jne .out
    mov eax, [sel_slot]
    lea rcx, [inv]
    dec byte [rcx + rax*4 + 1]
    jnz .out
    mov dword [rcx + rax*4], 0
    jmp .out
.table:
    mov edi, GS_CRAFT
    call invui_open
    jmp .out
.dyemaker:
    mov edi, GS_DYE
    call invui_open
    jmp .out
.beacon:
    mov edi, [target]
    mov esi, [target + 4]
    mov edx, [target + 8]
    call beacon_open
    jmp .out
.sleep:
    mov edi, [target]
    mov esi, [target + 4]
    mov edx, [target + 8]
    call try_sleep
    jmp .out
.placebed:
    ; the foot where the player points, the head one node further along
    ; the way they look; both empty with solid ground under them
    xor r13d, r13d                  ; dx
    xor r14d, r14d                  ; dz
    movss xmm0, [syaw]
    movaps xmm2, xmm0
    andps xmm2, [f_absmask]
    movss xmm1, [cyaw]
    movaps xmm3, xmm1
    andps xmm3, [f_absmask]
    comiss xmm2, xmm3
    jbe .bz
    mov r13d, 1
    comiss xmm0, [f_zero]
    ja .bdir
    mov r13d, -1
    jmp .bdir
.bz:
    mov r14d, -1                    ; looking along -cyaw
    comiss xmm1, [f_zero]
    ja .bdir
    mov r14d, 1
.bdir:
%macro BEDFREE 2                    ; dx, dz from the foot: jump to .out unless
    mov edi, [target + 12]          ; that node is air on solid ground
    add edi, %1
    mov esi, [target + 16]
    mov edx, [target + 20]
    add edx, %2
    call world_get
    test eax, eax
    jnz .out
    mov edi, [target + 12]
    add edi, %1
    mov esi, [target + 16]
    dec esi
    mov edx, [target + 20]
    add edx, %2
    call world_get
    lea rcx, [block_flags]
    test byte [rcx + rax], F_SOLID
    jz .out
%endmacro
    BEDFREE 0, 0
    BEDFREE r13d, r14d
    mov edi, [target + 12]
    mov esi, [target + 16]
    mov edx, [target + 20]
    mov ecx, B_BED_FOOT
    call world_set
    mov edi, [target + 12]
    add edi, r13d
    mov esi, [target + 16]
    mov edx, [target + 20]
    add edx, r14d
    mov ecx, B_BED_HEAD
    call world_set
    SFX S_TICK_WOOD, 85, 78
    mov dword [target_hit], 0
    call use_one
    jmp .out
.gate:
    ; closed <-> open: open ids are 2 above closed ones
    lea ecx, [rax + 2]
    cmp eax, B_GATEOPEN_X
    jb .gtoggle
    lea ecx, [rax - 2]
.gtoggle:
    mov edi, [target]
    mov esi, [target + 4]
    mov edx, [target + 8]
    call world_set
    SFX S_TICK_WOOD, 80, 115
    mov dword [hand_swing], 0x3f800000
    jmp .out
.furnace:
    mov edi, [target]
    mov esi, [target + 4]
    mov edx, [target + 8]
    call furnace_find
    test eax, eax
    jns .have
    mov edi, [target]
    mov esi, [target + 4]
    mov edx, [target + 8]
    call furnace_add
    test eax, eax
    js .out
.have:
    mov [cur_furnace], eax
    mov edi, GS_FURNACE
    call invui_open
.out:
    LEAVE_FN

; void drop_selected(void) - Q: throw one of the held item forward
drop_selected:
    ENTER_FN 16
    mov eax, [sel_slot]
    lea rbx, [inv]
    lea rbx, [rbx + rax*4]
    mov edi, [rbx]
    test edi, edi
    jz .out
    and edi, 0xffff00ff
    or edi, 1 << 8
    dec byte [rbx + 1]
    jnz .thrown
    mov dword [rbx], 0
.thrown:
    call throw_item
.out:
    LEAVE_FN

; void throw_item(int slotdword) - toss a stack forward from the eyes
throw_item:
    sub rsp, 8
    call eye_pos
    movss xmm3, [syaw]
    mulss xmm3, [f_throw]
    movss xmm4, [f_up]
    xorps xmm5, xmm5
    movss xmm6, [cyaw]
    mulss xmm6, [f_throw]
    subss xmm5, xmm6
    call ent_spawn
    add rsp, 8
    ret

NOEXECSTACK
