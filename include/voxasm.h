#ifndef VOXASM_H
#define VOXASM_H

#include <stdint.h>

/* ---- world geometry ---------------------------------------------------- */
#define VX_CHUNK_SIZE   16
#define VX_WORLD_H      256          /* y index 0..255 */
#define VX_WORLD_YMIN   (-64)        /* world y = index + VX_WORLD_YMIN */
#define VX_CHUNK_VOX    65536        /* bytes of block ids per chunk */
#define VX_NUM_SLOTS    1024         /* 32 x 32 ring of loaded chunks */
#define VX_WATER_LEVEL  1

/* voxel index inside a chunk */
#define VX_IDX(lx, yi, lz) (((lz) << 12) | ((lx) << 8) | (yi))

enum vx_block {
	VX_AIR, VX_STONE, VX_DIRT, VX_GRASS, VX_SAND, VX_WATER, VX_LOG,
	VX_LEAVES, VX_SNOWDIRT, VX_DSAND, VX_DSTONE, VX_DRYGRASS, VX_COBBLE,
	VX_PLANKS, VX_GLASS, VX_GRAVEL, VX_CACTUS, VX_PINENEEDLES, VX_SNOW,
	VX_PINELOG, VX_BRICK, VX_WFLOW1, VX_WFLOW7 = VX_WFLOW1 + 6, VX_BEDROCK,
	VX_COAL_ORE, VX_IRON_ORE, VX_GOLD_ORE, VX_DIAMOND_ORE, VX_CRAFTTABLE,
	VX_FURNACE, VX_FURNACE_LIT, VX_TORCH, VX_CLAY,
	VX_IRONBLOCK, VX_GOLDBLOCK, VX_DIAMONDBLOCK, VX_COALBLOCK, VX_FARMLAND,
	VX_TALLGRASS, VX_WHEAT0, VX_WHEAT7 = VX_WHEAT0 + 7, VX_CARROT0,
	VX_CARROT3 = VX_CARROT0 + 3, VX_FENCE, VX_GATE_X, VX_GATE_Z, VX_GATEOPEN_X,
	VX_GATEOPEN_Z, VX_WOOL, VX_CONCRETE = VX_WOOL + 16, VX_FLOWER_Y = VX_CONCRETE + 16,
	VX_FLOWER_R, VX_BED_FOOT, VX_BED_HEAD, VX_DYEMAKER, VX_LAVA, VX_LFLOW1,
	VX_LFLOW3 = VX_LFLOW1 + 2, VX_OBSIDIAN, VX_TNT, VX_FIRE, VX_NETHERRACK, VX_PORTAL, VX_SLIME,
	VX_SGLASS, VX_BEACON = VX_SGLASS + 16, VX_TORCH_WALL,
	VX_BLUE_ORE, VX_BLUEBLOCK,
	VX_NUM_BLOCKS,
	/* bluestone parts: ids that only sit in the world (wire.asm) */
	VX_W_WIRE = 128,              /* + signal 0..15 */
	VX_W_TORCH = 144,             /* + 2*k + lit; k 0 standing, 1..4 on +x -x +z -z */
	VX_W_LEVER = 154,             /* + 2*k + on */
	VX_W_BUTTON = 164,            /* + 2*side + pressed */
	VX_W_PLATE = 172,             /* + pressed */
	VX_W_REPEATER = 174,          /* + 2*facing + on */
	VX_W_COMPARATOR = 182,        /* + 2*facing + lit */
	VX_W_LAMP = 190,              /* + lit */
	VX_W_PISTON = 192,            /* + 2*dir + out; dir +x -x +y -y +z -z */
	VX_W_SPISTON = 204,
	VX_W_PHEAD = 216,             /* + dir */
	VX_W_RAIL = 222,              /* + shape 0..9 */
	VX_W_PRAIL = 232,             /* + 2*shape + on */
	VX_W_DOOR = 244,              /* + open; + 2 the upper half */
	VX_W_TRAP = 248,              /* + open */
	VX_W_END = 250,
	VX_W_BIRCHLOG = 250, VX_W_DARKLOG, VX_W_BIRCHPLANKS, VX_W_DARKPLANKS,
	VX_W_SHAPE = 254,             /* slab, stairs or chest (kept by position) */
	VX_UNKNOWN = 255
};

/* items that are not blocks (stored in the same byte as block ids) */
enum vx_item {
	VX_I_STICK = 128, VX_I_COAL, VX_I_IRON, VX_I_GOLD, VX_I_DIAMOND,
	VX_I_PICK = 133,              /* + tier: 0 wood, 1 stone, 2 iron, 3 diamond */
	VX_I_AXE = 137, VX_I_SHOVEL = 141, VX_I_SWORD = 145,
	VX_I_CLAYBALL = 149, VX_I_BRICK, VX_I_PORK, VX_I_COOKEDPORK, VX_I_BEEF,
	VX_I_STEAK, VX_I_FLESH, VX_I_EGG_PIG, VX_I_EGG_COW, VX_I_EGG_ZOMBIE,
	VX_I_HOE, VX_I_SEEDS = VX_I_HOE + 4, VX_I_WHEAT, VX_I_CARROT, VX_I_BREAD,
	VX_I_LEATHER, VX_I_SHEARS, VX_I_BED, VX_I_DYE, VX_I_EGG_SHEEP = VX_I_DYE + 16,
	VX_I_ARMOR,                   /* + material * 4 + piece (leather, iron, diamond x
	                                 helmet, chestplate, leggings, boots) */
	VX_I_BOAT = VX_I_ARMOR + 12, VX_I_BUCKET, VX_I_WATERBUCKET, VX_I_LAVABUCKET,
	VX_I_MILK, VX_I_FLINT, VX_I_FLINTSTEEL, VX_I_GUNPOWDER, VX_I_EGG_WITHER,
	VX_I_EGG_SLIME, VX_I_EGG_GHAST, VX_I_EGG_GIANT, VX_I_RIFLE, VX_I_SLIMEBALL,
	VX_I_DUST, VX_I_BTORCH, VX_I_LEVER, VX_I_BUTTON, VX_I_PLATE, VX_I_REPEATER,
	VX_I_COMPARATOR, VX_I_LAMP, VX_I_PISTON, VX_I_SPISTON, VX_I_RAIL, VX_I_PRAIL,
	VX_I_CART, VX_I_DOOR, VX_I_IRONDOOR, VX_I_TRAPDOOR, VX_I_IRONTRAP,
	VX_I_BIRCHLOG, VX_I_DARKLOG, VX_I_BIRCHPLANKS, VX_I_DARKPLANKS, VX_I_OAKSTAIRS,
	VX_I_BIRCHSTAIRS, VX_I_DARKSTAIRS, VX_I_STONESLAB, VX_I_OAKSLAB, VX_I_BIRCHSLAB,
	VX_I_DARKSLAB, VX_I_CHEST, VX_I_BEACONCORE, VX_I_DRAGONPORTAL, VX_I_END
};

enum vx_block_flags {
	VX_F_SOLID = 1, VX_F_OPAQUE = 2, VX_F_LIQUID = 4, VX_F_ALPHA = 8,
	VX_F_GROUND = 16, VX_F_CROSS = 32
};

enum vx_chunk_state { VX_ST_EMPTY, VX_ST_READY, VX_ST_PENDING };

typedef struct vx_chunk_info {
	int32_t cx, cz;
	uint8_t state, dirty, meshed, scale;  /* scale: mesh detail 1, 2 or 4 */
	int32_t maxy;
	int32_t nsurf, ndeep, nwat;   /* vertex counts of the three mesh parts */
	int32_t miny;                 /* lowest world y of surface / water faces */
	int32_t facecnt[6];           /* surface vertices per face: +X -X +Y -Y +Z -Z */
	uint8_t modified;             /* edited since loaded: save it */
	uint8_t lightdirty;           /* light needs recomputing */
	uint8_t pad3[6];
} vx_chunk_info;                      /* 64 bytes */

/* ---- noise.asm: Luanti value noise ------------------------------------- */
typedef struct vx_noise_params {      /* same field order as Luanti NoiseParams */
	float offset, scale;
	float spread_x, spread_y, spread_z;
	int32_t seed;
	uint32_t octaves;
	float persist, lacunarity;
	uint32_t flags;                   /* 1 defaults, 2 eased, 4 absvalue */
} vx_noise_params;                    /* 40 bytes */

float noise2d(int x, int y, int seed);
float noise3d(int x, int y, int z, int seed);
float noise2d_value(float x, float y, int seed, int eased);
float noise3d_value(float x, float y, float z, int seed, int eased);
float noise_fractal2d(const vx_noise_params *np, float x, float y, int seed);
float noise_fractal2d_p(const vx_noise_params *np, float x, float y, int seed,
		float persist);
float noise_fractal3d(const vx_noise_params *np, float x, float y, float z,
		int seed);

/* ---- mapgen.asm: Luanti mapgen v7 + biomes + caves + trees ------------- */
extern vx_noise_params np_terrain_base, np_terrain_alt, np_terrain_persist,
	np_height_select, np_filler_depth, np_mount_height, np_ridge_uwater,
	np_mountain, np_ridge, np_cave1, np_cave2;

/* Fills one 16x256x16 chunk and its u16 heightmap (top opaque y index + 1).
 * Returns the highest non-air y index. Thread-safe only one call at a time. */
int mapgen_chunk(uint8_t *blocks, uint16_t *hmap, int cx, int cz, int seed);
/* Base (non-mountain) terrain height of v7 at a world column. */
int mapgen_base_height(int x, int z, int seed);
/* Heightmap and max y index of a chunk filled some other way (loading). */
int mapgen_finish(uint8_t *blocks, uint16_t *hmap);
extern int mapgen_flat;               /* 1 = flat building world */

/* ---- light.asm ---------------------------------------------------------- */
/* one byte per node: low nibble sky light, high nibble block light */
extern uint8_t chunk_light[VX_NUM_SLOTS * VX_CHUNK_VOX];
void light_chunk(int slot, int flags);   /* 1 = use neighbours, 2 = worker */
int light_get(int x, int y, int z);

/* ---- world.asm: chunk ring ---------------------------------------------- */
extern uint8_t chunk_blocks[VX_NUM_SLOTS * VX_CHUNK_VOX];
extern uint16_t chunk_hmap[VX_NUM_SLOTS * 256];
extern vx_chunk_info chunk_info[VX_NUM_SLOTS];
extern const uint8_t block_flags[256];

int world_find(int cx, int cz);              /* slot or -1 when not ready */
int world_slot_of(int cx, int cz);
int world_get(int x, int y, int z);          /* block id, VX_UNKNOWN if unloaded */
void world_set(int x, int y, int z, int block);
void world_gen_sync(int cx, int cz, int seed);
void world_finish_slot(int slot, int maxy);  /* marks chunk + neighbours dirty */
/* DDA ray cast; out = hit xyz, previous (empty) xyz. Returns 1 on hit. */
int world_raycast(float ox, float oy, float oz, float dx, float dy, float dz,
		float maxd, int out[6]);

/* ---- mesh.asm ----------------------------------------------------------- */
typedef struct vx_vertex {
	int16_t x, y, z, pad;   /* 1/8 block units, chunk-local */
	int16_t u, v;           /* 1/16 texel units in the 128x64 atlas */
	uint8_t r, g, b, a;
} vx_vertex;                /* 16 bytes */

extern vx_vertex mesh_buf_surf[], mesh_buf_deep[], mesh_buf_wat[];
/* Builds the three mesh parts for a ready slot at detail scale 1, 2 or 4
 * (nodes per cell); counts land in chunk_info. */
void mesh_chunk(int slot, int scale);
void mesh_set_leaves_opaque(int opaque);

/* ---- texgen.asm --------------------------------------------------------- */
/* Atlas: 16 x 2 tiles, each a texture repeated 8 x 8 at res pixels per
 * node; (res*128) x (res*16) pixels. Texture coordinates are in 1/16 node
 * units: 2048 x 256 spans the atlas whatever the resolution. */
extern uint8_t atlas_rgba[2048 * 2048 * 4];
extern int atlas_w, atlas_h;
void texgen_atlas(int res, int leaves_opaque);   /* res 16, 8, 4 or 1 */
#define VX_TILE_CRACK 24              /* 5 digging crack stages */

/* ---- liquid.asm --------------------------------------------------------- */
void liquid_push_around(int x, int y, int z);
int liquid_step(int max);                     /* returns nodes processed */
void liquid_reset(void);
int liquid_pending(void);

/* ---- items.asm: inventory, dig rules, crafting, furnaces, dropped items -- */
/* a slot is a dword: item id | count << 8 | tool damage << 16 */
extern uint32_t inv[36];              /* 0-8 hotbar, 9-35 main inventory */
extern uint32_t cursor, craft_grid[9], craft_out;
void inv_clear(void);
int inv_add(int item, int count);     /* returns what did not fit */
float dig_time(int block, int held_item);   /* seconds, < 0 = cannot dig */
int can_harvest(int block, int held_item);
void craft_update(void), craft_take(void);
void furnace_tick(float dt);
void ent_spawn(float x, float y, float z, float vx, float vy, float vz,
		uint32_t slot);
void ent_update(void);

/* ---- save.asm: worlds under $XDG_DATA_HOME/voxasm/worlds/world<N> ------- */
void save_init(void);
void world_create_dir(int n);
int load_meta(int n);
void save_all(void);

/* ---- horizon.asm: far terrain shell ------------------------------------- */
/* cols: per cell a u32 mask of solid 8-node mountain levels above the
 * ground (bit k = y -64 + 8k .. +8) and the s16 ground height */
void mapgen_horizon_tile(int tx, int tz, int seed, int16_t *heights,
		uint8_t *tops, uint64_t *cols);               /* 34 x 34 cells of 8 nodes */
void horizon_update(void), horizon_draw(void), horizon_reset(void);
/* mobs.asm: pigs (1), cows (2), zombies (3) */
int mob_spawn(int type, float x, float y, float z);   /* index or -1 */
void mob_update(void), mob_clear(void), draw_mobs(void);
int mob_attack(void);                   /* left click: 1 if a mob was hit */
extern int mob_count, set_difficulty;   /* 0 peaceful, 1 normal */
/* lodcube.asm: the near horizon rings as textured 8- and 16-node cubes */
void build_cubes(int slot, int tile_chunk_x, int tile_chunk_z);
void crop_tick(void);                   /* crops near the player grow */
extern int horizon_cube_verts;          /* cube-ring vertices drawn last frame */

/* ---- font.asm ----------------------------------------------------------- */
extern uint8_t font_rgba[128 * 64 * 4];
void font_build(void);
extern const uint8_t block_tiles[256 * 4];   /* top, side, bottom, pad */

#endif
