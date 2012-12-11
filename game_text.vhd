-- Listing 13.6
library ieee;
use ieee.std_logic_1164.ALL;
use ieee.numeric_std.ALL;
entity game_text is
   port(
      clk: in std_logic;
      pixel_x, pixel_y: in std_logic_vector(9 downto 0);
		dig0, dig1: in std_logic_vector(3 downto 0);
      text_on: out std_logic;
      text_rgb: out std_logic_vector(2 downto 0)
   );
end game_text;

architecture arch of game_text is
   signal pix_x, pix_y: unsigned(9 downto 0);
   signal rom_addr: std_logic_vector(10 downto 0);
   signal char_addr, char_addr_s: std_logic_vector(6 downto 0);
   signal row_addr, row_addr_s: std_logic_vector(3 downto 0);
   signal bit_addr, bit_addr_s: std_logic_vector(2 downto 0);
   signal font_word: std_logic_vector(7 downto 0);
   signal font_bit: std_logic;
   signal score_on,score_bit_on: std_logic;
   
   
begin
   pix_x <= unsigned(pixel_x);
   pix_y <= unsigned(pixel_y);
   
	-- instantiate font rom
   font_unit: entity work.font_rom
      port map(clk=>clk, addr=>rom_addr, data=>font_word);

   ---------------------------------------------
   -- score region
   --  - display two-digit score, ball on top left
   --  - scale to 16-by-32 font
   --  - line 1, 16 chars: "Score:DD Ball:D"
   ---------------------------------------------
   score_on <=
      '1' when 
				pix_x > 0 and pix_x < 128 and 
				pix_y >  465 and pix_y < 480  else
		--pix_y(9 downto 5)=0 and
      --pix_x(9 downto 4)<6 else
      '0';
   row_addr_s <= std_logic_vector(pix_y(3 downto 0));
   bit_addr_s <= std_logic_vector(pix_x(3 downto 1));
   with pix_x(7 downto 4) select
     char_addr_s <=
        "1010011" when "0000", -- S x53
        "1100011" when "0001", -- c x63
        "1101111" when "0010", -- o x6f
        "1110010" when "0011", -- r x72
        "1100101" when "0100", -- e x65
        "0111010" when "0101", -- : x3a
		  "011" & dig1 when "0110", -- digit 10
        "011" & dig0 when "0111", -- digit 1
        "0000000" when others;

   
	score_bit_on <= '1' when (score_on='1' and font_bit='1') else '0';
	
	--process(score_on,pix_x,pix_y,font_bit,char_addr_s,row_addr_s,bit_addr_s)
   --begin
      --text_rgb <= "110";  -- background, yellow
      --if score_on='1' then
         char_addr <= char_addr_s;
         row_addr <= row_addr_s;
         bit_addr <= bit_addr_s;
         --if font_bit='1' then
         text_rgb <= "001";
         --end if;
--      else -- game over
--         char_addr <= char_addr_o;
--         row_addr <= row_addr_o;
--         bit_addr <= bit_addr_o;
--         if font_bit='1' then
--            text_rgb <= "001";
--         end if;
--      end if;
--   end process;
   text_on <= score_bit_on;
   ---------------------------------------------
   -- font rom interface
   ---------------------------------------------
   rom_addr <= char_addr & row_addr;
   font_bit <= font_word(to_integer(unsigned(not bit_addr)));
end arch;