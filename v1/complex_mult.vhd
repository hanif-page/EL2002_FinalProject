library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity complex_mult is
    Port (
        clk       : in  STD_LOGIC;
        i_data_re : in  STD_LOGIC_VECTOR(15 downto 0);
        i_data_im : in  STD_LOGIC_VECTOR(15 downto 0);
        i_w_re    : in  STD_LOGIC_VECTOR(15 downto 0);
        i_w_im    : in  STD_LOGIC_VECTOR(15 downto 0);
        o_res_re  : out STD_LOGIC_VECTOR(15 downto 0);
        o_res_im  : out STD_LOGIC_VECTOR(15 downto 0)
    );
end complex_mult;

architecture Behavioral of complex_mult is
    signal s_data_re, s_data_im : signed(15 downto 0);
    signal s_w_re, s_w_im       : signed(15 downto 0);
    signal s_res_re_long        : signed(31 downto 0);
    signal s_res_im_long        : signed(31 downto 0);
begin
    process(clk)
    begin
        if rising_edge(clk) then
            -- Stage 1: Registration
            s_data_re <= signed(i_data_re);
            s_data_im <= signed(i_data_im);
            s_w_re    <= signed(i_w_re);
            s_w_im    <= signed(i_w_im);

            -- Stage 2: Correct Complex Multiplication
            -- (A+jB)*(C+jD) = (AC - BD) + j(AD + BC)
            s_res_re_long <= (s_data_re * s_w_re) - (s_data_im * s_w_im);
            s_res_im_long <= (s_data_re * s_w_im) + (s_data_im * s_w_re);

            -- Truncate Q15 (bits 30 downto 15)
            o_res_re <= std_logic_vector(s_res_re_long(30 downto 15));
            o_res_im <= std_logic_vector(s_res_im_long(30 downto 15));
        end if;
    end process;
end Behavioral;