/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 29-6-2019 */


module jtcommnd_game(
    input             rst,
    input             prog_clk,
    input             clk,

    // Clock enables
    input             cen12,
    input             cen6,
    input             cen3,
    input             cen1p5,

    // Pixel enables
    output            pxl_cen,
    output            pxl2_cen,

    // Cabinet
    input      [5:0]  joystick1,
    input      [5:0]  joystick2,
    input      [1:0]  coin,
    input      [1:0]  cab_1p,
    input             service,

    // DIP switches
    input      [31:0] dipsw,
    input             dip_pause,
    output            dip_flip,

    // Video
    output     [3:0]  red,
    output     [3:0]  green,
    output     [3:0]  blue,
    output            LHBL,
    output            LVBL,
    output            HS,
    output            VS,

    // Audio
    output     [9:0]  psg0,
    output     [9:0]  psg1,
    output signed [15:0] fm0,
    output signed [15:0] fm1,

    // Main ROM
    output            main_cs,
    output     [16:0] main_addr,
    input      [7:0]  main_data,
    input             main_ok,

    // Sound ROM
    output            snd_cs,
    output     [14:0] snd_addr,
    input      [7:0]  snd_data,
    input             snd_ok,

    // Character ROM
    output     [13:1] char_addr,
    input      [15:0] char_data,
    input             char_ok,

    // Object ROM
    output     [16:1] obj_addr,
    input      [15:0] obj_data,
    input             obj_ok,

    // Scroll ROM
    output     [16:2] scr_addr,
    input      [31:0] scr_data,
    input             scr_ok,

    // PROM programming
    input      prog_we,
    input      [21:0] prog_addr,
    input      [7:0]  prog_data,

    // Layer enables
    input      [3:0]  gfx_en,

    // Debug
    input      [7:0]  debug_bus,
    output     [7:0]  debug_view
);

wire [ 8:0] V, H;
wire        HINIT, preLVBL, preLHBL;
wire [10:0] scr_hpos, scr_vpos;

wire [12:0] cpu_AB;
wire        flip;
wire [ 7:0] cpu_dout, char_dout, scr_dout;
wire        rd, cpu_cen, char_busy, scr_busy,
            char_cs, scr_cs, RnW;

wire [ 7:0] dipsw_a, dipsw_b;

// sound
wire sres_b, snd_int;
wire [7:0] snd_latch;

// OBJ
wire OKOUT, blcnten, bus_req, bus_ack;
wire [ 8:0] obj_AB;
wire [7:0] main_ram;

reg  [5:0] prom_sel;

wire LHBL_obj, LVBL_obj;
/*wire prom_1d = prom_sel[0];
wire prom_2d = prom_sel[1];
wire prom_3d = prom_sel[2];
// wire prom_1h = prom_sel[3];
// wire prom_6e = prom_sel[4];
wire prom_6l = prom_sel[5];*/

wire prom_1d = prog_we && prom_sel[0];
wire prom_2d = prog_we && prom_sel[1];
wire prom_3d = prog_we && prom_sel[2];
// wire prom_1h = prog_we && prom_sel[3];
// wire prom_6e = prog_we && prom_sel[4];
wire prom_6l = prog_we && prom_sel[5];

assign pxl2_cen = cen12;
assign pxl_cen  = cen6;

assign {dipsw_b, dipsw_a} = dipsw[15:0];
assign dip_flip = flip;
assign debug_view = 0;

jtgng_timer u_timer(
    .clk       ( clk      ),
    .cen6      ( cen6     ),
    .V         ( V        ),
    .H         ( H        ),
    .Hinit     ( HINIT    ),
    .LHBL      ( preLHBL  ),
    .LVBL      ( preLVBL  ),
    .LHBL_obj  ( LHBL_obj ),
    .LVBL_obj  ( LVBL_obj ),
    .HS        ( HS       ),
    .VS        ( VS       ),
    .Vinit     (          )
);

always @* begin
    prom_sel = 0;
    prom_sel[ prog_addr[10:8] ] = 1;
end

jtcommnd_main u_main(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .prog_clk   ( prog_clk      ),
    .cen6       ( cen6          ),
    .cen3       ( cen3          ),
    .cpu_cen    ( cpu_cen       ),
    .cen_sel     ( 1'b1         ),  // select 6 MHz see issue #22
    // Timing
    .flip       ( flip          ),
    .V          ( V             ),
    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),
    .H1         ( H[0]          ),
    // sound
    .sres_b     ( sres_b        ),
    .snd_latch  ( snd_latch     ),
    .snd_int    ( snd_int       ),
    // CHAR
    .char_dout  ( char_dout     ),
    .cpu_dout   ( cpu_dout      ),
    .char_cs    ( char_cs       ),
    .char_busy  ( char_busy     ),
    // SCROLL
    .scr_dout   ( scr_dout      ),
    .scr_cs     ( scr_cs        ),
    .scr_busy   ( scr_busy      ),
    .scr_hpos   ( scr_hpos      ),
    .scr_vpos   ( scr_vpos      ),
    // OBJ - bus sharing
    .obj_AB     ( obj_AB        ),
    .cpu_AB     ( cpu_AB        ),
    .ram_dout   ( main_ram      ),
    .OKOUT      ( OKOUT         ),
    .blcnten    ( blcnten       ),
    .bus_req    ( bus_req       ),
    .bus_ack    ( bus_ack       ),
    // ROM
    .rom_cs     ( main_cs       ),
    .rom_addr   ( main_addr     ),
    .rom_data   ( main_data     ),
    .rom_ok     ( main_ok       ),
    // Cabinet input
    .cab_1p     ( cab_1p[1:0]   ),
    .coin       ( coin[1:0]     ),
    .service    ( service       ),
    .joystick1  ( joystick1[5:0]),
    .joystick2  ( joystick2[5:0]),

    .RnW        ( RnW           ),
    // PROM 6L (interrupts)
    .prog_addr  ( prog_addr[7:0]),
    .prom_6l_we ( prom_6l       ),
    .prog_din   ( prog_data[3:0]),
    // DIP switches
    .dip_pause  ( dip_pause     ),
    .dipsw_a    ( dipsw_a       ),
    .dipsw_b    ( dipsw_b       ),
    // Unused pins
    .blue_cs     (              ),
    .redgreen_cs (              ),
    .char_on     (              ),
    .snd2_latch  (              ),
    .scr2_hpos   (              ),
    .scr1_on     (              ),
    .scr2_on     (              ),
    .obj_on      (              ),
    .scr1_pal    (              ),
    .scr2_pal    (              )
);

jtgng_sound #(.LAYOUT(1)) u_sound (
    .rst            ( rst            ),
    .clk            ( clk            ),
    .cen3           ( cen3           ),
    .cen1p5         ( cen1p5         ),
    // Interface with main CPU
    .sres_b         ( sres_b         ),
    .snd_latch      ( snd_latch      ),
    .snd_int        ( snd_int        ),
    // ROM
    .rom_addr       ( snd_addr       ),
    .rom_data       ( snd_data       ),
    .rom_cs         ( snd_cs         ),
    .rom_ok         ( snd_ok         ),
    // sound output
    .fm0            ( fm0            ),
    .fm1            ( fm1            ),
    .psg0           ( psg0           ),
    .psg1           ( psg1           ),
    // Unused
    .debug_bus      ( debug_bus      ),
    .debug_view     (                ),
    .mcu_sdin       ( 8'd0           ),
    .mcu_srd        (                ),
    .snd2_latch     (                )
);

jtgng_video #(
    .OBJ_PAL      (2'b10),
    .PALETTE_PROM (1),
    .SCRWIN       (0),
    .PALETTE_RED  ("../../../rom/commando/vtb1.1d"),
    .PALETTE_GREEN("../../../rom/commando/vtb2.2d"),
    .PALETTE_BLUE ("../../../rom/commando/vtb3.3d")
) u_video(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen12      ( cen12         ),
    .cen6       ( cen6          ),
    .cpu_AB     ( cpu_AB[10:0]  ),
    .V          ( V[7:0]        ),
    .H          ( H             ),
    .RnW        ( RnW           ),
    .flip       ( flip          ),
    .cpu_dout   ( cpu_dout      ),
    // CHAR
    .char_cs    ( char_cs       ),
    .char_dout  ( char_dout     ),
    .char_addr  ( char_addr     ),
    .char_data  ( char_data     ),
    .char_busy  ( char_busy     ),
    .char_ok    ( char_ok       ),
    // SCROLL - ROM
    .scr_cs     ( scr_cs        ),
    .scr_dout   ( scr_dout      ),
    .scr_addr   ( scr_addr      ),
    .scr_data   ( scr_data[23:0]),
    .scr_busy   ( scr_busy      ),
    .scr_hpos   ( scr_hpos[8:0] ),
    .scr_vpos   ( scr_vpos[8:0] ),
    .scr_ok     ( scr_ok        ),
    // OBJ
    .HINIT      ( HINIT         ),
    .obj_AB     ( obj_AB        ),
    .main_ram   ( main_ram      ),
    .obj_addr   ( obj_addr      ),
    .obj_data   ( obj_data      ),
    .obj_ok     ( obj_ok        ),
    .OKOUT      ( OKOUT         ),
    .bus_req    ( bus_req       ), // Request bus
    .bus_ack    ( bus_ack       ), // bus acknowledge
    .blcnten    ( blcnten       ), // bus line counter enable
    // PROMs
    .prog_addr    ( prog_addr[7:0]),
    .prom_red_we  ( prom_1d       ),
    .prom_green_we( prom_2d       ),
    .prom_blue_we ( prom_3d       ),
    .prom_din     ( prog_data[3:0]),
    // Color Mix
    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),
    .LHBL_obj   ( LHBL_obj      ),
    .LVBL_obj   ( LVBL_obj      ),
    .preLHBL    ( preLHBL       ),
    .preLVBL    ( preLVBL       ),
    .gfx_en     ( gfx_en        ),
    .blue_cs    ( 1'b0          ),
    .redgreen_cs( 1'b0          ),
    // Pixel Output
    .red        ( red           ),
    .green      ( green         ),
    .blue       ( blue          )
);

endmodule
