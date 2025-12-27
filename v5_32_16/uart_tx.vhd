library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_tx is
    generic ( g_CLKS_PER_BIT : integer := 5208 );
    port (
        i_Clk : in std_logic; i_Rst_n : in std_logic; i_Start : in std_logic;
        o_Addr : out integer range 0 to 31;
        i_Data : in signed(15 downto 0);
        o_UART_TX, o_Done : out std_logic
    );
end uart_tx;

architecture Behavioral of uart_tx is
    type t_TX_State is (s_IDLE, s_LOAD, s_START_BIT, s_DATA_BITS, s_STOP_BIT, s_NEXT_BYTE);
    signal r_SM : t_TX_State := s_IDLE;
    signal r_Bit_Ctr : integer := 0;
    signal r_Bit_Idx : integer range 0 to 7 := 0;
    signal r_TX_Data : std_logic_vector(7 downto 0);
    signal r_Addr : integer range 0 to 31 := 0;
    signal r_Byte_Sel : std_logic := '0'; -- 0: Low, 1: High
begin
    process(i_Clk, i_Rst_n) begin
        if i_Rst_n = '0' then r_SM <= s_IDLE; o_UART_TX <= '1'; o_Done <= '0'; r_Addr <= 0;
        elsif rising_edge(i_Clk) then
            o_Done <= '0';
            case r_SM is
                when s_IDLE => if i_Start = '1' then r_Addr <= 0; r_Byte_Sel <= '0'; r_SM <= s_LOAD; end if;
                when s_LOAD =>
                    o_Addr <= r_Addr;
                    if r_Byte_Sel = '0' then r_TX_Data <= std_logic_vector(i_Data(7 downto 0)); -- Low [cite: 329]
                    else r_TX_Data <= std_logic_vector(i_Data(15 downto 8)); end if; -- High [cite: 330]
                    r_SM <= s_START_BIT;
                when s_START_BIT =>
                    o_UART_TX <= '0';
                    if r_Bit_Ctr < g_CLKS_PER_BIT-1 then r_Bit_Ctr <= r_Bit_Ctr + 1;
                    else r_Bit_Ctr <= 0; r_SM <= s_DATA_BITS; r_Bit_Idx <= 0; end if;
                when s_DATA_BITS =>
                    o_UART_TX <= r_TX_Data(r_Bit_Idx);
                    if r_Bit_Ctr < g_CLKS_PER_BIT-1 then r_Bit_Ctr <= r_Bit_Ctr + 1;
                    else r_Bit_Ctr <= 0;
                        if r_Bit_Idx < 7 then r_Bit_Idx <= r_Bit_Idx + 1; else r_SM <= s_STOP_BIT; end if;
                    end if;
                when s_STOP_BIT =>
                    o_UART_TX <= '1';
                    if r_Bit_Ctr < g_CLKS_PER_BIT-1 then r_Bit_Ctr <= r_Bit_Ctr + 1;
                    else r_Bit_Ctr <= 0; r_SM <= s_NEXT_BYTE; end if;
                when s_NEXT_BYTE =>
                    if r_Byte_Sel = '0' then r_Byte_Sel <= '1'; r_SM <= s_LOAD;
                    else
                        r_Byte_Sel <= '0';
                        if r_Addr < 31 then r_Addr <= r_Addr + 1; r_SM <= s_LOAD;
                        else o_Done <= '1'; r_SM <= s_IDLE; end if;
                    end if;
                when others => r_SM <= s_IDLE;
            end case;
        end if;
    end process;
end Behavioral;