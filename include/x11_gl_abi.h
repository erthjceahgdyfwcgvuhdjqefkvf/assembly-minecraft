#ifndef VOXASM_X11_GL_ABI_H
#define VOXASM_X11_GL_ABI_H

/* XVisualInfo */
#define VX_XVI_VISUAL           0
#define VX_XVI_DEPTH            20

/* XSetWindowAttributes (112 bytes) */
#define VX_XSWA_EVENT_MASK      72
#define VX_XSWA_COLORMAP        96
#define VX_XSWA_SIZE            112

/* XEvent (192 bytes) and the members main.asm reads */
#define VX_XEVENT_SIZE          192
#define VX_XEV_TYPE             0
#define VX_XBUTTON_BUTTON       84
#define VX_XMOTION_X            64
#define VX_XMOTION_Y            68
#define VX_XCONFIGURE_WIDTH     56
#define VX_XCONFIGURE_HEIGHT    60
#define VX_XCLIENT_DATA         56
#define VX_XCOLOR_SIZE          16

/* event types and masks */
#define VX_KeyPress             2
#define VX_KeyRelease           3
#define VX_ButtonPress          4
#define VX_MotionNotify         6
#define VX_FocusOut             10
#define VX_ConfigureNotify      22
#define VX_ClientMessage        33
#define VX_EVENT_MASK           0x22804F   /* key, button, motion, exposure,
                                              structure, focus */
#define VX_CW_FLAGS             0x2800     /* CWColormap | CWEventMask */

/* GLX visual attributes */
#define VX_GLX_RGBA             4
#define VX_GLX_DOUBLEBUFFER     5
#define VX_GLX_DEPTH_SIZE       12

/* GL 1.5 entry points loaded through glXGetProcAddressARB */
typedef void (*vx_glGenBuffers)(int n, unsigned *buffers);
typedef void (*vx_glBindBuffer)(unsigned target, unsigned buffer);
typedef void (*vx_glBufferData)(unsigned target, long size, const void *data,
		unsigned usage);

#define VX_GL_ARRAY_BUFFER      0x8892
#define VX_GL_STATIC_DRAW       0x88E4
#define VX_GL_SHORT             0x1402     /* vertex positions and texcoords */

#endif
