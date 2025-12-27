library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_tx is
    generic ( g_CLKS_PER_BIT : integer := 5208 );
    port (
        i_Clk : in std_logic; i_Rst_n : in std_logic; i_Start : in std_logic;
        o_Addr : out integer range 0 to 63; i_Data : in signed(7 downto 0);
        o_UART_TX : out std_logic; o_Done, o_Busy : out std_logic
    );
end uart_tx;

architecture Behavioral of uart_tx is
    type t_State is (s_IDLE, s_FETCH, s_START, s_DATA, s_STOP);
    signal r_SM : t_State := s_IDLE;
    signal r_Idx : integer range 0 to 64 := 0;
    signal r_Bit_Ctr, r_Bit_Idx : integer := 0;
    signal r_Buffer : std_logic_vector(7 downto 0);
begin
    o_Busy <= '0' when r_SM = s_IDLE else '1';
    process(i_Clk, i_Rst_n) begin
        if i_Rst_n = '0' then r_SM <= s_IDLE; o_UART_TX <= '1';
        elsif rising_edge(i_Clk) then
            o_Done <= '0';
            case r_SM is
                when s_IDLE => if i_Start = '1' then r_Idx <= 0; r_SM <= s_FETCH; end if;
                when s_FETCH => o_Addr <= r_Idx; r_SM <= s_START; r_Bit_Ctr <= 0;
                when s_START =>
                    r_Buffer <= std_logic_vector(i_Data); o_UART_TX <= '0';
                    if r_Bit_Ctr < g_CLKS_PER_BIT-1 then r_Bit_Ctr <= r_Bit_Ctr + 1;
                    else r_Bit_Ctr <= 0; r_SM <= s_DATA; r_Bit_Idx <= 0; end if;
                when s_DATA =>
                    o_UART_TX <= r_Buffer(r_Bit_Idx);
                    if r_Bit_Ctr < g_CLKS_PER_BIT-1 then r_Bit_Ctr <= r_Bit_Ctr + 1;
                    else r_Bit_Ctr <= 0; if r_Bit_Idx < 7 then r_Bit_Idx <= r_Bit_Idx + 1; else r_SM <= s_STOP; end if; end if;
                when s_STOP =>
                    o_UART_TX <= '1';
                    if r_Bit_Ctr < g_CLKS_PER_BIT-1 then r_Bit_Ctr <= r_Bit_Ctr + 1;
                    else if r_Idx < 63 then r_Idx <= r_Idx + 1; r_SM <= s_FETCH; else r_SM <= s_IDLE; o_Done <= '1'; end if; end if;
                when others => r_SM <= s_IDLE;
            end case;
        end if;
    end process;
end Behavioral;