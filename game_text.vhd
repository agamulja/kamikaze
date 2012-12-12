-- Listing 13.6
library ieee;
use ieee.std_logic_1164.ALL;
use ieee.numeric_std.ALL;
entity game_text is
   port(
      clk, reset: in std_logic;
      pixel_x, pixel_y: in std_logic_vector(9 downto 0);
		dig0, dig1: in std_logic_vector(3 downto 0);
      text_on: out std_logic_vector(3 downto 0);
      text_rgb: out std_logic_vector(2 downto 0)
   );
end game_text;

architecture arch of game_text is
   signal pix_x, pix_y: unsigned(9 downto 0);
   signal rom_addr: std_logic_vector(10 downto 0);
   signal char_addr, char_addr_s,char_addr_l,char_addr_r,char_addr_o: std_logic_vector(6 downto 0);
   signal row_addr, row_addr_s,row_addr_l,row_addr_r,row_addr_o: std_logic_vector(3 downto 0);
   signal bit_addr, bit_addr_s, bit_addr_l,bit_addr_r,bit_addr_o : std_logic_vector(2 downto 0);
   signal font_word: std_logic_vector(7 downto 0);
   signal font_bit: std_logic;
   signal score_on,score_bit_on,logo_on,logo_bit_on,rule_on,rule_bit_on,over_on,over_bit_on: std_logic;
	signal rule_rom_addr: unsigned(5 downto 0);

   type rule_rom_type is array (0 to 63) of
       std_logic_vector (6 downto 0);
   -- rull text ROM definition
   constant RULE_ROM: rule_rom_type :=
   (
		-- row 1
		"0000000", --
      "0000000", --
      "0000000", --
      "0000000", --
      "0000000", --
      "0000000", --
      "0000000", --
      "0000000", --
      "0000000", --
      "0000000", --
      "0000000", --
      "0000000", --
      "0000000", --
      "0000000", --
      "0000000", --
      "0000000", --

      -- row 2
      "1010101", -- U
      "1110011", -- s
      "1100101", -- e
      "0000000", --
      "1100001", -- a
      "1101110", -- n
      "1111001", -- y
      "0000000", --
      "1100010", -- b
      "1110101", -- u
      "1110100", -- t
      "1110100", -- t
      "1101111", -- o
      "1101110", -- n
      "0000000", --
      "0000000", --
      -- row 3
      "1110100", -- t
      "1101111", -- o
      "0000000", --
      "1100011", -- c
      "1101111", -- o
      "1101110", -- n
      "1110100", -- t
      "1101001", -- i
      "1101110", -- n
      "1110101", -- u
      "1100101", -- e
      "0101110", -- .
      "0101110", -- .
      "0101110", -- .
      "0000000", --
      "0000000", --
      -- row 4
		"0000000", --
      "0000000", --
      "0000000", --
      "0000000",  --
      "0000000", --
      "0000000", --
      "0000000", --
      "0000000",  --
      "0000000", --
      "0000000", --
      "0000000", --
      "0000000",  --
      "0000000", --
      "0000000", --
      "0000000", --
      "0000000"  --
   );   
   
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
	
   ---------------------------------------------
   -- logo region:
   --   - display logo "PONG" on top center
   --   - used as background
   --   - scale to 64-by-128 font
   ---------------------------------------------
   logo_on <=
      '1' when pix_y(9 downto 7)=2 and
         (pix_x > 10 and pix_x< 500) else
      '0';
   row_addr_l <= std_logic_vector(pix_y(6 downto 3));
   bit_addr_l <= std_logic_vector(pix_x(5 downto 3));
   with pix_x(8 downto 6) select
     char_addr_l <=
        "1001011" when "000", -- K x4b
        "1000001" when "001", -- A x41
        "1001101" when "010", -- M x4d
        "1001001" when "011", --	I x49
		  "1001011" when "100", --	K x4b
		  "1000001" when "101", -- A x41
		  "1011010" when "110", --	Z x5a
		  "1000101" when others; -- E x45
	logo_bit_on <= '1' when (logo_on='1' and font_bit='1') else '0';
	
	   ---------------------------------------------
   -- rule region
   --   - display rule (4-by-16 tiles)on center
   --   - rule text:
   --  
   --        Use any button
   --        to continue...
   --  
   ---------------------------------------------
   rule_on <= '1' when pix_x(9 downto 7) = "010" and
                       pix_y(9 downto 6)=  "0110"  else
              '0';
   row_addr_r <= std_logic_vector(pix_y(3 downto 0));
   bit_addr_r <= std_logic_vector(pix_x(2 downto 0));
   rule_rom_addr <= pix_y(5 downto 4) & pix_x(6 downto 3);
   char_addr_r <= RULE_ROM(to_integer(rule_rom_addr));

	rule_bit_on <= '1' when (rule_on='1' and font_bit='1') else '0';

   ---------------------------------------------
   -- game over region
   --  - display }Game Over" on center
   --  - scale to 32-by-64 fonts
   ---------------------------------------------
   over_on <=
      '1' when pix_y(9 downto 6)=3 and
         5<= pix_x(9 downto 5) and pix_x(9 downto 5)<=13 else
      '0';
   row_addr_o <= std_logic_vector(pix_y(5 downto 2));
   bit_addr_o <= std_logic_vector(pix_x(4 downto 2));
   with pix_x(8 downto 5) select
     char_addr_o <=
        "1000111" when "0101", -- G x47
        "1100001" when "0110", -- a x61
        "1101101" when "0111", -- m x6d
        "1100101" when "1000", -- e x65
        "0000000" when "1001", --
        "1001111" when "1010", -- O x4f
        "1110110" when "1011", -- v x76
        "1100101" when "1100", -- e x65
        "1110010" when others; -- r x72

	over_bit_on <= '1' when (over_on='1' and font_bit='1') else '0';


	process(score_on,logo_on,rule_on,over_on,pix_x,pix_y,font_bit,char_addr_s,char_addr_l,
				char_addr_r,char_addr_o,row_addr_s,row_addr_l,row_addr_r,row_addr_o,bit_addr_s,
				bit_addr_l,bit_addr_r,bit_addr_o)
   begin
      if score_on='1' then
         char_addr <= char_addr_s;
         row_addr <= row_addr_s;
         bit_addr <= bit_addr_s;
         --if font_bit='1' then
         text_rgb <= "001";
         --end if;
		elsif rule_on='1' then
         char_addr <= char_addr_r;
         row_addr <= row_addr_r;
         bit_addr <= bit_addr_r;
         --if font_bit='1' then
            text_rgb <= "001";
         --end if;
		elsif logo_on='1' then
		  char_addr <= char_addr_l;
        row_addr <= row_addr_l;
        bit_addr <= bit_addr_l;
        --if font_bit='1' then
           text_rgb <= "011";
        --end if;
      else -- game over
         char_addr <= char_addr_o;
         row_addr <= row_addr_o;
         bit_addr <= bit_addr_o;
         -- if font_bit='1' then
            text_rgb <= "001";
         -- end if;
      end if;
	end process;
   text_on <= score_bit_on & logo_bit_on & rule_bit_on & over_bit_on;
--  text_on <= score_bit_on;
   ---------------------------------------------
   -- font rom interface
   ---------------------------------------------
   rom_addr <= char_addr & row_addr;
   font_bit <= font_word(to_integer(unsigned(not bit_addr)));
end arch;