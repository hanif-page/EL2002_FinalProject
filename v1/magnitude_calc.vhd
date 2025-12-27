library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity magnitude_calc is
    Port (
        clk       : in  STD_LOGIC;
        rst       : in  STD_LOGIC;
        i_valid   : in  STD_LOGIC; -- Valid signal from FFT
        i_re      : in  STD_LOGIC_VECTOR(15 downto 0);
        i_im      : in  STD_LOGIC_VECTOR(15 downto 0);
        o_valid   : out STD_LOGIC;
        o_mag     : out STD_LOGIC_VECTOR(15 downto 0)
    );
end magnitude_calc;

architecture Behavioral of magnitude_calc is
    -- Internal Signals
    signal s_abs_re : unsigned(15 downto 0);
    signal s_abs_im : unsigned(15 downto 0);
    signal s_max    : unsigned(15 downto 0);
    signal s_min    : unsigned(15 downto 0);
    signal s_term_a : unsigned(15 downto 0); -- Min * 0.25
    signal s_term_b : unsigned(15 downto 0); -- Min * 0.125
    signal s_sum    : unsigned(16 downto 0); -- 17 bit to catch overflow
    
    -- Pipeline Registers
    signal r_valid_1 : std_logic;
    signal r_valid_2 : std_logic;

begin

    process(clk)
        variable v_re_signed : signed(15 downto 0);
        variable v_im_signed : signed(15 downto 0);
    begin
        if rising_edge(clk) then
            if rst = '1' then
                o_valid <= '0';
                o_mag   <= (others => '0');
                r_valid_1 <= '0';
                r_valid_2 <= '0';
            else
                -- STAGE 1: Calculate Absolute Values
                -- Cast inputs to signed
                v_re_signed := signed(i_re);
                v_im_signed := signed(i_im);
                
                -- Absolute Value Logic (Handle -32768 edge case by clamping)
                if v_re_signed = -32768 then
                    s_abs_re <= to_unsigned(32767, 16);
                else
                    s_abs_re <= unsigned(abs(v_re_signed));
                end if;

                if v_im_signed = -32768 then
                    s_abs_im <= to_unsigned(32767, 16);
                else
                    s_abs_im <= unsigned(abs(v_im_signed));
                end if;
                
                r_valid_1 <= i_valid;

                -- STAGE 2: Determine Max/Min and Fractions
                if s_abs_re > s_abs_im then
                    s_max <= s_abs_re;
                    s_min <= s_abs_im;
                else
                    s_max <= s_abs_im;
                    s_min <= s_abs_re;
                end if;
                
                r_valid_2 <= r_valid_1;

                -- STAGE 3: Calculation (Alpha Max + Beta Min)
                -- Formula: Mag = Max + 0.375 * Min
                -- 0.375 is (1/4 + 1/8), which is (Shift >> 2) + (Shift >> 3)
                
                s_term_a <= shift_right(s_min, 2); -- Divide by 4
                s_term_b <= shift_right(s_min, 3); -- Divide by 8
                
                -- Summation (Max + 0.25*Min + 0.125*Min)
                s_sum <= resize(s_max, 17) + resize(s_term_a, 17) + resize(s_term_b, 17);
                
                -- Output Handling (Saturation)
                if s_sum > 65535 then
                    o_mag <= x"FFFF"; -- Saturate if overflow 16-bit
                else
                    o_mag <= std_logic_vector(s_sum(15 downto 0));
                end if;
                
                o_valid <= r_valid_2;
            end if;
        end if;
    end process;

end Behavioral;

