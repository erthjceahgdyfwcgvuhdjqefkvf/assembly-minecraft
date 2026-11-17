%include "common.inc"

global texgen_atlas, atlas_rgba, atlas_w, atlas_h, block_tiles
global icons_build, icons_rgba

; tile record: r, g, b, variation, pattern, alpha, r2, g2, b2, pad x3
TL_SIZE equ 12
P_NOISE   equ 0
P_TOPSTRIP equ 1
P_VSTRIPE equ 2
P_RINGS   equ 3
P_LEAVES  equ 4
P_GLASS   equ 5
P_PLANKS  equ 6
P_COBBLE  equ 7
P_BRICK   equ 8
P_WATER   equ 9
P_CRACK   equ 10                    ; digging cracks; stage in the r2 field
P_ORE     equ 11                    ; stone with specks of colour 2
P_TABLETOP equ 12
P_TABLESIDE equ 13
P_FURNACE equ 14                    ; front with an opening in colour 2
P_TORCH   equ 15
P_SMOOTH  equ 16                    ; noise with a darker rim
P_FARMLAND equ 17                   ; furrows: darker every fourth row
P_PLANT   equ 18                    ; blades up to a height (byte 9); byte 10:
                                    ; 1 = grain head, 2 = root tops (colour 2)
P_WOOL    equ 19                    ; knitted: faint diagonal stitches
P_FLOWER  equ 20                    ; stem (colour 1) and a flower head (colour 2)
P_TNT     equ 21                    ; byte 9: 0 side (white band), 1 top (fuse), 2 bottom
P_FLAME   equ 22                    ; tongues of fire, colour 2 (yellow) at the bottom
P_SGLASS  equ 23                    ; stained glass: see-through tint, solid rim
P_BEACON  equ 24                    ; glass shell (colour 2) round a bright core
P_METAL   equ 25                    ; blocks of iron / gold / diamond / coal: style in byte 9
P_STICKS  equ 26                    ; three posts side by side: an unlit bluestone
                                    ; torch, a lit one and a lever handle
P_LAMP    equ 27                    ; a lamp: panes in a frame
P_SLAB    equ 28                    ; repeater / comparator top: byte 9 the marks
P_RAIL    equ 29                    ; byte 9: 0 straight, 1 corner, 2 powered, 3 powered on
P_DOOR    equ 30                    ; byte 9: 0 door bottom, 1 door top (window),
                                    ; 2 trapdoor; + 4 iron
P_BIRCH   equ 31                    ; pale bark with dark dashes (colour 2)
P_CHEST   equ 32                    ; byte 9: 0 front (latch), 1 side, 2 top
NUM_TILES equ 157


%macro TILE 6-11 0, 0, 0, 0, 0
    db %1, %2, %3, %4, %5, %6, %7, %8, %9, %10, %11, 0
%endmacro

section .rodata
tiles:
    TILE 128, 128, 128, 40, P_NOISE,    255                  ; 0 stone
    TILE 134,  96,  67, 40, P_NOISE,    255                  ; 1 dirt
    TILE  90, 150,  60, 40, P_NOISE,    255                  ; 2 grass top
    TILE 134,  96,  67, 40, P_TOPSTRIP, 255,  90, 150,  60   ; 3 grass side
    TILE 219, 207, 163, 24, P_NOISE,    255                  ; 4 sand
    TILE  40,  90, 200, 20, P_WATER,    170                  ; 5 water
    TILE 102,  80,  50, 30, P_VSTRIPE,  255                  ; 6 log side
    TILE 160, 130,  85, 20, P_RINGS,    255, 102,  80,  50   ; 7 log top
    TILE  50, 120,  40, 60, P_LEAVES,   255                  ; 8 leaves
    TILE 240, 245, 250, 12, P_NOISE,    255                  ; 9 snow
    TILE 134,  96,  67, 40, P_TOPSTRIP, 255, 240, 245, 250   ; 10 snowy dirt side
    TILE 210, 160, 110, 24, P_NOISE,    255                  ; 11 desert sand
    TILE 170, 100,  70, 36, P_NOISE,    255                  ; 12 desert stone
    TILE 170, 160,  80, 36, P_NOISE,    255                  ; 13 dry grass top
    TILE 134,  96,  67, 40, P_TOPSTRIP, 255, 170, 160,  80   ; 14 dry grass side
    TILE 120, 120, 120, 50, P_COBBLE,   255                  ; 15 cobble
    TILE 180, 140,  90, 20, P_PLANKS,   255                  ; 16 planks
    TILE 200, 230, 240,  0, P_GLASS,    255                  ; 17 glass
    TILE 130, 125, 120, 90, P_NOISE,    255                  ; 18 gravel
    TILE  60, 140,  60, 30, P_VSTRIPE,  255                  ; 19 cactus side
    TILE  80, 160,  80, 20, P_NOISE,    255                  ; 20 cactus top
    TILE  30,  80,  40, 50, P_LEAVES,   255                  ; 21 pine needles
    TILE  70,  50,  35, 30, P_VSTRIPE,  255                  ; 22 pine log side
    TILE 160,  70,  55, 30, P_BRICK,    255, 200, 200, 190   ; 23 brick
    TILE   0,   0,   0,  0, P_CRACK,    200, 0               ; 24-28 cracks
    TILE   0,   0,   0,  0, P_CRACK,    200, 1
    TILE   0,   0,   0,  0, P_CRACK,    200, 2
    TILE   0,   0,   0,  0, P_CRACK,    200, 3
    TILE   0,   0,   0,  0, P_CRACK,    200, 4
    TILE  55,  55,  55, 90, P_NOISE,    255                  ; 29 bedrock
    TILE 128, 128, 128, 40, P_ORE,      255,  25,  25,  25   ; 30 coal ore
    TILE 128, 128, 128, 40, P_ORE,      255, 215, 170, 140   ; 31 iron ore
    TILE 128, 128, 128, 40, P_ORE,      255, 250, 215,  60   ; 32 gold ore
    TILE 128, 128, 128, 40, P_ORE,      255,  90, 230, 225   ; 33 diamond ore
    TILE 180, 140,  90, 20, P_TABLETOP, 255                  ; 34 crafting table top
    TILE 180, 140,  90, 20, P_TABLESIDE, 255, 110, 110, 110  ; 35 crafting table side
    TILE 125, 125, 125, 40, P_FURNACE,  255,  20,  20,  20   ; 36 furnace front
    TILE 125, 125, 125, 40, P_FURNACE,  255, 255, 150,  40   ; 37 furnace front, lit
    TILE 140, 140, 140, 20, P_SMOOTH,   255                  ; 38 furnace top
    TILE 110,  80,  40, 10, P_TORCH,    255, 255, 220,  80   ; 39 torch
    TILE 158, 164, 178, 14, P_NOISE,    255                  ; 40 clay
    TILE 216, 216, 216,  8, P_METAL,    255, 0, 0, 0, 1     ; 41 block of iron
    TILE 245, 205,  60,  8, P_METAL,    255, 0, 0, 0, 2     ; 42 block of gold
    TILE 100, 225, 215,  8, P_METAL,    255, 0, 0, 0, 3     ; 43 block of diamond
    TILE  64,  64,  68,  8, P_METAL,    255, 0, 0, 0, 4     ; 44 block of coal
    TILE 104,  72,  46, 30, P_FARMLAND, 255                  ; 45 farmland top
    TILE  86, 156,  62, 40, P_PLANT,    255,   0,   0,   0, 13, 0   ; 46 tall grass
    TILE  76, 160,  56, 30, P_PLANT,    255,   0,   0,   0,  2, 0   ; 47-54 wheat
    TILE  76, 160,  56, 30, P_PLANT,    255,   0,   0,   0,  4, 0
    TILE  80, 158,  56, 30, P_PLANT,    255,   0,   0,   0,  6, 0
    TILE  86, 156,  56, 30, P_PLANT,    255,   0,   0,   0,  8, 0
    TILE  96, 156,  56, 30, P_PLANT,    255,   0,   0,   0, 10, 0
    TILE 120, 156,  60, 30, P_PLANT,    255, 170, 170,  70, 12, 1
    TILE 160, 156,  64, 30, P_PLANT,    255, 200, 180,  80, 14, 1
    TILE 196, 164,  70, 30, P_PLANT,    255, 226, 196,  96, 15, 1
    TILE  70, 150,  50, 30, P_PLANT,    255,   0,   0,   0,  3, 0   ; 55-58 carrots
    TILE  70, 150,  50, 30, P_PLANT,    255,   0,   0,   0,  5, 0
    TILE  70, 152,  50, 30, P_PLANT,    255,   0,   0,   0,  7, 0
    TILE  70, 152,  50, 30, P_PLANT,    255, 232, 124,  34,  9, 2
    TILE 233, 236, 236, 18, P_WOOL,     255                  ; 59 white wool
    TILE 240, 118,  19, 18, P_WOOL,     255                  ; 60 orange wool
    TILE 189,  68, 179, 18, P_WOOL,     255                  ; 61 magenta wool
    TILE  58, 175, 217, 18, P_WOOL,     255                  ; 62 light blue wool
    TILE 248, 198,  39, 18, P_WOOL,     255                  ; 63 yellow wool
    TILE 112, 185,  25, 18, P_WOOL,     255                  ; 64 lime wool
    TILE 237, 141, 172, 18, P_WOOL,     255                  ; 65 pink wool
    TILE  62,  68,  71, 18, P_WOOL,     255                  ; 66 gray wool
    TILE 142, 142, 134, 18, P_WOOL,     255                  ; 67 light gray wool
    TILE  21, 137, 145, 18, P_WOOL,     255                  ; 68 cyan wool
    TILE 121,  42, 172, 18, P_WOOL,     255                  ; 69 purple wool
    TILE  53,  57, 157, 18, P_WOOL,     255                  ; 70 blue wool
    TILE 114,  71,  40, 18, P_WOOL,     255                  ; 71 brown wool
    TILE  84, 109,  27, 18, P_WOOL,     255                  ; 72 green wool
    TILE 161,  39,  34, 18, P_WOOL,     255                  ; 73 red wool
    TILE  20,  21,  25, 18, P_WOOL,     255                  ; 74 black wool
    TILE 207, 213, 214,  3, P_NOISE,    255                  ; 75 white concrete
    TILE 224,  97,   1,  3, P_NOISE,    255                  ; 76 orange concrete
    TILE 169,  48, 159,  3, P_NOISE,    255                  ; 77 magenta concrete
    TILE  36, 137, 199,  3, P_NOISE,    255                  ; 78 light blue concrete
    TILE 241, 175,  21,  3, P_NOISE,    255                  ; 79 yellow concrete
    TILE  94, 169,  24,  3, P_NOISE,    255                  ; 80 lime concrete
    TILE 213, 101, 142,  3, P_NOISE,    255                  ; 81 pink concrete
    TILE  54,  57,  61,  3, P_NOISE,    255                  ; 82 gray concrete
    TILE 125, 125, 115,  3, P_NOISE,    255                  ; 83 light gray concrete
    TILE  21, 119, 136,  3, P_NOISE,    255                  ; 84 cyan concrete
    TILE 100,  32, 156,  3, P_NOISE,    255                  ; 85 purple concrete
    TILE  45,  47, 143,  3, P_NOISE,    255                  ; 86 blue concrete
    TILE  96,  60,  32,  3, P_NOISE,    255                  ; 87 brown concrete
    TILE  73,  91,  36,  3, P_NOISE,    255                  ; 88 green concrete
    TILE 142,  33,  33,  3, P_NOISE,    255                  ; 89 red concrete
    TILE   8,  10,  15,  3, P_NOISE,    255                  ; 90 black concrete
    TILE  60, 140,  50, 10, P_FLOWER,   255, 248, 214,  40   ; 91 yellow flower
    TILE  60, 140,  50, 10, P_FLOWER,   255, 214,  36,  36   ; 92 red flower
    TILE 166,  40,  40, 16, P_NOISE,    255                  ; 93 bed, foot (blanket)
    TILE 166,  40,  40, 16, P_TOPSTRIP, 255, 236, 236, 232   ; 94 bed, head (pillow)
    TILE 180, 140,  90, 20, P_ORE,      255, 200,  60, 190   ; 95 dye maker
    TILE 212,  84,  14, 40, P_ORE,      255, 255, 196,  56   ; 96 lava
    TILE  22,  16,  34, 30, P_ORE,      255,  62,  42,  92   ; 97 obsidian
    TILE 200,  44,  34, 16, P_TNT,      255, 232, 230, 220, 0, 0   ; 98 TNT side
    TILE 200,  44,  34, 16, P_TNT,      255, 232, 230, 220, 1, 0   ; 99 TNT top
    TILE 200,  44,  34, 16, P_TNT,      255, 232, 230, 220, 2, 0   ; 100 TNT bottom
    TILE 232,  92,  24, 30, P_FLAME,    255, 255, 214,  70   ; 101 fire
    TILE 112,  40,  38, 50, P_ORE,      255,  70,  22,  24   ; 102 netherrack
    TILE  92,  30, 168, 40, P_ORE,      200, 196, 120, 255   ; 103 nether portal
    TILE 112, 200,  92, 20, P_SMOOTH,   200                  ; 104 slime block
    TILE 233, 236, 236,  6, P_SGLASS,   140                  ; 105 white stained glass
    TILE 240, 118,  19,  6, P_SGLASS,   140                  ; 106 orange stained glass
    TILE 189,  68, 179,  6, P_SGLASS,   140                  ; 107 magenta stained glass
    TILE  58, 175, 217,  6, P_SGLASS,   140                  ; 108 light blue stained glass
    TILE 248, 198,  39,  6, P_SGLASS,   140                  ; 109 yellow stained glass
    TILE 112, 185,  25,  6, P_SGLASS,   140                  ; 110 lime stained glass
    TILE 237, 141, 172,  6, P_SGLASS,   140                  ; 111 pink stained glass
    TILE  62,  68,  71,  6, P_SGLASS,   140                  ; 112 gray stained glass
    TILE 142, 142, 134,  6, P_SGLASS,   140                  ; 113 light gray stained glass
    TILE  21, 137, 145,  6, P_SGLASS,   140                  ; 114 cyan stained glass
    TILE 121,  42, 172,  6, P_SGLASS,   140                  ; 115 purple stained glass
    TILE  53,  57, 157,  6, P_SGLASS,   140                  ; 116 blue stained glass
    TILE 114,  71,  40,  6, P_SGLASS,   140                  ; 117 brown stained glass
    TILE  84, 109,  27,  6, P_SGLASS,   140                  ; 118 green stained glass
    TILE 161,  39,  34,  6, P_SGLASS,   140                  ; 119 red stained glass
    TILE  20,  21,  25,  6, P_SGLASS,   140                  ; 120 black stained glass
    TILE 110, 236, 226, 10, P_BEACON,   255, 236, 250, 248   ; 121 beacon
    TILE 166,  40,  40, 16, P_TOPSTRIP, 255, 236, 236, 232, 1  ; 122 bed head, pillow at the far edge
    TILE 166,  40,  40, 16, P_TOPSTRIP, 255, 236, 236, 232, 2  ; 123 pillow at the left edge
    TILE 166,  40,  40, 16, P_TOPSTRIP, 255, 236, 236, 232, 3  ; 124 pillow at the right edge
    TILE  44,  56,  92, 30, P_NOISE,    255                  ; 125 bluestone, dark
    TILE  96, 204, 255, 20, P_NOISE,    255                  ; 126 bluestone, lit
    TILE 110,  80,  40, 10, P_STICKS,   255, 120, 226, 255   ; 127 torch and lever posts
    TILE  44, 104, 224,  8, P_METAL,    255, 0, 0, 0, 2      ; 128 block of bluestone
    TILE  92,  74,  56, 20, P_LAMP,     255                  ; 129 lamp
    TILE 170, 226, 255, 10, P_LAMP,     255                  ; 130 lamp, lit
    TILE 118, 118, 124, 24, P_SMOOTH,   255                  ; 131 piston body
    TILE 200, 160, 104, 20, P_PLANKS,   255                  ; 132 piston face
    TILE 112, 190,  92, 20, P_SMOOTH,   255                  ; 133 sticky piston face
    TILE 176, 176, 176, 12, P_SLAB,     255,  40,  70, 150, 0  ; 134 repeater top
    TILE 176, 176, 176, 12, P_SLAB,     255,  40,  70, 150, 1  ; 135 comparator top
    TILE 190, 190, 196, 12, P_RAIL,     255, 120,  86,  50, 0  ; 136 rail
    TILE 190, 190, 196, 12, P_RAIL,     255, 120,  86,  50, 1  ; 137 rail corner
    TILE 232, 190,  60, 12, P_RAIL,     255,  40,  60, 120, 2  ; 138 powered rail
    TILE 232, 190,  60, 12, P_RAIL,     255, 110, 220, 255, 3  ; 139 powered rail, on
    TILE 128, 128, 128, 40, P_ORE,      255,  60, 120, 255   ; 140 bluestone ore
    TILE 164, 120,  72, 14, P_DOOR,     255, 190, 222, 236, 0  ; 141 wooden door, bottom
    TILE 164, 120,  72, 14, P_DOOR,     255, 190, 222, 236, 1  ; 142 wooden door, top
    TILE 204, 204, 208,  8, P_DOOR,     255, 190, 222, 236, 4  ; 143 iron door, bottom
    TILE 204, 204, 208,  8, P_DOOR,     255, 190, 222, 236, 5  ; 144 iron door, top
    TILE 164, 120,  72, 14, P_DOOR,     255,  50,  36,  24, 2  ; 145 trapdoor
    TILE 204, 204, 208,  8, P_DOOR,     255,  60,  60,  64, 6  ; 146 iron trapdoor
    TILE 216, 214, 204, 10, P_BIRCH,    255,  44,  40,  36   ; 147 birch log side
    TILE 206, 186, 136, 20, P_RINGS,    255, 216, 214, 204   ; 148 birch log top
    TILE  64,  46,  28, 30, P_VSTRIPE,  255                  ; 149 dark oak log side
    TILE 118,  86,  52, 20, P_RINGS,    255,  64,  46,  28   ; 150 dark oak log top
    TILE 214, 194, 138, 16, P_PLANKS,   255                  ; 151 birch planks
    TILE  92,  62,  36, 20, P_PLANKS,   255                  ; 152 dark oak planks
    TILE 168, 120,  60, 14, P_CHEST,    255,  70,  70,  76, 0  ; 153 chest front
    TILE 168, 120,  60, 14, P_CHEST,    255,  70,  70,  76, 1  ; 154 chest side
    TILE 168, 120,  60, 14, P_CHEST,    255,  70,  70,  76, 2  ; 155 chest top
    TILE  86, 170,  64, 40, P_ORE,      200, 150, 104,  80   ; 156 green portal (rotten flesh)

; "TNT" on the side band, rows 6-9: bit x = column x
tnt_glyph:  dw 0x3A5C, 0x12C8, 0x1348, 0x1248

; fixed icon colours for codes 6-11 (rainbow) and 12-13, 0xAABBGGRR
rainbow:    dd 0xff2828e0, 0xff1c8cf4, 0xff2cd8f8, 0xff30b848, 0xffd86030, 0xffb03c90
            dd 0xfff4f4f4, 0xff302c2c   ; 12 white, 13 near black

; per block: top, side, bottom tile
block_tiles:
    db 0, 0, 0, 0           ; air
    db 0, 0, 0, 0           ; stone
    db 1, 1, 1, 0           ; dirt
    db 2, 3, 1, 0           ; grass
    db 4, 4, 4, 0           ; sand
    db 5, 5, 5, 0           ; water
    db 7, 6, 7, 0           ; log
    db 8, 8, 8, 0           ; leaves
    db 9, 10, 1, 0          ; dirt with snow
    db 11, 11, 11, 0        ; desert sand
    db 12, 12, 12, 0        ; desert stone
    db 13, 14, 1, 0         ; dry grass
    db 15, 15, 15, 0        ; cobble
    db 16, 16, 16, 0        ; planks
    db 17, 17, 17, 0        ; glass
    db 18, 18, 18, 0        ; gravel
    db 20, 19, 20, 0        ; cactus
    db 21, 21, 21, 0        ; pine needles
    db 9, 9, 9, 0           ; snow block
    db 7, 22, 7, 0          ; pine log
    db 23, 23, 23, 0        ; brick
    times 7 db 5, 5, 5, 0   ; flowing water
    db 29, 29, 29, 0        ; bedrock
    db 30, 30, 30, 0        ; coal ore
    db 31, 31, 31, 0        ; iron ore
    db 32, 32, 32, 0        ; gold ore
    db 33, 33, 33, 0        ; diamond ore
    db 34, 35, 16, 0        ; crafting table
    db 38, 36, 38, 0        ; furnace
    db 38, 37, 38, 0        ; furnace, burning
    db 39, 39, 39, 0        ; torch
    db 40, 40, 40, 0        ; clay
    db 41, 41, 41, 0        ; block of iron
    db 42, 42, 42, 0        ; block of gold
    db 43, 43, 43, 0        ; block of diamond
    db 44, 44, 44, 0        ; block of coal
    db 45, 1, 1, 0          ; farmland
    db 46, 46, 46, 0        ; tall grass
%assign st 0
%rep 8
    db 47 + st, 47 + st, 47 + st, 0   ; wheat stages
%assign st st + 1
%endrep
%assign st 0
%rep 4
    db 55 + st, 55 + st, 55 + st, 0   ; carrot stages
%assign st st + 1
%endrep
    times 5 db 16, 16, 16, 0          ; fence, gates: planks
%assign c 0
%rep 16
    db 59 + c, 59 + c, 59 + c, 0      ; wool
%assign c c + 1
%endrep
%assign c 0
%rep 16
    db 75 + c, 75 + c, 75 + c, 0      ; concrete
%assign c c + 1
%endrep
    db 91, 91, 91, 0        ; yellow flower
    db 92, 92, 92, 0        ; red flower
    db 93, 93, 93, 0        ; bed, foot
    db 94, 93, 93, 0        ; bed, head
    db 95, 95, 95, 0        ; dye maker
    times 4 db 96, 96, 96, 0  ; lava, still and flowing
    db 97, 97, 97, 0        ; obsidian
    db 99, 98, 100, 0       ; TNT
    db 101, 101, 101, 0     ; fire
    db 102, 102, 102, 0     ; netherrack
    db 103, 103, 103, 0     ; nether portal
    db 104, 104, 104, 0     ; slime block
%assign c 0
%rep 16
    db 105 + c, 105 + c, 105 + c, 0   ; stained glass
%assign c c + 1
%endrep
    db 121, 121, 121, 0     ; beacon
    db 39, 39, 39, 0        ; torch on a wall
    db 140, 140, 140, 0     ; bluestone ore
    db 128, 128, 128, 0     ; block of bluestone
    ; the bluestone parts (wiremesh.inc draws them; these are the tiles
    ; their bits fly off with, and the lamp's faces)
    db 125, 125, 125, 0
    times 15 db 126, 126, 126, 0      ; dust
    times 10 db 127, 127, 127, 0      ; torch
    times 10 db 15, 15, 15, 0         ; lever
    times 10 db 0, 0, 0, 0            ; button, pressure plate
    times 8 db 134, 134, 134, 0       ; repeater
    times 8 db 135, 135, 135, 0       ; comparator
    db 129, 129, 129, 0               ; lamp
    db 130, 130, 130, 0
    times 24 db 131, 131, 131, 0      ; pistons
    times 6 db 132, 132, 132, 0       ; piston head
    times 10 db 136, 136, 136, 0      ; rail
    times 12 db 138, 138, 138, 0      ; powered rail
    times 4 db 141, 141, 141, 0       ; door
    times 2 db 145, 145, 145, 0       ; trapdoor
    db 148, 147, 148, 0               ; birch log
    db 150, 149, 150, 0               ; dark oak log
    db 151, 151, 151, 0               ; birch planks
    db 152, 152, 152, 0               ; dark oak planks
    db 16, 16, 16, 0                  ; slab, stairs, chest (drawn by wiremesh)
    times (256 - W_SHAPE - 1) * 4 db 0

%include "items_data.inc"

section .bss
alignb 16
atlas_rgba: resb ATLAS_W * ATLAS_H * 4
tilebuf:    resb 16 * 16 * 4
atlas_w:    resd 1
atlas_h:    resd 1
tex_res:    resd 1
tex_opaque: resd 1
alignb 16
icons_rgba: resb ICONS_W * ICONS_H * 4

section .text

; u32 phash(edi a, esi b, edx c) -> eax ; clobbers ecx
phash:
    imul eax, edi, 0x1f1f
    imul ecx, esi, 0x3797
    add eax, ecx
    imul ecx, edx, 0x2b9d
    add eax, ecx
    add eax, 0x5bd1e995
    mov ecx, eax
    shr ecx, 15
    xor eax, ecx
    imul eax, eax, 0x2c1b3c6d
    mov ecx, eax
    shr ecx, 12
    xor eax, ecx
    imul eax, eax, 0x297a2d39
    mov ecx, eax
    shr ecx, 15
    xor eax, ecx
    ret

; void texgen_atlas(int res, int leaves_opaque) - res 16, 8, 4 or 1
; r12 tile, r13 tile record, r14 py, r15 px, ebx factor f (x/256)
; locals: [rsp] colour index (0/1), [rsp+4] alpha
texgen_atlas:
    ENTER_FN 16
    mov [tex_res], edi
    mov [tex_opaque], esi
    mov eax, edi
    shl eax, 7
    mov [atlas_w], eax
    mov eax, edi
    shl eax, 7                      ; 16 rows of tiles
    mov [atlas_h], eax
    xor r12d, r12d
.tile:
    imul eax, r12d, TL_SIZE
    lea r13, [tiles]
    add r13, rax
    xor r14d, r14d
.py:
    xor r15d, r15d
.px:
    mov edi, r15d
    mov esi, r14d
    mov edx, r12d
    call phash
    movzx eax, al                   ; h 0..255
    movzx ecx, byte [r13 + 3]       ; variation
    mov ebx, 256
    sub ebx, ecx
    imul ecx, eax
    shr ecx, 7                      ; var*2*h/256
    add ebx, ecx
    mov dword [rsp], 0
    movzx ecx, byte [r13 + 5]
    mov [rsp + 4], ecx
    movzx ecx, byte [r13 + 4]
    cmp ecx, P_TOPSTRIP
    je .topstrip
    cmp ecx, P_VSTRIPE
    je .vstripe
    cmp ecx, P_RINGS
    je .rings
    cmp ecx, P_LEAVES
    je .leaves
    cmp ecx, P_GLASS
    je .glass
    cmp ecx, P_PLANKS
    je .planks
    cmp ecx, P_COBBLE
    je .cobble
    cmp ecx, P_BRICK
    je .brick
    cmp ecx, P_CRACK
    je .crack
    cmp ecx, P_ORE
    je .ore
    cmp ecx, P_TABLETOP
    je .tabletop
    cmp ecx, P_TABLESIDE
    je .tableside
    cmp ecx, P_FURNACE
    je .furnace
    cmp ecx, P_TORCH
    je .torch
    cmp ecx, P_SMOOTH
    je .smooth
    cmp ecx, P_METAL
    je .metal
    cmp ecx, P_FARMLAND
    je .farmland
    cmp ecx, P_PLANT
    je .plant
    cmp ecx, P_WOOL
    je .wool
    cmp ecx, P_FLOWER
    je .flower
    cmp ecx, P_TNT
    je .tnt
    cmp ecx, P_FLAME
    je .flame
    cmp ecx, P_SGLASS
    je .sglass
    cmp ecx, P_BEACON
    je .beacon
    cmp ecx, P_STICKS
    je .sticks
    cmp ecx, P_LAMP
    je .lamp
    cmp ecx, P_SLAB
    je .slab
    cmp ecx, P_RAIL
    je .rail
    cmp ecx, P_DOOR
    je .door
    cmp ecx, P_BIRCH
    je .birch
    cmp ecx, P_CHEST
    je .chest
    jmp .write

; RECT x0, x1, y0, y1, target - jump if px in [x0,x1] and py in [y0,y1]
%macro INRECT 5
    cmp r15d, %1
    jb %%no
    cmp r15d, %2
    ja %%no
    cmp r14d, %3
    jb %%no
    cmp r14d, %4
    jbe %5
%%no:
%endmacro

.ore:
    ; clumps of 2x2 pixel cells, ragged at the edges
    mov edi, r15d
    shr edi, 1
    mov esi, r14d
    shr esi, 1
    lea edx, [r12 + 50]
    call phash
    movzx eax, al
    cmp eax, 70
    jae .write
    mov edi, r15d
    mov esi, r14d
    lea edx, [r12 + 9]
    call phash
    test eax, 3
    jz .write
    mov dword [rsp], 1
    jmp .write

.border_dark:
    mov ebx, 140
    jmp .write
.tabletop:
    INRECT 0, 15, 0, 0, .border_dark
    INRECT 0, 15, 15, 15, .border_dark
    INRECT 0, 0, 0, 15, .border_dark
    INRECT 15, 15, 0, 15, .border_dark
    INRECT 7, 8, 0, 15, .tt_line
    INRECT 0, 15, 7, 8, .tt_line
    mov eax, r14d
    and eax, 3
    cmp eax, 3
    jne .write
    mov ebx, 200
    jmp .write
.tt_line:
    mov ebx, 165
    jmp .write

.tableside:
    INRECT 0, 15, 0, 1, .border_dark
    INRECT 3, 4, 4, 12, .ts_tool
    INRECT 2, 5, 4, 5, .ts_tool
    INRECT 11, 12, 4, 12, .ts_tool
    INRECT 10, 13, 11, 12, .ts_tool
    mov eax, r14d
    and eax, 3
    cmp eax, 3
    jne .write
    mov ebx, 185
    jmp .write
.ts_tool:
    mov dword [rsp], 1
    jmp .write

.furnace:
    INRECT 4, 11, 8, 13, .fu_hole
    INRECT 3, 12, 7, 14, .fu_frame
    INRECT 0, 15, 0, 1, .fu_frame
    jmp .write
.fu_hole:
    mov dword [rsp], 1
    mov ebx, 256
    jmp .write
.fu_frame:
    mov ebx, 150
    jmp .write

.torch:
    mov dword [rsp + 4], 0
    INRECT 7, 8, 3, 5, .to_flame
    INRECT 7, 8, 6, 15, .to_stick
    jmp .write
.to_flame:
    mov dword [rsp], 1
    mov dword [rsp + 4], 255
    mov ebx, 256
    jmp .write
.to_stick:
    mov dword [rsp + 4], 255
    jmp .write

.farmland:
    test r14d, 3
    jnz .write
    mov ebx, 150                    ; a furrow
    jmp .write

.plant:
    ; blades: every third column, leaning a little with height, from the
    ; bottom up to the height in byte 9; transparent elsewhere
    mov dword [rsp + 4], 0
    movzx eax, byte [r13 + 9]
    mov ecx, 16
    sub ecx, eax                    ; first row with blades
    cmp r14d, ecx
    jb .write
    mov eax, r14d
    shr eax, 2
    add eax, r15d
    xor edx, edx
    push rcx
    mov ecx, 3
    div ecx
    pop rcx
    test edx, edx
    jnz .write
    mov dword [rsp + 4], 255
    movzx eax, byte [r13 + 10]
    cmp eax, 1
    jne .pl_root
    ; grain head: the top 4 rows of the blades
    lea eax, [rcx + 4]
    cmp r14d, eax
    jae .write
    mov dword [rsp], 1
    jmp .write
.pl_root:
    cmp eax, 2
    jne .write
    ; root tops showing at the bottom 3 rows
    cmp r14d, 13
    jb .write
    mov dword [rsp], 1
    jmp .write

.wool:
    ; stitches: the diagonals (x + y) and (x - y) every 4 texels are a bit darker
    mov eax, r15d
    add eax, r14d
    test eax, 3
    jz .w_dark
    mov eax, r15d
    sub eax, r14d
    test eax, 3
    jnz .write
.w_dark:
    imul ebx, ebx, 225
    shr ebx, 8
    jmp .write

.flower:
    ; a stem in the middle (colour 1) under a round head (colour 2)
    mov dword [rsp + 4], 0
    INRECT 7, 8, 8, 15, .fl_stem
    INRECT 6, 9, 3, 7, .fl_head
    INRECT 5, 10, 4, 6, .fl_head
    INRECT 9, 11, 10, 11, .fl_stem   ; a leaf
    jmp .write
.fl_stem:
    mov dword [rsp + 4], 255
    jmp .write
.fl_head:
    mov dword [rsp + 4], 255
    mov dword [rsp], 1
    jmp .write

.tnt:
    ; red sticks; the side has a light band with "TNT" on it, the top the
    ; ends of the sticks and a fuse in the middle
    movzx eax, byte [r13 + 9]
    test eax, eax
    jnz .tnt_end
    INRECT 0, 15, 5, 10, .tnt_band
    jmp .tnt_seam
.tnt_band:
    mov dword [rsp], 1
    cmp r14d, 6
    jb .write
    cmp r14d, 9
    ja .write
    lea rax, [tnt_glyph]
    movzx eax, word [rax + r14*2 - 12]
    bt eax, r15d
    jnc .write
    mov ebx, 40                     ; a letter
    jmp .write
.tnt_end:
    cmp eax, 1
    jne .tnt_grid
    INRECT 7, 8, 7, 8, .tnt_fuse
    INRECT 6, 9, 6, 9, .tnt_ring
.tnt_grid:
    test r14d, 3
    jz .tnt_line
.tnt_seam:
    mov eax, r15d
    and eax, 3
    cmp eax, 3
    jne .write
.tnt_line:
    mov ebx, 160
    jmp .write
.tnt_fuse:
    mov dword [rsp], 1
    mov ebx, 60
    jmp .write
.tnt_ring:
    mov dword [rsp], 1
    jmp .write

.flame:
    ; each column burns up to a ragged height; yellow at the bottom
    mov dword [rsp + 4], 0
    mov edi, r15d
    mov esi, 31
    mov edx, 5
    call phash
    and eax, 7
    add eax, 2                      ; top row of this column: 2-9
    test r15d, 1
    jz .fl_h
    add eax, 2                      ; thinner tongues between
.fl_h:
    cmp r14d, eax
    jb .write
    mov dword [rsp + 4], 255
    cmp r14d, 11
    jb .write
    mov dword [rsp], 1
    jmp .write

.sglass:
    ; the tint lets light through (blended); a solid frame and a streak
    INRECT 0, 15, 0, 0, .sg_rim
    INRECT 0, 15, 15, 15, .sg_rim
    INRECT 0, 0, 0, 15, .sg_rim
    INRECT 15, 15, 0, 15, .sg_rim
    mov eax, r15d
    sub eax, r14d
    cmp eax, 4
    jb .write
    cmp eax, 5
    ja .write
    cmp r15d, 12
    jae .write
    mov ebx, 300                    ; bright streak
    jmp .write
.sg_rim:
    mov ebx, 190
    mov dword [rsp + 4], 235
    jmp .write

.beacon:
    ; a pale glass shell (colour 2) round a glowing core
    mov dword [rsp], 1
    INRECT 0, 15, 0, 0, .write
    INRECT 0, 15, 15, 15, .write
    INRECT 0, 0, 0, 15, .write
    INRECT 15, 15, 0, 15, .write
    INRECT 4, 11, 4, 11, .bc_core
    mov ebx, 200
    jmp .write
.bc_core:
    mov dword [rsp], 0
    mov ebx, 280
    jmp .write

.smooth:
    INRECT 0, 15, 0, 0, .sm_rim
    INRECT 0, 15, 15, 15, .sm_rim
    INRECT 0, 0, 0, 15, .sm_rim
    INRECT 15, 15, 0, 15, .sm_rim
    jmp .write
.sm_rim:
    mov ebx, 170
    jmp .write

.metal:
    ; polished blocks: a bevel (light top/left, dark bottom/right) and a
    ; surface that differs by style: 1 iron plates, 2 gold and 3 diamond
    ; with diagonal glints, 4 coal with raised, ragged lumps
    movzx eax, byte [r13 + 9]
    cmp eax, 1
    je .mt_iron
    cmp eax, 4
    je .mt_coal
    mov edx, r15d
    add edx, r14d                   ; gold: streaks along x + y
    cmp eax, 3
    jne .mt_streak
    mov edx, r15d                   ; diamond: along x - y, wider
    sub edx, r14d
    and edx, 15
    cmp edx, 3
    jae .mt_ring
    add ebx, 34
    jmp .mt_ring
.mt_streak:
    and edx, 15
    cmp edx, 3
    je .mt_gl
    cmp edx, 4
    jne .mt_g2
.mt_gl:
    add ebx, 34
    jmp .mt_ring
.mt_g2:
    cmp edx, 10
    jne .mt_ring
    add ebx, 18
    jmp .mt_ring
.mt_iron:
    mov eax, r14d
    and eax, 3
    jnz .mt_i1
    add ebx, 30                     ; the lit edge of a plate
    jmp .mt_ring
.mt_i1:
    cmp eax, 3
    jne .mt_ring
    sub ebx, 44                     ; the shaded edge under it
    cmp r15d, 7
    jne .mt_ring
    jmp .mt_ring
.mt_coal:
    mov edi, r15d
    shr edi, 1
    mov esi, r14d
    shr esi, 1
    mov edx, 61
    call phash
    and eax, 7
    cmp eax, 3
    jae .mt_pit
    mov eax, r14d                   ; a raised lump: lit on its top-left
    or eax, r15d
    test eax, 1
    jnz .mt_lump2
    add ebx, 70
    jmp .mt_ring
.mt_lump2:
    add ebx, 12
    jmp .mt_ring
.mt_pit:
    sub ebx, 30
.mt_ring:
    cmp r14d, 0
    je .mt_lit
    cmp r15d, 0
    je .mt_lit
    cmp r14d, 15
    je .mt_dark
    cmp r15d, 15
    je .mt_dark
    cmp r14d, 1                     ; an inner line one in from the edge
    je .mt_in
    cmp r15d, 1
    je .mt_in
    jmp .write
.mt_in:
    add ebx, 10
    jmp .write
.mt_lit:
    add ebx, 36
    jmp .write
.mt_dark:
    sub ebx, 52
    jmp .write

.crack:
    ; blotches that spread with the stage
    mov edi, r15d
    shr edi, 1
    mov esi, r14d
    shr esi, 1
    mov edx, 77
    call phash
    movzx eax, al
    movzx ecx, byte [r13 + 6]       ; stage 0-4
    inc ecx
    imul ecx, ecx, 40
    cmp eax, ecx
    jae .crack_no
    mov edi, r15d
    mov esi, r14d
    mov edx, r12d
    call phash
    test eax, 1
    jz .crack_no
    jmp .write
.crack_no:
    mov dword [rsp + 4], 0
    jmp .write

.topstrip:
    ; byte 9: which edge the strip lies along (0 top, 1 bottom, 2 left, 3 right)
    movzx edx, byte [r13 + 9]
    mov edi, r15d                   ; along the strip
    mov esi, r14d                   ; across it
    cmp edx, 2
    jb .ts_h
    xchg edi, esi
.ts_h:
    test edx, 1
    jz .ts_n
    neg esi
    add esi, 15
.ts_n:
    mov r8d, esi
    mov esi, 99
    mov edx, r12d
    call phash
    and eax, 1
    add eax, 3
    cmp r8d, eax
    jae .write
    mov dword [rsp], 1
    jmp .write

.vstripe:
    mov eax, r15d
    and eax, 3
    jnz .vs2
    sub ebx, 50
    jmp .write
.vs2:
    cmp eax, 2
    jne .write
    add ebx, 16
    jmp .write

.rings:
    lea eax, [r15*2 - 15]
    imul eax, eax
    lea ecx, [r14*2 - 15]
    imul ecx, ecx
    add eax, ecx
    cmp eax, 196
    jb .r_in
    mov dword [rsp], 1
    jmp .write
.r_in:
    xor edx, edx
    mov ecx, 24
    div ecx
    test eax, 1
    jz .write
    sub ebx, 30
    jmp .write

.leaves:
    cmp eax, 64                     ; eax = h: a quarter of the pixels are holes
    jae .write
    mov dword [rsp + 4], 0
    cmp dword [tex_opaque], 0
    je .write
    mov dword [rsp + 4], 255        ; opaque leaves: dark spots instead
    mov ebx, 150
    jmp .write

.glass:
    mov ebx, 256
    test r15d, r15d
    jz .write
    test r14d, r14d
    jz .write
    cmp r15d, 15
    je .write
    cmp r14d, 15
    je .write
    mov eax, r15d
    sub eax, r14d
    cmp eax, 4
    jb .g_no
    cmp eax, 5
    ja .g_no
    cmp r15d, 12
    jae .g_no
    mov ebx, 330                    ; bright streak
    jmp .write
.g_no:
    mov dword [rsp + 4], 0
    jmp .write

.planks:
    mov eax, r14d
    and eax, 3
    cmp eax, 3
    jne .p2
    mov ebx, 170
    jmp .write
.p2:
    mov eax, r14d
    shr eax, 2
    imul eax, eax, 5
    add eax, 3
    and eax, 15
    cmp eax, r15d
    jne .write
    mov ebx, 185
    jmp .write

.cobble:
    mov ecx, r14d
    shr ecx, 2                      ; row
    mov eax, ecx
    and eax, 1
    imul eax, eax, 3
    add eax, r15d                   ; px + offset
    mov r8d, eax
    test r14d, 3
    jz .c_mortar
    xor edx, edx
    mov r9d, 5
    div r9d
    test edx, edx
    jz .c_mortar
    ; stone cell shade: row * 8 + (px + offset) / 5
    lea edi, [rcx*8 + rax]
    mov esi, 7
    mov edx, r12d
    call phash
    and eax, 63
    add eax, 200
    mov ebx, eax
    jmp .write
.c_mortar:
    mov ebx, 150
    jmp .write

.brick:
    mov eax, r14d
    and eax, 3
    cmp eax, 3
    je .b_mortar
    mov eax, r14d
    shr eax, 2
    and eax, 1
    shl eax, 2
    add eax, r15d
    and eax, 7
    cmp eax, 7
    jne .write
.b_mortar:
    mov dword [rsp], 1
    jmp .write

.sticks:
    ; posts two texels wide from row 6 down: columns 2-3 a torch that is
    ; out, 8-9 one that is lit, 12-13 (from row 4) a lever handle
    mov dword [rsp + 4], 0
    INRECT 2, 3, 6, 7, .st_dead
    INRECT 8, 9, 6, 7, .st_lit
    INRECT 12, 13, 4, 5, .st_knob
    INRECT 2, 3, 8, 15, .st_wood
    INRECT 8, 9, 8, 15, .st_wood
    INRECT 12, 13, 6, 15, .st_wood
    jmp .write
.st_dead:
    mov dword [rsp], 1
    mov ebx, 70
    jmp .st_wood
.st_lit:
    mov dword [rsp], 1
    mov ebx, 256
    jmp .st_wood
.st_knob:
    mov ebx, 420
.st_wood:
    mov dword [rsp + 4], 255
    jmp .write

.lamp:
    ; four panes in a dark frame
    INRECT 0, 15, 0, 0, .lm_frame
    INRECT 0, 15, 15, 15, .lm_frame
    INRECT 0, 0, 0, 15, .lm_frame
    INRECT 15, 15, 0, 15, .lm_frame
    INRECT 7, 8, 0, 15, .lm_bar
    INRECT 0, 15, 7, 8, .lm_bar
    mov eax, r15d
    add eax, r14d
    test eax, 7
    jnz .write
    imul ebx, ebx, 290              ; a glint across each pane
    shr ebx, 8
    jmp .write
.lm_frame:
    mov ebx, 110
    jmp .write
.lm_bar:
    mov ebx, 160
    jmp .write

.slab:
    ; pale stone with a dark rim; marks in colour 2 pointing toward +u:
    ; a line with an arrow head (repeater) or three pads (comparator)
    INRECT 0, 15, 0, 0, .sm_rim
    INRECT 0, 15, 15, 15, .sm_rim
    INRECT 0, 0, 0, 15, .sm_rim
    INRECT 15, 15, 0, 15, .sm_rim
    cmp byte [r13 + 9], 0
    jne .sl_comp
    INRECT 3, 10, 7, 8, .sl_mark
    cmp r15d, 10
    jb .write
    cmp r15d, 13
    ja .write
    lea eax, [r14*2 - 15]
    imul eax, eax                   ; (2 py - 15)^2
    mov ecx, 13
    sub ecx, r15d
    lea ecx, [rcx*2 + 1]
    imul ecx, ecx
    cmp eax, ecx
    ja .write
.sl_mark:
    mov dword [rsp], 1
    mov ebx, 256
    jmp .write
.sl_comp:
    INRECT 2, 4, 3, 5, .sl_mark
    INRECT 2, 4, 10, 12, .sl_mark
    INRECT 11, 13, 7, 8, .sl_mark
    INRECT 5, 10, 7, 8, .sl_mark
    jmp .write

.birch:
    ; dark dashes across pale bark, 4 texels long
    mov edi, r15d
    shr edi, 2
    mov esi, r14d
    mov edx, 91
    call phash
    and eax, 15
    cmp eax, 2
    ja .write
    mov dword [rsp], 1
    jmp .write

.chest:
    ; boards in a dark frame; the sides show the lid's edge, the front
    ; its metal latch (colour 2)
    INRECT 0, 15, 0, 0, .ch_rim
    INRECT 0, 15, 15, 15, .ch_rim
    INRECT 0, 0, 0, 15, .ch_rim
    INRECT 15, 15, 0, 15, .ch_rim
    movzx eax, byte [r13 + 9]
    cmp eax, 2
    je .ch_board
    test eax, eax
    jnz .ch_lid
    INRECT 7, 8, 4, 7, .ch_latch
.ch_lid:
    INRECT 1, 14, 5, 5, .ch_rim
.ch_board:
    mov eax, r14d
    and eax, 3
    cmp eax, 3
    jne .write
    imul ebx, ebx, 215
    shr ebx, 8
    jmp .write
.ch_rim:
    mov ebx, 140
    jmp .write
.ch_latch:
    mov dword [rsp], 1
    mov ebx, 256
    jmp .write

.door:
    ; a frame; wood: boards and two sunk panels, iron: plates and rivets.
    ; The top has a window (colour 2), the trapdoor four holes (colour 2).
    INRECT 0, 15, 0, 0, .dr_rim
    INRECT 0, 15, 15, 15, .dr_rim
    INRECT 0, 0, 0, 15, .dr_rim
    INRECT 15, 15, 0, 15, .dr_rim
    movzx eax, byte [r13 + 9]
    mov ecx, eax
    and ecx, 3
    cmp ecx, 1
    je .dr_top
    cmp ecx, 2
    je .dr_trap
    INRECT 12, 13, 1, 2, .dr_knob         ; the handle, near the top
    INRECT 3, 12, 4, 7, .dr_panel
    INRECT 3, 12, 10, 13, .dr_panel
    jmp .dr_grain
.dr_top:
    INRECT 3, 12, 3, 12, .dr_glass
    jmp .dr_grain
.dr_trap:
    INRECT 3, 6, 3, 6, .dr_hole
    INRECT 9, 12, 3, 6, .dr_hole
    INRECT 3, 6, 9, 12, .dr_hole
    INRECT 9, 12, 9, 12, .dr_hole
.dr_grain:
    test eax, 4
    jnz .dr_iron
    mov ecx, r15d                   ; wood: a seam every 5 texels
    xor edx, edx
    mov eax, ecx
    mov ecx, 5
    div ecx
    cmp edx, 4
    jne .write
    imul ebx, ebx, 215
    shr ebx, 8
    jmp .write
.dr_iron:
    INRECT 2, 2, 2, 2, .dr_rivet
    INRECT 13, 13, 2, 2, .dr_rivet
    INRECT 2, 2, 13, 13, .dr_rivet
    INRECT 13, 13, 13, 13, .dr_rivet
    test r14d, 3
    jnz .write
    imul ebx, ebx, 225
    shr ebx, 8
    jmp .write
.dr_rim:
    mov ebx, 150
    jmp .write
.dr_panel:
    mov ebx, 205
    jmp .write
.dr_knob:
    mov ebx, 70
    jmp .write
.dr_rivet:
    mov ebx, 300
    jmp .write
.dr_glass:
    INRECT 7, 8, 3, 12, .dr_bar
    INRECT 3, 12, 7, 8, .dr_bar
.dr_hole:
    mov dword [rsp], 1
    mov ebx, 256
    jmp .write
.dr_bar:
    mov ebx, 170
    jmp .write

.rail:
    ; two rails on sleepers, clear between; +u is along the track. The
    ; corner turns from the +u edge to the +v edge. Powered rails have a
    ; strip of colour 2 down the middle.
    mov dword [rsp + 4], 0
    movzx eax, byte [r13 + 9]
    cmp eax, 1
    je .rl_corner
    INRECT 0, 15, 3, 4, .rl_metal
    INRECT 0, 15, 11, 12, .rl_metal
    cmp eax, 2
    jb .rl_ties
    INRECT 0, 15, 7, 8, .rl_strip
.rl_ties:
    mov ecx, r15d
    and ecx, 3
    cmp ecx, 1
    jb .write
    cmp ecx, 2
    ja .write
    cmp r14d, 2
    jb .write
    cmp r14d, 13
    ja .write
.rl_tie:
    mov dword [rsp + 4], 255
    cmp byte [r13 + 9], 2
    jae .rl_dtie
    mov dword [rsp], 1
    jmp .write
.rl_dtie:
    mov ebx, 110                    ; powered: dark gold sleepers
    jmp .write
.rl_strip:
    mov dword [rsp], 1
    mov ebx, 256
.rl_metal:
    mov dword [rsp + 4], 255
    jmp .write
.rl_corner:
    mov eax, 31
    sub eax, r15d
    sub eax, r15d
    imul eax, eax
    mov ecx, 31
    sub ecx, r14d
    sub ecx, r14d
    imul ecx, ecx
    add eax, ecx                    ; 4 x the squared distance from the corner
    cmp eax, 49
    jb .write
    cmp eax, 121
    jb .rl_metal
    cmp eax, 529
    jb .rl_ctie
    cmp eax, 729
    jb .rl_metal
    jmp .write
.rl_ctie:
    mov ecx, r15d
    sub ecx, r14d
    test ecx, 3
    jnz .write
    jmp .rl_tie

.write:
    ; destination pixel in the 16x16 tile buffer
    mov eax, r14d
    shl eax, 4
    add eax, r15d
    lea rdi, [tilebuf]
    lea rdi, [rdi + rax*4]
    lea rsi, [r13]                  ; colour 1
    cmp dword [rsp], 0
    je .c1
    lea rsi, [r13 + 6]              ; colour 2
.c1:
    xor ecx, ecx
.ch:
    movzx eax, byte [rsi + rcx]
    imul eax, ebx
    sar eax, 8
    jns .nn
    xor eax, eax
.nn:
    cmp eax, 255
    jbe .nc
    mov eax, 255
.nc:
    mov [rdi + rcx], al
    inc ecx
    cmp ecx, 3
    jb .ch
    mov eax, [rsp + 4]
    mov [rdi + 3], al

    inc r15d
    cmp r15d, 16
    jb .px
    inc r14d
    cmp r14d, 16
    jb .py
    mov edi, r12d
    call place_tile
    inc r12d
    cmp r12d, NUM_TILES
    jb .tile
    LEAVE_FN

; place_tile(edi tile): reduce tilebuf to tex_res and repeat it 8 x 8
; r12 tile, r13 out y, r14 out x (pixels within one repeat), ebx block size
place_tile:
    ENTER_FN 16
    mov r12d, edi
    mov eax, 16
    xor edx, edx
    div dword [tex_res]
    mov ebx, eax                    ; source pixels per output pixel
    xor r13d, r13d
.oy:
    xor r14d, r14d
.ox:
    ; average the ebx x ebx source block
    xor r8d, r8d                    ; r
    xor r9d, r9d                    ; g
    xor r10d, r10d                  ; b
    xor r11d, r11d                  ; a
    xor ecx, ecx                    ; sy
.sy:
    xor edx, edx                    ; sx
.sx:
    mov eax, r13d
    imul eax, ebx
    add eax, ecx
    shl eax, 4
    mov esi, r14d
    imul esi, ebx
    add esi, edx
    add eax, esi
    lea rsi, [tilebuf]
    lea rsi, [rsi + rax*4]
    movzx eax, byte [rsi]
    add r8d, eax
    movzx eax, byte [rsi + 1]
    add r9d, eax
    movzx eax, byte [rsi + 2]
    add r10d, eax
    movzx eax, byte [rsi + 3]
    add r11d, eax
    inc edx
    cmp edx, ebx
    jb .sx
    inc ecx
    cmp ecx, ebx
    jb .sy
    mov ecx, ebx
    imul ecx, ebx                   ; pixels averaged
    mov eax, r8d
    xor edx, edx
    div ecx
    mov r8d, eax
    mov eax, r9d
    xor edx, edx
    div ecx
    mov r9d, eax
    mov eax, r10d
    xor edx, edx
    div ecx
    mov r10d, eax
    mov eax, r11d
    xor edx, edx
    div ecx
    mov r11d, eax
    ; alpha-tested tiles stay crisp: cut-outs are either in or out
    cmp r11d, 255
    je .packed
    cmp r11d, 128
    jb .cut
    cmp r11d, 200
    jbe .packed                     ; water / cracks keep their alpha
    mov r11d, 255
    jmp .packed
.cut:
    cmp r11d, 64
    jae .packed
    xor r11d, r11d
.packed:
    shl r9d, 8
    shl r10d, 16
    shl r11d, 24
    or r8d, r9d
    or r8d, r10d
    or r8d, r11d                    ; rgba
    ; write to all 8 x 8 repeats
    xor ecx, ecx                    ; repeat y
.ry:
    xor edx, edx                    ; repeat x
.rx:
    mov eax, r12d
    shr eax, 4                      ; tile row
    shl eax, 3
    add eax, ecx
    imul eax, [tex_res]
    add eax, r13d                   ; atlas y
    imul eax, [atlas_w]
    mov esi, r12d
    and esi, 15
    shl esi, 3
    add esi, edx
    imul esi, [tex_res]
    add esi, r14d                   ; atlas x
    add eax, esi
    lea rsi, [atlas_rgba]
    mov [rsi + rax*4], r8d
    inc edx
    cmp edx, 8
    jb .rx
    inc ecx
    cmp ecx, 8
    jb .ry
    inc r14d
    cmp r14d, [tex_res]
    jb .ox
    inc r13d
    cmp r13d, [tex_res]
    jb .oy
    LEAVE_FN

; void icons_build(void) - item icons from the palette masks
; r12 icon, r13 py, r14 px; locals: [0] material r, g, b
icons_build:
    ENTER_FN 16
    xor r12d, r12d
.icon:
    imul eax, r12d, 3
    lea rcx, [icon_colors]
    add rcx, rax
    movzx eax, byte [rcx]
    mov [rsp], eax
    movzx eax, byte [rcx + 1]
    mov [rsp + 4], eax
    movzx eax, byte [rcx + 2]
    mov [rsp + 8], eax
    xor r13d, r13d
.py:
    xor r14d, r14d
.px:
    mov eax, r12d
    shl eax, 8
    mov ecx, r13d
    shl ecx, 4
    add eax, ecx
    add eax, r14d
    lea rcx, [icon_masks]
    movzx eax, byte [rcx + rax]     ; palette code
    xor r8d, r8d                    ; rgba
    test eax, eax
    jz .put
    cmp eax, 6
    jae .rainbow
    cmp eax, 4
    je .handle
    cmp eax, 5
    je .handle_dark
    ; material, scaled: 1 -> 256, 2 -> 346 (light), 3 -> 180 (dark)
    mov r9d, 256
    cmp eax, 2
    jne .nl
    mov r9d, 346
.nl:
    cmp eax, 3
    jne .nd
    mov r9d, 180
.nd:
    mov r8d, 0xff000000
    xor ecx, ecx
.ch:
    mov eax, [rsp + rcx*4]
    imul eax, r9d
    shr eax, 8
    cmp eax, 255
    jbe .cl
    mov eax, 255
.cl:
    shl ecx, 3
    shl eax, cl
    or r8d, eax
    shr ecx, 3
    inc ecx
    cmp ecx, 3
    jb .ch
    jmp .put
.handle:
    mov r8d, 0xff28506e             ; (110, 80, 40)
    jmp .put
.handle_dark:
    mov r8d, 0xff193246             ; (70, 50, 25)
    jmp .put
.rainbow:
    ; codes 6-11: red, orange, yellow, green, blue, purple (0xAABBGGRR)
    lea rcx, [rainbow]
    mov r8d, [rcx + rax*4 - 24]
.put:
    mov eax, r12d
    shr eax, 4
    shl eax, 4
    add eax, r13d                   ; texture row
    imul eax, eax, ICONS_W
    mov ecx, r12d
    and ecx, 15
    shl ecx, 4
    add eax, ecx
    add eax, r14d
    lea rcx, [icons_rgba]
    mov [rcx + rax*4], r8d
    inc r14d
    cmp r14d, 16
    jb .px
    inc r13d
    cmp r13d, 16
    jb .py
    inc r12d
    cmp r12d, ICON_COUNT
    jb .icon
    LEAVE_FN

NOEXECSTACK
