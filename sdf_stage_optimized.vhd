-- Project: 64-Point Radix-2 FFT Frequency Analyzer [cite: 1]
-- Module: Optimized SDF (Single-path Delay Feedback) Stage [cite: 474]
-- Description: Revised for M9K memory inference and balanced timing paths.

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity sdf_stage is
    Generic ( 
        G_DELAY : integer := 32  -- Delay Length: 32, 16, 8, 4, 2, or 1 [cite: 678, 901-919]
    );
    Port (
        clk       : in  STD_LOGIC; [cite: 681]
        rst       : in  STD_LOGIC; [cite: 682]
        i_mode    : in  STD_LOGIC; -- 0: Load/Feedback, 1: Butterfly Calculation [cite: 683, 687]
        i_data_re : in  STD_LOGIC_VECTOR(15 downto 0); [cite: 684]
        i_data_im : in  STD_LOGIC_VECTOR(15 downto 0); [cite: 689]
        i_w_re    : in  STD_LOGIC_VECTOR(15 downto 0); [cite: 692]
        i_w_im    : in  STD_LOGIC_VECTOR(15 downto 0); [cite: 692]
        o_data_re : out STD_LOGIC_VECTOR(15 downto 0); [cite: 692]
        o_data_im : out STD_LOGIC_VECTOR(15 downto 0)  [cite: 693]
    );
end sdf_stage;

architecture Behavioral of sdf_stage is

    -- Component for Complex Multiplication (Existing Module) [cite: 514, 704]
    component complex_mult is
        Port (
            clk       : in  STD_LOGIC;
            i_data_re : in  STD_LOGIC_VECTOR(15 downto 0);
            i_data_im : in  STD_LOGIC_VECTOR(15 downto 0);
            i_w_re    : in  STD_LOGIC_VECTOR(15 downto 0);
            i_w_im    : in  STD_LOGIC_VECTOR(15 downto 0);
            o_res_re  : out STD_LOGIC_VECTOR(15 downto 0);
            o_res_im  : out STD_LOGIC_VECTOR(15 downto 0)
        );
    end component;

    -- Internal Signal Definitions (Signed for Arithmetic) [cite: 495, 713]
    signal s_in_re, s_in_im       : signed(15 downto 0);
    signal s_fifo_out_re, s_fifo_out_im : signed(15 downto 0);
    signal s_bf_sum_re, s_bf_sum_im : signed(15 downto 0);
    signal s_bf_dif_re, s_bf_dif_im : signed(15 downto 0);
    
    -- Multiplier Input Mux Signals [cite: 723, 777]
    signal s_mult_in_re, s_mult_in_im : STD_LOGIC_VECTOR(15 downto 0);
    
    -- FIFO Memory Array (Optimized for Block RAM Inference) [cite: 715]
    type ram_type is array (0 to G_DELAY-1) of signed(31 downto 0);
    signal fifo_mem : ram_type := (others => (others => '0'));

begin

    -- Type Casting to Signed [cite: 498, 501]
    s_in_re <= signed(i_data_re);
    s_in_im <= signed(i_data_im);

    -- 1. Butterfly Addition and Subtraction [cite: 481, 720]
    -- Sum = A + B (Top output) [cite: 502, 721]
    -- Dif = A - B (Bottom output to FIFO) [cite: 503, 721]
    s_bf_sum_re <= s_fifo_out_re + s_in_re;
    s_bf_sum_im <= s_fifo_out_im + s_in_im;
    s_bf_dif_re <= s_fifo_out_re - s_in_re;
    s_bf_dif_im <= s_fifo_out_im - s_in_im;

    -- 2. Single-path Delay Feedback Logic (Shift Register) [cite: 750]
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then [cite: 756]
                fifo_mem <= (others => (others => '0')); [cite: 758, 759]
            else
                -- Shift Logic [cite: 761]
                for i in 0 to G_DELAY-2 loop
                    fifo_mem(i) <= fifo_mem(i+1);
                end loop;

                -- Feedback Mux Logic [cite: 763, 769]
                if i_mode = '0' then
                    -- Load Mode: Put input into FIFO [cite: 765, 766]
                    fifo_mem(G_DELAY-1) <= s_in_im & s_in_re; 
                else
                    -- Calculation Mode: Put Butterfly Difference into FIFO [cite: 769, 770]
                    fifo_mem(G_DELAY-1) <= s_bf_dif_im & s_bf_dif_re;
                end if;
            end if;
        end if;
    end process;

    -- FIFO Output Mapping [cite: 751, 752]
    s_fifo_out_re <= fifo_mem(0)(15 downto 0);
    s_fifo_out_im <= fifo_mem(0)(31 downto 16);

    -- 3. Multiplier Input Multiplexer [cite: 777, 788]
    process (i_mode, s_fifo_out_re, s_fifo_out_im, s_bf_sum_re, s_bf_sum_im)
    begin
        if i_mode = '0' then
            -- Pass Delayed Data to Multiplier during first N/2 cycles [cite: 780, 783]
            s_mult_in_re <= std_logic_vector(s_fifo_out_re);
            s_mult_in_im <= std_logic_vector(s_fifo_out_im);
        else
            -- Pass Butterfly Sum to Multiplier during second N/2 cycles [cite: 781, 786]
            s_mult_in_re <= std_logic_vector(s_bf_sum_re);
            s_mult_in_im <= std_logic_vector(s_bf_sum_im);
        end if;
    end process;

    -- 4. Instance of Complex Multiplier (External Module) [cite: 739, 740]
    inst_mult: complex_mult
        port map (
            clk       => clk, [cite: 742]
            i_data_re => s_mult_in_re, [cite: 743]
            i_data_im => s_mult_in_im, [cite: 744]
            i_w_re    => i_w_re, [cite: 745]
            i_w_im    => i_w_im, [cite: 746]
            o_res_re  => o_data_re, [cite: 747]
            o_res_im  => o_data_im  [cite: 1408]
        );

end Behavioral;