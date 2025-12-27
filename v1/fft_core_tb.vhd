library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_fft_core is
end tb_fft_core;

-- Inside fft_core_tb.vhd
architecture Behavioral of tb_fft_core is
    component fft_core
        Port (
            clk       : in  STD_LOGIC;
            rst       : in  STD_LOGIC;
            i_start   : in  STD_LOGIC;
            i_data_re : in  STD_LOGIC_VECTOR(15 downto 0);
            i_data_im : in  STD_LOGIC_VECTOR(15 downto 0);
            o_data_re : out STD_LOGIC_VECTOR(15 downto 0);
            o_data_im : out STD_LOGIC_VECTOR(15 downto 0);
            o_idx     : out STD_LOGIC_VECTOR(5 downto 0);
            o_done    : out STD_LOGIC
        );
    end component;
    -- ...

    -- Signals
    signal clk : std_logic := '0';
    signal rst : std_logic := '0';
    signal i_start : std_logic := '0';
    signal i_data_re : std_logic_vector(15 downto 0) := (others => '0');
    signal i_data_im : std_logic_vector(15 downto 0) := (others => '0');
    signal o_data_re, o_data_im : std_logic_vector(15 downto 0);
    signal o_idx : std_logic_vector(5 downto 0);
    signal o_done : std_logic;

    constant CLK_PERIOD : time := 20 ns;

    -- The 64 verified real samples from your input_buffer output
    type t_data_array is array (0 to 63) of std_logic_vector(15 downto 0);
    constant INPUT_SAMPLES : t_data_array := (
        x"0000", x"0134", x"0158", x"0104", x"0132", x"0164", x"0092", x"FF2E",
        x"FE96", x"FEE2", x"FEF2", x"FE9B", x"FEF7", x"004B", x"0153", x"0146",
        x"0100", x"0146", x"0153", x"004B", x"FEF7", x"FE9B", x"FEF2", x"FEE2",
        x"FE96", x"FF2E", x"0092", x"0164", x"0132", x"0104", x"0158", x"0134",
        x"0000", x"FECC", x"FEA8", x"FEFC", x"FECE", x"FE9C", x"FF6E", x"00D2",
        x"016A", x"011E", x"010E", x"0165", x"0109", x"FFB5", x"FEAD", x"FEBA",
        x"FF00", x"FEBA", x"FEAD", x"FFB5", x"0109", x"0165", x"010E", x"011E",
        x"016A", x"00D2", x"FF6E", x"FE9C", x"FECE", x"FEFC", x"FEA8", x"FECC"
    );

begin
    -- Unit Under Test
    uut: fft_core port map (
        clk => clk, rst => rst, i_start => i_start,
        i_data_re => i_data_re, i_data_im => i_data_im,
        o_data_re => o_data_re, o_data_im => o_data_im,
        o_idx => o_idx, o_done => o_done
    );

    clk <= not clk after CLK_PERIOD/2;

    stim_proc: process
    begin
        -- 1. Initialize System
        rst <= '1'; i_start <= '0';
        wait for 100 ns;
        rst <= '0';
        wait for 40 ns;

        -- 2. Trigger FFT Start (Simulation of Control Global Counter start)
        i_start <= '1';
        wait for CLK_PERIOD;
        i_start <= '0';

        -- 3. Sequentially Feed All 64 Samples
        report "Feeding 64 samples into the FFT core pipeline...";
        for i in 0 to 63 loop
            i_data_re <= INPUT_SAMPLES(i);
            i_data_im <= x"0000"; -- Imaginary is zero
            wait for CLK_PERIOD;
        end loop;

        -- 4. Monitor Output until Done
        -- Note: Pipelines have latency, so output continues after input finishes
        wait until o_done = '1';
        wait for CLK_PERIOD * 10;

        report "FFT Core Simulation Complete.";
        wait;
    end process;
end Behavioral;