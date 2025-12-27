library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.fft_pkg.all;

entity sdf_stage is
    generic (
        G_DELAY : integer := 32  -- FIFO Depth (Stages 1-6 use 32, 16, 8, 4, 2, 1)
    );
    port (
        clk    : in  std_logic;
        rst    : in  std_logic;
        i_mode : in  std_logic;   -- '0' = Load/Bypass, '1' = Butterfly/Twiddle
        i_data : in  complex_16;
        i_w    : in  complex_16;
        o_data : out complex_16
    );
end sdf_stage;

architecture Behavioral of sdf_stage is

    -- FIFO/Delay Line definition
    type t_fifo is array (0 to G_DELAY-1) of complex_16;
    signal r_fifo : t_fifo := (others => (re => (others => '0'), im => (others => '0')));

    -- Internal signals
    signal s_bf_sum, s_bf_dif : complex_16;
    signal s_mult_out         : complex_16;
    signal r_fifo_out         : complex_16;

begin

    -- 1. Butterfly Unit: High-Precision DIF (Unscaled)
    U_BF : entity work.butterfly_dif
        port map (
            i_A   => r_fifo_out, 
            i_B   => i_data,     
            o_Sum => s_bf_sum,   
            o_Dif => s_bf_dif    
        );

    -- 2. Complex Multiplier: Rounding-Enabled
    U_MULT : entity work.complex_mult
        port map (
            clk    => clk,
            i_data => s_bf_dif,
            i_w    => i_w,
            o_res  => s_mult_out
        );

    -- 3. SDF Control Logic and FIFO Management
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                -- CRITICAL: Explicitly clear the FIFO to stop 'X' propagation
                for i in 0 to G_DELAY-1 loop
                    r_fifo(i).re <= (others => '0');
                    r_fifo(i).im <= (others => '0');
                end loop;
                r_fifo_out.re <= (others => '0');
                r_fifo_out.im <= (others => '0');
                o_data.re     <= (others => '0');
                o_data.im     <= (others => '0');
            else
                -- FIFO Shift and Input Multiplexer
                if i_mode = '0' then
                    r_fifo(0) <= i_data; -- Loading new data into the delay line
                else
                    r_fifo(0) <= s_bf_sum; -- Storing butterfly sum for feedback
                end if;

                -- Shift through the delay stages
                for i in 1 to G_DELAY-1 loop
                    r_fifo(i) <= r_fifo(i-1);
                end loop;
                
                r_fifo_out <= r_fifo(G_DELAY-1);

                -- Output Multiplexer
                if i_mode = '0' then
                    -- Output the rotated difference result
                    o_data <= s_mult_out;
                else
                    -- Output the current butterfly sum
                    o_data <= r_fifo_out;
                end if;
            end if;
        end if;
    end process;

end Behavioral;