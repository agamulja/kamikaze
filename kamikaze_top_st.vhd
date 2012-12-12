library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity kamikaze_top_st is
	port(
		clk, reset: in std_logic;
		btn: in std_logic_vector(3 downto 0);
		hsync, vsync: out std_logic;
		rgb: out std_logic_vector(7 downto 0);
		led, led2: out std_logic
	);
end kamikaze_top_st;

architecture arch of kamikaze_top_st is
	
	type state_type is (welcome, get_ready, play, game_over);
	signal state_reg, state_next: state_type;
	
	signal pixel_x, pixel_y: std_logic_vector(9 downto 0);
	signal video_on, pixel_tick: std_logic;
	signal rgb_reg, rgb_next: std_logic_vector(7 downto 0);
	--signal enemy_reg, enemy_next: unsigned(1 downto 0);
	signal reset_all: std_logic;
	signal timer_tick, timer_start, timer_up: std_logic;
	signal ship_main_hit: std_logic;
	signal welcome_on,gameover_on: std_logic;
begin

-- registers
	process(clk, reset)
	begin
		if(reset='1') then
			state_reg <= welcome;
			--enemy_reg <= (others=>'0');
		elsif (clk'event and clk='1') then
			state_reg <= state_next;
			--enemy_reg <= enemy_next;
		end if;
	end process;

-- instantiate 2 seconds timer
	timer_tick <=  -- 60 Hz tick
      '1' when pixel_x="0000000000" and
               pixel_y="0000000000" else
      '0';

	timer_unit: entity work.timer
      port map(clk=>clk, reset=>reset,
               timer_tick=>timer_tick,
               timer_start=>timer_start,
               timer_up=>timer_up);

-- instantiate VGA sync
	vga_sync_unit: entity work.vga_sync
		port map(clk=>clk, reset=>reset,
			video_on=>video_on, p_tick=>pixel_tick,
			hsync=>hsync, vsync=>vsync,
			pixel_x=>pixel_x, pixel_y=>pixel_y);

-- instantiate pixel generation circuit
	kamikaze_grf_st_unit: entity work.kamikaze_graph_st(arch)
		port map(clk=>clk, reset=>reset, reset_all=>reset_all, btn=>btn, 
			video_on=>video_on, pixel_x=>pixel_x, pixel_y=>pixel_y, 
			graph_rgb=>rgb_next, led=>ship_main_hit, led2=>led2, welcome_on=>welcome_on,
			gameover_on=> gameover_on);
	
	
-- fsmd next-state logic
   process(btn,state_reg,ship_main_hit,timer_up)
   begin
      
		timer_start <= '0';
      state_next <= state_reg;
      -- enemy_next <= enemy_reg;
		reset_all <= '0';
		welcome_on <= '0';
		gameover_on <= '0';
      case state_reg is
         when welcome =>
            welcome_on <= '1';
				if (btn /= "0000") then -- button pressed
               -- enemy_next <= enemy_reg + 1;
					state_next <= get_ready;
            end if;
				
			when get_ready =>
				reset_all <= '1';
				state_next <= play;
			
         when play =>
            if ship_main_hit='1' then
               state_next <= game_over;
					timer_start <= '1';
            end if;
         
         when game_over =>
            -- wait for 2 sec to display game over
				gameover_on <= '1';
            if timer_up='1' then
                state_next <= welcome;
            end if;
       end case;
   end process;

	
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
	led <= ship_main_hit;
	
end arch;