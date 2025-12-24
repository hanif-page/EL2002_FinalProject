library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_uart_module is
end tb_uart_module;

architecture Behavioral of tb_uart_module is
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

    signal clk, rst, tx_start, tx_pin, rx_done, tx_done : std_logic := '0';
    signal rx_pin : std_logic := '1';
    signal tx_data, rx_data : std_logic_vector(7 downto 0) := (others => '0');

    constant CLK_PERIOD : time := 20 ns;
    constant BIT_PERIOD : time := 104166 ns; -- 1/9600 Baud [cite: 1082, 1099]

    procedure send_uart_byte(
        constant data_byte : in std_logic_vector(7 downto 0);
        signal rx_line     : out std_logic
    ) is
    begin
        rx_line <= '0'; -- Start Bit [cite: 1139]
        wait for BIT_PERIOD;
        for i in 0 to 7 loop
            rx_line <= data_byte(i); -- Data Bits (LSB First) [cite: 1144]
            wait for BIT_PERIOD;
        end loop;
        rx_line <= '1'; -- Stop Bit [cite: 1152]
        wait for BIT_PERIOD;
    end procedure;

begin
    uut: uart_module port map (
        clk => clk, rst => rst, rx_pin => rx_pin, tx_start => tx_start,
        tx_data => tx_data, tx_pin => tx_pin, rx_data => rx_data,
        rx_done => rx_done, tx_done => tx_done
    );

    clk <= not clk after CLK_PERIOD/2;

    stim_proc: process
    begin
        -- 1. System Reset [cite: 1130, 1167]
        rst <= '1'; 
        wait for 100 ns;
        rst <= '0';
        wait for 100 ns;

        -- 2. Sending Sample 1: High Byte (0x01)
        report "Sending High Byte (0x01)";
        send_uart_byte("00000001", rx_pin);
        wait until rx_done = '1'; -- WAIT for hardware to finalize byte 
        assert rx_data = "00000001" report "Error: High Byte Sample 1 Mismatch" severity error;

        -- 3. INTER-BYTE DELAY (Crucial Fix)
        -- This ensures rx_pin stays high (Idle) for at least one full bit period
        -- so the Receiver FSM can transition back to RX_IDLE[cite: 1172, 1190].
        rx_pin <= '1';
        wait for BIT_PERIOD; 

        -- 4. Sending Sample 1: Low Byte (0x34)
        report "Sending Low Byte (0x34)";
        send_uart_byte("00110100", rx_pin);
        wait until rx_done = '1'; -- WAIT for hardware to finalize byte 
        assert rx_data = "00110100" report "Error: Low Byte Sample 1 Mismatch" severity error;

        -- 5. Finalize Simulation
        wait for 1 ms;
        report "Simulation Finished Successfully";
        wait; -- Stop simulation
    end process;
end Behavioral;