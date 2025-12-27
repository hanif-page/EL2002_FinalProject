library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.fft_pkg.all;

entity sdf_stage is
    generic (
        G_DELAY : integer := 32 -- 32, 16, 8, 4, 2, or 1
    );
    port (
        clk    : in  std_logic;
        rst    : in  std_logic;
        i_mode : in  std_logic;      -- 0: Feedback/Load, 1: Butterfly
        i_data : in  complex_16;     -- Data from previous stage
        i_w    : in  complex_16;     -- Twiddle factor from ROM
        o_data : out complex_16      -- Output to next stage
    );
end sdf_stage;

architecture Behavioral of sdf_stage is

    -- Internal Signals
    signal s_fifo_out   : complex_16;
    signal s_bf_sum     : complex_16;
    signal s_bf_dif     : complex_16;
    signal s_mult_in    : complex_16;
    signal s_mult_out   : complex_16;
    signal s_fifo_in    : complex_16;
    
    -- FIFO Memory (Shift Register)
    type ram_type is array (0 to G_DELAY-1) of complex_16;
    signal r_fifo_mem : ram_type := (others => (re => (others => '0'), im => (others => '0')));

begin

    -- 1. Butterfly Unit (Scaled DIF)
    -- Input A comes from FIFO, Input B comes from Stage Input
    U_BF : entity work.butterfly_dif_scaled
        port map (
            i_A   => s_fifo_out,
            i_B   => i_data,
            o_Sum => s_bf_sum,
            o_Dif => s_bf_dif
        );

    -- 2. Complex Multiplier (Twiddle Rotation)
    -- This rotates the Difference result. Sum result bypasses the multiplier.
    U_MULT : entity work.complex_mult
        port map (
            clk    => clk,
            i_data => s_bf_dif,
            i_w    => i_w,
            o_res  => s_mult_out
        );

    -- 3. SDF Control Logic (The Mux and Feedback)
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                r_fifo_mem <= (others => (re => (others => '0'), im => (others => '0')));
                o_data     <= (re => (others => '0'), im => (others => '0'));
            else
                -- FIFO Shift Logic
                if G_DELAY > 1 then
                    r_fifo_mem(0 to G_DELAY-2) <= r_fifo_mem(1 to G_DELAY-1);
                end if;

                if i_mode = '0' then
                    -- MODE 0: LOADING/FEEDBACK
                    -- 1. Push stage input into the FIFO
                    r_fifo_mem(G_DELAY-1) <= i_data;
                    -- 2. Output the data that was already in the FIFO
                    -- (This data was the multiplied Difference from the previous half-frame)
                    o_data <= s_fifo_out;
                else
                    -- MODE 1: BUTTERFLY CALCULATION
                    -- 1. Push the rotated Difference result back into FIFO
                    r_fifo_mem(G_DELAY-1) <= s_mult_out;
                    -- 2. Output the Sum result directly to the next stage
                    o_data <= s_bf_sum;
                end if;
            end if;
        end if;
    end process;

    -- FIFO Output Mapping
    s_fifo_out <= r_fifo_mem(0);

end Behavioral;