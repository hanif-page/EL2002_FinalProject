library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.fft_pkg.all;

entity fft_engine is
    port (
        i_Clk        : in  std_logic;
        i_Rst_n      : in  std_logic;
        i_Start      : in  std_logic;
        -- Interface Bus Memori
        o_Addr_A     : out integer range 0 to 63;
        o_Addr_B     : out integer range 0 to 63;
        i_Re_A       : in  signed(7 downto 0);
        i_Im_A       : in  signed(7 downto 0);
        i_Re_B       : in  signed(7 downto 0);
        i_Im_B       : in  signed(7 downto 0);
        o_Re_A       : out signed(7 downto 0);
        o_Im_A       : out signed(7 downto 0);
        o_Re_B       : out signed(7 downto 0);
        o_Im_B       : out signed(7 downto 0);
        o_WE         : out std_logic;
        o_Done       : out std_logic;
        o_Busy       : out std_logic
    );
end fft_engine;

architecture Behavioral of fft_engine is
    type t_State is (s_IDLE, s_BIT_REV_START, s_BIT_REV_PROC, s_STAGE, s_GROUP, s_BUTTERFLY, s_READ, s_WAIT, s_EXEC, s_WRITE, s_DONE);
    signal r_SM : t_State := s_IDLE;

    signal r_Point_Idx  : integer range 0 to 64 := 0;
    signal r_Stage      : integer range 1 to 7 := 1;
    signal r_Group      : integer range 0 to 64 := 0;
    signal r_Butterfly  : integer range 0 to 32 := 0;
    signal r_DFT_Size   : integer range 0 to 64 := 1;

    signal r_Ar, r_Ai, r_Br, r_Bi : signed(7 downto 0);
    signal r_Wr, r_Wi             : signed(7 downto 0);

    function reverse_bits(n : integer) return integer is
        variable v_in, v_out : unsigned(5 downto 0);
    begin
        v_in := to_unsigned(n, 6); -- [cite: 28]
        v_out(0) := v_in(5); v_out(1) := v_in(4); v_out(2) := v_in(3); -- [cite: 29]
        v_out(3) := v_in(2); v_out(4) := v_in(1); v_out(5) := v_in(0); -- [cite: 29]
        return to_integer(v_out); -- [cite: 29]
    end function;

begin
    o_Busy <= '0' when r_SM = s_IDLE else '1';

    process(i_Clk, i_Rst_n)
        variable v_Mult_R, v_Mult_I : signed(15 downto 0); -- [cite: 33]
        variable v_TR, v_TI : signed(7 downto 0); -- [cite: 34]
    begin
        if i_Rst_n = '0' then 
            r_SM <= s_IDLE; o_WE <= '0'; o_Done <= '0';
        elsif rising_edge(i_Clk) then
            o_WE <= '0'; o_Done <= '0';

            case r_SM is
                when s_IDLE =>
                    if i_Start = '1' then r_SM <= s_BIT_REV_START; end if;

                -- BIT REVERSAL PROCESS -- [cite: 55-56]
                when s_BIT_REV_START =>
                    r_Point_Idx <= 0;
                    r_SM <= s_BIT_REV_PROC;

                when s_BIT_REV_PROC =>
                    if r_Point_Idx < 64 then
                        if r_Point_Idx < reverse_bits(r_Point_Idx) then
                            o_Addr_A <= r_Point_Idx;
                            o_Addr_B <= reverse_bits(r_Point_Idx);
                            r_SM <= s_WAIT; -- Tunggu latensi memori
                        else
                            r_Point_Idx <= r_Point_Idx + 1;
                        end if;
                    else
                        r_Stage <= 1; r_DFT_Size <= 1; r_SM <= s_STAGE; -- [cite: 57-58]
                    end if;

                when s_STAGE =>
                    r_DFT_Size <= r_DFT_Size * 2; -- [cite: 58]
                    r_Stage <= r_Stage + 1; -- [cite: 59]
                    if r_Stage > 6 then r_SM <= s_DONE; else r_SM <= s_GROUP; end if; -- [cite: 59]

                when s_GROUP =>
                    r_Group <= 0; r_SM <= s_BUTTERFLY; -- [cite: 61-62]

                when s_BUTTERFLY =>
                    if r_Group < 64 then r_Butterfly <= 0; r_SM <= s_READ; -- [cite: 62-63]
                    else r_SM <= s_STAGE; end if; -- [cite: 63]

                when s_READ =>
                    o_Addr_A <= r_Group + r_Butterfly; -- [cite: 64]
                    o_Addr_B <= r_Group + r_Butterfly + (r_DFT_Size/2); -- [cite: 65]
                    r_SM <= s_WAIT;

                when s_WAIT =>
                    if r_Point_Idx < 64 and r_Stage = 1 then -- Swap Mode
                        o_Addr_A <= r_Point_Idx; o_Addr_B <= reverse_bits(r_Point_Idx);
                        o_Re_A <= i_Re_B; o_Im_A <= i_Im_B; -- [cite: 55-56]
                        o_Re_B <= i_Re_A; o_Im_B <= i_Im_A; -- [cite: 55-56]
                        o_WE <= '1'; r_Point_Idx <= r_Point_Idx + 1; r_SM <= s_BIT_REV_PROC;
                    else -- Butterfly Mode
                        r_Ar <= i_Re_A; r_Ai <= i_Im_A; -- [cite: 65]
                        r_Br <= i_Re_B; r_Bi <= i_Im_B; -- [cite: 66]
                        r_Wr <= TWIDDLE_COS(r_Butterfly * (64 / r_DFT_Size)); -- [cite: 67]
                        r_Wi <= TWIDDLE_SIN(r_Butterfly * (64 / r_DFT_Size)); -- [cite: 67]
                        r_SM <= s_EXEC;
                    end if;

                when s_EXEC =>
                    v_Mult_R := (r_Br * r_Wr) - (r_Bi * r_Wi); -- [cite: 69]
                    v_Mult_I := (r_Br * r_Wi) + (r_Bi * r_Wr); -- [cite: 70]
                    v_TR := resize(shift_right(v_Mult_R, 7), 8); -- [cite: 71]
                    v_TI := resize(shift_right(v_Mult_I, 7), 8); -- [cite: 71]
                    o_Addr_A <= r_Group + r_Butterfly;
                    o_Addr_B <= r_Group + r_Butterfly + (r_DFT_Size/2);
                    -- SCALING SESUAI REFERENSI -- [cite: 72-73]
                    o_Re_A <= resize(shift_right(resize(r_Ar, 9) + resize(v_TR, 9), 1), 8);
                    o_Im_A <= resize(shift_right(resize(r_Ai, 9) + resize(v_TI, 9), 1), 8);
                    o_Re_B <= resize(shift_right(resize(r_Ar, 9) - resize(v_TR, 9), 1), 8);
                    o_Im_B <= resize(shift_right(resize(r_Ai, 9) - resize(v_TI, 9), 1), 8);
                    o_WE <= '1';
                    r_SM <= s_WRITE;

                when s_WRITE =>
                    if r_Butterfly < (r_DFT_Size/2) - 1 then
                        r_Butterfly <= r_Butterfly + 1; r_SM <= s_READ; -- [cite: 75]
                    else
                        r_Group <= r_Group + r_DFT_Size; r_SM <= s_BUTTERFLY; -- [cite: 68-69]
                    end if;

                when s_DONE => o_Done <= '1'; r_SM <= s_IDLE;
                when others => r_SM <= s_IDLE;
            end case;
        end if;
    end process;
end Behavioral;