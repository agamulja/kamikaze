library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.all;

entity enemy is
	port(
		clk, reset, refr_tick: in std_logic;
		pixel_x, pixel_y: in std_logic_vector(9 downto 0);
		ship_enemy_rgb: out std_logic_vector(7 downto 0);
		ship_enemy_on: out std_logic
	);
end enemy;

architecture arch of enemy is

	-- constants
	constant MAX_X: integer := 640;
	constant MAX_Y: integer := 480;
	constant SHIP_V: integer := 1;
	constant SHIP_SIZE: integer := 22;
	constant ROM_ADDR_SIZE: integer := 8;	--	size of rom_addr (bits)
	constant ROM_COL_SIZE: integer := 5;	-- size of rom_col signal used to access every column
	
	-- x, y coordinates (0,0) to (639, 479)
	signal pix_x, pix_y: unsigned(9 downto 0);
	
	-- enemy ship borders
	signal ship_enemy_y_t: unsigned(9 downto 0);
	signal ship_enemy_y_b: unsigned(9 downto 0);
	signal ship_enemy_y_reg, ship_enemy_y_next: unsigned(9 downto 0); -- for anchor point in top left
	signal ship_enemy_x_l: unsigned(9 downto 0);
	signal ship_enemy_x_r: unsigned(9 downto 0);
	signal ship_enemy_x_reg, ship_enemy_x_next: unsigned(9 downto 0);
	signal sq_ship_enemy_on: std_logic; -- signal to indicate scan coord is within enemy ship
	--------- end enemy ship signal declaration-------

	--Enemy ship rom address
	signal rom_addr: std_logic_vector(ROM_ADDR_SIZE-1 downto 0);	
	signal rom_addr_num: unsigned(ROM_ADDR_SIZE-1 downto 0);
	signal rom_col: unsigned(ROM_COL_SIZE-1 downto 0);
	signal rom_data: std_logic_vector(SHIP_SIZE-1 downto 0);
	signal rom_bit: std_logic;

	-- Enemy ship orientation
	signal ship_enemy_orient_reg, ship_enemy_orient_next: unsigned(2 downto 0);

begin

	pix_x <= unsigned(pixel_x);
	pix_y <= unsigned(pixel_y);
	
	process(clk, reset)
	begin
		if (reset='1') then
			--enemy ship
			ship_enemy_y_reg <= to_unsigned(MAX_Y/4, 10);
			ship_enemy_x_reg <= to_unsigned(MAX_X/2, 10);
			ship_enemy_orient_reg <= ("100");
		elsif (clk'event and clk='1') then
			ship_enemy_y_reg <= ship_enemy_y_next;
			ship_enemy_x_reg <= ship_enemy_x_next;
			ship_enemy_orient_reg <= ship_enemy_orient_next;
		end if;
	end process;

	-- current position of the enemy ship box
	ship_enemy_y_t <= ship_enemy_y_reg;
	ship_enemy_y_b <= ship_enemy_y_t + SHIP_SIZE-1;
	ship_enemy_x_l <= ship_enemy_x_reg;
	ship_enemy_x_r <= ship_enemy_x_l + SHIP_SIZE-1;
			
	-- Determine whether current pixel is within enemy ship box
	sq_ship_enemy_on <= '1' when (ship_enemy_x_l <= pix_x) and	(pix_x <= ship_enemy_x_r) and
											(ship_enemy_y_t <= pix_y) and	(pix_y <= ship_enemy_y_b) 
									else '0';

	-- map scan coord to ROM addr/col
	ship_main_rom : entity work.ship_rom
		port map (
			clka => clk,
			addra => rom_addr,
			douta => rom_data);
			
	-- select row from Enemy ROM
	process (ship_enemy_orient_reg, sq_ship_enemy_on, pix_y, ship_enemy_y_t)
	begin
			rom_addr_num <= (others=>'0');
		if sq_ship_enemy_on = '1' then
			case ship_enemy_orient_reg is
				when "000" =>
					rom_addr_num <= resize(pix_y-ship_enemy_y_t, ROM_ADDR_SIZE);
				
				when "001" =>
					rom_addr_num <= SHIP_SIZE + resize(pix_y-ship_enemy_y_t, ROM_ADDR_SIZE);
					
				when "010" =>
					rom_addr_num <= SHIP_SIZE*2 + resize(pix_y-ship_enemy_y_t, ROM_ADDR_SIZE);
					
				when "011" =>
					rom_addr_num <= SHIP_SIZE*3 + resize(pix_y-ship_enemy_y_t, ROM_ADDR_SIZE);
					
				when "100" =>
					rom_addr_num <= SHIP_SIZE*4 + resize(pix_y-ship_enemy_y_t, ROM_ADDR_SIZE);
				
				when "101" =>
					rom_addr_num <= SHIP_SIZE*5 + resize(pix_y-ship_enemy_y_t, ROM_ADDR_SIZE);
				
				when "110" =>
					rom_addr_num <= SHIP_SIZE*6 + resize(pix_y-ship_enemy_y_t, ROM_ADDR_SIZE);
				
				when others =>
					rom_addr_num <= SHIP_SIZE*7 + resize(pix_y-ship_enemy_y_t, ROM_ADDR_SIZE);
			end case;
		end if;
	end process;

	-- Enemy ship on and color
	rom_addr <= std_logic_vector(rom_addr_num);
	rom_col <= resize(pix_x-ship_enemy_x_l, ROM_COL_SIZE) when sq_ship_enemy_on = '1' else (others=>'0');
	rom_bit <= rom_data(to_integer(SHIP_SIZE-1-rom_col));
	
	-- Outputs
	ship_enemy_on <= '1' when (sq_ship_enemy_on = '1') and (rom_bit = '1') else '0';
	ship_enemy_rgb <= "00000000"; -- color of the enemy ship
	
end arch;

