library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity magnitude_calc is
    Port (
        clk       : in  STD_LOGIC;
        rst       : in  STD_LOGIC;
        i_valid   : in  STD_LOGIC;
        i_re      : in  STD_LOGIC_VECTOR(15 downto 0);
        i_im      : in  STD_LOGIC_VECTOR(15 downto 0);
        o_valid   : out STD_LOGIC;
        o_mag     : out STD_LOGIC_VECTOR(15 downto 0)
    );
end magnitude_calc;

architecture Behavioral of magnitude_calc is
    -- Stage 1 Signals
    signal s_abs_re : unsigned(15 downto 0);
    signal s_abs_im : unsigned(15 downto 0);
    signal r_val_1  : std_logic;

    -- Stage 2 Signals
    signal s_max    : unsigned(15 downto 0);
    signal s_min    : unsigned(15 downto 0);
    signal r_val_2  : std_logic;

    -- Stage 3 Signals (Output)
    -- Tidak butuh signal internal, langsung ke output register
    
begin

    process(clk)
        variable v_re_signed : signed(15 downto 0);
        variable v_im_signed : signed(15 downto 0);
        variable v_term_1    : unsigned(15 downto 0);
        variable v_term_2    : unsigned(15 downto 0);
        variable v_sum_full  : unsigned(16 downto 0);
    begin
        if rising_edge(clk) then
            if rst = '1' then
                r_val_1 <= '0';
                r_val_2 <= '0';
                o_valid <= '0';
                o_mag   <= (others => '0');
            else
                -- ==========================================
                -- PIPELINE STAGE 1: Absolute Value
                -- ==========================================
                v_re_signed := signed(i_re);
                v_im_signed := signed(i_im);

                -- Handle corner case -32768
                if v_re_signed = -32768 then s_abs_re <= to_unsigned(32767, 16);
                else s_abs_re <= unsigned(abs(v_re_signed)); end if;

                if v_im_signed = -32768 then s_abs_im <= to_unsigned(32767, 16);
                else s_abs_im <= unsigned(abs(v_im_signed)); end if;

                r_val_1 <= i_valid;

                -- ==========================================
                -- PIPELINE STAGE 2: Sorting Max/Min
                -- ==========================================
                if s_abs_re > s_abs_im then
                    s_max <= s_abs_re;
                    s_min <= s_abs_im;
                else
                    s_max <= s_abs_im;
                    s_min <= s_abs_re;
                end if;

                r_val_2 <= r_val_1;

                -- ==========================================
                -- PIPELINE STAGE 3: Calculation & Output
                -- Formula: Max + (Min >> 2) + (Min >> 3) 
                -- = Max + 0.375 * Min
                -- ==========================================
                
                -- Gunakan VARIABLE agar perhitungan terjadi instan di clock ini
                v_term_1   := shift_right(s_min, 2); -- Min / 4
                v_term_2   := shift_right(s_min, 3); -- Min / 8
                v_sum_full := resize(s_max, 17) + resize(v_term_1, 17) + resize(v_term_2, 17);

                -- Saturation Logic (Agar tidak overflow balik ke 0)
                if v_sum_full > 65535 then
                    o_mag <= x"FFFF";
                else
                    o_mag <= std_logic_vector(v_sum_full(15 downto 0));
                end if;

                o_valid <= r_val_2;

            end if;
        end if;
    end process;

end Behavioral;