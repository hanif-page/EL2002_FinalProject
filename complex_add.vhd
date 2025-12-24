library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity complex_add is
    Port (
        clk      : in  STD_LOGIC;
        rst      : in  STD_LOGIC;
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
begin
    process(clk)
        variable v_a_re, v_a_im : signed(15 downto 0);
        variable v_b_re, v_b_im : signed(15 downto 0);
    begin
        if rising_edge(clk) then
            if rst = '1' then
                o_sum_re <= (others => '0'); o_sum_im <= (others => '0');
                o_dif_re <= (others => '0'); o_dif_im <= (others => '0');
            else
                v_a_re := signed(i_a_re); v_a_im := signed(i_a_im);
                v_b_re := signed(i_b_re); v_b_im := signed(i_b_im);

                -- Butterfly Addition/Subtraction
                o_sum_re <= std_logic_vector(v_a_re + v_b_re);
                o_sum_im <= std_logic_vector(v_a_im + v_b_im);
                o_dif_re <= std_logic_vector(v_a_re - v_b_re);
                o_dif_im <= std_logic_vector(v_a_im - v_b_im);
            end if;
        end if;
    end process;
end Behavioral;