library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity kamikaze_graph_st is
	port(
		clk, reset: in std_logic;
		btn: in std_logic_vector(3 downto 0);
		video_on, reset_all: in std_logic;
		pixel_x, pixel_y: in std_logic_vector(9 downto 0);
		welcome_on, gameover_on: in std_logic;
		graph_rgb: out std_logic_vector(7 downto 0);
		led, led2: out std_logic
	);
end kamikaze_graph_st;

architecture arch of kamikaze_graph_st is
	
	-- constants
	constant MAX_X: integer := 640;			-- number of horizontal pixels
	constant MAX_Y: integer := 480;			-- number of vertical pixels
	constant SHIP_V: integer := 1;			-- ship moving velocity
	constant BULLET_V: integer := 5;			-- bullet moving velocity
	constant SHIP_SIZE: integer := 53;		-- size of ship square box
	constant BULLET_SIZE: integer := 8;		-- size of bullet box
	constant ROM_ADDR_SIZE: integer := 15;	--	size of rom_addr (bits)
	constant ROM_COL_SIZE: integer := 5;	-- size of rom_col signal used to access every column
	constant ENEMY1_X_POS, ENEMY1_Y_POS: std_logic_vector(9 downto 0) := (others=>'0');
	constant ENEMY2_X_POS: std_logic_vector(9 downto 0) := "1001101001";
	constant ENEMY2_Y_POS: std_logic_vector(9 downto 0) := (others=>'0');
	constant ENEMY3_X_POS: std_logic_vector(9 downto 0) := (others=>'0');
	constant ENEMY3_Y_POS: std_logic_vector(9 downto 0) := "0111001001";
	constant ENEMY4_X_POS: std_logic_vector(9 downto 0) := "1001101001";
	constant ENEMY4_Y_POS: std_logic_vector(9 downto 0) := "0111001001";
	constant ROM_MULTI: integer := 2809;
--	constant BG_SIZE_X: integer := 160;
--	constant BG_SIZE_Y: integer := 120;
--	constant ROM_BG_ADDR_SIZE: integer := 15;
	
	-- bullet image rom
	type rom_type is array(0 to BULLET_SIZE-1) of std_logic_vector(0 to BULLET_SIZE-1);
	constant BULLET_ROM: rom_type := (
		"00111100",
		"01111110",
		"11111111",
		"11111111",
		"11111111",
		"11111111",
		"01111110",
		"00111100");

	-- x, y coordinates (0,0) to (639, 479)
	signal pix_x, pix_y: unsigned(9 downto 0);
	signal refr_tick: std_logic; -- 60-Hz enable tick
	signal mod16_ref_reg, mod16_ref_next: unsigned(3 downto 0);
	signal mod128_ref_reg, mod128_ref_next: unsigned(6 downto 0);
	
	-- ship box: left, right, top, bottom borders
	signal ship_main_y_t: unsigned(9 downto 0);
	signal ship_main_y_b: unsigned(9 downto 0);
	signal ship_main_y_reg, ship_main_y_next: unsigned(9 downto 0); -- for anchor point in top left
	signal ship_main_x_l: unsigned(9 downto 0);
	signal ship_main_x_r: unsigned(9 downto 0);
	signal ship_main_x_reg, ship_main_x_next: unsigned(9 downto 0);
	-- main ship orientation register
	signal ship_main_orient_reg, ship_main_orient_next: unsigned(2 downto 0);
	
	-- ship bullet signals
	signal bullet_y_t, bullet_y_b: unsigned(9 downto 0);
	signal bullet_x_l, bullet_x_r: unsigned(9 downto 0);
	signal bullet_x_reg, bullet_x_next: unsigned(9 downto 0);
	signal bullet_y_reg, bullet_y_next: unsigned(9 downto 0);
	signal bullet_at_edge_reg, bullet_at_edge_next: std_logic;
	signal bullet_direction_reg, bullet_direction_next: unsigned(2 downto 0);
	signal sq_bullet_on, rd_bullet_on: std_logic;
	signal bullet_rgb: std_logic_vector(7 downto 0);
	signal hit_by_enemy: std_logic_vector(3 downto 0);
	signal enemy_hit: std_logic_vector(3 downto 0);
	
	-- signal to indicate if scan coord is whithin the ship
	signal sq_ship_main_on: std_logic;
	signal ship_main_on: std_logic;
	-- signal ship_rgb: std_logic_vector(7 downto 0);
	signal ship_enemy_on: std_logic_vector(3 downto 0);
	signal enemy1_rgb, enemy2_rgb, enemy3_rgb, enemy4_rgb: std_logic_vector(7 downto 0);
	signal level_up: std_logic_vector(3 downto 0);
	-- signal to be used for main ship ROM
	signal rom_addr: std_logic_vector(ROM_ADDR_SIZE-1 downto 0);	
	signal rom_addr_num: unsigned(ROM_ADDR_SIZE-1 downto 0);
	signal rom_data: std_logic_vector(7 downto 0);
	signal rom_byte: std_logic;
	
	-- signal to be used for bullet ROM
	signal rom_addr_bullet: unsigned(2 downto 0);	
	signal rom_col_bullet: unsigned(2 downto 0);
	signal rom_data_bullet: std_logic_vector(BULLET_SIZE-1 downto 0);
	signal rom_bit_bullet: std_logic;
	
--	-- signal to be used for background image
--	signal rom_bg_addr: std_logic_vector(ROM_BG_ADDR_SIZE-1 downto 0);
--	signal rom_bg_data: std_logic_vector(7 downto 0);
--	signal bg_rgb: std_logic_vector(7 downto 0);

	-- score
	signal dig0, dig1: std_logic_vector(3 downto 0);
	signal text_on: std_logic_vector(3 downto 0);
	signal text_rgb: std_logic_vector(2 downto 0);
	signal ship_main_hit: std_logic;
		
begin

	pix_x <= unsigned(pixel_x);
	pix_y <= unsigned(pixel_y);
	
	-- create a reference tick refr_tick: 1-clock tick asserted at start of v_sync
	-- e.g., when the screen is refreshed -- speed is 60 Hz
	refr_tick <= '1' when (pix_y = 481) and (pix_x = 0) else '0';
		
	-- registers for the ships and bullet(position and orientation)
	process(clk, reset)
	begin
		if (reset='1') then
			ship_main_y_reg <= to_unsigned(MAX_Y/2, 10);
			ship_main_x_reg <= to_unsigned(MAX_X/2, 10);
			ship_main_orient_reg <= (others=>'0');
			bullet_y_reg <= to_unsigned(MAX_Y/2,10);
			bullet_x_reg <= to_unsigned(MAX_X/2,10);
			bullet_at_edge_reg <= '0';
			bullet_direction_reg <= (others=>'0');
			mod16_ref_reg <= (others=>'0');
			mod128_ref_reg <= (others=>'0');
		elsif (clk'event and clk='1') then
			ship_main_y_reg <= ship_main_y_next;
			ship_main_x_reg <= ship_main_x_next;
			ship_main_orient_reg <= ship_main_orient_next;
			bullet_y_reg <= bullet_y_next;
			bullet_x_reg <= bullet_x_next;
			bullet_at_edge_reg <= bullet_at_edge_next;
			bullet_direction_reg <= bullet_direction_next;
			mod16_ref_reg <= mod16_ref_next;
			mod128_ref_reg <= mod128_ref_next;
		end if;
	end process;
	
--	-- instantiate background image
--	ocean_rom : entity work.background_rom
--		port map (
--			clka => clk,
--			addra => rom_bg_addr,
--			douta => rom_bg_data);
--			
--	-- BG_ROM access
--	process(pixel_tick, mod4_cnt_reg)
--	begin
--		mod4_cnt_next <= mod4_cnt_reg;
--		if (pixel_tick='1') then
--			mod4_cnt_next <= mod4_cnt_reg + 1; 
--		
--	
--	end process;
--	
--	-- stretch background image
--	process(pix_x, pix_y, )
--	begin
--		
--		
--		
--	end process;
		
	-- Current position of the main_ship box and its bullets
	ship_main_y_t <= ship_main_y_reg;
	ship_main_y_b <= ship_main_y_t + SHIP_SIZE-1;
	ship_main_x_l <= ship_main_x_reg;
	ship_main_x_r <= ship_main_x_l + SHIP_SIZE-1;
	bullet_y_t <= bullet_y_reg;
	bullet_y_b <= bullet_y_t + BULLET_SIZE-1;
	bullet_x_l <= bullet_x_reg;
	bullet_x_r <= bullet_x_l + BULLET_SIZE-1;
	
	-- Determine whether current pixel is within main ship box
	sq_ship_main_on <= '1' when (ship_main_x_l <= pix_x) and	(pix_x <= ship_main_x_r) and
						    (ship_main_y_t <= pix_y) and	(pix_y <= ship_main_y_b) 
					  else '0';
		
	-- map scan coord to ROM addr/col
	ship_main_rom : entity work.ship_rom
		port map (
			clka => clk,
			addra => rom_addr,
			douta => rom_data);
		
	-- select row from ROM
	process (ship_main_orient_reg, sq_ship_main_on, pix_y, pix_x, ship_main_y_t, ship_main_x_l)
	begin
		rom_addr_num <= (others=>'0');
		if sq_ship_main_on = '1' then
			case ship_main_orient_reg is
				when "000" =>
					rom_addr_num <= resize(SHIP_SIZE*(pix_y - ship_main_y_t) + pix_x - ship_main_x_l, ROM_ADDR_SIZE);
				
				when "001" =>
					rom_addr_num <= resize(ROM_MULTI + SHIP_SIZE*(pix_y - ship_main_y_t) + pix_x - ship_main_x_l, ROM_ADDR_SIZE);
					
				when "010" =>
					rom_addr_num <= resize(2*ROM_MULTI + SHIP_SIZE*(pix_y - ship_main_y_t) + pix_x - ship_main_x_l, ROM_ADDR_SIZE);
					
				when "011" =>
					rom_addr_num <= resize(3*ROM_MULTI + SHIP_SIZE*(pix_y - ship_main_y_t) + pix_x - ship_main_x_l, ROM_ADDR_SIZE);
					
				when "100" =>
					rom_addr_num <= resize(4*ROM_MULTI + SHIP_SIZE*(pix_y - ship_main_y_t) + pix_x - ship_main_x_l, ROM_ADDR_SIZE);
				
				when "101" =>
					rom_addr_num <= resize(5*ROM_MULTI + SHIP_SIZE*(pix_y - ship_main_y_t) + pix_x - ship_main_x_l, ROM_ADDR_SIZE);
				
				when "110" =>
					rom_addr_num <= resize(6*ROM_MULTI + SHIP_SIZE*(pix_y - ship_main_y_t) + pix_x - ship_main_x_l, ROM_ADDR_SIZE);
				
				when others =>
					rom_addr_num <= resize(7*ROM_MULTI + SHIP_SIZE*(pix_y - ship_main_y_t) + pix_x - ship_main_x_l, ROM_ADDR_SIZE);
			end case;
		end if;
	end process;

	rom_addr <= std_logic_vector(rom_addr_num);
	rom_byte <= '1' when rom_data /= x"00" else '0';
	ship_main_on <= '1' when (sq_ship_main_on = '1') and (rom_byte = '1') else '0';
		
	
	-- process ship movement request
	process(ship_main_y_reg, ship_main_x_reg, ship_main_orient_reg, ship_main_y_t, ship_main_y_b,
			  ship_main_x_r, ship_main_x_l, refr_tick, reset_all, btn, mod16_ref_reg, mod128_ref_reg)
	begin
		-- no move
		ship_main_y_next <= ship_main_y_reg;
		ship_main_x_next <= ship_main_x_reg;
		ship_main_orient_next <= ship_main_orient_reg;
		mod16_ref_next <= mod16_ref_reg;
		mod128_ref_next <= mod128_ref_reg;
		
		if (reset_all = '1') then
			ship_main_y_next <= to_unsigned(MAX_Y/2, 10);
			ship_main_x_next <= to_unsigned(MAX_X/2, 10);
			ship_main_orient_next <= (others=>'0');
			mod16_ref_next <= (others=>'0');
			mod128_ref_next <= (others=>'0');
		elsif (refr_tick = '1') then
		
			mod16_ref_next <= mod16_ref_reg + 1;
			mod128_ref_next <= mod128_ref_reg + 1;
			
			-- turn clockwise USE REFERENCE TICK and counter to control it slower
			if (btn(0) = '1' and mod16_ref_reg = 8) then
				ship_main_orient_next <= ship_main_orient_reg + 1;
			
			-- turn anti-clockwise
			elsif (btn(3) = '1' and mod16_ref_reg = 8) then
				ship_main_orient_next <= ship_main_orient_reg - 1;
				
			-- move forward
			elsif (btn(1) = '1') then
				case ship_main_orient_reg is
					when "000" =>
						if (ship_main_y_t > SHIP_V) then
							ship_main_y_next <= ship_main_y_reg - SHIP_V;
						end if;
						
					when "001" =>
						if (ship_main_x_r < (MAX_X - 1 - SHIP_V)) and (ship_main_y_t > SHIP_V) then
							ship_main_x_next <= ship_main_x_reg + SHIP_V;
							ship_main_y_next <= ship_main_y_reg - SHIP_V;
						end if;
					
					when "010" =>
						if (ship_main_x_r < (MAX_X - 1 - SHIP_V)) then
							ship_main_x_next <= ship_main_x_reg + SHIP_V;
						end if;
						
					when "011" =>
						if (ship_main_x_r < (MAX_X - 1 - SHIP_V)) and (ship_main_y_b < (MAX_Y - 1 - SHIP_V)) then
							ship_main_x_next <= ship_main_x_reg + SHIP_V;
							ship_main_y_next <= ship_main_y_reg + SHIP_V;
						end if;
						
					when "100" =>
						if (ship_main_y_b < (MAX_Y - 1 - SHIP_V)) then
							ship_main_y_next <= ship_main_y_reg + SHIP_V;
						end if;
					
					when "101" =>
						if (ship_main_y_b < (MAX_Y - 1 - SHIP_V)) and (ship_main_x_l > SHIP_V) then
							ship_main_x_next <= ship_main_x_reg - SHIP_V;
							ship_main_y_next <= ship_main_y_reg + SHIP_V;
						end if;
					
					when "110" =>
						if (ship_main_x_l > SHIP_V) then
							ship_main_x_next <= ship_main_x_reg - SHIP_V;
						end if;
						
					when others =>
						if (ship_main_x_l > SHIP_V) and (ship_main_y_t > SHIP_V) then
							ship_main_x_next <= ship_main_x_reg - SHIP_V;
							ship_main_y_next <= ship_main_y_reg - SHIP_V;
						end if;
				end case;
				
			-- move backward	
			elsif (btn(2) = '1') then
				case ship_main_orient_reg is
					when "000" =>
						if (ship_main_y_b < (MAX_Y - 1 - SHIP_V)) then
							ship_main_y_next <= ship_main_y_reg + SHIP_V;
						end if;
						
					when "001" =>
						if (ship_main_x_l > SHIP_V) and (ship_main_y_b < (MAX_Y - 1 - SHIP_V)) then
							ship_main_x_next <= ship_main_x_reg - SHIP_V;
							ship_main_y_next <= ship_main_y_reg + SHIP_V;
						end if;
					
					when "010" =>
						if (ship_main_x_l > SHIP_V) then
							ship_main_x_next <= ship_main_x_reg - SHIP_V;
						end if;
						
					when "011" =>
						if (ship_main_x_l > SHIP_V) and (ship_main_y_t > SHIP_V) then
							ship_main_x_next <= ship_main_x_reg - SHIP_V;
							ship_main_y_next <= ship_main_y_reg - SHIP_V;
						end if;
						
					when "100" =>
						if (ship_main_y_t > SHIP_V) then
							ship_main_y_next <= ship_main_y_reg - SHIP_V;
						end if;
					
					when "101" =>
						if (ship_main_x_r < (MAX_X - 1 - SHIP_V)) and (ship_main_y_t > SHIP_V) then
							ship_main_x_next <= ship_main_x_reg + SHIP_V;
							ship_main_y_next <= ship_main_y_reg - SHIP_V;
						end if;
					
					when "110" =>
						if (ship_main_x_r < (MAX_X - 1 - SHIP_V)) then
							ship_main_x_next <= ship_main_x_reg + SHIP_V;
						end if;
						
					when others =>
						if (ship_main_x_r < (MAX_X - 1 - SHIP_V)) and (ship_main_y_b < (MAX_Y - 1 - SHIP_V)) then
							ship_main_x_next <= ship_main_x_reg + SHIP_V;
							ship_main_y_next <= ship_main_y_reg + SHIP_V;
						end if;
				end case;
			end if;
		end if;
	end process;
	
	
	sq_bullet_on <= '1' when (bullet_x_l <= pix_x) and	(pix_x <= bullet_x_r) and
						    (bullet_y_t <= pix_y) and	(pix_y <= bullet_y_b) 
					  else '0';
	rom_addr_bullet <= pix_y(2 downto 0) - bullet_y_t(2 downto 0);
	rom_col_bullet <= pix_x(2 downto 0) - bullet_x_l(2 downto 0);
	rom_data_bullet <= BULLET_ROM(to_integer(rom_addr_bullet));
	rom_bit_bullet <= rom_data_bullet(to_integer(rom_col_bullet));
	rd_bullet_on <= '1' when (sq_bullet_on = '1') and (rom_bit_bullet = '1') else '0';
	bullet_rgb <= x"00";
	
	-- process shooting
	process(refr_tick, reset_all, bullet_x_reg, bullet_y_reg, bullet_y_t, bullet_y_b, bullet_x_l,
			  bullet_x_r, bullet_at_edge_reg, bullet_direction_reg, ship_main_orient_reg, 
			  ship_main_y_t, ship_main_y_b, ship_main_x_l, ship_main_x_r, mod128_ref_reg)
	begin
		-- default assignments
		bullet_y_next <= bullet_y_reg;
		bullet_x_next <= bullet_x_reg;
		bullet_at_edge_next <= bullet_at_edge_reg;
		bullet_direction_next <= bullet_direction_reg;
		
		if (reset_all='1') then
			bullet_y_next <= to_unsigned(MAX_Y/2,10);
			bullet_x_next <= to_unsigned(MAX_X/2,10);
			bullet_at_edge_next <= '0';
			bullet_direction_next <= (others=>'0');
		elsif (bullet_at_edge_reg='0') then
			-- keep on moving
			case bullet_direction_reg is
				when "000" =>
					if (bullet_y_t > BULLET_V) then
						if (refr_tick='1') then
							bullet_y_next <= bullet_y_reg - BULLET_V;
						end if;
					else
						bullet_at_edge_next <= '1';
					end if;
						
				when "001" =>
					if (bullet_x_r < (MAX_X - 1 - BULLET_V)) and (bullet_y_t > BULLET_V) then
						if (refr_tick='1') then
							bullet_x_next <= bullet_x_reg + BULLET_V;
							bullet_y_next <= bullet_y_reg - BULLET_V;
						end if;
					else
						bullet_at_edge_next <= '1';
					end if;
				
				when "010" =>
					if (bullet_x_r < (MAX_X - 1 - BULLET_V)) then
						if (refr_tick='1') then
							bullet_x_next <= bullet_x_reg + BULLET_V;
						end if;
					else
						bullet_at_edge_next <= '1';
					end if;
					
				when "011" =>
					if (bullet_x_r < (MAX_X - 1 - BULLET_V)) and (bullet_y_b < (MAX_Y - 1 - BULLET_V)) then
						if (refr_tick='1') then	
							bullet_x_next <= bullet_x_reg + BULLET_V;
							bullet_y_next <= bullet_y_reg + BULLET_V;
						end if;
					else
						bullet_at_edge_next <= '1';
					end if;
					
				when "100" =>
					if (bullet_y_b < (MAX_Y - 1 - BULLET_V)) then
						if (refr_tick='1') then	
							bullet_y_next <= bullet_y_reg + BULLET_V;
						end if;
					else
						bullet_at_edge_next <= '1';
					end if;
				
				when "101" =>
					if (bullet_y_b < (MAX_Y - 1 - BULLET_V)) and (bullet_x_l > BULLET_V) then
						if (refr_tick='1') then
							bullet_x_next <= bullet_x_reg - BULLET_V;
							bullet_y_next <= bullet_y_reg + BULLET_V;
						end if;
					else
						bullet_at_edge_next <= '1';
					end if;
				
				when "110" =>
					if (bullet_x_l > BULLET_V) then
						if (refr_tick='1') then
							bullet_x_next <= bullet_x_reg - BULLET_V;
						end if;
					else
						bullet_at_edge_next <= '1';
					end if;
					
				when others =>
					if (bullet_x_l > BULLET_V) and (bullet_y_t > BULLET_V) then
						if (refr_tick='1') then
							bullet_x_next <= bullet_x_reg - BULLET_V;
							bullet_y_next <= bullet_y_reg - BULLET_V;
						end if;
					else
						bullet_at_edge_next <= '1';
					end if;
				
				end case; 
						
		else -- start from the pointy end of the ship and travels straight
			if (mod128_ref_reg=9) then
				case ship_main_orient_reg is
					when "000" =>
						bullet_direction_next <= ship_main_orient_reg;
						bullet_y_next <= ship_main_y_t - BULLET_SIZE;
						bullet_x_next <= ship_main_x_l + 26;
						
						bullet_at_edge_next <= '0';
					
					when "001" =>
						bullet_direction_next <= ship_main_orient_reg;
						bullet_y_next <= ship_main_y_t - BULLET_SIZE;
						bullet_x_next <= ship_main_x_r - 4;
						
						bullet_at_edge_next <= '0';
						
					when "010" =>
						bullet_direction_next <= ship_main_orient_reg;
						bullet_y_next <= ship_main_y_t + 26;
						bullet_x_next <= ship_main_x_r + 1;
						
						bullet_at_edge_next <= '0';
						
					when "011" =>
						bullet_direction_next <= ship_main_orient_reg;
						bullet_y_next <= ship_main_y_b + 1;
						bullet_x_next <= ship_main_x_r - 4;
						
						bullet_at_edge_next <= '0';
						
					when "100" =>
						bullet_direction_next <= ship_main_orient_reg;
						bullet_y_next <= ship_main_y_b + 1;
						bullet_x_next <= ship_main_x_l + 26;
						
						bullet_at_edge_next <= '0';
					
					when "101" =>
						bullet_direction_next <= ship_main_orient_reg;
						bullet_y_next <= ship_main_y_b + 1;
						bullet_x_next <= ship_main_x_l - 4;
						
						bullet_at_edge_next <= '0';
					
					when "110" =>
						bullet_direction_next <= ship_main_orient_reg;
						bullet_y_next <= ship_main_y_t + 26;
						bullet_x_next <= ship_main_x_l - BULLET_SIZE;
						
						bullet_at_edge_next <= '0';
					
					when others =>
						bullet_direction_next <= ship_main_orient_reg;
						bullet_y_next <= ship_main_y_t - BULLET_SIZE;
						bullet_x_next <= ship_main_x_l - 4;
						
						bullet_at_edge_next <= '0';
						
				end case;
			end if;
		end if;
	end process;
	
	level_up(0)<='1';
	level_up(1)<='1';
	level_up(2)<='1' when dig1 >= "0001" else '0';
	level_up(3)<='1' when dig1 >= "0001" else '0';
	
	-- 1st enemy instantiation
	enemy_1: entity work.enemy(arch)
		generic map(X=>ENEMY1_X_POS, Y=>ENEMY1_Y_POS)
		port map(clk=>clk, reset=>reset, pixel_x=>pixel_x,
			pixel_y=>pixel_y, refr_tick=>refr_tick, reset_all=>reset_all, ship_main_y_t=>std_logic_vector(ship_main_y_t),
			ship_main_y_b=>std_logic_vector(ship_main_y_b), ship_main_x_l=>std_logic_vector(ship_main_x_l), 
			ship_main_x_r=>std_logic_vector(ship_main_x_r), bullet_y_t=>std_logic_vector(bullet_y_t),
			bullet_y_b=>std_logic_vector(bullet_y_b), bullet_x_l=>std_logic_vector(bullet_x_l),
			bullet_x_r=>std_logic_vector(bullet_x_r), ship_enemy_on=>ship_enemy_on(0), led=>hit_by_enemy(0),
			enemy_hit_on=>enemy_hit(0), enemy_rgb=>enemy1_rgb, level_up => level_up(0));
			
	-- 2nd enemy instantiation
	enemy_2: entity work.enemy(arch)
		generic map(X=>ENEMY2_X_POS, Y=>ENEMY2_Y_POS)
		port map(clk=>clk, reset=>reset, pixel_x=>pixel_x,
			pixel_y=>pixel_y, refr_tick=>refr_tick, reset_all=>reset_all, ship_main_y_t=>std_logic_vector(ship_main_y_t),
			ship_main_y_b=>std_logic_vector(ship_main_y_b), ship_main_x_l=>std_logic_vector(ship_main_x_l), 
			ship_main_x_r=>std_logic_vector(ship_main_x_r), bullet_y_t=>std_logic_vector(bullet_y_t),
			bullet_y_b=>std_logic_vector(bullet_y_b), bullet_x_l=>std_logic_vector(bullet_x_l),
			bullet_x_r=>std_logic_vector(bullet_x_r), ship_enemy_on => ship_enemy_on(1), led=>hit_by_enemy(1),
			enemy_hit_on=>enemy_hit(1), enemy_rgb=>enemy2_rgb,level_up => level_up(1));
			
	-- 3rd enemy instantiation
	enemy_3: entity work.enemy(arch)
		generic map(X=>ENEMY3_X_POS, Y=>ENEMY3_Y_POS)
		port map(clk=>clk, reset=>reset, pixel_x=>pixel_x,
			pixel_y=>pixel_y, refr_tick=>refr_tick, reset_all=>reset_all, ship_main_y_t=>std_logic_vector(ship_main_y_t),
			ship_main_y_b=>std_logic_vector(ship_main_y_b), ship_main_x_l=>std_logic_vector(ship_main_x_l), 
			ship_main_x_r=>std_logic_vector(ship_main_x_r), bullet_y_t=>std_logic_vector(bullet_y_t),
			bullet_y_b=>std_logic_vector(bullet_y_b), bullet_x_l=>std_logic_vector(bullet_x_l),
			bullet_x_r=>std_logic_vector(bullet_x_r), ship_enemy_on => ship_enemy_on(2), led=>hit_by_enemy(2),
			enemy_hit_on=>enemy_hit(2), enemy_rgb=>enemy3_rgb, level_up => level_up(2));
			
	-- 4th enemy instantiation
	enemy_4: entity work.enemy(arch)
		generic map(X=>ENEMY4_X_POS, Y=>ENEMY4_Y_POS)
		port map(clk=>clk, reset=>reset, pixel_x=>pixel_x,
			pixel_y=>pixel_y, refr_tick=>refr_tick, reset_all=>reset_all, ship_main_y_t=>std_logic_vector(ship_main_y_t),
			ship_main_y_b=>std_logic_vector(ship_main_y_b), ship_main_x_l=>std_logic_vector(ship_main_x_l), 
			ship_main_x_r=>std_logic_vector(ship_main_x_r), bullet_y_t=>std_logic_vector(bullet_y_t),
			bullet_y_b=>std_logic_vector(bullet_y_b), bullet_x_l=>std_logic_vector(bullet_x_l),
			bullet_x_r=>std_logic_vector(bullet_x_r), ship_enemy_on => ship_enemy_on(3), led=>hit_by_enemy(3),
			enemy_hit_on=>enemy_hit(3), enemy_rgb=>enemy4_rgb,level_up => level_up(3));
			
	ship_main_hit <= hit_by_enemy(0) or hit_by_enemy(1) or hit_by_enemy(2) or hit_by_enemy(3);
	
	-- instantiate text	
	text_unit: entity work.game_text
      port map(clk=>clk,pixel_x=>pixel_x, pixel_y=>pixel_y,
               dig0=>dig0, dig1=>dig1,text_on=>text_on, text_rgb=>text_rgb);
			 
 -- instantiate 2-digit decade counter
   counter_unit: entity work.m100_counter
      port map(clk=>clk, reset=>reset, enemy_hit=>enemy_hit, d_clr=>ship_main_hit, dig0=>dig0, dig1=>dig1, refr_tick=>refr_tick);

			   
	-- output logic
	process (video_on, ship_main_on, rom_data, ship_enemy_on, enemy1_rgb, enemy2_rgb, 
				enemy3_rgb, enemy4_rgb, rd_bullet_on, bullet_rgb,text_on,text_rgb, 
				gameover_on, welcome_on)
	begin
		if (video_on = '0') then
			graph_rgb <= (others=>'0'); -- blank
		else -- priority encoding implicit here
			if (ship_main_on='1') then
				graph_rgb <= rom_data(1 downto 0) & rom_data(4 downto 2) & rom_data(7 downto 5);
			elsif (rd_bullet_on='1') then
				graph_rgb <= bullet_rgb;			
			elsif ship_enemy_on(0) = '1' then 
					graph_rgb <= enemy1_rgb(1 downto 0) & enemy1_rgb(4 downto 2) & enemy1_rgb(7 downto 5);
			elsif ship_enemy_on(1) = '1' then
					graph_rgb <= enemy2_rgb(1 downto 0) & enemy2_rgb(4 downto 2) & enemy2_rgb(7 downto 5);
			elsif ship_enemy_on(2) = '1' then
					graph_rgb <= enemy3_rgb(1 downto 0) & enemy3_rgb(4 downto 2) & enemy3_rgb(7 downto 5);
			elsif ship_enemy_on(3) = '1' then
					graph_rgb <= enemy4_rgb(1 downto 0) & enemy4_rgb(4 downto 2) & enemy4_rgb(7 downto 5);
			elsif(text_on(3)='1') and (welcome_on /= '1') and (gameover_on /='1') then
				graph_rgb <= "00000" & text_rgb;
			elsif(text_on(2)='1') and (welcome_on = '1') then
				graph_rgb <= "00000" & text_rgb;
			elsif(text_on(1)='1') and (welcome_on = '1') then
				graph_rgb <= "00000" & text_rgb;
			elsif(text_on(0)='1') and (gameover_on='1') then
				graph_rgb <= "00000" & text_rgb;
			else
				graph_rgb <= "10011001"; -- bkgnd color
			end if;
		end if;
	end process;
	
	led <= ship_main_hit;
	led2 <= enemy_hit(0) or enemy_hit(1) or enemy_hit(2) or enemy_hit(3);
	
end arch;