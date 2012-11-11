library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity kamikaze_graph_st is
	port(
		clk, reset: in std_logic;
		btn: in std_logic_vector(3 downto 0);
		video_on: in std_logic;
		pixel_x, pixel_y: in std_logic_vector(9 downto 0);
		graph_rgb: out std_logic_vector(7 downto 0)
	);
end kamikaze_graph_st;

architecture arch of kamikaze_graph_st is
-- x, y coordinates (0,0 to (639, 479)
	signal pix_x, pix_y: unsigned(9 downto 0);
	signal refr_tick: std_logic; -- 60-Hz enable tick
	constant MAX_X: integer := 640;
	constant MAX_Y: integer := 480;
		
	-- bar moving velocity
	constant BAR_V: integer := 4;
	
	-- paddle left, right, top, bottom and height
	signal bar_y_t: unsigned(9 downto 0);
	signal bar_y_b: unsigned(9 downto 0);
	signal bar_y_reg, bar_y_next: unsigned(9 downto 0); -- for anchor point in top left
	constant BAR_SIZE: integer := 20;
	signal bar_x_l: unsigned(9 downto 0);
	signal bar_x_r: unsigned(9 downto 0);
	signal bar_x_reg, bar_x_next: unsigned(9 downto 0);
	
	-- object output signals
	signal wall_on, bar_on, sq_ball_on: std_logic;
	signal wall_rgb, bar_rgb, ball_rgb:	std_logic_vector(7 downto 0);

begin
	-- create a reference tick refr_tick: 1-clock tick asserted at start of v_sync
	-- e.g., when the screen is refreshed -- speed is 60 Hz
	refr_tick <= '1' when (pix_y = 481) and (pix_x = 0) else '0';
		
	-- register for the paddle
	process(clk, reset)
	begin
		if (reset='1') then
			bar_y_reg <= (others=>'0');
			bar_x_reg <= (others=>'0');
		elsif (clk'event and clk='1') then
			bar_y_reg <= bar_y_next;
			bar_x_reg <= bar_x_next;
		end if;
	end process;
		
	pix_x <= unsigned(pixel_x);
	pix_y <= unsigned(pixel_y);
	
	-- Pixel within paddle
	bar_y_t <= bar_y_reg;
	bar_y_b <= bar_y_t + BAR_SIZE-1;
	bar_x_l <= bar_x_reg;
	bar_x_r <= bar_x_l + BAR_SIZE-1;
	bar_on <= '1' when (bar_x_l <= pix_x) and	(pix_x <= bar_x_r) and
						    (bar_y_t <= pix_y) and	(pix_y <= bar_y_b) 
					  else '0';
	bar_rgb <= "00011100"; -- green
	
	-- process bar movement request
	process(bar_y_reg, bar_y_t, bar_y_b, refr_tick, btn)
	begin
		-- no move
		bar_y_next <= bar_y_reg;
		bar_x_next <= bar_x_reg;
		if (refr_tick = '1') then
			-- if btn 1 is pressed and paddle not at bottom yet
			if (btn(0) = '1' and bar_y_b < (MAX_Y - 1 - BAR_V)) then
				bar_y_next <= bar_y_reg + BAR_V;
			elsif (btn(1) = '1' and bar_y_t > BAR_V) then
				bar_y_next <= bar_y_reg - BAR_V;
			elsif (btn(2) = '1' and bar_x_r < (MAX_X - 1 - BAR_V)) then
				bar_x_next <= bar_x_reg + BAR_V;
			elsif (btn(3) = '1' and bar_x_l > BAR_V) then
				bar_x_next <= bar_x_reg - BAR_V;
			end if;
		end if;
	end process;
	
	process (video_on, wall_on, bar_on, sq_ball_on, wall_rgb, bar_rgb, ball_rgb)
	begin
		if (video_on = '0') then
			graph_rgb <= (others=>'0'); -- blank
		else -- priority encoding implicit here
			if (bar_on = '1') then
				graph_rgb <= bar_rgb;
			else
				graph_rgb <= "10011001"; -- yellow bkgnd
			end if;
		end if;
	end process;
end arch;