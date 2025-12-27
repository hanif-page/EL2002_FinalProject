library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_rx is
    generic ( g_CLKS_PER_BIT : integer := 5208 );
    port (
        i_Clk, i_Rst_n, i_UART_RX : in std_logic; i_Clear_Sync : in std_logic;
        o_RX_Done : out std_logic; 
        o_RX_Byte : out std_logic_vector(15 downto 0) 
    );
end uart_rx;

architecture Behavioral of uart_rx is
    type t_RX_State is (s_IDLE, s_RX_WAIT_START, s_RX_DATABITS, s_RX_STOPBIT);
    signal r_SM : t_RX_State := s_IDLE;
    signal r_RX_Sync, r_RX_Data : std_logic := '1';
    signal r_Bit_Ctr : integer := 0;
    signal r_Bit_Idx : integer range 0 to 7 := 0;
    signal r_Byte_Reg : std_logic_vector(7 downto 0);
    signal r_LSB_Reg : std_logic_vector(7 downto 0) := (others => '0');
    signal r_Waiting_Byte : integer range 0 to 1 := 0; 
    constant C_TIMEOUT_VAL : integer := 1000000; -- Refactor: Idle Reset [cite: 221-222]
    signal r_Idle_Timer : integer range 0 to C_TIMEOUT_VAL := 0;
begin
    process(i_Clk, i_Rst_n) begin
        if i_Rst_n = '0' then r_SM <= s_IDLE; o_RX_Done <= '0'; r_Waiting_Byte <= 0;
        elsif rising_edge(i_Clk) then
            if i_Clear_Sync = '1' then
                r_Waiting_Byte <= 0;
            end if;

            r_RX_Sync <= i_UART_RX; r_RX_Data <= r_RX_Sync; o_RX_Done <= '0';
            case r_SM is
                when s_IDLE =>
                    if r_RX_Data = '0' then r_SM <= s_RX_WAIT_START; r_Idle_Timer <= 0;
                    else
                        -- Refactor: Sinkronisasi awal file .bin [cite: 228-229]
                        if r_Idle_Timer < C_TIMEOUT_VAL then r_Idle_Timer <= r_Idle_Timer + 1;
                        else r_Waiting_Byte <= 0; end if;
                    end if;
                when s_RX_WAIT_START =>
                    if r_Bit_Ctr = (g_CLKS_PER_BIT-1)/2 then
                        if r_RX_Data = '0' then r_Bit_Ctr <= 0; r_SM <= s_RX_DATABITS; r_Bit_Idx <= 0;
                        else r_SM <= s_IDLE; end if;
                    else r_Bit_Ctr <= r_Bit_Ctr + 1; end if;
                when s_RX_DATABITS =>
                    if r_Bit_Ctr < g_CLKS_PER_BIT-1 then r_Bit_Ctr <= r_Bit_Ctr + 1;
                    else
                        r_Bit_Ctr <= 0; r_Byte_Reg(r_Bit_Idx) <= r_RX_Data;
                        if r_Bit_Idx < 7 then r_Bit_Idx <= r_Bit_Idx + 1;
                        else r_SM <= s_RX_STOPBIT; end if;
                    end if;
                when s_RX_STOPBIT =>
                    if r_Bit_Ctr < (g_CLKS_PER_BIT/2) then r_Bit_Ctr <= r_Bit_Ctr + 1;
                    else
                        r_Bit_Ctr <= 0; r_SM <= s_IDLE;
                        -- Little Endian Assembly [cite: 237-240, 513-514]
                        if r_Waiting_Byte = 0 then
                            r_LSB_Reg <= r_Byte_Reg; r_Waiting_Byte <= 1;
                        else
                            o_RX_Byte <= r_Byte_Reg & r_LSB_Reg; o_RX_Done <= '1'; r_Waiting_Byte <= 0;
                        end if;
                    end if;
                when others => r_SM <= s_IDLE;
            end case;
        end if;
    end process;
end Behavioral;