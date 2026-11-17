%include "common.inc"

global weather_update, weather_draw, weather_reset, weather_set
global raining, rain_level, weather_timer, l_cave, l_sky, echo_push, cave_t

extern dt, pos, sunlight, dimension, world_get, world_find, chunk_hmap
extern cur_pcx, cur_pcz, syaw, cyaw, eye_h, upload_texture, sound_play, light_get
extern glEnable, glDisable, glBindTexture, glBegin, glEnd, glColor4f
extern glTexCoord2f, glVertex3f, glBlendFunc, glDepthMask, glGenTextures

GL_QUADS        equ 7
GL_TEXTURE_2D   equ 0x0DE1
GL_ALPHA_TEST   equ 0x0BC0
GL_CULL_FACE    equ 0x0B44
GL_BLEND        equ 0x0BE2
GL_SRC_ALPHA    equ 0x0302
GL_ONE_MINUS_SRC_ALPHA equ 0x0303

RADIUS      equ 9                   ; columns drawn round the player
MAX_ECHO    equ 8
K_NONE      equ 0
K_RAIN      equ 1
K_SNOW      equ 2

section .rodata
align 4
f_zero:     dd 0.0
f_half:     dd 0.5
f_one:      dd 1.0
f_fade:     dd 0.1                  ; fades in or out in 10 s
f_clear0:   dd 600.0                ; clear: 10 min ..
f_clearr:   dd 900.0                ; .. + up to 15
f_rain0:    dd 300.0                ; rain: 5 min ..
f_rainr:    dd 300.0                ; .. + up to 5
f_inv65536: dd 1.52587891e-5
f_dim:      dd 0.3                  ; daylight lost in full rain
f_below:    dd 10.0                 ; drawn from this far below the eyes ..
f_above:    dd 12.0                 ; .. to this far above
f_rainv:    dd 0.25                 ; the rain texture: 4 nodes tall
f_rainsp:   dd 11.0                 ; nodes a second
f_snowsp:   dd 1.4
f_drift:    dd 0.08
f_rainalpha: dd 0.55
f_snowalpha: dd 0.95
f_r2:       dd 100.0                ; (RADIUS + 1)^2
f_lit0:     dd 0.22
f_lit1:     dd 0.78
f_snd:      dd 0.85                 ; the rain sound again after this
f_sndvol:   dd 0.9
f_inv15:    dd 0.0666666667
f_cave0:    dd 13.0                 ; a cave sound every 13 .. 20 s
f_caver:    dd 7.0
f_cavev:    dd 0.9
f_third:    dd 0.3333333
f_drip0:    dd 3.0                  ; a drop of water every 3 .. 4 s
f_five:     dd 5.0
f_dripv0:   dd 0.3                  ; loudness 0.3 .. 0.5
f_dripvr:   dd 0.2
f_dripp0:   dd 0.9                  ; speed 0.9 .. 1.1
f_drippr:   dd 0.2
; a step's echoes in a cave: delay, loudness and speed of each
echo_spec:  dd 0.15, 0.40, 0.98
            dd 0.32, 0.18, 0.96
f_open:     dd 0.85                 ; rain: 0.15 shut in .. 1 under the sky
f_shut:     dd 0.15
f_hash:     dd 0.0039215686

section .data
align 4
weather_timer: dd 900.0             ; seconds to the next turn
w_seed:     dd 0x2545F491
cave_t:     dd 4.0                  ; the first cave sound soon after going in
drip_t:     dd 1.0

section .bss
alignb 4
raining:    resd 1                  ; 1 while it rains (or is coming)
rain_level: resd 1                  ; 0 .. 1, fading
w_clock:    resd 1                  ; seconds, for the falling
snd_t:      resd 1
tex_rain:   resd 1
tex_snow:   resd 1
tex_ready:  resd 1
pix:        resd 16 * 64
col_lit:    resd 1
l_sky:      resd 1                  ; listen's findings
l_blk:      resd 1
l_kind:     resd 1
l_cave:     resd 1
echo_q:     resd MAX_ECHO * 4       ; sounds to play again: id, loudness,
                                    ; speed, seconds left (0: free)
col_alpha:  resd 1

section .text

; 0 .. 1 in xmm0
w_rand:
    imul eax, [w_seed], 1103515245
    add eax, 12345
    mov [w_seed], eax
    shr eax, 16
    cvtsi2ss xmm0, eax
    mulss xmm0, [f_inv65536]
    ret

; the time until the weather turns again, for the weather now
new_timer:
    call w_rand
    cmp dword [raining], 0
    jne .rain
    mulss xmm0, [f_clearr]
    addss xmm0, [f_clear0]
    movss [weather_timer], xmm0
    ret
.rain:
    mulss xmm0, [f_rainr]
    addss xmm0, [f_rain0]
    movss [weather_timer], xmm0
    ret

; void weather_reset(void) - a new world: clear, rain some time off
weather_reset:
    mov dword [raining], 0
    mov dword [rain_level], 0
    jmp new_timer

; void weather_set(int rain) - rain now (1) or clear now (0), at once
weather_set:
    mov [raining], edi
    cvtsi2ss xmm0, edi
    movss [rain_level], xmm0
    jmp new_timer

; eax = the world y just above the highest light-tight node of column
; (edi, esi), or -10000 when it is not loaded; ecx = what kind of weather
; falls on it
col_top:
    push rbx
    push r12
    push r13
    mov r12d, edi
    mov r13d, esi
    sar edi, 4
    sar esi, 4
    call world_find
    test eax, eax
    js .none
    shl eax, 8
    mov ecx, r13d
    and ecx, 15
    shl ecx, 4
    mov edx, r12d
    and edx, 15
    or ecx, edx
    add eax, ecx
    lea rcx, [chunk_hmap]
    movzx ebx, word [rcx + rax*2]
    add ebx, WORLD_YMIN             ; the top (world y)
    mov edi, r12d
    lea esi, [rbx - 1]
    mov edx, r13d
    call world_get
    mov ecx, K_SNOW
    cmp eax, B_SNOW
    je .k
    cmp eax, B_SNOWDIRT
    je .k
    mov ecx, K_NONE
    cmp eax, B_DSAND
    je .k
    cmp eax, B_DSTONE
    je .k
    mov ecx, K_RAIN
.k:
    mov eax, ebx
    jmp .out
.none:
    mov eax, -10000
    xor ecx, ecx
.out:
    pop r13
    pop r12
    pop rbx
    ret

; void weather_update(void) - once a frame (after the day clock)
weather_update:
    push rbx
    sub rsp, 16
    cmp dword [dimension], 2
    jne .notisland
    mov dword [sunlight], 0x3f333333 ; the island: a steady dim light (0.7)
.notisland:
    movss xmm0, [w_clock]
    addss xmm0, [dt]
    movss [w_clock], xmm0
    ; the turn of the weather
    movss xmm0, [weather_timer]
    subss xmm0, [dt]
    movss [weather_timer], xmm0
    comiss xmm0, [f_zero]
    ja .fade
    xor dword [raining], 1
    call new_timer
.fade:
    ; towards raining or clear
    cvtsi2ss xmm1, dword [raining]
    cmp dword [dimension], 0
    je .ow
    xorps xmm1, xmm1                ; never in the nether
.ow:
    movss xmm0, [rain_level]
    movss xmm2, [dt]
    mulss xmm2, [f_fade]
    comiss xmm1, xmm0
    ja .up
    subss xmm0, xmm2
    maxss xmm0, xmm1
    jmp .lvl
.up:
    addss xmm0, xmm2
    minss xmm0, xmm1
.lvl:
    movss [rain_level], xmm0
    ; greyer daylight
    mulss xmm0, [f_dim]
    movss xmm1, [f_one]
    subss xmm1, xmm0
    mulss xmm1, [sunlight]
    movss [sunlight], xmm1
    ; where the player's head is: how much sky reaches it, and is there
    ; rock well over it (a cave)
    call listen
    call echo_tick
    ; the rain: as loud as the sky open to the head; none in a cave
    movss xmm0, [snd_t]
    subss xmm0, [dt]
    movss [snd_t], xmm0
    comiss xmm0, [f_zero]
    ja .amb
    movss xmm0, [rain_level]
    comiss xmm0, [f_hash]
    jb .amb
    mov eax, [f_snd]
    mov [snd_t], eax
    cmp dword [l_kind], K_RAIN
    jne .amb
    cmp dword [l_cave], 0
    jne .amb
    cvtsi2ss xmm1, dword [l_sky]
    mulss xmm1, [f_inv15]
    mulss xmm1, [f_open]
    addss xmm1, [f_shut]            ; 0.15 shut in .. 1 under the open sky
    movss xmm0, [rain_level]
    mulss xmm0, [f_sndvol]
    mulss xmm0, xmm1
    movss xmm1, [f_one]
    mov edi, S_RAIN
    call sound_play
.amb:
    ; in a cave: a drop of water every 3 to 4 seconds, and every 13 to 20
    ; seconds one of the cave sounds
    call drops_tick
    cmp dword [l_cave], 0
    je .out
    movss xmm0, [cave_t]
    subss xmm0, [dt]
    movss [cave_t], xmm0
    comiss xmm0, [f_zero]
    ja .out
    call w_rand
    mulss xmm0, [f_caver]
    addss xmm0, [f_cave0]
    movss [cave_t], xmm0
    call w_rand
    mov edi, S_CAVE1
    comiss xmm0, [f_third]
    jb .cs
    mov edi, S_CAVE2
    addss xmm0, xmm0
    comiss xmm0, [f_one]
    jb .cs
    mov edi, S_CAVE3
.cs:
    movss xmm0, [f_cavev]
    movss xmm1, [f_one]
    call sound_play
.out:
    add rsp, 16
    pop rbx
    ret

; void echo_push(int id, float loudness, float speed) - a step in a cave:
; it is heard again twice, softer and a little lower. Keeps edi, xmm0, xmm1.
echo_push:
    cmp dword [l_cave], 0
    je .out
    xor ecx, ecx                    ; which echo
    lea rdx, [echo_q]
.e:
    ; a free place
    xor eax, eax
.f:
    mov r8d, eax
    shl r8d, 4                      ; 16 bytes each
    cmp dword [rdx + r8 + 12], 0
    je .got
    inc eax
    cmp eax, MAX_ECHO
    jb .f
    ret
.got:
    shl eax, 4
    mov [rdx + rax], edi
    lea r8, [echo_spec]
    imul r9d, ecx, 12
    movss xmm2, xmm0
    mulss xmm2, [r8 + r9 + 4]
    movss [rdx + rax + 4], xmm2
    movss xmm2, xmm1
    mulss xmm2, [r8 + r9 + 8]
    movss [rdx + rax + 8], xmm2
    mov r10d, [r8 + r9]
    mov [rdx + rax + 12], r10d
    inc ecx
    cmp ecx, 2
    jb .e
.out:
    ret

; echo_tick - the echoes whose time has come are played
echo_tick:
    push rbx
    xor ebx, ebx
.e:
    mov eax, ebx
    shl eax, 4
    lea rcx, [echo_q]
    add rcx, rax
    cmp dword [rcx + 12], 0
    je .n
    movss xmm0, [rcx + 12]
    subss xmm0, [dt]
    movss [rcx + 12], xmm0
    comiss xmm0, [f_zero]
    ja .n
    mov dword [rcx + 12], 0
    mov edi, [rcx]
    movss xmm0, [rcx + 4]
    movss xmm1, [rcx + 8]
    call sound_play
.n:
    inc ebx
    cmp ebx, MAX_ECHO
    jb .e
    pop rbx
    ret

; drops_tick - in a cave a drop of water falls every 3 to 4 seconds: one
; of the five, a little louder or softer, higher or lower each time
drops_tick:
    cmp dword [l_cave], 0
    je .ret
    sub rsp, 24
    movss xmm0, [drip_t]
    subss xmm0, [dt]
    movss [drip_t], xmm0
    comiss xmm0, [f_zero]
    ja .out
    call w_rand
    addss xmm0, [f_drip0]           ; 3 .. 4 s to the next
    movss [drip_t], xmm0
    call w_rand
    mulss xmm0, [f_five]
    cvttss2si eax, xmm0
    cmp eax, 4
    jbe .k
    mov eax, 4
.k:
    add eax, S_DRIP1
    mov [rsp], eax
    call w_rand
    mulss xmm0, [f_dripvr]
    addss xmm0, [f_dripv0]          ; loudness
    movss [rsp + 4], xmm0
    call w_rand
    mulss xmm0, [f_drippr]
    addss xmm0, [f_dripp0]          ; speed
    movaps xmm1, xmm0
    movss xmm0, [rsp + 4]
    mov edi, [rsp]
    call sound_play
.out:
    add rsp, 24
.ret:
    ret

; listen - l_sky the sky light at the head, l_kind the weather that falls
; on its column, l_cave 1 in the dark under 4 or more nodes of ground
; (overworld only)
listen:
    push rbx
    push r12
    push r13
    movss xmm0, [pos]
    call floor_i
    mov r12d, eax
    movss xmm0, [pos + 4]
    addss xmm0, [eye_h]
    call floor_i
    mov ebx, eax
    movss xmm0, [pos + 8]
    call floor_i
    mov r13d, eax
    mov edi, r12d
    mov esi, ebx
    mov edx, r13d
    call light_get
    mov ecx, eax
    and eax, 15
    mov [l_sky], eax
    shr ecx, 4
    and ecx, 15
    mov [l_blk], ecx
    mov edi, r12d
    mov esi, r13d
    call col_top
    mov [l_kind], ecx
    mov dword [l_cave], 0
    cmp dword [dimension], 0
    jne .out
    cmp dword [l_sky], 2
    ja .out
    cmp dword [l_blk], 10           ; (a well lit room is no cave)
    ja .out
    lea ecx, [rbx + 4]
    cmp eax, ecx
    jle .out
    mov dword [l_cave], 1
.out:
    pop r13
    pop r12
    pop rbx
    ret

; eax = floor(xmm0)
floor_i:
    cvttss2si eax, xmm0
    cvtsi2ss xmm1, eax
    comiss xmm1, xmm0
    jbe .ok
    dec eax
.ok:
    ret

; make the two textures (once there is a GL context)
make_textures:
    push rbx
    ; rain: thin streaks every 4 texels, 6 long in 16, staggered
    xor ebx, ebx
.rp:
    mov eax, ebx
    and eax, 15                     ; x
    mov ecx, ebx
    shr ecx, 4                      ; y
    xor edx, edx
    mov r8d, eax
    and r8d, 3
    cmp r8d, 1
    jne .rput
    imul r8d, eax, 13
    add r8d, ecx
    and r8d, 15
    cmp r8d, 6
    jae .rput
    mov edx, 0x96ffe0c8             ; pale blue, alpha 150
.rput:
    lea rax, [pix]
    mov [rax + rbx*4], edx
    inc ebx
    cmp ebx, 16 * 64
    jb .rp
    mov edi, 1
    lea rsi, [tex_rain]
    call glGenTextures PLT
    mov edi, [tex_rain]
    lea rsi, [pix]
    mov edx, 16
    mov ecx, 64
    call upload_texture
    ; snow: single white flakes scattered
    xor ebx, ebx
.sp:
    mov eax, ebx
    and eax, 15
    mov ecx, ebx
    shr ecx, 4
    imul eax, eax, 7
    imul ecx, ecx, 13
    add eax, ecx
    xor edx, edx
    mov ecx, 19
    div ecx
    xor eax, eax
    test edx, edx
    jnz .sput
    mov eax, 0xf0ffffff
.sput:
    lea rcx, [pix]
    mov [rcx + rbx*4], eax
    inc ebx
    cmp ebx, 16 * 16
    jb .sp
    mov edi, 1
    lea rsi, [tex_snow]
    call glGenTextures PLT
    mov edi, [tex_snow]
    lea rsi, [pix]
    mov edx, 16
    mov ecx, 16
    call upload_texture
    mov dword [tex_ready], 1
    pop rbx
    ret

; void weather_draw(void) - in node units round the player's chunk (as the
; dropped items); the falling sheets, rain then snow
weather_draw:
    cmp dword [dimension], 0
    jne .ret
    movss xmm0, [rain_level]
    comiss xmm0, [f_hash]
    jb .ret
    push rbx
    sub rsp, 16
    cmp dword [tex_ready], 0
    jne .have
    call make_textures
.have:
    mov edi, GL_TEXTURE_2D
    call glEnable PLT
    mov edi, GL_BLEND
    call glEnable PLT
    mov edi, GL_SRC_ALPHA
    mov esi, GL_ONE_MINUS_SRC_ALPHA
    call glBlendFunc PLT
    xor edi, edi
    call glDepthMask PLT
    mov edi, GL_CULL_FACE
    call glDisable PLT
    mov edi, GL_ALPHA_TEST
    call glDisable PLT
    ; their light: the (greyed) daylight
    movss xmm0, [sunlight]
    mulss xmm0, [f_lit1]
    addss xmm0, [f_lit0]
    movss [col_lit], xmm0
    mov ebx, K_RAIN
.kind:
    mov edi, GL_TEXTURE_2D
    mov esi, [tex_rain]
    cmp ebx, K_RAIN
    je .bind
    mov esi, [tex_snow]
.bind:
    call glBindTexture PLT
    mov edi, GL_QUADS
    call glBegin PLT
    mov edi, ebx
    call sheets
    call glEnd PLT
    inc ebx
    cmp ebx, K_SNOW
    jbe .kind
    mov edi, 1
    call glDepthMask PLT
    mov edi, GL_BLEND
    call glDisable PLT
    mov edi, GL_CULL_FACE
    call glEnable PLT
    movss xmm0, [f_one]
    movaps xmm1, xmm0
    movaps xmm2, xmm0
    movaps xmm3, xmm0
    call glColor4f PLT
    add rsp, 16
    pop rbx
.ret:
    ret

; sheets(edi kind) - a sheet in every column round the player that gets
; this kind of weather
; locals: [0] kind, [4] dx, [8] dz, [12] px, [16] pz, [20] bottom, [24] top,
;         [28] x, [32] z (centre, chunk relative), [36] v0, [40] v1,
;         [44] u0, [48] eye y
sheets:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 64
    mov [rsp], edi
    movss xmm0, [pos]
    cvttss2si eax, xmm0
    mov [rsp + 12], eax
    movss xmm0, [pos + 8]
    cvttss2si eax, xmm0
    mov [rsp + 16], eax
    movss xmm0, [pos + 4]
    addss xmm0, [eye_h]
    movss [rsp + 48], xmm0
    mov r12d, -RADIUS
.z:
    mov r13d, -RADIUS
.x:
    mov eax, r12d
    imul eax, eax
    mov ecx, r13d
    imul ecx, ecx
    add eax, ecx
    cmp eax, RADIUS * RADIUS
    jg .next
    cvtsi2ss xmm0, eax
    divss xmm0, [f_r2]
    movss xmm1, [f_one]
    subss xmm1, xmm0                ; fainter further out
    movss [rsp + 4], xmm1
    mov edi, [rsp + 12]
    add edi, r13d
    mov esi, [rsp + 16]
    add esi, r12d
    call col_top
    cmp ecx, [rsp]
    jne .next
    ; from the top of the column (or below the eyes) to above the head
    cvtsi2ss xmm0, eax
    movss xmm1, [rsp + 48]
    subss xmm1, [f_below]
    maxss xmm0, xmm1
    movss [rsp + 20], xmm0
    movss xmm1, [rsp + 48]
    addss xmm1, [f_above]
    movss [rsp + 24], xmm1
    comiss xmm0, xmm1
    jae .next
    ; where (chunk relative), and a texture offset of its own
    mov eax, [rsp + 12]
    add eax, r13d
    mov r14d, eax
    mov ecx, [cur_pcx]
    shl ecx, 4
    sub eax, ecx
    cvtsi2ss xmm0, eax
    addss xmm0, [f_half]
    movss [rsp + 28], xmm0
    mov eax, [rsp + 16]
    add eax, r12d
    mov r15d, eax
    mov ecx, [cur_pcz]
    shl ecx, 4
    sub eax, ecx
    cvtsi2ss xmm0, eax
    addss xmm0, [f_half]
    movss [rsp + 32], xmm0
    imul eax, r14d, 0x9E3779B1
    imul ecx, r15d, 0x85EBCA77
    xor eax, ecx
    shr eax, 24
    cvtsi2ss xmm3, eax
    mulss xmm3, [f_hash]            ; 0 .. 1
    ; v: falling with time; snow drifts sideways a little too
    movss xmm4, [w_clock]
    xorps xmm5, xmm5
    cmp dword [rsp], K_RAIN
    jne .snowv
    mulss xmm4, [f_rainsp]
    movss xmm6, [f_rainv]
    movss xmm7, [f_rainalpha]
    jmp .v
.snowv:
    movss xmm5, xmm4
    mulss xmm5, [f_drift]
    addss xmm5, xmm3
    mulss xmm4, [f_snowsp]
    movss xmm6, [f_one]
    movss xmm7, [f_snowalpha]
.v:
    movss [rsp + 44], xmm5
    movss xmm0, [rsp + 20]
    addss xmm0, xmm4
    mulss xmm0, xmm6
    addss xmm0, xmm3
    movss [rsp + 36], xmm0
    movss xmm0, [rsp + 24]
    addss xmm0, xmm4
    mulss xmm0, xmm6
    addss xmm0, xmm3
    movss [rsp + 40], xmm0
    ; its colour
    movss xmm3, [rsp + 4]
    mulss xmm3, xmm7
    mulss xmm3, [rain_level]
    movss xmm0, [col_lit]
    movaps xmm1, xmm0
    movaps xmm2, xmm0
    call glColor4f PLT
    ; a sheet facing the player: across the view (cyaw, syaw), half a node
    ; each way
%macro WV 3                         ; u (0 / 1), v local, side (-1 / 1)
    movss xmm0, [rsp + 44]
%if %1
    addss xmm0, [f_one]
%endif
    movss xmm1, [rsp + %2]
    call glTexCoord2f PLT
    movss xmm3, [cyaw]
    mulss xmm3, [f_half]
    movss xmm4, [syaw]
    mulss xmm4, [f_half]
    movss xmm0, [rsp + 28]
    movss xmm2, [rsp + 32]
%if %3 > 0
    addss xmm0, xmm3
    addss xmm2, xmm4
%else
    subss xmm0, xmm3
    subss xmm2, xmm4
%endif
%if %2 == 36
    movss xmm1, [rsp + 20]
%else
    movss xmm1, [rsp + 24]
%endif
    call glVertex3f PLT
%endmacro
    WV 0, 36, -1
    WV 1, 36, 1
    WV 1, 40, 1
    WV 0, 40, -1
.next:
    inc r13d
    cmp r13d, RADIUS
    jle .x
    inc r12d
    cmp r12d, RADIUS
    jle .z
    add rsp, 64
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

NOEXECSTACK
