library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity m100_counter is
   port(
      clk, reset: in std_logic;
		refr_tick: in std_logic;
		enemy_hit: in std_logic_vector(3 downto 0);
      d_clr: in std_logic;
      dig0,dig1: out std_logic_vector (3 downto 0)
   );
end m100_counter;

architecture arch of m100_counter is

   signal dig0_reg, dig1_reg: unsigned(3 downto 0);
   signal dig0_next, dig1_next: unsigned(3 downto 0);
	signal inc: std_logic_vector(3 downto 0);
	signal mod3_reg, mod3_next: unsigned(2 downto 0);
	
	type state_type is (idle, count);
	signal mod3_state_reg, mod3_state_next: state_type;
	
begin

   -- registers
   process (clk,reset)
   begin
      if reset='1' then
         dig1_reg <= (others=>'0');
         dig0_reg <= (others=>'0');
			mod3_reg <= (others=>'0');
			mod3_state_reg <= idle;
      elsif (clk'event and clk='1') then
         dig1_reg <= dig1_next;
         dig0_reg <= dig0_next;
			mod3_reg <= mod3_next;
			mod3_state_reg <= mod3_state_next;
      end if;
   end process;
	
	-- start counting when refr_tick is received
	process(mod3_state_reg, refr_tick, mod3_reg)
	begin
	
		mod3_state_next <= mod3_state_reg;
		mod3_next <= mod3_reg;
	
		case mod3_state_reg is
			when idle =>
				if refr_tick='1' then
					mod3_state_next <= count;
					mod3_next <= (others=>'0');
				end if;
				
			when count =>
				if mod3_reg<7 then
					mod3_next <= mod3_reg + 1;
				else
					mod3_state_next <= idle;
				end if;
		end case;
	end process;
				
				
	-- calculate the number of enemy hit
	inc(0) <= '1' when (enemy_hit = "0001") or
							 (enemy_hit = "0010") or
							 (enemy_hit = "0100") or
							 (enemy_hit = "1000") else '0';
	inc(1) <= '1' when (enemy_hit = "0011") or
							 (enemy_hit = "0101") or
							 (enemy_hit = "0110") or
							 (enemy_hit = "1001") or
							 (enemy_hit = "1010") or
							 (enemy_hit = "1100") else '0';
	inc(2) <= '1' when (enemy_hit = "0111") or
							 (enemy_hit = "1011") or
							 (enemy_hit = "1101") or
							 (enemy_hit = "1110") else '0';
	inc(3) <= '1' when enemy_hit = "1111" else '0';
	
   -- next-state logic for the decimal counter
   process(d_clr,dig1_reg,dig0_reg, inc, refr_tick, mod3_reg)
   begin
      dig0_next <= dig0_reg;
      dig1_next <= dig1_reg;
		
      if (d_clr='1') then
         dig0_next <= (others=>'0');
         dig1_next <= (others=>'0');
      elsif (refr_tick = '1' and mod3_reg=7) then
			case dig0_reg is
				when "1001" => -- 9
					case inc is
						when "0001" =>
							dig0_next <= (others=>'0');
							if dig1_reg >= 9 then
								dig1_next <= "0000";
							else
								dig1_next <= dig1_reg + 1;
							end if;
							
						when "0010" =>
							dig0_next <= "0001";
							if dig1_reg >= 9 then
								dig1_next <= "0000";
							else
								dig1_next <= dig1_reg + 1;
							end if;
							
						when "0100" =>
							dig0_next <= "0010";
							if dig1_reg >= 9 then
								dig1_next <= "0000";
							else
								dig1_next <= dig1_reg + 1;
							end if;
							
						when "1000" =>
							dig0_next <= "0011";
							if dig1_reg >= 9 then
								dig1_next <= "0000";
							else
								dig1_next <= dig1_reg + 1;
							end if;
							
						when others =>
						
					end case;
			
				when "1000" =>	-- 8
					case inc is
						when "0001" =>
							dig0_next <= dig0_reg + 1;
							
						when "0010" =>
							dig0_next <= (others=>'0');
							if dig1_reg >= 9 then
								dig1_next <= "0000";
							else
								dig1_next <= dig1_reg + 1;
							end if;
							
						when "0100" =>
							dig0_next <= "0001";
							if dig1_reg >= 9 then
								dig1_next <= "0000";
							else
								dig1_next <= dig1_reg + 1;
							end if;
							
						when "1000" =>
							dig0_next <= "0010";
							if dig1_reg >= 9 then
								dig1_next <= "0000";
							else
								dig1_next <= dig1_reg + 1;
							end if;
							
						when others =>
							
					end case;
				
				when "0111" =>	-- 7
					case inc is
						when "0001" =>
							dig0_next <= dig0_reg + 1;
							
						when "0010" =>
							dig0_next <= dig0_reg + 2;
							
						when "0100" =>
							dig0_next <= (others=>'0');
							if dig1_reg >= 9 then
								dig1_next <= "0000";
							else
								dig1_next <= dig1_reg + 1;
							end if;
							
						when "1000" =>
							dig0_next <= "0001";
							if dig1_reg >= 9 then
								dig1_next <= "0000";
							else
								dig1_next <= dig1_reg + 1;
							end if;
							
						when others =>
							
					end case;
			
				when "0110" =>	-- 6 
					case inc is
						when "0001" =>
							dig0_next <= dig0_reg + 1;
							
						when "0010" =>
							dig0_next <= dig0_reg + 2;
							
						when "0100" =>
							dig0_next <= dig0_reg + 3;
							
						when "1000" =>
							dig0_next <= (others=>'0');
							if dig1_reg >= 9 then
								dig1_next <= "0000";
							else
								dig1_next <= dig1_reg + 1;
							end if;
							
						when others =>
							
					end case;
							
				when "0000"|"0001"|"0010"|"0011"|"0100"|"0101" => 
					case inc is
						when "0001" =>
							dig0_next <= dig0_reg + 1;
							
						when "0010" =>
							dig0_next <= dig0_reg + 2;
							
						when "0100" =>
							dig0_next <= dig0_reg + 3;
							
						when "1000" =>
							dig0_next <= dig0_reg + 4;
							
						when others =>
							
					end case;
					
				when others =>
					dig0_next <= (others=>'0');
					if dig1_reg >= 9 then
						dig1_next <= "0000";
					else
						dig1_next <= dig1_reg + 1;
					end if;
					
				end case;
			end if;
   end process;
	
	-- outputs
   dig0 <= std_logic_vector(dig0_reg);
   dig1 <= std_logic_vector(dig1_reg);
	
end arch;
