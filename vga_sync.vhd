library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity vga_sync is
	port(
		clk, reset: in std_logic;
		hsync, vsync: out std_logic;
		video_on, p_tick: out std_logic;
		pixel_x, pixel_y: out std_logic_vector(9 downto 0)
);

end vga_sync;

architecture arch of vga_sync is
	constant HD: integer:= 640; -- horizontal display
	constant HF: integer:= 16; -- hsync front porch (right border)
	constant HB: integer:= 48; -- hsync back porch	(left border)
	constant HR: integer:= 96; -- hsync retrace
	constant VD: integer:= 480; -- vertical display
	constant VF: integer:= 11; -- vsync front porch
	constant VB: integer:= 31; -- vsync back porch
	constant VR: integer:= 2; -- vsync retrace
		
	-- clk divider
	signal clk_div_reg, clk_div_next: std_logic;
	
	-- sync counters
	signal v_cnt_reg, v_cnt_next: unsigned(9 downto 0);
	signal h_cnt_reg, h_cnt_next: unsigned(9 downto 0);
	
	-- output buffers
	signal v_sync_reg, h_sync_reg: std_logic;
	signal v_sync_next, h_sync_next: std_logic;
--	signal h_sync_delay1_reg, h_sync_delay2_reg:	std_logic;
--	signal h_sync_delay1_next, h_sync_delay2_next: std_logic;
--	signal v_sync_delay1_reg, v_sync_delay2_reg: std_logic;
--	signal v_sync_delay1_next, v_sync_delay2_next: std_logic;
	
	-- status signal
	signal h_end, v_end, pixel_tick: std_logic;

begin
-- ===============================================
	process (clk, reset)
	begin
		if (reset = '1') then
			clk_div_reg <= '0';
			v_cnt_reg <= (others => '0');
			h_cnt_reg <= (others => '0');
			v_sync_reg <= '0';
			h_sync_reg <= '0';
--			v_sync_delay1_reg <= ’0’;
--			h_sync_delay1_reg <= ’0’;
--			v_sync_delay2_reg <= ’0’;
--			h_sync_delay2_reg <= ’0’;
		elsif ( clk'event and clk = '1' ) then
			clk_div_reg <= clk_div_next;
			v_cnt_reg <= v_cnt_next;
			h_cnt_reg <= h_cnt_next;
			v_sync_reg <= v_sync_next;
			h_sync_reg <= h_sync_next;
		
		-- Add to cycles of delay for DAC pipeline.
--			v_sync_delay1_reg <= v_sync_delay1_next;
--			h_sync_delay1_reg <= h_sync_delay1_next;
--			v_sync_delay2_reg <= v_sync_delay2_next;
--			h_sync_delay2_reg <= h_sync_delay2_next;
		end if;
	end process;
	
	-- Pipeline registers
--	v_sync_delay1_next <= v_sync_reg;
--	h_sync_delay1_next <= h_sync_reg;
--	v_sync_delay2_next <= v_sync_delay1_reg;
--	h_sync_delay2_next <= h_sync_delay1_reg;
	
	-- Generate a 25 MHz enable tick from 50 MHz clock
	clk_div_next <= '0' when clk_div_reg='1' else '1';
	pixel_tick <= clk_div_reg;
	
	-- h_end and v_end depend on constants above
	h_end <= '1' when h_cnt_reg=(HD+HF+HB+HR-1) else '0';
	v_end <= '1' when v_cnt_reg=(VD+VF+VB+VR-1) else '0';
	
	
	-- mod-800 horz sync counter for 640 pixels
-- =======================================
	process (h_cnt_reg, h_end, pixel_tick)
	begin
		if (pixel_tick = '1') then
			if (h_end = '1') then -- mod 800 counter
				h_cnt_next <= (others => '0');
			else
				h_cnt_next <= h_cnt_reg + 1;
			end if;
		else
			h_cnt_next <= h_cnt_reg;
		end if;
	end process;
	
	
	-- mod-525 vertical sync cnter for 480 pixels
	-- ===========================================
	process (v_cnt_reg, h_end, v_end, pixel_tick)
	begin
		if (pixel_tick = '1' and h_end = '1') then
			if (v_end = '1') then
				v_cnt_next <= (others => '0');
			else
				v_cnt_next <= v_cnt_reg + 1;
			end if;
		else
			v_cnt_next <= v_cnt_reg;
		end if;
	end process;
	
	-- horz and vert sync, buffered to avoid glitch
	h_sync_next <= '1' when (h_cnt_reg >= (HD+HF)) and (h_cnt_reg <= (HD+HF+HR-1)) else '0';
	v_sync_next <= '1' when (v_cnt_reg >= (VD+VF)) and	(v_cnt_reg <= (VD+VF+VR-1)) else '0';
	
	-- video on/off (640)
	video_on <= '1' when (h_cnt_reg < HD) and	(v_cnt_reg < VD) else '0';
	
	-- output signals
	hsync <= h_sync_reg;
	vsync <= v_sync_reg;
	pixel_x <= std_logic_vector(h_cnt_reg);
	pixel_y <= std_logic_vector(v_cnt_reg);
	p_tick <= pixel_tick;


end arch;

