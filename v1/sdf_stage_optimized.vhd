-- Project: 64-Point Radix-2 FFT Frequency Analyzer
-- Module: Refactored SDF (Single-path Delay Feedback) Stage
-- Description: Updated for synchronization with 2-cycle latency complex multiplier.

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity sdf_stage is
    Generic ( 
        G_DELAY : integer := 32  -- Delay Length: 32, 16, 8, 4, 2, or 1
    );
    Port (
        clk       : in  STD_LOGIC;
        rst       : in  STD_LOGIC;
        i_mode    : in  STD_LOGIC; -- 0: Load/Feedback, 1: Butterfly Calculation
        i_data_re : in  STD_LOGIC_VECTOR(15 downto 0);
        i_data_im : in  STD_LOGIC_VECTOR(15 downto 0);
        i_w_re    : in  STD_LOGIC_VECTOR(15 downto 0); -- From twiddle_rom
        i_w_im    : in  STD_LOGIC_VECTOR(15 downto 0); -- From twiddle_rom
        o_data_re : out STD_LOGIC_VECTOR(15 downto 0);
        o_data_im : out STD_LOGIC_VECTOR(15 downto 0)
    );
end sdf_stage;

architecture Behavioral of sdf_stage is

    -- Internal Signal Definitions
    signal s_in_re, s_in_im             : signed(15 downto 0);
    signal s_fifo_out_re, s_fifo_out_im : signed(15 downto 0);
    signal s_bf_sum_re, s_bf_sum_im     : signed(15 downto 0);
    signal s_bf_dif_re, s_bf_dif_im     : signed(15 downto 0);
    
    -- Multiplier Input Mux Signals
    signal s_mult_in_re, s_mult_in_im   : std_logic_vector(15 downto 0);
    
    -- Twiddle Factor Delay Registers (to match Multiplier Latency)
    signal r_w_re_reg, r_w_im_reg       : std_logic_vector(15 downto 0);

    -- FIFO Memory Array (Optimized for Block RAM Inference)
    type ram_type is array (0 to G_DELAY-1) of signed(31 downto 0);
    signal fifo_mem : ram_type := (others => (others => '0'));

begin

    -- Type Casting
    s_in_re <= signed(i_data_re);
    s_in_im <= signed(i_data_im);

    -- 1. Butterfly Addition and Subtraction (Combinational)
    -- This matches the SDF architecture: Sum goes forward, Difference goes to Feedback
    s_bf_sum_re <= s_fifo_out_re + s_in_re;
    s_bf_sum_im <= s_fifo_out_im + s_in_im;
    s_bf_dif_re <= s_fifo_out_re - s_in_re;
    s_bf_dif_im <= s_fifo_out_im - s_in_im;

    -- 2. Single-path Delay Feedback Logic (FIFO)
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                fifo_mem <= (others => (others => '0'));
            else
                -- Shift Register Logic
                if G_DELAY > 1 then
                    fifo_mem(0 to G_DELAY-2) <= fifo_mem(1 to G_DELAY-1);
                end if;

                -- Feedback Mux
                if i_mode = '0' then
                    -- First N/2 cycles: Load input into FIFO
                    fifo_mem(G_DELAY-1) <= s_in_im & s_in_re; 
                else
                    -- Second N/2 cycles: Store Butterfly Difference for processing
                    fifo_mem(G_DELAY-1) <= s_bf_dif_im & s_bf_dif_re;
                end if;
            end if;
        end if;
    end process;

    -- FIFO Output Mapping
    s_fifo_out_re <= fifo_mem(0)(15 downto 0);
    s_fifo_out_im <= fifo_mem(0)(31 downto 16);

    -- 3. Multiplier Input Multiplexer
    -- Selects between FIFO output (direct) or Butterfly Sum
    process (i_mode, s_fifo_out_re, s_fifo_out_im, s_bf_sum_re, s_bf_sum_im)
    begin
        if i_mode = '0' then
            s_mult_in_re <= std_logic_vector(s_fifo_out_re);
            s_mult_in_im <= std_logic_vector(s_fifo_out_im);
        else
            s_mult_in_re <= std_logic_vector(s_bf_sum_re);
            s_mult_in_im <= std_logic_vector(s_bf_sum_im);
        end if;
    end process;

    -- 4. Twiddle Factor Sync Logic
    -- We pass twiddles directly; the complex_mult module handles its internal registration.
    -- This ensures i_w and s_mult_in are sampled on the same clock edge.

    -- 5. Complex Multiplier Instance (The Mathematics Engine)
    inst_mult: entity work.complex_mult
        port map (
            clk       => clk,
            i_data_re => s_mult_in_re,
            i_data_im => s_mult_in_im,
            i_w_re    => i_w_re,
            i_w_im    => i_w_im,
            o_res_re  => o_data_re,
            o_res_im  => o_data_im
        );

end Behavioral;