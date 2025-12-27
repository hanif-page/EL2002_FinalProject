library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_fft_sys is
    generic (
        g_CLKS_PER_BIT : integer := 5208; -- 9600 Baud
        data_width     : integer := 16;
        points         : integer := 32
    );
    port (
        i_Clk       : in  std_logic;
        i_Rst_n     : in  std_logic;
        i_UART_RX   : in  std_logic;
        o_UART_TX   : out std_logic;
        o_LED_Idle  : out std_logic; 
        o_LED_Busy  : out std_logic
    );
end uart_fft_sys;

architecture Behavioral of uart_fft_sys is

    type t_Complex_Array is array (0 to points-1) of signed(data_width-1 downto 0);
    type t_Twiddle_Array is array (0 to points/2 - 1) of signed(data_width-1 downto 0);

    signal mem_Real : t_Complex_Array;
    signal mem_Imag : t_Complex_Array;

    constant TWIDDLE_COS : t_Twiddle_Array := (
        to_signed(256, 16), to_signed(251, 16), to_signed(236, 16), to_signed(212, 16),
        to_signed(181, 16), to_signed(142, 16), to_signed(97, 16),  to_signed(49, 16),
        to_signed(0, 16),   to_signed(-49, 16), to_signed(-97, 16), to_signed(-142, 16),
        to_signed(-181, 16),to_signed(-212, 16),to_signed(-236, 16),to_signed(-251, 16)
    );
    
    constant TWIDDLE_SIN : t_Twiddle_Array := (
        to_signed(0, 16),   to_signed(-50, 16), to_signed(-98, 16), to_signed(-142, 16),
        to_signed(-181, 16),to_signed(-212, 16),to_signed(-236, 16),to_signed(-251, 16),
        to_signed(-256, 16),to_signed(-251, 16),to_signed(-236, 16),to_signed(-212, 16),
        to_signed(-181, 16),to_signed(-142, 16),to_signed(-98, 16), to_signed(-50, 16)
    );

    type t_Main_SM is (
        s_IDLE, 
        s_RX_WAIT_START, s_RX_DATABITS, s_RX_STOPBIT,
        s_BIT_REV_START, s_BIT_REV_PROCESS,
        s_FFT_STAGE, s_FFT_GROUP, s_FFT_BUTTERFLY, 
        s_CALC_READ, s_CALC_EXEC, s_CALC_WRITE,
        s_MAG_PREP, s_MAG_ITER,
        s_TX_NEXT_BYTE, s_TX_STARTBIT, s_TX_DATABITS, s_TX_STOPBIT
    );
    signal r_SM : t_Main_SM := s_IDLE;

    signal r_Bit_Ctr : integer range 0 to g_CLKS_PER_BIT*2 := 0; 
    signal r_Bit_Idx : integer range 0 to 9 := 0; 
    signal r_RX_Data : std_logic := '1';
    signal r_RX_Sync : std_logic := '1';
    signal r_RX_Byte : std_logic_vector(7 downto 0);
    signal r_RX_State  : integer range 0 to 2 := 0;
    signal r_TX_Active : std_logic := '0';

    -- [FIX 1] Range diperbesar ke 'points' (32)
    signal r_Point_Idx : integer range 0 to points := 0; 
    
    -- [FIX 2] Range diperbesar ke 7 (Agar bisa menampung increment akhir)
    signal r_Stage     : integer range 1 to 7 := 1; 
    
    -- [FIX 3] Range diperbesar ke 64 (Agar bisa menampung 32*2)
    -- Init diubah ke 1 (Untuk memulai Stage 1 dengan benar)
    signal r_DFT_Size  : integer range 0 to 64 := 1; 
    
    signal r_Group     : integer range 0 to 32 := 0; 
    signal r_Butterfly : integer range 0 to 16 := 0; 
    
    signal r_Ar, r_Ai, r_Br, r_Bi : signed(15 downto 0);
    signal r_Wr, r_Wi             : signed(15 downto 0);
    signal r_New_Ar, r_New_Ai     : signed(15 downto 0);
    signal r_New_Br, r_New_Bi     : signed(15 downto 0);
    
    signal w_Idx_A, w_Idx_B : integer range 0 to points-1;
    signal r_TX_Buffer      : std_logic_vector(7 downto 0);

    signal r_Sqrt_Op   : unsigned(31 downto 0);
    signal r_Sqrt_Rem  : unsigned(17 downto 0);
    signal r_Sqrt_Root : unsigned(15 downto 0);
    signal r_Sqrt_Iter : integer range 0 to 17 := 0;

    function reverse_bits(n : integer) return integer is
        variable v_in  : unsigned(4 downto 0);
        variable v_out : unsigned(4 downto 0);
    begin
        v_in := to_unsigned(n, 5);
        v_out(0) := v_in(4); v_out(1) := v_in(3); v_out(2) := v_in(2);
        v_out(3) := v_in(1); v_out(4) := v_in(0);
        return to_integer(v_out);
    end function;

begin

    o_LED_Idle <= '0' when (r_SM = s_RX_WAIT_START or r_SM = s_RX_DATABITS or r_SM = s_RX_STOPBIT) else '1';
    
    o_LED_Busy <= '0' when (r_SM = s_BIT_REV_START or r_SM = s_BIT_REV_PROCESS or 
                            r_SM = s_FFT_STAGE or r_SM = s_FFT_GROUP or r_SM = s_FFT_BUTTERFLY or 
                            r_SM = s_CALC_READ or r_SM = s_CALC_EXEC or r_SM = s_CALC_WRITE or
                            r_SM = s_MAG_PREP or r_SM = s_MAG_ITER or
                            r_SM = s_TX_NEXT_BYTE or r_SM = s_TX_STARTBIT or r_SM = s_TX_DATABITS or r_SM = s_TX_STOPBIT) 
                  else '1';

    process(i_Clk, i_Rst_n)
        variable v_Mult_R, v_Mult_I : signed(31 downto 0);
        variable v_Temp_TR, v_Temp_TI : signed(15 downto 0);
        variable v_test_sub : unsigned(17 downto 0);
    begin
        if i_Rst_n = '0' then 
            r_SM <= s_IDLE;
            o_UART_TX <= '1';
            r_Point_Idx <= 0;
            r_Bit_Ctr <= 0;
            r_Bit_Idx <= 0;
            r_RX_State <= 0;
            
        elsif rising_edge(i_Clk) then
            
            r_RX_Sync <= i_UART_RX;
            r_RX_Data <= r_RX_Sync;

            case r_SM is
                
                when s_IDLE =>
                    r_Point_Idx <= 0;
                    r_RX_State <= 0;
                    if r_RX_Data = '0' then 
                        r_SM <= s_RX_WAIT_START;
                        r_Bit_Ctr <= 0;
                    end if;

                -- ================= RX =================
                when s_RX_WAIT_START =>
                    if r_Bit_Ctr = (g_CLKS_PER_BIT-1)/2 then
                        r_Bit_Ctr <= 0;
                        if r_RX_Data = '0' then
                            r_SM <= s_RX_DATABITS;
                            r_Bit_Idx <= 0;
                        else
                            r_SM <= s_IDLE;
                        end if;
                    else
                        r_Bit_Ctr <= r_Bit_Ctr + 1;
                    end if;

                when s_RX_DATABITS =>
                    if r_Bit_Ctr < g_CLKS_PER_BIT-1 then
                        r_Bit_Ctr <= r_Bit_Ctr + 1;
                    else
                        r_Bit_Ctr <= 0;
                        r_RX_Byte(r_Bit_Idx) <= r_RX_Data;
                        if r_Bit_Idx < 7 then
                            r_Bit_Idx <= r_Bit_Idx + 1;
                        else
                            r_SM <= s_RX_STOPBIT;
                        end if;
                    end if;

                when s_RX_STOPBIT =>
                    if r_Bit_Ctr < (g_CLKS_PER_BIT/2) then
                        r_Bit_Ctr <= r_Bit_Ctr + 1;
                    else
                        r_Bit_Ctr <= 0;
                        
                        if r_RX_State = 0 then
                            mem_Real(r_Point_Idx)(7 downto 0) <= signed(r_RX_Byte);
                            r_RX_State <= 1; 
                            r_SM <= s_RX_WAIT_START; 
                            
                        else
                            mem_Real(r_Point_Idx)(15 downto 8) <= signed(r_RX_Byte);
                            mem_Imag(r_Point_Idx) <= (others => '0'); 
                            r_RX_State <= 0; 
                            
                            if r_Point_Idx < points-1 then
                                r_Point_Idx <= r_Point_Idx + 1;
                                r_SM <= s_RX_WAIT_START; 
                            else
                                r_SM <= s_BIT_REV_START; 
                            end if;
                        end if;
                    end if;

                -- ================= BIT REVERSAL =================
                when s_BIT_REV_START =>
                   r_Point_Idx <= 0;
                   r_SM <= s_BIT_REV_PROCESS;

                when s_BIT_REV_PROCESS =>
                   if r_Point_Idx < points then
                       if r_Point_Idx < reverse_bits(r_Point_Idx) then
                           mem_Real(r_Point_Idx) <= mem_Real(reverse_bits(r_Point_Idx));
                           mem_Real(reverse_bits(r_Point_Idx)) <= mem_Real(r_Point_Idx);
                       end if;
                       r_Point_Idx <= r_Point_Idx + 1;
                   else
                       r_Stage <= 1;
                       r_DFT_Size <= 1; -- Init 1, nanti di stage pertama dikali 2
                       r_SM <= s_FFT_STAGE; -- FIXED: Ke Stage dulu baru Group
                   end if;

                -- ================= FFT STAGES =================
                when s_FFT_STAGE =>
                    r_DFT_Size <= r_DFT_Size * 2;
                    r_Stage <= r_Stage + 1;
                    
                    if r_Stage > 5 then 
                        r_Point_Idx <= 0;
                        r_SM <= s_MAG_PREP;
                    else
                        r_SM <= s_FFT_GROUP;
                    end if;

                when s_FFT_GROUP =>
                    r_Group <= 0;
                    r_SM <= s_FFT_BUTTERFLY;

                when s_FFT_BUTTERFLY =>
                    if r_Group < points then
                        r_Butterfly <= 0;
                        r_SM <= s_CALC_READ; 
                    else
                        r_SM <= s_FFT_STAGE; 
                    end if;

                when s_CALC_READ =>
                    if r_Butterfly < r_DFT_Size / 2 then
                        w_Idx_A <= r_Group + r_Butterfly;
                        w_Idx_B <= r_Group + r_Butterfly + (r_DFT_Size / 2);
                        
                        r_Ar <= mem_Real(r_Group + r_Butterfly);
                        r_Ai <= mem_Imag(r_Group + r_Butterfly);
                        r_Br <= mem_Real(r_Group + r_Butterfly + (r_DFT_Size/2));
                        r_Bi <= mem_Imag(r_Group + r_Butterfly + (r_DFT_Size/2));
                        
                        r_Wr <= TWIDDLE_COS(r_Butterfly * (points / r_DFT_Size));
                        r_Wi <= TWIDDLE_SIN(r_Butterfly * (points / r_DFT_Size));
                        
                        r_SM <= s_CALC_EXEC;
                    else
                        r_Group <= r_Group + r_DFT_Size;
                        r_SM <= s_FFT_BUTTERFLY; 
                    end if;

                when s_CALC_EXEC =>
                    v_Mult_R := (r_Br * r_Wr) - (r_Bi * r_Wi); 
                    v_Mult_I := (r_Br * r_Wi) + (r_Bi * r_Wr);
                    
                    v_Temp_TR := resize(shift_right(v_Mult_R, 8), 16);
                    v_Temp_TI := resize(shift_right(v_Mult_I, 8), 16);

                    r_New_Ar <= shift_right(r_Ar + v_Temp_TR, 1);
                    r_New_Ai <= shift_right(r_Ai + v_Temp_TI, 1);
                    
                    r_New_Br <= shift_right(r_Ar - v_Temp_TR, 1);
                    r_New_Bi <= shift_right(r_Ai - v_Temp_TI, 1);
                    
                    r_SM <= s_CALC_WRITE;

                when s_CALC_WRITE =>
                    mem_Real(w_Idx_A) <= r_New_Ar;
                    mem_Imag(w_Idx_A) <= r_New_Ai;
                    mem_Real(w_Idx_B) <= r_New_Br;
                    mem_Imag(w_Idx_B) <= r_New_Bi;
                    
                    r_Butterfly <= r_Butterfly + 1;
                    r_SM <= s_CALC_READ; 

                -- ================= MAGNITUDE =================
                when s_MAG_PREP =>
                    if r_Point_Idx < points then
                        r_Ar <= mem_Real(r_Point_Idx);
                        r_Ai <= mem_Imag(r_Point_Idx);
                        r_SM <= s_MAG_ITER;
                        r_Sqrt_Iter <= 0;
                    else
                        r_Point_Idx <= 0;
                        r_TX_Active <= '1';
                        r_SM        <= s_TX_NEXT_BYTE;
                    end if;

                when s_MAG_ITER =>
                    if r_Sqrt_Iter = 0 then
                        r_Sqrt_Op   <= unsigned(abs(r_Ar)*abs(r_Ar) + abs(r_Ai)*abs(r_Ai));
                        r_Sqrt_Rem  <= (others => '0');
                        r_Sqrt_Root <= (others => '0');
                        r_Sqrt_Iter <= 1;
                    elsif r_Sqrt_Iter <= 16 then
                        v_test_sub := resize((r_Sqrt_Root(14 downto 0) & '0'), 18) or to_unsigned(1, 18);
                        
                        if (r_Sqrt_Rem(15 downto 0) & r_Sqrt_Op(31 downto 30)) >= v_test_sub then
                            r_Sqrt_Rem  <= (r_Sqrt_Rem(15 downto 0) & r_Sqrt_Op(31 downto 30)) - v_test_sub;
                            r_Sqrt_Root <= (r_Sqrt_Root(14 downto 0) & '1');
                        else
                            r_Sqrt_Rem  <= (r_Sqrt_Rem(15 downto 0) & r_Sqrt_Op(31 downto 30));
                            r_Sqrt_Root <= (r_Sqrt_Root(14 downto 0) & '0');
                        end if;
                        
                        r_Sqrt_Op   <= r_Sqrt_Op(29 downto 0) & "00";
                        r_Sqrt_Iter <= r_Sqrt_Iter + 1;
                    else
                        mem_Real(r_Point_Idx) <= signed(r_Sqrt_Root);
                        r_Point_Idx <= r_Point_Idx + 1;
                        r_SM <= s_MAG_PREP;
                    end if;

                -- ================= TX =================
                when s_TX_NEXT_BYTE =>
                    if r_Point_Idx < points then
                        if r_TX_Active = '1' then
                            r_TX_Buffer <= std_logic_vector(mem_Real(r_Point_Idx)(7 downto 0));
                        else
                            r_TX_Buffer <= std_logic_vector(mem_Real(r_Point_Idx)(15 downto 8));
                        end if;
                        r_SM <= s_TX_STARTBIT;
                        r_Bit_Ctr <= 0;
                    else
                        r_SM <= s_IDLE;
                    end if;

                when s_TX_STARTBIT =>
                    o_UART_TX <= '0';
                    if r_Bit_Ctr < g_CLKS_PER_BIT-1 then
                        r_Bit_Ctr <= r_Bit_Ctr + 1;
                    else
                        r_Bit_Ctr <= 0;
                        r_SM <= s_TX_DATABITS;
                        r_Bit_Idx <= 0;
                    end if;

                when s_TX_DATABITS =>
                    o_UART_TX <= r_TX_Buffer(r_Bit_Idx);
                    if r_Bit_Ctr < g_CLKS_PER_BIT-1 then
                        r_Bit_Ctr <= r_Bit_Ctr + 1;
                    else
                        r_Bit_Ctr <= 0;
                        if r_Bit_Idx < 7 then
                            r_Bit_Idx <= r_Bit_Idx + 1;
                        else
                            r_SM <= s_TX_STOPBIT;
                        end if;
                    end if;

                when s_TX_STOPBIT =>
                    o_UART_TX <= '1';
                    if r_Bit_Ctr < g_CLKS_PER_BIT-1 then
                        r_Bit_Ctr <= r_Bit_Ctr + 1;
                    else
                        r_Bit_Ctr <= 0;
                        if r_TX_Active = '1' then
                            r_TX_Active <= '0';
                            r_SM <= s_TX_NEXT_BYTE;
                        else
                            r_TX_Active <= '1';
                            r_Point_Idx <= r_Point_Idx + 1;
                            r_SM <= s_TX_NEXT_BYTE;
                        end if;
                    end if;

                when others =>
                    r_SM <= s_IDLE;

            end case;
            
            -- Override untuk Logic Wait Start Bit
            if r_SM = s_RX_WAIT_START then
                 if r_RX_Data = '1' then
                     r_Bit_Ctr <= 0; 
                 end if;
            end if;

        end if;
    end process;
    
end Behavioral;