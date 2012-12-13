library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.all;

entity enemy is
	generic(
		X: std_logic_vector(9 downto 0) := (others=>'0');
		Y: std_logic_vector(9 downto 0) := (others=>'0')
	);
	port(
		clk, reset, refr_tick, reset_all: in std_logic;
		pixel_x, pixel_y: in std_logic_vector(9 downto 0);
		ship_main_y_t, ship_main_y_b: in std_logic_vector(9 downto 0);
		ship_main_x_l, ship_main_x_r: in std_logic_vector(9 downto 0);
		bullet_y_t, bullet_y_b: in std_logic_vector(9 downto 0);
		bullet_x_l, bullet_x_r: in std_logic_vector(9 downto 0);
		ship_enemy_on: out std_logic;
		enemy_hit_on: out std_logic;
		level_up: in std_logic;
		led: out std_logic;
		enemy_rgb: out std_logic_vector(7 downto 0)
	);
end enemy;

architecture arch of enemy is

	-- constants
	constant MAX_X: integer := 640;
	constant MAX_Y: integer := 480;
	constant SHIP_V: integer := 1;
	constant SHIP_SIZE: integer := 22;
	constant ROM_ADDR_SIZE: integer := 12;	--	size of rom_addr (bits)
	constant ROM_COL_SIZE: integer := 5;	-- size of rom_col signal used to access every column
	constant ROM_MULTI: integer := 484;
	
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
	
	-- Enemy ship orientation
	signal ship_enemy_orient_reg, ship_enemy_orient_next: unsigned(2 downto 0);
	
	--Enemy ship rom address
	signal rom_addr: std_logic_vector(ROM_ADDR_SIZE-1 downto 0);	
	signal rom_addr_num: unsigned(ROM_ADDR_SIZE-1 downto 0);
	-- signal rom_col: unsigned(ROM_COL_SIZE-1 downto 0);
	signal rom_data: std_logic_vector(7 downto 0);
	signal pixel_byte: std_logic;
	
	-- FSMD states, registers and signals for use in the tracking algorithm
	type state_type is (idle, move_right, move_45_degree, move_up, move_135_degree,
							  move_left, move_225_degree, move_down, move_315_degree,
							  load1, load1_comp1, load1_comp2, 
							  load2, load2_comp1, load2_comp2,
							  load3, load3_comp1, load3_comp2,
							  load4, load4_comp1, load4_comp2);
	signal state_reg, state_next: state_type;
	signal min_dist_reg, min_dist_next: unsigned(9 downto 0); -- register to store the minimum distance
	signal dist_reg, dist_next: unsigned(9 downto 0); -- register to store distance for comparison
	signal ready, start: std_logic;
	signal pix_x_main, pix_y_main: unsigned(9 downto 0);
	signal pix_x_enemy, pix_y_enemy: unsigned(9 downto 0);
	signal region_x, region_y: std_logic;
	signal ship_main_region: std_logic_vector(1 downto 0);
	signal ship_main_hit: std_logic; 
	signal enemy_hit_reg, enemy_hit_next: std_logic;

begin

	pix_x <= unsigned(pixel_x);
	pix_y <= unsigned(pixel_y);
	
	process(clk, reset)
	begin
		if (reset='1') then
			ship_enemy_y_reg <= unsigned(Y);
			ship_enemy_x_reg <= unsigned(X);
			ship_enemy_orient_reg <= ("100");
			min_dist_reg <= (others=>'0');
			dist_reg <= (others=>'0');
			enemy_hit_reg <= '0';
			state_reg <= idle;
		elsif (clk'event and clk='1') then
			ship_enemy_y_reg <= ship_enemy_y_next;
			ship_enemy_x_reg <= ship_enemy_x_next;
			ship_enemy_orient_reg <= ship_enemy_orient_next;
			min_dist_reg <= min_dist_next;
			dist_reg <= dist_next;
			enemy_hit_reg <= enemy_hit_next;
			state_reg <= state_next;
		end if;
	end process;

	-- current position of the enemy and main ship box
	ship_enemy_y_t <= ship_enemy_y_reg;
	ship_enemy_y_b <= ship_enemy_y_t + SHIP_SIZE-1;
	ship_enemy_x_l <= ship_enemy_x_reg;
	ship_enemy_x_r <= ship_enemy_x_l + SHIP_SIZE-1;
			
	-- Determine whether current pixel is within enemy ship box
	sq_ship_enemy_on <= '1' when (ship_enemy_x_l <= pix_x) and	(pix_x <= ship_enemy_x_r) and
											(ship_enemy_y_t <= pix_y) and	(pix_y <= ship_enemy_y_b) 
									else '0';

	-- map scan coord to ROM addr/col
	ship_enemy_rom : entity work.enemy_rom
		port map (
			clka => clk,
			addra => rom_addr,
			douta => rom_data);
			
	-- select row from Enemy ROM
	process (ship_enemy_orient_reg, sq_ship_enemy_on, pix_y, pix_x, ship_enemy_y_t, ship_enemy_x_l)
	begin
		rom_addr_num <= (others=>'0');
		if sq_ship_enemy_on = '1' then
			case ship_enemy_orient_reg is
				when "000" =>
					rom_addr_num <= resize(SHIP_SIZE*(pix_y - ship_enemy_y_t) + pix_x - ship_enemy_x_l, ROM_ADDR_SIZE);
				
				when "001" =>
					rom_addr_num <= resize(ROM_MULTI + SHIP_SIZE*(pix_y - ship_enemy_y_t) + pix_x - ship_enemy_x_l, ROM_ADDR_SIZE);
					
				when "010" =>
					rom_addr_num <= resize(2*ROM_MULTI + SHIP_SIZE*(pix_y - ship_enemy_y_t) + pix_x - ship_enemy_x_l, ROM_ADDR_SIZE);
					
				when "011" =>
					rom_addr_num <= resize(3*ROM_MULTI + SHIP_SIZE*(pix_y - ship_enemy_y_t) + pix_x - ship_enemy_x_l, ROM_ADDR_SIZE);
					
				when "100" =>
					rom_addr_num <= resize(4*ROM_MULTI + SHIP_SIZE*(pix_y - ship_enemy_y_t) + pix_x - ship_enemy_x_l, ROM_ADDR_SIZE);
				
				when "101" =>
					rom_addr_num <= resize(5*ROM_MULTI + SHIP_SIZE*(pix_y - ship_enemy_y_t) + pix_x - ship_enemy_x_l, ROM_ADDR_SIZE);
				
				when "110" =>
					rom_addr_num <= resize(6*ROM_MULTI + SHIP_SIZE*(pix_y - ship_enemy_y_t) + pix_x - ship_enemy_x_l, ROM_ADDR_SIZE);
				
				when others =>
					rom_addr_num <= resize(7*ROM_MULTI + SHIP_SIZE*(pix_y - ship_enemy_y_t) + pix_x - ship_enemy_x_l, ROM_ADDR_SIZE);
			end case;
		end if;
	end process;

	-- enemy ship access bit 
	rom_addr <= std_logic_vector(rom_addr_num);
	-- rom_col <= resize(pix_x-ship_enemy_x_l, ROM_COL_SIZE) when sq_ship_enemy_on = '1' else (others=>'0');
	pixel_byte <= '1' when (rom_data /= x"00") else '0';
	
	
	-- signals to use in the tracking algorithm
	pix_x_main <= unsigned(ship_main_x_l) + 26; 	-- center x pixel of main ship
	pix_y_main <= unsigned(ship_main_y_t) + 26; 	-- center y pixel of main ship
	pix_x_enemy <= ship_enemy_x_reg + (SHIP_SIZE/2)-1; 		-- center x pixel of enemy ship
	pix_y_enemy <= ship_enemy_y_reg + (SHIP_SIZE/2)-1;			-- center y pixel of enemy ship
	
	region_x <= '1' when (pix_x_main < pix_x_enemy) else '0';
	region_y <= '1' when (pix_y_main > pix_y_enemy) else '0';
	ship_main_region <= region_y & region_x;
	start <= '1' when (refr_tick='1' and ready='1') else '0';
	
	-- signals ship_main hit
	process(ship_enemy_y_b, ship_enemy_y_t, ship_enemy_x_l, ship_enemy_x_r,
			  ship_main_y_b, ship_main_y_t, ship_main_x_l, ship_main_x_r)
	begin
		ship_main_hit <= '0';
		if (ship_enemy_y_b >= unsigned(ship_main_y_t)) and (ship_enemy_y_t <= unsigned(ship_main_y_b)) then
			if (ship_enemy_x_l <= unsigned(ship_main_x_r)) and (ship_enemy_x_r >= unsigned(ship_main_x_l)) then
				ship_main_hit <= '1';
			end if;
		end if;
	end process;
	
	-- signals enemy hit
	process(ship_enemy_y_b, ship_enemy_y_t, ship_enemy_x_l, ship_enemy_x_r,
			  bullet_y_b, bullet_y_t, bullet_x_l, bullet_x_r, enemy_hit_reg, reset_all)
	begin
		enemy_hit_next <= '0';
		if (reset_all='1') then
			enemy_hit_next <= '1';
		else
			if (ship_enemy_y_b >= unsigned(bullet_y_t)) and (ship_enemy_y_t <= unsigned(bullet_y_b)) then
				if (ship_enemy_x_l <= unsigned(bullet_x_r)) and (ship_enemy_x_r >= unsigned(bullet_x_l)) then
					enemy_hit_next <= '1';
				end if;
			end if;
		end if;
	end process;
	
	
	-- Process the tracking algorithm using FSMD
	process(state_reg, start, reset_all, ship_main_region, ship_enemy_x_reg, ship_enemy_y_reg,
			  ship_enemy_orient_reg, min_dist_reg, dist_reg, min_dist_next, dist_next, 
			  pix_x_main, pix_x_enemy,	pix_y_main, pix_y_enemy, ship_main_hit, enemy_hit_reg,level_up)
			  
	begin
	
		-- default values
		ship_enemy_x_next <= ship_enemy_x_reg;
		ship_enemy_y_next <= ship_enemy_y_reg;
		ship_enemy_orient_next <= ship_enemy_orient_reg;
		min_dist_next <= min_dist_reg;
		dist_next <= dist_reg;
		ready <= '0';
		
		case state_reg is
			when idle =>
				ready <= '1';
				if (reset_all='1') then
					ship_enemy_x_next <= unsigned(X);
					ship_enemy_y_next <= unsigned(Y);
					ship_enemy_orient_next <= (others=>'0');
					min_dist_next <= (others=>'0');
					dist_next <= (others=>'0');
					state_next <= idle;
				elsif (start='1') then
					if (ship_main_hit='1') then
						state_next <= idle;
					elsif (enemy_hit_reg='1') then
						state_next <= idle;
						if(level_up='1') then
							ship_enemy_x_next <= unsigned(X);
							ship_enemy_y_next <= unsigned(Y);
						end if;
					else
					
						case ship_main_region is	
							when "00" => -- first quadrant
								if (pix_y_main=pix_y_enemy) then
									state_next <= move_right;
								elsif (pix_x_main=pix_x_enemy) then
									state_next <= move_up;
								else
									state_next <= load1;
								end if;
								
							when "01" => -- second quadrant
								if (pix_y_main=pix_y_enemy) then
									state_next <= move_left;
								else
									state_next <= load2;
								end if;
									
							when "11" => -- third quadrant
								state_next <= load3;
								
							when others => -- fourth quadrant
								if (pix_x_main=pix_x_enemy) then
									state_next <= move_down;
								else
									state_next <= load4;
								end if;
						end case;
					end if;
				else
					state_next <= idle;
				end if;
				
			when move_right =>
				if (ship_enemy_orient_reg=2) then
					if(level_up='1') then
						ship_enemy_x_next <= ship_enemy_x_reg + SHIP_V;
					end if;
				else
					ship_enemy_orient_next <= "010";
				end if;
				state_next <= idle;
				
			when move_45_degree =>
				if (ship_enemy_orient_reg=1) then
					if(level_up='1') then
						ship_enemy_x_next <= ship_enemy_x_reg + SHIP_V;
						ship_enemy_y_next <= ship_enemy_y_reg - SHIP_V;
					end if;
				else
					ship_enemy_orient_next <= "001";
				end if;
				state_next <= idle;
				
			when move_up =>
				if (ship_enemy_orient_reg=0) then
					if(level_up='1') then
						ship_enemy_y_next <= ship_enemy_y_reg - SHIP_V;
					end if;
				else
					ship_enemy_orient_next <= "000";
				end if;
				state_next <= idle;
				
			when move_135_degree =>
				if (ship_enemy_orient_reg=7) then
					if(level_up='1') then
						ship_enemy_x_next <= ship_enemy_x_reg - SHIP_V;
						ship_enemy_y_next <= ship_enemy_y_reg - SHIP_V;
					end if;
				else
					ship_enemy_orient_next <= "111";
				end if;
				state_next <= idle;
				
			when move_left =>
				if (ship_enemy_orient_reg=6) then
					if(level_up='1') then
					ship_enemy_x_next <= ship_enemy_x_reg - SHIP_V;
					end if;
				else
					ship_enemy_orient_next <= "110";
				end if;
				state_next <= idle;
				
			when move_225_degree =>
				if (ship_enemy_orient_reg=5) then
					if(level_up='1') then
						ship_enemy_x_next <= ship_enemy_x_reg - SHIP_V;
						ship_enemy_y_next <= ship_enemy_y_reg + SHIP_V;
					end if;
				else 
					ship_enemy_orient_next <= "101";
				end if;
				state_next <= idle;
				
			when move_down =>
				if (ship_enemy_orient_reg=4) then
					if(level_up='1') then
						ship_enemy_y_next <= ship_enemy_y_reg + SHIP_V;
					end if;
				else
					ship_enemy_orient_next <= "100";
				end if;
				state_next <= idle;
				
			when move_315_degree =>
				if (ship_enemy_orient_reg=3) then
					if(level_up='1') then
						ship_enemy_x_next <= ship_enemy_x_reg + SHIP_V;
						ship_enemy_y_next <= ship_enemy_y_reg + SHIP_V;
					end if;
				else
					ship_enemy_orient_next <= "011";
				end if;
				state_next <= idle;
				
			when load1 =>
				min_dist_next <= ((pix_y_enemy-SHIP_V) - pix_y_main) +
									  (pix_x_main - pix_x_enemy);
				dist_next <= ((pix_y_enemy-SHIP_V) - pix_y_main) +
								 (pix_x_main - (pix_x_enemy+SHIP_V));
								 
				if (min_dist_next < dist_next) then
					state_next <= load1_comp1;
				else
					state_next <= load1_comp2;
				end if;
				
			when load1_comp1 => -- likely to move up
				dist_next <= (pix_y_enemy - pix_y_main) +
								 (pix_x_main - (pix_x_enemy+SHIP_V));
				if (min_dist_reg < dist_next) then
					state_next <= move_up;
				else
					state_next <= move_right;
				end if;
				
			when load1_comp2 => -- likely to move at 45 degree direction
				min_dist_next <= dist_reg;
				dist_next <= (pix_y_enemy - pix_y_main) +
								 (pix_x_main - (pix_x_enemy+SHIP_V));
				if (min_dist_next < dist_next) then
					state_next <= move_45_degree;
				else
					state_next <= move_right;
				end if;
				
			when load2 =>
				min_dist_next <= ((pix_y_enemy-SHIP_V) - pix_y_main) +
									  (pix_x_enemy - pix_x_main);
				dist_next <= ((pix_y_enemy-SHIP_V) - pix_y_main) +
								 ((pix_x_enemy-SHIP_V) - pix_x_main);
								 
				if (min_dist_next < dist_next) then
					state_next <= load2_comp1;
				else
					state_next <= load2_comp2;
				end if;
				
			when load2_comp1 => -- likely to move up
				dist_next <= (pix_y_enemy - pix_y_main) +
								 ((pix_x_enemy-SHIP_V) - pix_x_main);
				if (min_dist_reg < dist_next) then
					state_next <= move_up;
				else
					state_next <= move_left;
				end if;
				
			when load2_comp2 => -- likely to move at 135 degree direction
				min_dist_next <= dist_reg;
				dist_next <= (pix_y_enemy - pix_y_main) +
								 ((pix_x_enemy-SHIP_V) - pix_x_main);
				if (min_dist_next < dist_next) then
					state_next <= move_135_degree;
				else
					state_next <= move_left;
				end if;
				
			when load3 =>
				min_dist_next <= (pix_y_main - (pix_y_enemy+SHIP_V)) +
									  (pix_x_enemy - pix_x_main);
				dist_next <= (pix_y_main - (pix_y_enemy+SHIP_V)) +
								 ((pix_x_enemy-SHIP_V) - pix_x_main);
								 
				if (min_dist_next < dist_next) then
					state_next <= load3_comp1;
				else
					state_next <= load3_comp2;
				end if;
				
			when load3_comp1 => -- likely to move down
				dist_next <= (pix_y_main - pix_y_enemy) +
								 ((pix_x_enemy-SHIP_V) - pix_x_main);
				if (min_dist_reg < dist_next) then
					state_next <= move_down;
				else
					state_next <= move_left;
				end if;
				
			when load3_comp2 => -- likely to move at 225 degree direction
				min_dist_next <= dist_reg;
				dist_next <= (pix_y_main - pix_y_enemy) +
								 ((pix_x_enemy-SHIP_V) - pix_x_main);
				if (min_dist_next < dist_next) then
					state_next <= move_225_degree;
				else
					state_next <= move_left;
				end if;
				
			when load4 =>
				min_dist_next <= (pix_y_main - (pix_y_enemy+SHIP_V)) +
									  (pix_x_main - pix_x_enemy);
				dist_next <= (pix_y_main - (pix_y_enemy+SHIP_V)) +
								 (pix_x_main - (pix_x_enemy+SHIP_V));
								 
				if (min_dist_next < dist_next) then
					state_next <= load4_comp1;
				else
					state_next <= load4_comp2;
				end if;
				
			when load4_comp1 => -- likely to move down
				dist_next <= (pix_y_main - pix_y_enemy) +
								 (pix_x_main - (pix_x_enemy+SHIP_V));
				if (min_dist_reg < dist_next) then
					state_next <= move_down;
				else
					state_next <= move_right;
				end if;
				
			when load4_comp2 => -- likely to move at 315 degree direction
				min_dist_next <= dist_reg;
				dist_next <= (pix_y_main - pix_y_enemy) +
								 (pix_x_main - (pix_x_enemy+SHIP_V));
				if (min_dist_next < dist_next) then
					state_next <= move_315_degree;
				else
					state_next <= move_right;
				end if;
					
		end case;
	end process;
	
	-- Outputs
	ship_enemy_on <= '1' when (sq_ship_enemy_on='1') and (pixel_byte='1') and (level_up ='1') else '0';
	enemy_rgb <= rom_data;
	led <= '1' when (ship_main_hit='1') else '0';
	enemy_hit_on <= enemy_hit_reg;
	
	
end arch;

