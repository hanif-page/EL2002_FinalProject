library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.fft_pkg.all;

entity magnitude_unit is
    port (
        i_Clk : in std_logic; i_Rst_n : in std_logic; i_Start : in std_logic;
        o_Addr : out integer range 0 to 63; i_Re, i_Im : in signed(7 downto 0);
        o_Re : out signed(7 downto 0); o_WE : out std_logic; o_Done, o_Busy : out std_logic
    );
end magnitude_unit;

architecture Behavioral of magnitude_unit is
    type t_State is (s_IDLE, s_READ, s_CALC, s_WRITE, s_DONE);
    signal r_SM : t_State := s_IDLE;
    signal r_Idx : integer range 0 to 64 := 0;
    signal r_Sqrt_Op, r_Sqrt_Rem : unsigned(15 downto 0);
    signal r_Sqrt_Root : unsigned(7 downto 0);
    signal r_Iter : integer := 0;
begin
    o_Busy <= '0' when r_SM = s_IDLE else '1';
    process(i_Clk, i_Rst_n)
        variable v_sub : unsigned(15 downto 0);
    begin
        if i_Rst_n = '0' then r_SM <= s_IDLE; o_WE <= '0';
        elsif rising_edge(i_Clk) then
            o_WE <= '0'; o_Done <= '0';
            case r_SM is
                when s_IDLE => if i_Start = '1' then r_Idx <= 0; r_SM <= s_READ; end if;
                when s_READ => o_Addr <= r_Idx; r_SM <= s_CALC; r_Iter <= 0;
                when s_CALC =>
                    if r_Iter = 0 then
                        r_Sqrt_Op <= resize(unsigned(abs(resize(i_Re, 16)*resize(i_Re, 16)) + abs(resize(i_Im, 16)*resize(i_Im, 16))), 16);
                        r_Sqrt_Rem <= (others => '0'); r_Sqrt_Root <= (others => '0'); r_Iter <= 1;
                    elsif r_Iter <= 8 then
                        v_sub := resize((r_Sqrt_Root(6 downto 0) & '0'), 16) or to_unsigned(1, 16);
                        if (r_Sqrt_Rem(13 downto 0) & r_Sqrt_Op(15 downto 14)) >= v_sub then
                            r_Sqrt_Rem <= (r_Sqrt_Rem(13 downto 0) & r_Sqrt_Op(15 downto 14)) - v_sub;
                            r_Sqrt_Root <= (r_Sqrt_Root(6 downto 0) & '1');
                        else
                            r_Sqrt_Rem <= (r_Sqrt_Rem(13 downto 0) & r_Sqrt_Op(15 downto 14));
                            r_Sqrt_Root <= (r_Sqrt_Root(6 downto 0) & '0');
                        end if;
                        r_Sqrt_Op <= r_Sqrt_Op(13 downto 0) & "00"; r_Iter <= r_Iter + 1;
                    else r_SM <= s_WRITE; end if;
                when s_WRITE =>
                    o_Addr <= r_Idx; o_Re <= signed(r_Sqrt_Root); o_WE <= '1';
                    if r_Idx < 63 then r_Idx <= r_Idx + 1; r_SM <= s_READ; else r_SM <= s_DONE; end if;
                when s_DONE => o_Done <= '1'; r_SM <= s_IDLE;
                when others => r_SM <= s_IDLE;
            end case;
        end if;
    end process;
end Behavioral;