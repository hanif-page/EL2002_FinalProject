library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.fft_pkg.all;

entity uart_fft_top is
    generic ( g_CLKS_PER_BIT : integer := 5208 );
    port (
        i_Clk, i_Rst_n, i_UART_RX : in std_logic;
        o_UART_TX, o_LED_Idle, o_LED_Busy : out std_logic
    );
end uart_fft_top;

architecture Structural of uart_fft_top is
    signal mem_Real, mem_Imag : t_Complex_Array := (others => (others => '0'));
    type t_Master_SM is (s_IDLE, s_RX, s_RX_SETTLE, s_FFT, s_MAG, s_TX);
    signal r_Master_SM : t_Master_SM := s_IDLE;
    signal rx_done, fft_start, fft_done, fft_we, mag_start, mag_done, mag_we, tx_start, tx_done : std_logic;
    signal rx_data : std_logic_vector(15 downto 0);
    signal fft_addr_a, fft_addr_b, mag_addr, tx_addr : integer range 0 to 31;
    signal fft_ore_a, fft_oim_a, fft_ore_b, fft_oim_b, mag_ore : signed(15 downto 0);
    signal rx_count : integer range 0 to 32 := 0;
    signal r_Settle_Timer : integer range 0 to 50000 := 0;
    signal uart_sync_reset : std_logic := '0';
begin
    o_LED_Idle <= '0' when r_Master_SM = s_IDLE or r_Master_SM = s_RX else '1';
    o_LED_Busy <= '0' when r_Master_SM /= s_IDLE and r_Master_SM /= s_RX else '1';

    u_rx : entity work.uart_rx generic map (g_CLKS_PER_BIT => g_CLKS_PER_BIT) port map (i_Clk, i_Rst_n, i_UART_RX, uart_sync_reset, rx_done, rx_data);
    u_fft : entity work.fft_engine port map (i_Clk, i_Rst_n, fft_start, fft_addr_a, fft_addr_b, mem_Real(fft_addr_a), mem_Imag(fft_addr_a), mem_Real(fft_addr_b), mem_Imag(fft_addr_b), fft_ore_a, fft_oim_a, fft_ore_b, fft_oim_b, fft_we, fft_done, open);
    u_mag : entity work.magnitude_unit port map (i_Clk, i_Rst_n, mag_start, mag_addr, mem_Real(mag_addr), mem_Imag(mag_addr), mag_ore, mag_we, mag_done, open);
    u_tx : entity work.uart_tx generic map (g_CLKS_PER_BIT => g_CLKS_PER_BIT) port map (i_Clk, i_Rst_n, tx_start, tx_addr, mem_Real(tx_addr), o_UART_TX, tx_done);

    process(i_Clk, i_Rst_n) begin
        if i_Rst_n = '0' then 
            r_Master_SM <= s_IDLE; 
            rx_count <= 0;
            uart_sync_reset <= '0';
        elsif rising_edge(i_Clk) then
            -- FIX: Reset trigger sinyal di setiap siklus (PENTING!)
            fft_start <= '0'; mag_start <= '0'; tx_start <= '0'; 
            uart_sync_reset <= '0';

            case r_Master_SM is
                when s_IDLE => 
                    rx_count <= 0;
                    uart_sync_reset <= '1'; 
                    r_Master_SM <= s_RX;
                when s_RX =>
                    if rx_done = '1' then
                        mem_Real(rx_count) <= signed(rx_data); mem_Imag(rx_count) <= (others => '0');
                        if rx_count < 31 then rx_count <= rx_count + 1; else r_Settle_Timer <= 0; r_Master_SM <= s_RX_SETTLE; end if;
                    end if;
                when s_RX_SETTLE =>
                    if r_Settle_Timer < 50000 then r_Settle_Timer <= r_Settle_Timer + 1; else fft_start <= '1'; r_Master_SM <= s_FFT; end if;
                when s_FFT =>
                    if fft_we = '1' then
                        mem_Real(fft_addr_a) <= fft_ore_a; mem_Imag(fft_addr_a) <= fft_oim_a;
                        mem_Real(fft_addr_b) <= fft_ore_b; mem_Imag(fft_addr_b) <= fft_oim_b;
                    end if;
                    if fft_done = '1' then mag_start <= '1'; r_Master_SM <= s_MAG; end if;
                when s_MAG =>
                    if mag_we = '1' then mem_Real(mag_addr) <= mag_ore; end if;
                    if mag_done = '1' then tx_start <= '1'; r_Master_SM <= s_TX; end if;
                when s_TX => if tx_done = '1' then r_Master_SM <= s_IDLE; end if;
                when others => r_Master_SM <= s_IDLE;
            end case;
        end if;
    end process;
end Structural;