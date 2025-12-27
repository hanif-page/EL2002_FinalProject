library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_fft_sys is
    generic (
        g_CLKS_PER_BIT : integer := 5208; -- 9600 Baud
        data_width     : integer := 16;   -- 16 BIT
        points         : integer := 32    -- 32 POINT
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
    -- Twiddle Array Size = Points/2 = 16
    type t_Twiddle_Array is array (0 to 15) of signed(data_width-1 downto 0);

    signal mem_Real : t_Complex_Array;
    signal mem_Imag : t_Complex_Array;

    -- TWIDDLE 32 POINT (16-BIT, Scale 32767)
    -- Presisi Tinggi Q0.15
    constant TWIDDLE_COS : t_Twiddle_Array := (
        to_signed(32767, 16), to_signed(32137, 16), to_signed(30272, 16), to_signed(27244, 16),
        to_signed(23169, 16), to_signed(18204, 16), to_signed(12539, 16), to_signed(6392, 16),
        to_signed(0, 16),     to_signed(-6393, 16), to_signed(-12540,16), to_signed(-18205,16),
        to_signed(-23170,16), to_signed(-27245,16), to_signed(-30273,16), to_signed(-32138,16)
    );
    
    constant TWIDDLE_SIN : t_Twiddle_Array := (
        to_signed(0, 16),     to_signed(-6393, 16), to_signed(-12540,16), to_signed(-18205,16),
        to_signed(-23170,16), to_signed(-27245,16), to_signed(-30273,16), to_signed(-32138,16),
        to_signed(-32767,16), to_signed(-32138,16), to_signed(-30273,16), to_signed(-27245,16),
        to_signed(-23170,16), to_signed(-18205,16), to_signed(-12540,16), to_signed(-6393, 16)
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
    
    -- RX State Machine untuk 16-bit (0: Low Byte, 1: High Byte)
    signal r_RX_State : integer range 0 to 1 := 0; 
    
    -- TX State Machine untuk 16-bit (0: Low Byte, 1: High Byte)
    signal r_TX_State : integer range 0 to 1 := 0;

    signal r_Point_Idx : integer range 0 to points := 0; 
    signal r_Stage     : integer range 1 to 6 := 1; -- 32 Point = 5 Stages (Log2 32 = 5)
    signal r_Group     : integer range 0 to 32 := 0; 
    signal r_Butterfly : integer range 0 to 16 := 0; 
    signal r_DFT_Size  : integer range 0 to 32 := 1; 
    
    -- Math Buffers (16-bit)
    signal r_Ar, r_Ai, r_Br, r_Bi : signed(15 downto 0);
    signal r_Wr, r_Wi             : signed(15 downto 0);
    signal r_New_Ar, r_New_Ai     : signed(15 downto 0);
    signal r_New_Br, r_New_Bi     : signed(15 downto 0);
    
    signal w_Idx_A, w_Idx_B : integer range 0 to points-1;
    signal r_TX_Buffer      : std_logic_vector(7 downto 0);

    -- Sqrt Variables (32-bit intermediate for 16-bit result)
    signal r_Sqrt_Op   : unsigned(31 downto 0); 
    signal r_Sqrt_Rem  : unsigned(31 downto 0); 
    signal r_Sqrt_Root : unsigned(15 downto 0);  
    signal r_Sqrt_Iter : integer range 0 to 17 := 0;

    -- Bit Reversal 5-bit (32 Points)
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
        variable v_Mult_R, v_Mult_I : signed(31 downto 0); -- 16x16 = 32 bit
        variable v_Temp_TR, v_Temp_TI : signed(15 downto 0);
        variable v_test_sub : unsigned(31 downto 0);
    begin
        if i_Rst_n = '0' then 
            r_SM <= s_IDLE;
            o_UART_TX <= '1';
            r_Point_Idx <= 0;
            r_Bit_Ctr <= 0;
            r_Bit_Idx <= 0;
            r_RX_State <= 0;
            r_TX_State <= 0;
            
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

                -- ================= RX (Terima 64 Byte untuk 32 Point 16-bit) =================
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
                        
                        -- LOGIKA GABUNG BYTE (Little Endian: Low dulu, baru High)
                        if r_RX_State = 0 then
                            -- Terima Low Byte
                            mem_Real(r_Point_Idx)(7 downto 0) <= signed(r_RX_Byte);
                            r_RX_State <= 1;
                            r_SM <= s_RX_WAIT_START; -- Tunggu byte kedua
                        else
                            -- Terima High Byte
                            mem_Real(r_Point_Idx)(15 downto 8) <= signed(r_RX_Byte);
                            mem_Imag(r_Point_Idx) <= (others => '0');
                            r_RX_State <= 0;
                            
                            if r_Point_Idx < points-1 then
                                r_Point_Idx <= r_Point_Idx + 1;
                                r_SM <= s_RX_WAIT_START; 
                            else
                                r_SM <= s_BIT_REV_START; -- Selesai Terima Semua Point
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
                       r_DFT_Size <= 1; 
                       r_SM <= s_FFT_STAGE; 
                   end if;

                -- ================= FFT STAGES (5 Stage untuk 32 Point) =================
                when s_FFT_STAGE =>
                    r_DFT_Size <= r_DFT_Size * 2;
                    r_Stage <= r_Stage + 1;
                    
                    if r_Stage > 5 then -- Log2(32) = 5
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
                    -- 1. Perkalian (32-bit result)
                    v_Mult_R := (r_Br * r_Wr) - (r_Bi * r_Wi); 
                    v_Mult_I := (r_Br * r_Wi) + (r_Bi * r_Wr);
                    
                    -- 2. Scaling Twiddle (Shift 15 karena skala 32767)
                    v_Temp_TR := resize(shift_right(v_Mult_R, 15), 16);
                    v_Temp_TI := resize(shift_right(v_Mult_I, 15), 16);

                    -- 3. Butterfly Add/Sub dengan Overflow Protection (Resize ke 17-bit)
                    r_New_Ar <= resize(shift_right(resize(r_Ar, 17) + resize(v_Temp_TR, 17), 1), 16);
                    r_New_Ai <= resize(shift_right(resize(r_Ai, 17) + resize(v_Temp_TI, 17), 1), 16);
                    
                    r_New_Br <= resize(shift_right(resize(r_Ar, 17) - resize(v_Temp_TR, 17), 1), 16);
                    r_New_Bi <= resize(shift_right(resize(r_Ai, 17) - resize(v_Temp_TI, 17), 1), 16);
                    
                    r_SM <= s_CALC_WRITE;

                when s_CALC_WRITE =>
                    mem_Real(w_Idx_A) <= r_New_Ar;
                    mem_Imag(w_Idx_A) <= r_New_Ai;
                    mem_Real(w_Idx_B) <= r_New_Br;
                    mem_Imag(w_Idx_B) <= r_New_Bi;
                    
                    r_Butterfly <= r_Butterfly + 1;
                    r_SM <= s_CALC_READ; 

                -- ================= MAGNITUDE (16-Bit Sqrt) =================
                when s_MAG_PREP =>
                    if r_Point_Idx < points then
                        r_Ar <= mem_Real(r_Point_Idx);
                        r_Ai <= mem_Imag(r_Point_Idx);
                        r_SM <= s_MAG_ITER;
                        r_Sqrt_Iter <= 0;
                    else
                        r_Point_Idx <= 0;
                        r_TX_State  <= 0;
                        r_SM        <= s_TX_NEXT_BYTE;
                    end if;

                when s_MAG_ITER =>
                    if r_Sqrt_Iter = 0 then
                        -- Jumlah Kuadrat bisa 32-bit (32767^2 + 32767^2)
								r_Sqrt_Op   <= resize(unsigned(abs(resize(r_Ar, 32)*resize(r_Ar, 32)) + abs(resize(r_Ai, 32)*resize(r_Ai, 32))), 32);
                        r_Sqrt_Rem  <= (others => '0');
                        r_Sqrt_Root <= (others => '0');
                        r_Sqrt_Iter <= 1;
                    elsif r_Sqrt_Iter <= 16 then 
                        -- Algoritma Restoring Sqrt 16-bit
                        v_test_sub := resize((r_Sqrt_Root(14 downto 0) & '0'), 32) or to_unsigned(1, 32);
                        
                        -- Cek 2 bit MSB dari Op
                        if (r_Sqrt_Rem(29 downto 0) & r_Sqrt_Op(31 downto 30)) >= v_test_sub then
                            r_Sqrt_Rem  <= (r_Sqrt_Rem(29 downto 0) & r_Sqrt_Op(31 downto 30)) - v_test_sub;
                            r_Sqrt_Root <= (r_Sqrt_Root(14 downto 0) & '1');
                        else
                            r_Sqrt_Rem  <= (r_Sqrt_Rem(29 downto 0) & r_Sqrt_Op(31 downto 30));
                            r_Sqrt_Root <= (r_Sqrt_Root(14 downto 0) & '0');
                        end if;
                        
                        r_Sqrt_Op   <= r_Sqrt_Op(29 downto 0) & "00";
                        r_Sqrt_Iter <= r_Sqrt_Iter + 1;
                    else
                        mem_Real(r_Point_Idx) <= signed(r_Sqrt_Root);
                        r_Point_Idx <= r_Point_Idx + 1;
                        r_SM <= s_MAG_PREP;
                    end if;

                -- ================= TX (Kirim 64 Byte untuk 32 Point 16-bit) =================
                when s_TX_NEXT_BYTE =>
                    if r_Point_Idx < points then
                        if r_TX_State = 0 then
                            -- Kirim Low Byte
                            r_TX_Buffer <= std_logic_vector(mem_Real(r_Point_Idx)(7 downto 0));
                        else
                            -- Kirim High Byte
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
                        if r_TX_State = 0 then
                            r_TX_State <= 1; -- Lanjut ke High Byte
                            r_SM <= s_TX_NEXT_BYTE;
                        else
                            r_TX_State <= 0; -- Reset ke Low Byte
                            r_Point_Idx <= r_Point_Idx + 1; -- Lanjut ke Point berikutnya
                            r_SM <= s_TX_NEXT_BYTE;
                        end if;
                    end if;

                when others =>
                    r_SM <= s_IDLE;

            end case;
            
            if r_SM = s_RX_WAIT_START then
                 if r_RX_Data = '1' then
                     r_Bit_Ctr <= 0; 
                 end if;
            end if;

        end if;
    end process;
end Behavioral;