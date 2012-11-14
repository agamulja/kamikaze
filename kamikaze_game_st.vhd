library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity kamikaze_graph_st is
	port(
		clk, reset: in std_logic;
		btn: in std_logic_vector(3 downto 0);
		video_on: in std_logic;
		pixel_x, pixel_y: in std_logic_vector(9 downto 0);
		graph_rgb: out std_logic_vector(7 downto 0);
		led: out std_logic
	);
end kamikaze_graph_st;

architecture arch of kamikaze_graph_st is
	-- constants
	constant MAX_X: integer := 640;			-- number of horizontal pixels
	constant MAX_Y: integer := 480;			-- number of vertical pixels
	constant SHIP_V: integer := 4;			-- ship moving velocity
	constant SHIP_SIZE: integer := 16;		-- size of ship square box
	constant ROM_ADDR_SIZE: integer := 7;	--	size of rom_addr (bits)
	constant ROM_COL_SIZE: integer := 4;	-- size of rom_col signal used to access every column

	-- x, y coordinates (0,0) to (639, 479)
	signal pix_x, pix_y: unsigned(9 downto 0);
	signal refr_tick: std_logic; -- 60-Hz enable tick
	signal mod4_ref_reg, mod4_ref_next: unsigned(4 downto 0);
	
	-- ship box: left, right, top, bottom borders
	signal ship_main_y_t: unsigned(9 downto 0);
	signal ship_main_y_b: unsigned(9 downto 0);
	signal ship_main_y_reg, ship_main_y_next: unsigned(9 downto 0); -- for anchor point in top left
	signal ship_main_x_l: unsigned(9 downto 0);
	signal ship_main_x_r: unsigned(9 downto 0);
	signal ship_main_x_reg, ship_main_x_next: unsigned(9 downto 0);
	-- main ship orientation register
	signal ship_main_orient_reg, ship_main_orient_next: unsigned(2 downto 0);
	
	-- signal to indicate if scan coord is whithin the ship
	signal ship_main_on: std_logic;
	signal sq_ship_main_on: std_logic;
	signal ship_rgb: std_logic_vector(7 downto 0);
	
	-- signal to be used for ROM
	signal rom_addr: std_logic_vector(ROM_ADDR_SIZE-1 downto 0);	
	signal rom_addr_num: unsigned(ROM_ADDR_SIZE-1 downto 0);
	signal rom_col: unsigned(ROM_COL_SIZE-1 downto 0);
	signal rom_data: std_logic_vector(SHIP_SIZE-1 downto 0);
	signal rom_bit: std_logic;
	-- Declare ship image ROM
	component ship_rom
		port (
		a: in std_logic_vector(ROM_ADDR_SIZE-1 downto 0);
		spo: out std_logic_vector(SHIP_SIZE-1 downto 0));
	end component;
		
		
begin

	pix_x <= unsigned(pixel_x);
	pix_y <= unsigned(pixel_y);
	
	-- create a reference tick refr_tick: 1-clock tick asserted at start of v_sync
	-- e.g., when the screen is refreshed -- speed is 60 Hz
	refr_tick <= '1' when (pix_y = 481) and (pix_x = 0) else '0';
		
	-- registers for the ship (position and orientation)
	process(clk, reset)
	begin
		if (reset='1') then
			ship_main_y_reg <= to_unsigned(MAX_Y/2, 10);
			ship_main_x_reg <= to_unsigned(MAX_X/2, 10);
			ship_main_orient_reg <= (others=>'0');
			mod4_ref_reg <= (others=>'0');
		elsif (clk'event and clk='1') then
			ship_main_y_reg <= ship_main_y_next;
			ship_main_x_reg <= ship_main_x_next;
			ship_main_orient_reg <= ship_main_orient_next;
			mod4_ref_reg <= mod4_ref_next;
		end if;
	end process;
		
	-- Current position of the ship box
	ship_main_y_t <= ship_main_y_reg;
	ship_main_y_b <= ship_main_y_t + SHIP_SIZE-1;
	ship_main_x_l <= ship_main_x_reg;
	ship_main_x_r <= ship_main_x_l + SHIP_SIZE-1;
	
	-- Determine whether current pixel is within main ship box
	sq_ship_main_on <= '1' when (ship_main_x_l <= pix_x) and	(pix_x <= ship_main_x_r) and
						    (ship_main_y_t <= pix_y) and	(pix_y <= ship_main_y_b) 
					  else '0';
		
	-- map scan coord to ROM addr/col
	ship_main_rom : ship_rom
			port map (
				a => rom_addr,
				spo => rom_data
			);
			
	-- select row from ROM
	process (ship_main_orient_reg, sq_ship_main_on, pix_y, ship_main_y_t)
	begin
		rom_addr_num <= (others=>'0');
		if sq_ship_main_on = '1' then
			case ship_main_orient_reg is
				when "000" =>
					rom_addr_num <= resize(pix_y-ship_main_y_t, ROM_ADDR_SIZE);
				
				when "001" =>
					rom_addr_num <= SHIP_SIZE + resize(pix_y-ship_main_y_t, ROM_ADDR_SIZE);
					
				when "010" =>
					rom_addr_num <= SHIP_SIZE*2 + resize(pix_y-ship_main_y_t, ROM_ADDR_SIZE);
					
				when "011" =>
					rom_addr_num <= SHIP_SIZE*3 + resize(pix_y-ship_main_y_t, ROM_ADDR_SIZE);
					
				when "100" =>
					rom_addr_num <= SHIP_SIZE*4 + resize(pix_y-ship_main_y_t, ROM_ADDR_SIZE);
				
				when "101" =>
					rom_addr_num <= SHIP_SIZE*5 + resize(pix_y-ship_main_y_t, ROM_ADDR_SIZE);
				
				when "110" =>
					rom_addr_num <= SHIP_SIZE*6 + resize(pix_y-ship_main_y_t, ROM_ADDR_SIZE);
				
				when others =>
					rom_addr_num <= SHIP_SIZE*7 + resize(pix_y-ship_main_y_t, ROM_ADDR_SIZE);
			end case;
		end if;
	end process;

	rom_addr <= std_logic_vector(rom_addr_num);
	rom_col <= pix_x(3 downto 0) - ship_main_x_l(3 downto 0);
	rom_bit <= rom_data(to_integer(SHIP_SIZE-1-rom_col));
	ship_main_on <= '1' when (sq_ship_main_on = '1') and (rom_bit = '1') else '0';
	ship_rgb <= "00011100"; -- color of the ship
	
	
	-- process ship movement request
	process(ship_main_y_reg, ship_main_x_reg, ship_main_orient_reg, ship_main_y_t, ship_main_y_b,
			  ship_main_x_r, ship_main_x_l, refr_tick, btn, mod4_ref_reg)
	begin
		-- no move
		ship_main_y_next <= ship_main_y_reg;
		ship_main_x_next <= ship_main_x_reg;
		ship_main_orient_next <= ship_main_orient_reg;
		mod4_ref_next <= mod4_ref_reg;
		if (refr_tick = '1') then
		
			mod4_ref_next <= mod4_ref_reg + 1;
			
			-- turn clockwise USE REFERENCE TICK and counter to control it slower
			if (btn(0) = '1' and mod4_ref_reg = 16) then
				ship_main_orient_next <= ship_main_orient_reg + 1;
			
			-- turn anti-clockwise
			elsif (btn(3) = '1' and mod4_ref_reg = 16) then
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
							ship_main_y_next <= ship_main_y_reg + SHIP_v;
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
						if (ship_main_x_r < (MAX_X - 1 - SHIP_V)) then
							ship_main_x_next <= ship_main_x_reg + SHIP_V;
						end if;
						
					when others =>
						if (ship_main_x_r < (MAX_X - 1 - SHIP_V)) and (ship_main_y_b < (MAX_Y - 1 - SHIP_V)) then
							ship_main_x_next <= ship_main_x_reg + SHIP_V;
							ship_main_y_next <= ship_main_y_reg + SHIP_v;
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
							ship_main_y_next <= ship_main_y_reg - SHIP_v;
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
						if (ship_main_x_l > SHIP_V) then
							ship_main_x_next <= ship_main_x_reg - SHIP_V;
						end if;
						
					when others =>
						if (ship_main_x_l > SHIP_V) and (ship_main_y_t > SHIP_V) then
							ship_main_x_next <= ship_main_x_reg - SHIP_V;
							ship_main_y_next <= ship_main_y_reg - SHIP_V;
						end if;
				end case;
			end if;
		end if;
	end process;
	
	-- output logic
	process (video_on, ship_main_on, ship_rgb)
	begin
		if (video_on = '0') then
			graph_rgb <= (others=>'0'); -- blank
		else -- priority encoding implicit here
			if (ship_main_on = '1') then
				graph_rgb <= ship_rgb;
			else
				graph_rgb <= "10011001"; -- bkgnd color
			end if;
		end if;
	end process;
	
	
	led <= '1' when ship_main_orient_reg = 2 else '0';
	
end arch;