library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity twiddle_rom is
   Port (
       clk      : in  STD_LOGIC;
       i_addr   : in  STD_LOGIC_VECTOR(5 downto 0); -- Addresses 0 to 63
       o_w_re   : out STD_LOGIC_VECTOR(15 downto 0);
       o_w_im   : out STD_LOGIC_VECTOR(15 downto 0)
   );
end twiddle_rom;

architecture Behavioral of twiddle_rom is
   type rom_type is array (0 to 63) of signed(15 downto 0);
  
   -- REAL PART (COSINE) - Stays the same as your original
   constant C_ROM_RE : rom_type := (
       to_signed(32767, 16), to_signed(32609, 16), to_signed(32137, 16), to_signed(31356, 16),
       to_signed(30272, 16), to_signed(28897, 16), to_signed(27244, 16), to_signed(25329, 16),
       to_signed(23170, 16), to_signed(20787, 16), to_signed(18204, 16), to_signed(15446, 16),
       to_signed(12539, 16), to_signed(9511, 16),  to_signed(6392, 16),  to_signed(3211, 16),
       to_signed(0, 16),     to_signed(-3211, 16), to_signed(-6392, 16), to_signed(-9511, 16),
       to_signed(-12539, 16),to_signed(-15446, 16),to_signed(-18204, 16),to_signed(-20787, 16),
       to_signed(-23170, 16),to_signed(-25329, 16),to_signed(-27244, 16),to_signed(-28897, 16),
       to_signed(-30272, 16),to_signed(-31356, 16),to_signed(-32137, 16),to_signed(-32609, 16),
       to_signed(-32767, 16),to_signed(-32609, 16),to_signed(-32137, 16),to_signed(-31356, 16),
       to_signed(-30272, 16),to_signed(-28897, 16),to_signed(-27244, 16),to_signed(-25329, 16),
       to_signed(-23170, 16),to_signed(-20787, 16),to_signed(-18204, 16),to_signed(-15446, 16),
       to_signed(-12539, 16),to_signed(-9511, 16), to_signed(-6392, 16), to_signed(-3211, 16),
       to_signed(0, 16),     to_signed(3212, 16),  to_signed(6393, 16),  to_signed(9512, 16),
       to_signed(12540, 16), to_signed(15447, 16), to_signed(18205, 16), to_signed(20788, 16),
       to_signed(23171, 16), to_signed(25330, 16), to_signed(27246, 16), to_signed(28898, 16),
       to_signed(30273, 16), to_signed(31357, 16), to_signed(32138, 16), to_signed(32610, 16)
   );

   -- IMAGINARY PART (SINE) - ALL SIGNS FLIPPED for Forward FFT
   constant C_ROM_IM : rom_type := (
       to_signed(0, 16),      to_signed(-3211, 16),  to_signed(-6392, 16),  to_signed(-9511, 16),
       to_signed(-12539, 16), to_signed(-15446, 16), to_signed(-18204, 16), to_signed(-20787, 16),
       to_signed(-23170, 16), to_signed(-25329, 16), to_signed(-27244, 16), to_signed(-28897, 16),
       to_signed(-30272, 16), to_signed(-31356, 16), to_signed(-32137, 16), to_signed(-32609, 16),
       to_signed(-32767, 16), to_signed(-32609, 16), to_signed(-32137, 16), to_signed(-31356, 16),
       to_signed(-30272, 16), to_signed(-28897, 16), to_signed(-27244, 16), to_signed(-25329, 16),
       to_signed(-23170, 16), to_signed(-20787, 16), to_signed(-18204, 16), to_signed(-15446, 16),
       to_signed(-12539, 16), to_signed(-9511, 16),  to_signed(-6392, 16),  to_signed(-3211, 16),
       to_signed(0, 16),      to_signed(3211, 16),   to_signed(6392, 16),   to_signed(9511, 16),
       to_signed(12539, 16),  to_signed(15446, 16),  to_signed(18204, 16),  to_signed(20787, 16),
       to_signed(23170, 16),  to_signed(25329, 16),  to_signed(27244, 16),  to_signed(28897, 16),
       to_signed(30272, 16),  to_signed(31356, 16),  to_signed(32137, 16),  to_signed(32609, 16),
       to_signed(32767, 16),  to_signed(32609, 16),  to_signed(32137, 16),  to_signed(31356, 16),
       to_signed(30272, 16),  to_signed(28897, 16),  to_signed(27244, 16),  to_signed(25329, 16),
       to_signed(23170, 16),  to_signed(20787, 16),  to_signed(18204, 16),  to_signed(15446, 16),
       to_signed(12539, 16),  to_signed(9511, 16),   to_signed(6392, 16),   to_signed(3211, 16)
   );

begin

   process(clk)
   begin
       if rising_edge(clk) then
           -- Read from ROM based on input address
           o_w_re <= std_logic_vector(C_ROM_RE(to_integer(unsigned(i_addr))));
           o_w_im <= std_logic_vector(C_ROM_IM(to_integer(unsigned(i_addr))));
       end if;
   end process;

end Behavioral;

