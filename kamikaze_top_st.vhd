library IEEE;
use IEEE.std_logic_1164.all;

entity kamikaze_top_st is
	port(
		clk, reset: in std_logic;
		btn: in std_logic_vector(3 downto 0);
		hsync, vsync: out std_logic;
		rgb: out std_logic_vector(7 downto 0);
		led: out std_logic
	);
end kamikaze_top_st;

architecture arch of kamikaze_top_st is
	
	signal pixel_x, pixel_y: std_logic_vector(9 downto 0);
	signal video_on, pixel_tick: std_logic;
	signal rgb_reg, rgb_next: std_logic_vector(7 downto 0);
	
begin
-- instantiate VGA sync
	vga_sync_unit: entity work.vga_sync
		port map(clk=>clk, reset=>reset,
			video_on=>video_on, p_tick=>pixel_tick,
			hsync=>hsync, vsync=>vsync,
			pixel_x=>pixel_x, pixel_y=>pixel_y);

-- instantiate pixel generation circuit
	kamikaze_grf_st_unit: entity work.kamikaze_graph_st(arch)
		port map(clk=>clk, reset=>reset, btn=>btn, video_on=>video_on, pixel_x=>pixel_x,
			pixel_y=>pixel_y, graph_rgb=>rgb_next, led=>led);
	
	
	-- rgb buffer, graph_rgb is routed to the ouput through
	-- an output buffer -- loaded when pixel_tick = '1'.
	-- This syncs. rgb output with buffered hsync/vsync sig.
	process (clk)
	begin
		if (clk'event and clk = '1') then
--			if (pixel_tick = '1') then
				rgb_reg <= rgb_next;
--			end if;
		end if;
	end process;
	
	rgb <= rgb_reg;
end arch;