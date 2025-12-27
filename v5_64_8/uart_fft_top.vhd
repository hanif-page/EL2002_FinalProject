library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.fft_pkg.all;

entity uart_fft_top is
    generic ( g_CLKS_PER_BIT : integer := 5208 ); -- [cite: 1]
    port (
        i_Clk, i_Rst_n, i_UART_RX : in std_logic; -- [cite: 2]
        o_UART_TX, o_LED_Idle, o_LED_Busy : out std_logic -- [cite: 2]
    );
end uart_fft_top;

architecture Structural of uart_fft_top is
    signal mem_Real, mem_Imag : t_Complex_Array; -- [cite: 3, 5]
    -- FSM dengan tambahan Jeda Pengaman
    type t_Master_SM is (s_IDLE, s_RX, s_RX_SETTLE, s_FFT, s_MAG, s_TX); -- [cite: 9]
    signal r_Master_SM : t_Master_SM := s_IDLE;
    
    signal rx_done : std_logic; signal rx_byte : std_logic_vector(7 downto 0);
    signal fft_start, fft_done, fft_we : std_logic;
    signal fft_addr_a, fft_addr_b : integer range 0 to 63;
    signal fft_ore_a, fft_oim_a, fft_ore_b, fft_oim_b : signed(7 downto 0);
    signal mag_start, mag_done, mag_we : std_logic;
    signal mag_addr : integer range 0 to 63; signal mag_ore : signed(7 downto 0);
    signal tx_start, tx_done : std_logic; signal tx_addr : integer range 0 to 63;
    signal rx_count : integer range 0 to 64 := 0; -- [cite: 13]
    signal r_Settle_Timer : integer range 0 to 50000 := 0;

begin
    -- LED Status -- [cite: 30-32]
    o_LED_Idle <= '0' when r_Master_SM = s_IDLE or r_Master_SM = s_RX else '1';
    o_LED_Busy <= '0' when r_Master_SM /= s_IDLE and r_Master_SM /= s_RX else '1';

    u_rx  : entity work.uart_rx port map(i_Clk, i_Rst_n, i_UART_RX, rx_done, rx_byte);
    u_fft : entity work.fft_engine port map(i_Clk, i_Rst_n, fft_start, fft_addr_a, fft_addr_b, 
            mem_Real(fft_addr_a), mem_Imag(fft_addr_a), mem_Real(fft_addr_b), mem_Imag(fft_addr_b), 
            fft_ore_a, fft_oim_a, fft_ore_b, fft_oim_b, fft_we, fft_done);
    u_mag : entity work.magnitude_unit port map(i_Clk, i_Rst_n, mag_start, mag_addr, 
            mem_Real(mag_addr), mem_Imag(mag_addr), mag_ore, mag_we, mag_done);
    u_tx  : entity work.uart_tx port map(i_Clk, i_Rst_n, tx_start, tx_addr, mem_Real(tx_addr), 
            o_UART_TX, tx_done);

    process(i_Clk, i_Rst_n) begin
        if i_Rst_n = '0' then r_Master_SM <= s_IDLE; -- [cite: 35]
        elsif rising_edge(i_Clk) then
            fft_start <= '0'; mag_start <= '0'; tx_start <= '0';
            case r_Master_SM is
                when s_IDLE => rx_count <= 0; r_Master_SM <= s_RX; -- [cite: 38]
                
                when s_RX =>
                    if rx_done = '1' then
                        mem_Real(rx_count) <= signed(rx_byte); -- [cite: 50]
                        mem_Imag(rx_count) <= (others => '0'); -- [cite: 51]
                        if rx_count < 63 then rx_count <= rx_count + 1; -- [cite: 51]
                        else r_Settle_Timer <= 0; r_Master_SM <= s_RX_SETTLE; end if; -- [cite: 52]
                    end if;

                when s_RX_SETTLE =>
                    -- Jeda pengaman untuk melepaskan port serial PC
                    if r_Settle_Timer < 50000 then r_Settle_Timer <= r_Settle_Timer + 1;
                    else fft_start <= '1'; r_Master_SM <= s_FFT; end if;

                when s_FFT =>
                    if fft_we = '1' then
                        mem_Real(fft_addr_a) <= fft_ore_a; mem_Imag(fft_addr_a) <= fft_oim_a; -- [cite: 74-75]
                        mem_Real(fft_addr_b) <= fft_ore_b; mem_Imag(fft_addr_b) <= fft_oim_b; -- [cite: 74-75]
                    end if;
                    if fft_done = '1' then mag_start <= '1'; r_Master_SM <= s_MAG; end if; -- [cite: 60]

                when s_MAG =>
                    if mag_we = '1' then mem_Real(mag_addr) <= mag_ore; end if; -- [cite: 87]
                    if mag_done = '1' then tx_start <= '1'; r_Master_SM <= s_TX; end if; -- [cite: 78]

                when s_TX => if tx_done = '1' then r_Master_SM <= s_IDLE; end if; -- [cite: 91]
            end case;
        end if;
    end process;
end Structural;