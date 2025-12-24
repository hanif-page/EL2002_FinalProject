library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_uart_module is
end tb_uart_module;

architecture Behavioral of tb_uart_module is
    -- Component Declaration [cite: 1078]
    component uart_module
        Generic (
            CLK_FREQ  : integer := 50000000;
            BAUD_RATE : integer := 9600
        );
        Port (
            clk      : in  STD_LOGIC;
            rst      : in  STD_LOGIC;
            rx_pin   : in  STD_LOGIC;
            tx_start : in  STD_LOGIC;
            tx_data  : in  STD_LOGIC_VECTOR(7 downto 0);
            tx_pin   : out STD_LOGIC;
            rx_data  : out STD_LOGIC_VECTOR(7 downto 0);
            rx_done  : out STD_LOGIC;
            tx_done  : out STD_LOGIC
        );
    end component;

    -- Signals [cite: 1102, 1112]
    signal clk      : std_logic := '0';
    signal rst      : std_logic := '0';
    signal rx_pin   : std_logic := '1';
    signal tx_start : std_logic := '0';
    signal tx_data  : std_logic_vector(7 downto 0) := (others => '0');
    signal tx_pin   : std_logic;
    signal rx_data  : std_logic_vector(7 downto 0);
    signal rx_done  : std_logic;
    signal tx_done  : std_logic;

    -- Timing constants [cite: 1099]
    constant CLK_PERIOD : time := 20 ns; -- 50 MHz
    constant BIT_PERIOD : time := 104166 ns; -- 1/9600 Baud

    -- Your Data (First 10 samples converted to Bytes: High, Low)
    type byte_array is array (0 to 19) of std_logic_vector(7 downto 0);
    constant test_data : byte_array := (
        "00000000", "00000000", -- Sample 0: 0000000000000000
        "00000001", "00110100", -- Sample 1: 0000000100110100
        "00000001", "01011000", -- Sample 2: 0000000101011000
        "00000001", "00000100", -- Sample 3: 0000000100000100
        "00000001", "00110010", -- Sample 4: 0000000100110010
        "00000001", "01100100", -- Sample 5: 0000000101100100
        "00000000", "10010010", -- Sample 6: 0000000010010010
        "11111111", "00101110", -- Sample 7: 1111111100101110
        "11111110", "10010110", -- Sample 8: 1111111010010110
        "11111110", "11100010"  -- Sample 9: 1111111011100010
    );

    -- Procedure to send 1 byte serially (PC to FPGA) [cite: 1111, 1172]
    procedure send_uart_byte(
        constant data_byte : in std_logic_vector(7 downto 0);
        signal rx_line     : out std_logic
    ) is
    begin
        rx_line <= '0'; -- Start Bit 
        wait for BIT_PERIOD;
        for i in 0 to 7 loop
            rx_line <= data_byte(i); -- Data Bits (LSB First) 
            wait for BIT_PERIOD;
        end loop;
        rx_line <= '1'; -- Stop Bit [cite: 1188]
        wait for BIT_PERIOD;
    end procedure;

begin
    -- Instantiate UUT [cite: 1392]
    uut: uart_module
        port map (
            clk => clk, rst => rst, rx_pin => rx_pin,
            tx_start => tx_start, tx_data => tx_data,
            tx_pin => tx_pin, rx_data => rx_data,
            rx_done => rx_done, tx_done => tx_done
        );

    -- Clock Generation
    clk <= not clk after CLK_PERIOD/2;

    -- Stimulus Process
    stim_proc: process
    begin
        rst <= '1'; [cite: 1166]
        wait for 100 ns;
        rst <= '0';
        wait for 100 ns;

        -- Testcase: Sending Sample 1 (16-bit word split into 2 bytes)
        report "Sending High Byte of Sample 1";
        send_uart_byte(test_data(2), rx_pin); -- 0x01
        
        report "Sending Low Byte of Sample 1";
        send_uart_byte(test_data(3), rx_pin); -- 0x34

        wait for 1 ms;
        
        -- Testcase: FPGA Sending data back to PC
        tx_data <= "10101010"; -- 0xAA
        tx_start <= '1'; [cite: 1135]
        wait for CLK_PERIOD;
        tx_start <= '0';
        
        wait until tx_done = '1'; [cite: 1154]
        wait for 500 us;
        
        finish;
    end process;
end Behavioral;