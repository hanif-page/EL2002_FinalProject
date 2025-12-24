library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity complex_add is
   Port (
       i_a_re   : in  STD_LOGIC_VECTOR(15 downto 0);
       i_a_im   : in  STD_LOGIC_VECTOR(15 downto 0);
       i_b_re   : in  STD_LOGIC_VECTOR(15 downto 0);
       i_b_im   : in  STD_LOGIC_VECTOR(15 downto 0);
       o_sum_re : out STD_LOGIC_VECTOR(15 downto 0);
       o_sum_im : out STD_LOGIC_VECTOR(15 downto 0);
       o_dif_re : out STD_LOGIC_VECTOR(15 downto 0);
       o_dif_im : out STD_LOGIC_VECTOR(15 downto 0)
   );
end complex_add;

architecture Behavioral of complex_add is
   signal s_a_re, s_a_im, s_b_re, s_b_im : signed(15 downto 0);
begin
   -- Type casting
   s_a_re <= signed(i_a_re);
   s_a_im <= signed(i_a_im);
   s_b_re <= signed(i_b_re);
   s_b_im <= signed(i_b_im);

   -- Butterfly Addition: Sum = A + B
   o_sum_re <= std_logic_vector(s_a_re + s_b_re);
   o_sum_im <= std_logic_vector(s_a_im + s_b_im);

   -- Butterfly Subtraction: Dif = A - B
   o_dif_re <= std_logic_vector(s_a_re - s_b_re);
   o_dif_im <= std_logic_vector(s_a_im - s_b_im);

end Behavioral;

