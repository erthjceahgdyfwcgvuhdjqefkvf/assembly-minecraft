%include "common.inc"

global rail_event, rail_use_item, cart_move

extern world_get, world_set, world_poke, block_flags, dt, syaw, cyaw
extern target, target_hit, wire_held, w_indirect, ev_push, ev_around, look_h
extern wkind, boat_spawn, solid_at, sound_keep_at

K_RAIL      equ 11
K_PRAIL     equ 12
BT_X        equ 4                   ; boat.asm record
BT_Y        equ 8
BT_Z        equ 12
BT_VX       equ 16
BT_VY       equ 20
BT_VZ       equ 24
BT_YAW      equ 28

section .rodata
align 4
; per shape: the two ends of the line through the node (x, y, z each)
rail_line:
    dd 0.0, 0.0, 0.5,   1.0, 0.0, 0.5      ; along x
    dd 0.5, 0.0, 0.0,   0.5, 0.0, 1.0      ; along z
    dd 0.0, 0.0, 0.5,   1.0, 1.0, 0.5      ; up toward +x
    dd 1.0, 0.0, 0.5,   0.0, 1.0, 0.5      ; up toward -x
    dd 0.5, 0.0, 0.0,   0.5, 1.0, 1.0      ; up toward +z
    dd 0.5, 0.0, 1.0,   0.5, 1.0, 0.0      ; up toward -z
    dd 1.0, 0.0, 0.5,   0.5, 0.0, 1.0      ; +x and +z
    dd 0.0, 0.0, 0.5,   0.5, 0.0, 1.0      ; -x and +z
    dd 0.0, 0.0, 0.5,   0.5, 0.0, 0.0      ; -x and -z
    dd 1.0, 0.0, 0.5,   0.5, 0.0, 0.0      ; +x and -z
rail_yaw:   dd 90.0, 0.0, 90.0, 90.0, 0.0, 0.0, -45.0, 45.0, -45.0, 45.0
f_zero:     dd 0.0
f_half:     dd 0.5
f_one:      dd 1.0
f_two:      dd 2.0
f_quarter:  dd 0.25
f_lift:     dd 0.0625               ; the cart's bottom above the node's floor
f_slope:    dd 2.5                  ; rolling down a slope, nodes/s^2
f_boost:    dd 16.0                 ; a powered rail
f_brake:    dd 10.0
f_start:    dd 0.6                  ; pushed off from a block by a powered rail
f_still:    dd 0.03
f_fric:     dd 0.12                 ; slowing, per second: with a rider
f_fric0:    dd 0.45                 ; empty
f_push:     dd 2.5                  ; the rider pushing with forward / back
f_pushmax:  dd 3.0
f_max:      dd 8.0
f_exit:     dd 0.02
f_grav:     dd 26.0
f_maxfall:  dd -40.0
f_drag:     dd 5.0
f_skin:     dd 0.001
align 16
absmask:    dd 0x7fffffff, 0, 0, 0
; rail ends: for each shape two (side, rise) pairs; side +x -x +z -z
rail_ends:
    db 0,0, 1,0,   2,0, 3,0,   0,1, 1,0,   1,1, 0,0,   2,1, 3,0
    db 3,1, 2,0,   0,0, 2,0,   1,0, 2,0,   1,0, 3,0,   0,0, 3,0
side_dx:    db 1, -1, 0, 0
side_dz:    db 0, 0, 1, -1
corner:     db 6, 9, 7, 8           ; +x+z, +x-z, -x+z, -x-z

section .text

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
%macro HERE 0
    mov edi, r12d
    mov esi, r13d
    mov edx, r14d
%endmacro
; floor of xmm float %2 into %1 (xmm7 scratch)
%macro FLOORF 2
    cvttss2si %1, %2
    cvtsi2ss xmm7, %1
    comiss xmm7, %2
    jbe %%ok
    dec %1
%%ok:
%endmacro

; shape_of(edi block) -> eax 0..9, or -1 if it is no rail
shape_of:
    lea eax, [rdi - W_RAIL]
    cmp eax, 9
    jbe .out
    lea eax, [rdi - W_PRAIL]
    cmp eax, 11
    ja .none
    shr eax, 1
.out:
    ret
.none:
    mov eax, -1
    ret

; rail_at(x, y, z) -> eax shape or -1, ecx the block
rail_at:
    sub rsp, 8
    call world_get
    mov edi, eax
    call shape_of
    mov ecx, edi
    add rsp, 8
    ret

; side_rail(side ecx) for the rail at (r12, r13, r14): eax = 0 none, 1 a
; rail beside it or one node down, 2 one node up
side_rail:
    push rbx
    mov ebx, ecx
%macro SIDEPOS 1                    ; the node on side ebx, %1 higher
    lea rax, [side_dx]
    movsx edi, byte [rax + rbx]
    add edi, r12d
    lea esi, [r13 + %1]
    lea rax, [side_dz]
    movsx edx, byte [rax + rbx]
    add edx, r14d
%endmacro
    SIDEPOS 0
    call rail_at
    test eax, eax
    jns .level
    SIDEPOS -1
    call rail_at
    test eax, eax
    jns .level
    SIDEPOS 1
    call rail_at
    test eax, eax
    js .none
    mov eax, 2
    pop rbx
    ret
.level:
    mov eax, 1
    pop rbx
    ret
.none:
    xor eax, eax
    pop rbx
    ret

; rail_fix(x, y, z) - the rail there takes the shape that joins the rails
; round it
; locals: [0..12] what is on each side (0, 1, 2 = up), [16] block,
;         [20] shape now, [24] new shape
rail_fix:
    ENTER_FN 32
    mov r12d, edi
    mov r13d, esi
    mov r14d, edx
    call rail_at
    test eax, eax
    js .out
    mov [rsp + 20], eax
    mov [rsp + 16], ecx
    xor ebx, ebx
.s:
    mov ecx, ebx
    call side_rail
    mov [rsp + rbx*4], eax
    inc ebx
    cmp ebx, 4
    jb .s
    mov eax, [rsp]
    or eax, [rsp + 4]               ; rails along x
    mov ecx, [rsp + 8]
    or ecx, [rsp + 12]              ; along z
    test eax, eax
    jz .only_z
    test ecx, ecx
    jz .x
    ; both ways: a line straight through wins, else a corner
    cmp dword [rsp], 0
    je .corner
    cmp dword [rsp + 4], 0
    je .corner
    jmp .x
.corner:
    cmp dword [rsp + 8], 0
    je .turn
    cmp dword [rsp + 12], 0
    jne .z
.turn:
    mov eax, [rsp + 16]
    lea rcx, [wkind]
    cmp byte [rcx + rax], K_PRAIL
    je .x                           ; powered rails do not turn
    xor eax, eax
    cmp dword [rsp], 0
    jne .tx
    mov eax, 2
.tx:
    cmp dword [rsp + 8], 0
    jne .tz
    inc eax
.tz:
    lea rcx, [corner]
    movzx eax, byte [rcx + rax]
    jmp .set
.only_z:
    test ecx, ecx
    jnz .z
    ; alone: as it lies
    mov eax, [rsp + 20]
    cmp eax, 6
    jb .set
    xor eax, eax
    jmp .set
.x:
    mov eax, 2
    cmp dword [rsp], 2
    je .set
    mov eax, 3
    cmp dword [rsp + 4], 2
    je .set
    xor eax, eax
    jmp .set
.z:
    mov eax, 4
    cmp dword [rsp + 8], 2
    je .set
    mov eax, 5
    cmp dword [rsp + 12], 2
    je .set
    mov eax, 1
.set:
    cmp eax, [rsp + 20]
    je .out
    mov ecx, [rsp + 16]
    lea rdx, [wkind]
    cmp byte [rdx + rcx], K_PRAIL
    je .pset
    lea ecx, [rax + W_RAIL]
    jmp .put
.pset:
    and ecx, 1                      ; (still on or off)
    lea ecx, [rcx + rax*2 + W_PRAIL]
.put:
    HERE
    call world_poke
.out:
    LEAVE_FN

; ends_joined(x, y, z) -> eax how many of the rail's two ends meet a rail
ends_joined:
    ENTER_FN 16
    mov r12d, edi
    mov r13d, esi
    mov r14d, edx
    call rail_at
    mov dword [rsp + 4], 0
    test eax, eax
    js .done
    mov [rsp], eax
    xor r15d, r15d
.e:
    mov eax, [rsp]
    lea rcx, [rail_ends]
    lea rcx, [rcx + rax*4]
    movzx ebx, byte [rcx + r15*2]       ; side
    movzx eax, byte [rcx + r15*2 + 1]   ; rise
    mov [rsp + 8], eax
    lea rax, [side_dx]
    movsx edi, byte [rax + rbx]
    add edi, r12d
    mov esi, r13d
    add esi, [rsp + 8]
    lea rax, [side_dz]
    movsx edx, byte [rax + rbx]
    add edx, r14d
    call rail_at
    test eax, eax
    jns .yes
    cmp dword [rsp + 8], 0
    jne .next
    lea rax, [side_dx]
    movsx edi, byte [rax + rbx]
    add edi, r12d
    lea esi, [r13 - 1]
    lea rax, [side_dz]
    movsx edx, byte [rax + rbx]
    add edx, r14d
    call rail_at
    test eax, eax
    js .next
.yes:
    inc dword [rsp + 4]
.next:
    inc r15d
    cmp r15d, 2
    jb .e
.done:
    mov eax, [rsp + 4]
    LEAVE_FN

; int rail_use_item(int item) - a rail in the hand: lay it in front of the
; block looked at (on a solid block); a minecart: stand it on the rail
; looked at. 1 if it was used.
; locals: [0] side, [4] rise
rail_use_item:
    ENTER_FN 16
    mov ebx, edi
    cmp dword [target_hit], 0
    je .no
    cmp ebx, I_CART
    je .cart
    mov r12d, [target + 12]
    mov r13d, [target + 16]
    mov r14d, [target + 20]
    HERE
    call world_get
    test eax, eax
    jnz .no
    HERE
    mov ecx, 3
    call wire_held
    test eax, eax
    jz .no
    call look_h
    shr eax, 1                      ; along x or along z
    mov ecx, W_RAIL
    cmp ebx, I_RAIL
    je .lay
    lea eax, [rax*2]
    mov ecx, W_PRAIL
.lay:
    add ecx, eax
    HERE
    call world_set
    HERE
    call rail_fix
    ; the rails beside it that still have an end free turn to meet it
    mov dword [rsp], 0
.side:
    mov dword [rsp + 4], -1
.rise:
    mov eax, [rsp]
    lea rcx, [side_dx]
    movsx r15d, byte [rcx + rax]
    add r15d, r12d
    lea rcx, [side_dz]
    movsx ebx, byte [rcx + rax]
    add ebx, r14d
    mov edi, r15d
    mov esi, r13d
    add esi, [rsp + 4]
    mov edx, ebx
    call ends_joined
    cmp eax, 2
    jae .next
    mov edi, r15d
    mov esi, r13d
    add esi, [rsp + 4]
    mov edx, ebx
    call rail_fix
.next:
    inc dword [rsp + 4]
    cmp dword [rsp + 4], 1
    jle .rise
    inc dword [rsp]
    cmp dword [rsp], 4
    jb .side
    HERE
    call rail_fix                   ; (once more, now that they have turned)
    HERE
    mov ecx, 1
    call ev_push
    cvtsi2ss xmm0, r12d
    cvtsi2ss xmm1, r13d
    cvtsi2ss xmm2, r14d
    SFX_AT S_TICK_METAL, 70, 120
    mov eax, 1
    LEAVE_FN
.cart:
    mov edi, [target]
    mov esi, [target + 4]
    mov edx, [target + 8]
    call rail_at
    test eax, eax
    js .no
    cvtsi2ss xmm0, dword [target]
    addss xmm0, [f_half]
    cvtsi2ss xmm1, dword [target + 4]
    addss xmm1, [f_lift]
    cvtsi2ss xmm2, dword [target + 8]
    addss xmm2, [f_half]
    mov edi, 1
    call boat_spawn
    test rax, rax
    jz .no
    mov eax, 1
    LEAVE_FN
.no:
    xor eax, eax
    LEAVE_FN

; chain(x, y, z, axis ecx 0 x / 1 z, way r8d +1 / -1) -> 1 if one of the
; next 8 powered rails that way along the track has power
; locals: [0] axis, [4] way, [8] left
chain:
    ENTER_FN 16
    mov r12d, edi
    mov r13d, esi
    mov r14d, edx
    mov [rsp], ecx
    mov [rsp + 4], r8d
    mov dword [rsp + 8], 8
.step:
    mov eax, [rsp + 4]
    cmp dword [rsp], 0
    jne .az
    add r12d, eax
    jmp .find
.az:
    add r14d, eax
.find:
    ; the next rail: level, one up or one down
    HERE
    call world_get
    lea rcx, [wkind]
    cmp byte [rcx + rax], K_PRAIL
    je .have
    inc r13d
    HERE
    call world_get
    lea rcx, [wkind]
    cmp byte [rcx + rax], K_PRAIL
    je .have
    sub r13d, 2
    HERE
    call world_get
    lea rcx, [wkind]
    cmp byte [rcx + rax], K_PRAIL
    jne .no
.have:
    ; it must run the same way
    sub eax, W_PRAIL
    shr eax, 1
    lea rcx, [axis_of]
    movzx eax, byte [rcx + rax]
    cmp eax, [rsp]
    jne .no
    HERE
    call w_indirect
    test eax, eax
    jnz .yes
    dec dword [rsp + 8]
    jnz .step
.no:
    xor eax, eax
    LEAVE_FN
.yes:
    mov eax, 1
    LEAVE_FN

section .rodata
axis_of:    db 0, 1, 0, 0, 1, 1
section .text

; void rail_event(int x, int y, int z, int block) - something changed next
; to a powered rail: is it on?
; locals: [0] axis, [4] on
rail_event:
    ENTER_FN 16
    mov r12d, edi
    mov r13d, esi
    mov r14d, edx
    mov r15d, ecx
    lea eax, [r15 - W_PRAIL]
    shr eax, 1
    lea rcx, [axis_of]
    movzx eax, byte [rcx + rax]
    mov [rsp], eax
    mov dword [rsp + 4], 1
    HERE
    call w_indirect
    test eax, eax
    jnz .have
    HERE
    mov ecx, [rsp]
    mov r8d, 1
    call chain
    test eax, eax
    jnz .have
    HERE
    mov ecx, [rsp]
    mov r8d, -1
    call chain
    mov [rsp + 4], eax
.have:
    mov eax, r15d
    and eax, 1
    cmp eax, [rsp + 4]
    je .out
    mov ecx, r15d
    and ecx, ~1
    or ecx, [rsp + 4]
    HERE
    call world_poke
    ; the rails along the track (level, up and down) look again
    mov ebx, -1
.y:
    mov r15d, -1
.w:
    mov edi, r12d
    mov edx, r14d
    cmp dword [rsp], 0
    jne .wz
    add edi, r15d
    jmp .tell
.wz:
    add edx, r15d
.tell:
    lea esi, [r13 + rbx]
    mov ecx, 1
    call ev_push
    add r15d, 2
    cmp r15d, 1
    jle .w
    inc ebx
    cmp ebx, 1
    jle .y
.out:
    LEAVE_FN

; ---------------------------------------------------------------------------
; void cart_move(rdi cart record, esi push: 1 forward, -1 back, 0; edx 1
; with a rider) - one frame of a minecart
; locals: [0] cell x, [4] y, [8] z, [12] shape, [16] block, [20] push,
;         [24] rider, [28] speed along the line, [32] place along it 0..1,
;         [36] line x, [40] z (level, unit), [44] its level length,
;         [48] rise
cart_move:
    ENTER_FN 64
    mov rbx, rdi
    mov [rsp + 20], esi
    mov [rsp + 24], edx
    ; the rail under it: in its node, or the node below (the top of a slope)
    movss xmm0, [rbx + BT_X]
    FLOORF eax, xmm0
    mov [rsp], eax
    movss xmm0, [rbx + BT_Z]
    FLOORF eax, xmm0
    mov [rsp + 8], eax
    movss xmm0, [rbx + BT_Y]
    addss xmm0, [f_quarter]
    FLOORF eax, xmm0
    mov [rsp + 4], eax
    mov edi, [rsp]
    mov esi, eax
    mov edx, [rsp + 8]
    call rail_at
    test eax, eax
    jns .onrail
    dec dword [rsp + 4]
    mov edi, [rsp]
    mov esi, [rsp + 4]
    mov edx, [rsp + 8]
    call rail_at
    test eax, eax
    js .loose
.onrail:
    mov [rsp + 12], eax
    mov [rsp + 16], ecx
    mov dword [rbx + BT_VY], 0
    imul eax, eax, 24
    lea r12, [rail_line]
    add r12, rax                    ; ends A (0, 4, 8) and B (12, 16, 20)
    ; the line, level: its direction and length
    movss xmm0, [r12 + 12]
    subss xmm0, [r12]
    movss xmm1, [r12 + 20]
    subss xmm1, [r12 + 8]
    movaps xmm2, xmm0
    mulss xmm2, xmm2
    movaps xmm3, xmm1
    mulss xmm3, xmm3
    addss xmm2, xmm3
    sqrtss xmm2, xmm2
    movss [rsp + 44], xmm2
    divss xmm0, xmm2
    divss xmm1, xmm2
    movss [rsp + 36], xmm0
    movss [rsp + 40], xmm1
    movss xmm3, [r12 + 16]
    subss xmm3, [r12 + 4]
    movss [rsp + 48], xmm3
    ; speed along it, and how far along it is
    movss xmm4, [rbx + BT_VX]
    mulss xmm4, xmm0
    movss xmm5, [rbx + BT_VZ]
    mulss xmm5, xmm1
    addss xmm4, xmm5
    ; all of its speed, the way it is going along the line (a corner
    ; turns it, it does not slow it)
    movss xmm5, [rbx + BT_VX]
    mulss xmm5, xmm5
    movss xmm6, [rbx + BT_VZ]
    mulss xmm6, xmm6
    addss xmm5, xmm6
    sqrtss xmm5, xmm5
    comiss xmm4, [f_zero]
    jae .fwd
    xorps xmm6, xmm6
    subss xmm6, xmm5
    movaps xmm5, xmm6
.fwd:
    movss [rsp + 28], xmm5
    cvtsi2ss xmm4, dword [rsp]
    addss xmm4, [r12]
    movss xmm5, [rbx + BT_X]
    subss xmm5, xmm4
    mulss xmm5, xmm0
    cvtsi2ss xmm4, dword [rsp + 8]
    addss xmm4, [r12 + 8]
    movss xmm6, [rbx + BT_Z]
    subss xmm6, xmm4
    mulss xmm6, xmm1
    addss xmm5, xmm6
    divss xmm5, xmm2
    maxss xmm5, [f_zero]
    minss xmm5, [f_one]
    movss [rsp + 32], xmm5
    ; downhill
    movss xmm0, [rsp + 48]
    mulss xmm0, [f_slope]
    mulss xmm0, [dt]
    movss xmm4, [rsp + 28]
    subss xmm4, xmm0
    ; the rider pushes it the way they look
    cmp dword [rsp + 20], 0
    je .nopush
    movss xmm0, [syaw]
    mulss xmm0, [rsp + 36]
    movss xmm1, [cyaw]
    mulss xmm1, [rsp + 40]
    subss xmm0, xmm1                ; the look along the line
    cvtsi2ss xmm1, dword [rsp + 20]
    mulss xmm0, xmm1
    movaps xmm1, xmm4
    andps xmm1, [absmask]
    comiss xmm1, [f_pushmax]
    jae .nopush
    mulss xmm0, [f_push]
    mulss xmm0, [dt]
    addss xmm4, xmm0
.nopush:
    ; a powered rail drives or brakes
    mov eax, [rsp + 16]
    lea rcx, [wkind]
    cmp byte [rcx + rax], K_PRAIL
    jne .fric
    test eax, 1
    jz .brake
    movaps xmm1, xmm4
    andps xmm1, [absmask]
    comiss xmm1, [f_still]
    ja .drive
    ; standing: off it goes, away from a block at one end
    movss [rsp + 28], xmm4
    xor esi, esi
    call .blocked
    movss xmm4, [rsp + 28]
    test eax, eax
    jz .tryb
    movss xmm4, [f_start]
    jmp .fric
.tryb:
    mov esi, 12
    call .blocked
    movss xmm4, [rsp + 28]
    test eax, eax
    jz .fric
    xorps xmm4, xmm4
    subss xmm4, [f_start]
    jmp .fric
.drive:
    movss xmm0, [f_boost]
    mulss xmm0, [dt]
    comiss xmm4, [f_zero]
    ja .dpos
    subss xmm4, xmm0
    jmp .fric
.dpos:
    addss xmm4, xmm0
    jmp .fric
.brake:
    movss xmm0, [f_brake]
    mulss xmm0, [dt]
    movss xmm1, [f_one]
    subss xmm1, xmm0
    maxss xmm1, [f_zero]
    mulss xmm4, xmm1
    movaps xmm1, xmm4
    andps xmm1, [absmask]
    comiss xmm1, [f_still]
    ja .fric
    xorps xmm4, xmm4
.fric:
    movss xmm0, [f_fric0]
    cmp dword [rsp + 24], 0
    je .f0
    movss xmm0, [f_fric]
.f0:
    mulss xmm0, [dt]
    movss xmm1, [f_one]
    subss xmm1, xmm0
    mulss xmm4, xmm1
    minss xmm4, [f_max]
    xorps xmm0, xmm0
    subss xmm0, [f_max]
    maxss xmm4, xmm0
    movss [rsp + 28], xmm4
    ; along the line
    mulss xmm4, [dt]
    divss xmm4, [rsp + 44]
    addss xmm4, [rsp + 32]
    movss [rsp + 32], xmm4
    comiss xmm4, [f_one]
    ja .off_b
    comiss xmm4, [f_zero]
    jb .off_a
    ; still on this rail
%macro ALONG 2                      ; record field, line offset
    movss xmm0, [r12 + %2 + 12]
    subss xmm0, [r12 + %2]
    mulss xmm0, [rsp + 32]
    addss xmm0, [r12 + %2]
    cvtsi2ss xmm1, dword [rsp + %2]
    addss xmm0, xmm1
    movss [rbx + %1], xmm0
%endmacro
    ALONG BT_X, 0
    ALONG BT_Y, 4
    ALONG BT_Z, 8
    movss xmm0, [rbx + BT_Y]
    addss xmm0, [f_lift]
    movss [rbx + BT_Y], xmm0
    movss xmm0, [rsp + 36]
    mulss xmm0, [rsp + 28]
    movss [rbx + BT_VX], xmm0
    movss xmm0, [rsp + 40]
    mulss xmm0, [rsp + 28]
    movss [rbx + BT_VZ], xmm0
    jmp .yaw
.off_b:
    mov esi, 12
    jmp .leave
.off_a:
    xor esi, esi
.leave:
    ; out through that end (esi 0 A, 12 B): into the next node, going
    ; straight out of this one - unless a block is in the way
    mov r13d, esi
    call .blocked
    test eax, eax
    jz .go
    mov dword [rbx + BT_VX], 0
    mov dword [rbx + BT_VZ], 0
    jmp .yaw
.go:
    movss xmm4, [rsp + 28]
    andps xmm4, [absmask]           ; speed
    ; outward: 2 x (end - middle), level
    movss xmm0, [r12 + r13]
    subss xmm0, [f_half]
    addss xmm0, xmm0
    movss xmm1, [r12 + r13 + 8]
    subss xmm1, [f_half]
    addss xmm1, xmm1
    movaps xmm2, xmm0
    mulss xmm2, xmm4
    movss [rbx + BT_VX], xmm2
    movaps xmm2, xmm1
    mulss xmm2, xmm4
    movss [rbx + BT_VZ], xmm2
    mulss xmm0, [f_exit]
    mulss xmm1, [f_exit]
    addss xmm0, [r12 + r13]
    cvtsi2ss xmm2, dword [rsp]
    addss xmm0, xmm2
    movss [rbx + BT_X], xmm0
    addss xmm1, [r12 + r13 + 8]
    cvtsi2ss xmm2, dword [rsp + 8]
    addss xmm1, xmm2
    movss [rbx + BT_Z], xmm1
    movss xmm0, [r12 + r13 + 4]
    cvtsi2ss xmm2, dword [rsp + 4]
    addss xmm0, xmm2
    addss xmm0, [f_lift]
    movss [rbx + BT_Y], xmm0
.yaw:
    mov eax, [rsp + 12]
    lea rcx, [rail_yaw]
    mov eax, [rcx + rax*4]
    mov [rbx + BT_YAW], eax
    LEAVE_FN

; is the node beyond end esi (0 A, 12 B) of the rail a solid block with no
; rail to go on to? -> eax (called inside cart_move: its frame + 8)
.blocked:
    sub rsp, 8
    movss xmm0, [r12 + rsi]
    subss xmm0, [f_half]
    addss xmm0, xmm0
    cvttss2si edi, xmm0
    add edi, [rsp + 16]
    movss xmm0, [r12 + rsi + 8]
    subss xmm0, [f_half]
    addss xmm0, xmm0
    cvttss2si edx, xmm0
    add edx, [rsp + 16 + 8]
    movss xmm0, [r12 + rsi + 4]
    cvttss2si esi, xmm0
    add esi, [rsp + 16 + 4]
    call world_get
    lea rcx, [block_flags]
    movzx eax, byte [rcx + rax]
    and eax, F_SOLID
    add rsp, 8
    ret

.loose:
    ; off the rails: it drops, and slides to a stop
    movss xmm0, [rbx + BT_VY]
    movss xmm1, [f_grav]
    mulss xmm1, [dt]
    subss xmm0, xmm1
    maxss xmm0, [f_maxfall]
    movss [rbx + BT_VY], xmm0
    mulss xmm0, [dt]
    addss xmm0, [rbx + BT_Y]
    movss [rsp + 28], xmm0
    movaps xmm1, xmm0
    movss xmm0, [rbx + BT_X]
    movss xmm2, [rbx + BT_Z]
    call solid_at
    test eax, eax
    jz .fall
    mov dword [rbx + BT_VY], 0
    movss xmm0, [rsp + 28]
    FLOORF eax, xmm0
    inc eax
    cvtsi2ss xmm0, eax
    movss [rsp + 28], xmm0
    ; inside something even there: stay
    movaps xmm1, xmm0
    addss xmm1, [f_skin]
    movss xmm0, [rbx + BT_X]
    movss xmm2, [rbx + BT_Z]
    call solid_at
    test eax, eax
    jnz .slide
.fall:
    mov eax, [rsp + 28]
    mov [rbx + BT_Y], eax
.slide:
    movss xmm0, [f_drag]
    mulss xmm0, [dt]
    movss xmm1, [f_one]
    subss xmm1, xmm0
    maxss xmm1, [f_zero]
    movss xmm0, [rbx + BT_VX]
    mulss xmm0, xmm1
    movss [rbx + BT_VX], xmm0
    movss xmm2, [rbx + BT_VZ]
    mulss xmm2, xmm1
    movss [rbx + BT_VZ], xmm2
    mulss xmm0, [dt]
    addss xmm0, [rbx + BT_X]
    movss [rsp + 32], xmm0
    mulss xmm2, [dt]
    addss xmm2, [rbx + BT_Z]
    movss [rsp + 36], xmm2
    movss xmm1, [rbx + BT_Y]
    addss xmm1, [f_quarter]
    call solid_at
    test eax, eax
    jnz .stop
    mov eax, [rsp + 32]
    mov [rbx + BT_X], eax
    mov eax, [rsp + 36]
    mov [rbx + BT_Z], eax
    LEAVE_FN
.stop:
    mov dword [rbx + BT_VX], 0
    mov dword [rbx + BT_VZ], 0
    LEAVE_FN

NOEXECSTACK
