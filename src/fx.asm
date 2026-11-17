%include "common.inc"

global fx_burst, fx_update, fx_draw, fx_clear, fx_count

extern dt, pos, syaw, cyaw, sunlight, cur_pcx, cur_pcz, dimension
extern block_tiles, tex_atlas, light_get, light_curve, solid_at
extern f_tile_u, f_tile_v, f_rep_u, f_rep_v
extern glEnable, glDisable, glBindTexture, glBegin, glEnd, glColor4f
extern glTexCoord2f, glVertex3f

GL_QUADS        equ 7
GL_TEXTURE_2D   equ 0x0DE1
GL_ALPHA_TEST   equ 0x0BC0
GL_CULL_FACE    equ 0x0B44
NETHER_LIGHT    equ 8

MAX_FX      equ 96
FX_X        equ 0
FX_VX       equ 12
FX_LIFE     equ 24                  ; seconds left
FX_U        equ 28                  ; its square of the texture
FX_V        equ 32
FX_LIGHT    equ 36                  ; brightness 0 .. 1
FX_SIZE     equ 48

section .rodata
align 4
f_zero:     dd 0.0
f_one:      dd 1.0
f_half:     dd 0.5
f_quarter:  dd 0.25
f_inv65536: dd 1.52587891e-5
f_inv255:   dd 0.00392156863
f_eye:      dd 1.6
f_grav:     dd 16.0
f_inset:    dd 0.15                 ; bits start inside the block: 0.15 .. 0.85
f_span:     dd 0.7
f_side:     dd 2.4                  ; speed sideways -1.2 .. 1.2, up 0.6 .. 3.2
f_up:       dd 2.6
f_upmin:    dd 0.6
f_life:     dd 0.4                  ; 0.3 .. 0.7 seconds
f_lifemin:  dd 0.3
f_size:     dd 0.045                ; half a bit's width (nodes)

section .data
fx_seed:    dd 0x3C6EF35F

section .bss
alignb 16
fx:         resb MAX_FX * FX_SIZE
fx_count:   resd 1

section .text

; 0 .. 1 in xmm0 (eax, edx changed)
fx_rand:
    imul eax, [fx_seed], 1103515245
    add eax, 12345
    mov [fx_seed], eax
    shr eax, 16
    cvtsi2ss xmm0, eax
    mulss xmm0, [f_inv65536]
    ret

; void fx_clear(void)
fx_clear:
    mov dword [fx_count], 0
    ret

; void fx_burst(int block, int x, int y, int z, int count) - bits of the
; block fly out of the node
; locals: [0] x, [4] y, [8] z, [12] left, [16] u, [20] v, [24] light
fx_burst:
    ENTER_FN 32
    movzx edi, dil
    test edi, edi
    jz .out
    mov [rsp], esi
    mov [rsp + 4], edx
    mov [rsp + 8], ecx
    mov [rsp + 12], r8d
    ; the corner of its side texture in the atlas
    lea rax, [block_tiles]
    movzx eax, byte [rax + rdi*4 + 1]
    mov ecx, eax
    and ecx, 15
    cvtsi2ss xmm0, ecx
    mulss xmm0, [f_tile_u]
    movss [rsp + 16], xmm0
    shr eax, 4
    cvtsi2ss xmm0, eax
    mulss xmm0, [f_tile_v]
    movss [rsp + 20], xmm0
    ; lit like the place the player stands (the node itself is dark inside)
    movss xmm0, [pos]
    cvttss2si edi, xmm0
    movss xmm0, [pos + 4]
    addss xmm0, [f_eye]
    cvttss2si esi, xmm0
    movss xmm0, [pos + 8]
    cvttss2si edx, xmm0
    call light_get
    mov ecx, eax
    and eax, 15
    shr ecx, 4
    lea rdx, [light_curve]
    movzx eax, byte [rdx + rax]
    movzx ecx, byte [rdx + rcx]
    cvtsi2ss xmm0, eax
    mulss xmm0, [sunlight]
    cvtsi2ss xmm1, ecx
    maxss xmm0, xmm1
    cmp dword [dimension], 1
    jne .lit
    movzx ecx, byte [rdx + NETHER_LIGHT]
    cvtsi2ss xmm1, ecx
    maxss xmm0, xmm1
.lit:
    mulss xmm0, [f_inv255]
    movss [rsp + 24], xmm0
.one:
    cmp dword [rsp + 12], 0
    jle .out
    dec dword [rsp + 12]
    mov eax, [fx_count]
    cmp eax, MAX_FX
    jae .out
    inc dword [fx_count]
    imul eax, eax, FX_SIZE
    lea rbx, [fx]
    add rbx, rax
    ; where: anywhere inside the node; which way: out and up
    xor r12d, r12d
.axis:
    call fx_rand
    mulss xmm0, [f_span]
    addss xmm0, [f_inset]
    cvtsi2ss xmm1, dword [rsp + r12*4]
    addss xmm0, xmm1
    movss [rbx + FX_X + r12*4], xmm0
    call fx_rand
    subss xmm0, [f_half]
    mulss xmm0, [f_side]
    movss [rbx + FX_VX + r12*4], xmm0
    inc r12d
    cmp r12d, 3
    jb .axis
    call fx_rand
    mulss xmm0, [f_up]
    addss xmm0, [f_upmin]
    movss [rbx + FX_VX + 4], xmm0
    call fx_rand
    mulss xmm0, [f_life]
    addss xmm0, [f_lifemin]
    movss [rbx + FX_LIFE], xmm0
    ; one of the 16 quarter squares of the texture
    call fx_rand
    mov eax, [fx_seed]
    shr eax, 20
    mov ecx, eax
    and eax, 3
    cvtsi2ss xmm0, eax
    mulss xmm0, [f_quarter]
    mulss xmm0, [f_rep_u]
    addss xmm0, [rsp + 16]
    movss [rbx + FX_U], xmm0
    shr ecx, 2
    and ecx, 3
    cvtsi2ss xmm0, ecx
    mulss xmm0, [f_quarter]
    mulss xmm0, [f_rep_v]
    addss xmm0, [rsp + 20]
    movss [rbx + FX_V], xmm0
    mov eax, [rsp + 24]
    mov [rbx + FX_LIGHT], eax
    jmp .one
.out:
    LEAVE_FN

; void fx_update(void) - they fall, stop on what they land on, and go
; locals: [0] new x, [4] new y, [8] new z
fx_update:
    ENTER_FN 16
    xor r12d, r12d
.p:
    cmp r12d, [fx_count]
    jae .out
    imul eax, r12d, FX_SIZE
    lea rbx, [fx]
    add rbx, rax
    movss xmm0, [rbx + FX_LIFE]
    subss xmm0, [dt]
    movss [rbx + FX_LIFE], xmm0
    comiss xmm0, [f_zero]
    ja .move
    ; gone: the last one takes its place
    mov eax, [fx_count]
    dec eax
    mov [fx_count], eax
    imul eax, eax, FX_SIZE
    lea rsi, [fx]
    add rsi, rax
    mov rdi, rbx
    mov ecx, FX_SIZE / 8
    rep movsq
    jmp .p                          ; the same place again
.move:
    movss xmm0, [rbx + FX_VX + 4]
    movss xmm1, [dt]
    mulss xmm1, [f_grav]
    subss xmm0, xmm1
    movss [rbx + FX_VX + 4], xmm0
    xor ecx, ecx
.axis:
    movss xmm0, [rbx + FX_VX + rcx*4]
    mulss xmm0, [dt]
    addss xmm0, [rbx + FX_X + rcx*4]
    movss [rsp + rcx*4], xmm0
    inc ecx
    cmp ecx, 3
    jb .axis
    movss xmm0, [rsp]
    movss xmm1, [rsp + 4]
    movss xmm2, [rsp + 8]
    call solid_at
    test eax, eax
    jz .free
    xor eax, eax                    ; it has landed (or hit a wall): it lies there
    mov [rbx + FX_VX], eax
    mov [rbx + FX_VX + 4], eax
    mov [rbx + FX_VX + 8], eax
    jmp .next
.free:
    mov eax, [rsp]
    mov [rbx + FX_X], eax
    mov eax, [rsp + 4]
    mov [rbx + FX_X + 4], eax
    mov eax, [rsp + 8]
    mov [rbx + FX_X + 8], eax
.next:
    inc r12d
    jmp .p
.out:
    LEAVE_FN

; void fx_draw(void) - in node units round the player's chunk (as the
; dropped items): squares facing the player
; locals: [0] centre x, [4] y, [8] z, [12] right x, [16] right z,
;         [20] u1, [24] v1
fx_draw:
    ENTER_FN 32
    cmp dword [fx_count], 0
    je .out
    mov edi, GL_CULL_FACE
    call glDisable PLT
    mov edi, GL_TEXTURE_2D
    call glEnable PLT
    mov edi, GL_ALPHA_TEST
    call glEnable PLT
    mov edi, GL_TEXTURE_2D
    mov esi, [tex_atlas]
    call glBindTexture PLT
    movss xmm0, [cyaw]
    mulss xmm0, [f_size]
    movss [rsp + 12], xmm0
    movss xmm0, [syaw]
    mulss xmm0, [f_size]
    movss [rsp + 16], xmm0
    mov edi, GL_QUADS
    call glBegin PLT
    xor r12d, r12d
.p:
    cmp r12d, [fx_count]
    jae .done
    imul eax, r12d, FX_SIZE
    lea rbx, [fx]
    add rbx, rax
    movss xmm0, [rbx + FX_LIGHT]
    movaps xmm1, xmm0
    movaps xmm2, xmm0
    movss xmm3, [f_one]
    call glColor4f PLT
    mov eax, [cur_pcx]
    shl eax, 4
    cvtsi2ss xmm1, eax
    movss xmm0, [rbx + FX_X]
    subss xmm0, xmm1
    movss [rsp], xmm0
    mov eax, [rbx + FX_X + 4]
    mov [rsp + 4], eax
    mov eax, [cur_pcz]
    shl eax, 4
    cvtsi2ss xmm1, eax
    movss xmm0, [rbx + FX_X + 8]
    subss xmm0, xmm1
    movss [rsp + 8], xmm0
    movss xmm0, [f_quarter]
    mulss xmm0, [f_rep_u]
    addss xmm0, [rbx + FX_U]
    movss [rsp + 20], xmm0
    movss xmm0, [f_quarter]
    mulss xmm0, [f_rep_v]
    addss xmm0, [rbx + FX_V]
    movss [rsp + 24], xmm0
; FXV u, v, side (-1 left, 1 right), up (-1, 1)
%macro FXV 4
    movss xmm0, %1
    movss xmm1, %2
    call glTexCoord2f PLT
    movss xmm0, [rsp]
    movss xmm2, [rsp + 8]
%if %3 > 0
    addss xmm0, [rsp + 12]
    addss xmm2, [rsp + 16]
%else
    subss xmm0, [rsp + 12]
    subss xmm2, [rsp + 16]
%endif
    movss xmm1, [rsp + 4]
%if %4 > 0
    addss xmm1, [f_size]
%else
    subss xmm1, [f_size]
%endif
    call glVertex3f PLT
%endmacro
    FXV [rbx + FX_U], [rsp + 24], -1, -1
    FXV [rsp + 20], [rsp + 24], 1, -1
    FXV [rsp + 20], [rbx + FX_V], 1, 1
    FXV [rbx + FX_U], [rbx + FX_V], -1, 1
    inc r12d
    jmp .p
.done:
    call glEnd PLT
    movss xmm0, [f_one]
    movaps xmm1, xmm0
    movaps xmm2, xmm0
    movaps xmm3, xmm0
    call glColor4f PLT
    mov edi, GL_ALPHA_TEST
    call glDisable PLT
    mov edi, GL_CULL_FACE
    call glEnable PLT
.out:
    LEAVE_FN

NOEXECSTACK
