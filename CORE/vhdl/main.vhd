----------------------------------------------------------------------------------
-- MiSTer2MEGA65 Framework
--
-- Wrapper for the MiSTer core that runs exclusively in the core's clock domanin
--
-- MiSTer2MEGA65 done by sy2002 and MJoergen in 2022 and licensed under GPL v3
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.video_modes_pkg.all;
use work.globals.all;
library work;
use work.video_modes_pkg.all;
library xpm;
use xpm.vcomponents.all;



entity main is
   generic (
      G_VDNUM                 : natural                     -- amount of virtual drives
   );
   port (
      clk_main_i              : in  std_logic;
      reset_soft_i            : in  std_logic;
      reset_hard_i            : in  std_logic;
      pause_i                 : in  std_logic;

      -- MiSTer core main clock speed:
      -- Make sure you pass very exact numbers here, because they are used for avoiding clock drift at derived clocks
      clk_main_speed_i        : in  natural;

      -- Video output
      video_ce_o              : out std_logic;
      video_ce_ovl_o          : out std_logic;
      video_red_o             : out std_logic_vector(3 downto 0);
      video_green_o           : out std_logic_vector(3 downto 0);
      video_blue_o            : out std_logic_vector(3 downto 0);
      video_vs_o              : out std_logic;
      video_hs_o              : out std_logic;
      video_hblank_o          : out std_logic;
      video_vblank_o          : out std_logic;

      -- Audio output (Signed PCM)
      audio_left_o            : out signed(15 downto 0);
      audio_right_o           : out signed(15 downto 0);

      -- M2M Keyboard interface
      kb_key_num_i            : in  integer range 0 to 79;    -- cycles through all MEGA65 keys
      kb_key_pressed_n_i      : in  std_logic;                -- low active: debounced feedback: is kb_key_num_i pressed right now?

      -- MEGA65 joysticks and paddles/mouse/potentiometers
      joy_1_up_n_i            : in  std_logic;
      joy_1_down_n_i          : in  std_logic;
      joy_1_left_n_i          : in  std_logic;
      joy_1_right_n_i         : in  std_logic;
      joy_1_fire_n_i          : in  std_logic;

      joy_2_up_n_i            : in  std_logic;
      joy_2_down_n_i          : in  std_logic;
      joy_2_left_n_i          : in  std_logic;
      joy_2_right_n_i         : in  std_logic;
      joy_2_fire_n_i          : in  std_logic;

      pot1_x_i                : in  std_logic_vector(7 downto 0);
      pot1_y_i                : in  std_logic_vector(7 downto 0);
      pot2_x_i                : in  std_logic_vector(7 downto 0);
      pot2_y_i                : in  std_logic_vector(7 downto 0);
      
       -- ROM download bus from QNICE
      dn_clk_i                : in  std_logic;
      dn_addr_i               : in  std_logic_vector(24 downto 0);
      dn_data_i               : in  std_logic_vector(7 downto 0);
      dn_wr_i                 : in  std_logic;
      
      
      osm_control_i           : in  std_logic_vector(255 downto 0)
   );
end entity main;

architecture synthesis of main is

-- @TODO: Remove these demo core signals
signal keyboard_n          : std_logic_vector(79 downto 0);


-- -------------------------------------------------------------------------
-- Exed Exes core signals
-- -------------------------------------------------------------------------

-- Reset
signal reset       : std_logic;


-- DIP switches
signal cm_dipsw_a  : std_logic_vector(7 downto 0);
signal cm_dipsw_b  : std_logic_vector(7 downto 0);
signal cm_dipsw    : std_logic_vector(31 downto 0);

-- Commando controls
signal commnd_cab_1p     : std_logic_vector(1 downto 0);
signal commnd_coin       : std_logic_vector(1 downto 0);
signal service           : std_logic;
signal joystick1         : std_logic_vector(5 downto 0);
signal joystick2         : std_logic_vector(5 downto 0);

-- DIP switches
signal commnd_dipsw      : std_logic_vector(31 downto 0);
signal dip_pause         : std_logic;
signal dip_flip          : std_logic;

-- JTFRAME clock enables
signal cen12             : std_logic;
signal cen6              : std_logic;
signal cen3              : std_logic;
signal cen1p5            : std_logic;
signal cen_bus           : std_logic_vector(3 downto 0);

signal pxl_cen           : std_logic;
signal pxl2_cen          : std_logic;

-- Audio
signal psg0              : std_logic_vector(9 downto 0);
signal psg1              : std_logic_vector(9 downto 0);
signal fm0               : std_logic_vector(15 downto 0);
signal fm1               : std_logic_vector(15 downto 0);

signal audio_mixed       : signed(15 downto 0);

-- Main ROM
signal main_cs           : std_logic;
signal main_addr         : std_logic_vector(16 downto 0);
signal main_data         : std_logic_vector(7 downto 0);
signal main_ok           : std_logic;

-- Sound ROM
signal snd_cs            : std_logic;
signal snd_addr          : std_logic_vector(14 downto 0);
signal snd_data          : std_logic_vector(7 downto 0);
signal snd_ok            : std_logic;

-- Character ROM
signal char_addr         : std_logic_vector(13 downto 1);
signal char_data         : std_logic_vector(15 downto 0);
signal char_ok           : std_logic;

-- Object ROM
signal obj_addr          : std_logic_vector(16 downto 1);
signal obj_data          : std_logic_vector(15 downto 0);
signal obj_ok            : std_logic;

-- Scroll ROM
signal scr_addr          : std_logic_vector(16 downto 2);
signal scr_data          : std_logic_vector(31 downto 0);
signal scr_ok            : std_logic;


-- ROM download / PROM programming
signal ioctl_addr  : std_logic_vector(25 downto 0);
signal prog_addr   : std_logic_vector(25 downto 0);
signal prog_data   : std_logic_vector(7 downto 0);
signal prom_we     : std_logic;
signal pre_addr    : std_logic_vector(25 downto 0);
signal post_addr   : std_logic_vector(25 downto 0);
signal shoot2_button1_n : std_logic := '1';
signal shoot2_button2_n : std_logic := '1';
signal pot1_val    : std_logic_vector(7 downto 0);
signal pot2_val    : std_logic_vector(7 downto 0);
signal potxy1_sw   : std_logic;
signal potxy2_sw   : std_logic;
signal pot_pol1_sw : std_logic;
signal pot_pol2_sw : std_logic;

signal dn_main_we   : std_logic;
signal dn_snd_we     : std_logic;

signal dn_char_lo_we : std_logic;
signal dn_char_hi_we : std_logic;

signal dn_obj_lo_we  : std_logic;
signal dn_obj_hi_we  : std_logic;

signal dn_scr_0_we   : std_logic;
signal dn_scr_1_we   : std_logic;
signal dn_scr_2_we   : std_logic;
signal dn_scr_3_we   : std_logic;


-- Offer some keyboard controls in addition to Joy 1 Controls
constant m65_1          : integer := 56; --Player 1 Start
constant m65_2          : integer := 59; --Player 2 Start
constant m65_5          : integer := 16; --Insert coin 1
constant m65_6          : integer := 19; --Insert coin 2
constant m65_9          : integer := 32; --Service button

constant m65_up_crsr    : integer := 73; --Player up
constant m65_vert_crsr  : integer := 7;  --Player down
constant m65_left_crsr  : integer := 74; --Player left
constant m65_horz_crsr  : integer := 2;  --Player right
constant m65_z          : integer := 12; --Fire 1
constant m65_x          : integer := 23; --Fire 2
constant m65_capslock   : integer := 72; --Pause




-- -------------------------------------------------------------------------
-- Commando ROM download map
-- -------------------------------------------------------------------------
constant C_MAIN_START : natural := 16#000000#;
constant C_SND_START  : natural := 16#00C000#;
constant C_CHAR_START : natural := 16#010000#;
constant C_OBJ_START  : natural := 16#014000#;
constant C_SCR_START  : natural := 16#02C000#;
constant C_PROM_START : natural := 16#04C000#;
constant C_IRQ_START  : natural := 16#04C500#;
constant C_ROM_END    : natural := 16#04C600#;



-- Object ROM download address after converting the physical graphics
-- layout into the layout expected by jtgng_objdraw.
signal dl_obj_word : std_logic_vector(14 downto 0);

-- Scroll 1 ROM download address after converting the physical 16x16
-- graphics layout into the layout expected by jtexed_scr1.
signal dl_scr1_word : std_logic_vector(14 downto 0);

begin

    -- Core reset
    reset <= reset_soft_i or reset_hard_i;
    
    cen_bus <= cen1p5 & cen3 & cen6 & cen12;
    video_ce_o <= cen6;

    prog_addr <= '0' & dn_addr_i;
    prog_data <= dn_data_i;
    
    dn_main_we <= dn_wr_i
       when unsigned(dn_addr_i) >= C_MAIN_START and
            unsigned(dn_addr_i) <  C_SND_START
       else '0';

    dn_snd_we <= dn_wr_i
       when unsigned(dn_addr_i) >= C_SND_START and
            unsigned(dn_addr_i) <  C_CHAR_START
       else '0';
    
    
    dn_char_lo_we <= dn_wr_i
       when unsigned(dn_addr_i) >= C_CHAR_START and
            unsigned(dn_addr_i) <  C_OBJ_START and
            dn_addr_i(0) = '0'
       else '0';
    
    dn_char_hi_we <= dn_wr_i
       when unsigned(dn_addr_i) >= C_CHAR_START and
            unsigned(dn_addr_i) <  C_OBJ_START and
            dn_addr_i(0) = '1'
       else '0';
    
    
    dn_obj_lo_we <= dn_wr_i
       when unsigned(dn_addr_i) >= C_OBJ_START and
            unsigned(dn_addr_i) <  C_SCR_START and
            dn_addr_i(0) = '0'
       else '0';
    
    dn_obj_hi_we <= dn_wr_i
       when unsigned(dn_addr_i) >= C_OBJ_START and
            unsigned(dn_addr_i) <  C_SCR_START and
            dn_addr_i(0) = '1'
       else '0';
    
    
    dn_scr_0_we <= dn_wr_i
       when unsigned(dn_addr_i) >= C_SCR_START and
            unsigned(dn_addr_i) <  C_PROM_START and
            dn_addr_i(1 downto 0) = "00"
       else '0';
    
    dn_scr_1_we <= dn_wr_i
       when unsigned(dn_addr_i) >= C_SCR_START and
            unsigned(dn_addr_i) <  C_PROM_START and
            dn_addr_i(1 downto 0) = "01"
       else '0';
    
    dn_scr_2_we <= dn_wr_i
       when unsigned(dn_addr_i) >= C_SCR_START and
            unsigned(dn_addr_i) <  C_PROM_START and
            dn_addr_i(1 downto 0) = "10"
       else '0';
    
    dn_scr_3_we <= dn_wr_i
       when unsigned(dn_addr_i) >= C_SCR_START and
            unsigned(dn_addr_i) <  C_PROM_START and
            dn_addr_i(1 downto 0) = "11"
       else '0';
    
 
    -- SW1
    cm_dipsw_a <= not (
    osm_control_i(C_MENU_SW1_0) &
    osm_control_i(C_MENU_SW1_1) &
    osm_control_i(C_MENU_SW1_2) &
    osm_control_i(C_MENU_SW1_3) &
    osm_control_i(C_MENU_SW1_4) &
    osm_control_i(C_MENU_SW1_5) &
    osm_control_i(C_MENU_SW1_6) &
    osm_control_i(C_MENU_SW1_7));
    
    cm_dipsw_b <= not (
    osm_control_i(C_MENU_SW2_0) &
    osm_control_i(C_MENU_SW2_1) &
    osm_control_i(C_MENU_SW2_2) &
    osm_control_i(C_MENU_SW2_3) &
    osm_control_i(C_MENU_SW2_4) &
    osm_control_i(C_MENU_SW2_5) &
    osm_control_i(C_MENU_SW2_6) &
    osm_control_i(C_MENU_SW2_7));
    
    cm_dipsw <=  x"0000" & cm_dipsw_b & cm_dipsw_a;
    commnd_cab_1p(0) <= keyboard_n(m65_1); -- 1P Start
    commnd_cab_1p(1) <= keyboard_n(m65_2); -- 2P Start
    commnd_coin(0) <= keyboard_n(m65_6);   -- Coin 1
    commnd_coin(1) <= keyboard_n(m65_5);   -- Coin 2
    
    potxy1_sw   <= osm_control_i(C_MENU_SECOND_FIRE_1); -- Joy 1: 0 = POTX, 1 = POTY
    potxy2_sw   <= osm_control_i(C_MENU_SECOND_FIRE_2); -- Joy 2: 0 = POTX, 1 = POTY
    pot_pol1_sw <= osm_control_i(C_MENU_POTPOL_1);      -- Joy 1 polarity
    pot_pol2_sw <= osm_control_i(C_MENU_POTPOL_2);      -- Joy 2 polarity
    
    second_button_proc : process(all)
    begin
    
       -------------------------------------------------------------------------
       -- Select POTX/POTY independently for both joystick ports
       ------------------------------------------------------------------------
        
        -- Player 1
        if potxy1_sw = '0' then
           pot1_val <= pot1_x_i;
        else
           pot1_val <= pot1_y_i;
        end if;
        
        -- Player 2
        if potxy2_sw = '0' then
           pot2_val <= pot2_x_i;
        else
           pot2_val <= pot2_y_i;
        end if;
    
       ------------------------------------------------------------------------
       -- Player 1 second fire
       ------------------------------------------------------------------------
       if pot_pol1_sw = '1' then
    
          -- Active-low POT button
          if unsigned(pot1_val) < unsigned'(x"80") then
             shoot2_button1_n <= '0';
          else
             shoot2_button1_n <= '1';
          end if;
       else
          -- Active-high POT button
          if unsigned(pot1_val) >= unsigned'(x"80") then
             shoot2_button1_n <= '0';
          else
             shoot2_button1_n <= '1';
          end if;
       end if;
       
       -----------------------------------------------------------------------
       -- Player 2 second fire
       ------------------------------------------------------------------------
       if pot_pol2_sw = '1' then
    
          -- Active-low POT button
          if unsigned(pot2_val) < unsigned'(x"80") then
             shoot2_button2_n <= '0';
          else
             shoot2_button2_n <= '1';
          end if;
       else
          -- Active-high POT button
          if unsigned(pot2_val) >= unsigned'(x"80") then
             shoot2_button2_n <= '0';
          else
             shoot2_button2_n <= '1';
          end if;
       end if;
    end process;
    
    -- -------------------------------------------------------------------------
    -- Player 1 controls
    -- Active low
    -- -------------------------------------------------------------------------
    
    -- Player 1 joystick - active low
    joystick1(0) <= joy_1_right_n_i and keyboard_n(m65_horz_crsr);
    joystick1(1) <= joy_1_left_n_i  and keyboard_n(m65_left_crsr);
    joystick1(2) <= joy_1_down_n_i  and keyboard_n(m65_vert_crsr);
    joystick1(3) <= joy_1_up_n_i    and keyboard_n(m65_up_crsr);
    -- Button 1 = Z / joystick fire
    joystick1(4) <= joy_1_fire_n_i and keyboard_n(m65_z);
    -- Button 2 = X / second joystick button
    joystick1(5) <=  keyboard_n(m65_x) and shoot2_button1_n;
    
    -- Player 2 joystick - active low
    joystick2(0) <= joy_2_right_n_i and keyboard_n(m65_horz_crsr);
    joystick2(1) <= joy_2_left_n_i  and keyboard_n(m65_left_crsr);
    joystick2(2) <= joy_2_down_n_i  and keyboard_n(m65_vert_crsr);
    joystick2(3) <= joy_2_up_n_i    and keyboard_n(m65_up_crsr);
    -- Butto2 1 = Z / joystick fire
    joystick2(4) <= joy_2_fire_n_i and keyboard_n(m65_z);
    -- Button 2 = X / second joystick button
    joystick2(5) <=  keyboard_n(m65_x) and shoot2_button2_n;
    
    i_jtframe_gated_cen : entity work.jtframe_gated_cen
    generic map (
       W     => 4,
       NUM   => 1,
       DEN   => 4,
       MFREQ => 48000
    )
    port map (
       rst    => reset,
       clk    => clk_main_i,
       busy   => '0',
       cen    => cen_bus,
       fave   => open,
       fworst => open
    );
   
   

    -- -------------------------------------------------------------------------
    -- Commando
    -- -------------------------------------------------------------------------
    
    i_jtcommnd_game : entity work.jtcommnd_game
    port map (
       -- Clock / reset
       rst         => reset,
       clk         => clk_main_i,
    
       -- Clock enables
       cen12       => cen12,
       cen6        => cen6,
       cen3        => cen3,
       cen1p5      => cen1p5,
    
       -- Pixel enables
       pxl_cen     => pxl_cen,
       pxl2_cen    => pxl2_cen,
    
       -- Cabinet
       joystick1   => joystick1,
       joystick2   => joystick2,
       coin        => commnd_coin,
       cab_1p      => commnd_cab_1p,
       service     => service,
    
       -- DIP switches
       dipsw       => cm_dipsw,
       dip_pause   => keyboard_n(m65_capslock),-- '1',     -- pause is active low, active high run
       dip_flip    => open,
    
       -- Video
       
       red         => video_red_o,
       green       => video_green_o,
       blue        => video_blue_o,
       LHBL        => video_hblank_o,
       LVBL        => video_vblank_o,
       HS          => video_hs_o,
       VS          => video_vs_o,
    
       -- Audio
       psg0        => psg0,
       psg1        => psg1,
       fm0         => fm0,
       fm1         => fm1,
    
       -- Main ROM
       main_cs     => main_cs,
       main_addr   => main_addr,
       main_data   => main_data,
       main_ok     => main_ok,
    
       -- Sound ROM
       snd_cs      => snd_cs,
       snd_addr    => snd_addr,
       snd_data    => snd_data,
       snd_ok      => snd_ok,
    
       -- Character ROM
       char_addr   => char_addr,
       char_data   => char_data,
       char_ok     => char_ok,
    
       -- Object ROM
       obj_addr    => obj_addr,
       obj_data    => obj_data,
       obj_ok      => obj_ok,
    
       -- Scroll ROM
       scr_addr    => scr_addr,
       scr_data    => scr_data,
       scr_ok      => scr_ok,
    
       -- PROM programming
       prog_addr   => prog_addr(21 downto 0),
       prog_data   => prog_data,

       -- Layer enables
       gfx_en      => (others => '1'),
    
       -- Debug
       debug_bus   => (others => '0'),
       debug_view  => open
    );
   
   
   -- Jotego audio path.
   -- Use the audio mixer
    i_audio_mixer : entity work.jtframe_mixer
    generic map (
       W0   => 10,
       W1   => 10,
       W2   => 16,
       W3   => 16,
       WOUT => 16
    )
    port map (
       rst   => reset,
       clk   => clk_main_i,
       cen   => '1',
    
       ch0   => signed(psg0),
       ch1   => signed(psg1),
       ch2   => signed(fm0),
       ch3   => signed(fm1),
    
       gain0 => x"10",
       gain1 => x"10",
       gain2 => x"20",
       gain3 => x"20",
    
       mixed => audio_mixed,
       peak  => open
    );
    
    audio_left_o  <= audio_mixed;
    audio_right_o <= audio_mixed;


   -- ----------------------------------------------------------------------
   -- Exed Exes ROM BRAMs. Port A = 48 MHz core read, Port B = QNICE write.
   -- Wide JTFRAME buses are assembled from byte lanes.
   -- ----------------------------------------------------------------------
    

     
   i_keyboard : entity work.keyboard
      port map (
         clk_main_i           => clk_main_i,

         -- Interface to the MEGA65 keyboard
         key_num_i            => kb_key_num_i,
         key_pressed_n_i      => kb_key_pressed_n_i,

         -- @TODO: Create the kind of keyboard output that your core needs
         -- "example_n_o" is a low active register and used by the demo core:
         --    bit 0: Space
         --    bit 1: Return
         --    bit 2: Run/Stop
         example_n_o          => keyboard_n
      ); -- i_keyboard

end architecture synthesis;