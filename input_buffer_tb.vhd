library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_input_buffer is
end tb_input_buffer;

architecture Behavioral of tb_input_buffer is
    -- Component Declaration [cite: 936-949]
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

    -- Signals [cite: 1352-1369]
    signal clk       : std_logic := '0';
    signal rst       : std_logic := '0';
    signal i_rx_data : std_logic_vector(7 downto 0) := (others => '0');
    signal i_rx_done : std_logic := '0';
    signal i_enable  : std_logic := '0';
    signal i_rd_addr : std_logic_vector(5 downto 0) := (others => '0');
    signal o_data_re : std_logic_vector(15 downto 0);
    signal o_data_im : std_logic_vector(15 downto 0);

    constant CLK_PERIOD : time := 20 ns;

    -- Procedure to simulate 4 bytes arriving from UART for one 16-bit Real sample
    -- Assuming Imaginary part is 0 for these test cases.
    procedure load_complex_sample(
        constant re_val    : in std_logic_vector(15 downto 0);
        signal rx_data_sig : out std_logic_vector(7 downto 0);
        signal rx_done_sig : out std_logic
    ) is
    begin
        -- Byte 0: Re_Low [cite: 972]
        rx_data_sig <= re_val(7 downto 0);
        rx_done_sig <= '1'; wait for CLK_PERIOD; rx_done_sig <= '0'; wait for CLK_PERIOD*2;
        -- Byte 1: Re_High [cite: 972]
        rx_data_sig <= re_val(15 downto 8);
        rx_done_sig <= '1'; wait for CLK_PERIOD; rx_done_sig <= '0'; wait for CLK_PERIOD*2;
        -- Byte 2: Im_Low (0x00) [cite: 973]
        rx_data_sig <= x"00";
        rx_done_sig <= '1'; wait for CLK_PERIOD; rx_done_sig <= '0'; wait for CLK_PERIOD*2;
        -- Byte 3: Im_High (0x00) [cite: 974]
        rx_data_sig <= x"00";
        rx_done_sig <= '1'; wait for CLK_PERIOD; rx_done_sig <= '0'; wait for CLK_PERIOD*2;
    end procedure;

begin
    -- Unit Under Test [cite: 1379-1384]
    uut: input_buffer
        port map (
            clk => clk, rst => rst, i_rx_data => i_rx_data,
            i_rx_done => i_rx_done, i_enable => i_enable,
            i_rd_addr => i_rd_addr, o_data_re => o_data_re,
            o_data_im => o_data_im
        );

    clk <= not clk after CLK_PERIOD/2;

    stim_proc: process
    begin
        -- Initialize
        rst <= '1'; i_enable <= '0';
        wait for 100 ns;
        rst <= '0';
        wait for 40 ns;
        
        -- Enable writing to buffer (IDLE state behavior) [cite: 441, 1251]
        i_enable <= '1';
        
        -- Load Sample 0: 0000000000000000
        load_complex_sample(x"0000", i_rx_data, i_rx_done);
        
        -- Load Sample 1: 0000000100110100 (0x0134)
        load_complex_sample(x"0134", i_rx_data, i_rx_done);
        
        -- Load Sample 2: 0000000101011000 (0x0158)
        load_complex_sample(x"0158", i_rx_data, i_rx_done);

        -- Stop writing and test reading
        i_enable <= '0';
        wait for 100 ns;
        
        -- Verify Address 1 
        i_rd_addr <= "000001";
        wait for 40 ns;
        
        -- Verify Address 2 
        i_rd_addr <= "000010";
        wait for 40 ns;

        wait;
    end process;
end Behavioral;