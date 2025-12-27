library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_input_buffer is
end tb_input_buffer;

architecture Behavioral of tb_input_buffer is
    component input_buffer
        Port (
            clk       : in  STD_LOGIC;
            rst       : in  STD_LOGIC;
            i_rx_data : in  STD_LOGIC_VECTOR(7 downto 0);
            i_rx_done : in  STD_LOGIC;
            i_enable  : in  STD_LOGIC;
            i_rd_addr : in  STD_LOGIC_VECTOR(5 downto 0);
            o_data_re : out STD_LOGIC_VECTOR(15 downto 0);
            o_data_im : out STD_LOGIC_VECTOR(15 downto 0)
        );
    end component;

    signal clk       : std_logic := '0';
    signal rst       : std_logic := '0';
    signal i_rx_data : std_logic_vector(7 downto 0) := (others => '0');
    signal i_rx_done : std_logic := '0';
    signal i_enable  : std_logic := '0';
    signal i_rd_addr : std_logic_vector(5 downto 0) := (others => '0');
    signal o_data_re : std_logic_vector(15 downto 0);
    signal o_data_im : std_logic_vector(15 downto 0);

    constant CLK_PERIOD : time := 20 ns;

    -- Complete 64-point dataset from your data.txt
    type t_data_array is array (0 to 63) of std_logic_vector(15 downto 0);
    constant DATA_ROM : t_data_array := (
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
    uut: input_buffer port map (
        clk => clk, rst => rst, i_rx_data => i_rx_data,
        i_rx_done => i_rx_done, i_enable => i_enable,
        i_rd_addr => i_rd_addr, o_data_re => o_data_re,
        o_data_im => o_data_im
    );

    clk <= not clk after CLK_PERIOD/2;

    stim_proc: process
    begin
        -- 1. System Initialization
        rst <= '1'; i_enable <= '0'; i_rd_addr <= (others => '0');
        wait for 100 ns;
        rst <= '0';
        wait for 40 ns;
        
        -- 2. Data Loading Phase (UART Simulation)
        i_enable <= '1'; -- Enable writing to buffer
        report "Starting Data Loading Phase...";
        for i in 0 to 63 loop
            -- Bytes for Real component (from your DATA_ROM)
            i_rx_data <= DATA_ROM(i)(7 downto 0); -- Low Byte
            i_rx_done <= '1'; wait for CLK_PERIOD; i_rx_done <= '0'; wait for CLK_PERIOD;
            i_rx_data <= DATA_ROM(i)(15 downto 8); -- High Byte
            i_rx_done <= '1'; wait for CLK_PERIOD; i_rx_done <= '0'; wait for CLK_PERIOD;
            
            -- Bytes for Imaginary component (Fixed at 0x00)
            i_rx_data <= x"00"; -- Low Byte
            i_rx_done <= '1'; wait for CLK_PERIOD; i_rx_done <= '0'; wait for CLK_PERIOD;
            i_rx_data <= x"00"; -- High Byte
            i_rx_done <= '1'; wait for CLK_PERIOD; i_rx_done <= '0'; wait for CLK_PERIOD;

            wait for 1 us; -- Delay between samples as requested
        end loop;
        i_enable <= '0'; -- Disable writing, prepare for read-back
        wait for 500 ns;

        -- 3. SEQUENTIAL READ-BACK PHASE (The part you need)
        -- This loop will show every single o_data_re value in the waveform
        report "Starting Sequential Read-Back Phase...";
        for j in 0 to 63 loop
            i_rd_addr <= std_logic_vector(to_unsigned(j, 6)); -- Set Address 0 to 63
            wait for 2 us; -- Hold each address for 2 microseconds to make it visible
        end loop;

        report "Full Buffer Verification Complete.";
        wait; -- End Simulation
    end process;
end Behavioral;