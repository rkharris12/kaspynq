----------------------------------------------------------------------------------
-- Richie Harris
-- rkharris12@gmail.com
-- 5/6/2022
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity kaspynq is
    port (
        CLK_125M : in std_logic
    );
end kaspynq;

architecture rtl of kaspynq is

    component clk_wiz_0 is
        port ( 
          clk_out1 : out std_logic;
          resetn   : in  std_logic;
          locked   : out std_logic;
          clk_in1  : in  std_logic
        );
    end component;

    component soc_wrapper is
        port (
            ARST_AVL_N             : out std_logic_vector(0 to 0);
            CLK_AVL                : out std_logic;
            M_AVALON_address       : out std_logic_vector(31 downto 0);
            M_AVALON_byteenable    : out std_logic_vector(3 downto 0);
            M_AVALON_read          : out std_logic;
            M_AVALON_readdata      : in  std_logic_vector(31 downto 0);
            M_AVALON_readdatavalid : in  std_logic;
            M_AVALON_waitrequest   : in  std_logic;
            M_AVALON_write         : out std_logic;
            M_AVALON_writedata     : out std_logic_vector(31 downto 0);
            S_AVALON_address       : in  std_logic_vector(31 downto 0);
            S_AVALON_burstcount    : in  std_logic_vector(10 downto 0);
            S_AVALON_read          : in  std_logic;
            S_AVALON_readdata      : out std_logic_vector(63 downto 0);
            S_AVALON_readdatavalid : out std_logic;
            S_AVALON_waitrequest   : out std_logic;
            S_AVALON_write         : in  std_logic;
            S_AVALON_writedata     : in  std_logic_vector(63 downto 0)
        );
    end component;

    component blk_mem_gen_1 is
        port ( 
            clka  : in  std_logic;
            ena   : in  std_logic;
            wea   : in  std_logic_vector(0 to 0);
            addra : in  std_logic_vector(7 downto 0);
            dina  : in  std_logic_vector(63 downto 0);
            clkb  : in  std_logic;
            enb   : in  std_logic;
            addrb : in  std_logic_vector(2 downto 0);
            doutb : out std_logic_vector(2047 downto 0)
        );
    end component;

    component pulse_cdc is
        port (
            CLK_IN     : in  std_logic;
            ARST_IN_N  : in  std_logic;
            CLK_OUT    : in  std_logic;
            ARST_OUT_N : in  std_logic;
            DIN        : in  std_logic;
            DOUT       : out std_logic
        );
    end component;

    component data_cdc is
        generic (
            G_DATA_BITS : integer
        );
        port (
            CLK_IN     : in  std_logic;
            ARST_IN_N  : in  std_logic;
            CLK_OUT    : in  std_logic;
            ARST_OUT_N : in  std_logic;
            DIN        : in  std_logic_vector(G_DATA_BITS-1 downto 0);
            DIN_EN     : in  std_logic;
            DOUT       : out std_logic_vector(G_DATA_BITS-1 downto 0);
            DOUT_EN    : out std_logic
        );
    end component;

    component nonce_mem is
        port ( 
            clka  : in  std_logic;
            ena   : in  std_logic;
            wea   : in  std_logic_vector(0 to 0);
            addra : in  std_logic_vector(4 downto 0);
            dina  : in  std_logic_vector(63 downto 0);
            clkb  : in  std_logic;
            enb   : in  std_logic;
            addrb : in  std_logic_vector(4 downto 0);
            doutb : out std_logic_vector(63 downto 0)
        );
    end component;

    component heavy_hash is
        port (
            CLK              : in  std_logic;
            ARST_N           : in  std_logic;
            DIN_EN           : in  std_logic;
            DIN              : in  std_logic_vector(639 downto 0);
            MATRIX_ROW_IN    : in  std_logic_vector(2047 downto 0);
            MATRIX_ROW_IN_EN : in  std_logic;
            MATRIX_ROW_REQ   : out std_logic;
            MATRIX_ROW_IDX   : out unsigned(2 downto 0);
            DOUT             : out std_logic_vector(255 downto 0);
            DOUT_EN          : out std_logic
        );
    end component;

    constant C_VERSION            : std_logic_vector(31 downto 0) := x"0000001a";

    constant C_MEM_INTF_BITS      : integer := 64;
    constant C_TARGET_BITS        : integer := 256;
    constant C_DATA_BITS          : integer := 576; -- 32 byte header hash, 8 byte timestamp, 32 byte zero pad
    constant C_MATRIX_BITS        : integer := 16384; -- 64x64x4
    constant C_RESULT_BITS        : integer := 320; -- 5*64=320 (256 bit hash result concatenated with 64 bit nonce)
    constant C_TARGET_WORDS       : integer := C_TARGET_BITS / C_MEM_INTF_BITS;
    constant C_DATA_WORDS         : integer := C_DATA_BITS / C_MEM_INTF_BITS;
    constant C_MATRIX_WORDS       : integer := C_MATRIX_BITS / C_MEM_INTF_BITS;
    constant C_RESULT_WORDS       : integer := C_RESULT_BITS / C_MEM_INTF_BITS;

    constant C_INPUT_CYCLES       : integer := 14; -- 2 outputs every 16 cycles because 3 parallel sha3s, and 24 rounds

    signal clk_avalon             : std_logic;
    signal arst_avalon_n          : std_logic;
    signal clk_hash               : std_logic;
    signal arst_hash_n            : std_logic;
    signal pll_hash_locked        : std_logic;

    signal m_avalon_address       : std_logic_vector(31 downto 0);
    signal m_avalon_byteenable    : std_logic_vector(3 downto 0);
    signal m_avalon_read          : std_logic;
    signal m_avalon_readdata      : std_logic_vector(31 downto 0);
    signal m_avalon_readdatavalid : std_logic;
    signal m_avalon_waitrequest   : std_logic;
    signal m_avalon_write         : std_logic;
    signal m_avalon_writedata     : std_logic_vector(31 downto 0);
    signal s_avalon_address       : std_logic_vector(31 downto 0);
    signal s_avalon_burstcount    : std_logic_vector(10 downto 0);
    signal s_avalon_read          : std_logic;
    signal s_avalon_readdata      : std_logic_vector(63 downto 0);
    signal s_avalon_readdatavalid : std_logic;
    signal s_avalon_waitrequest   : std_logic;
    signal s_avalon_write         : std_logic;
    signal s_avalon_writedata     : std_logic_vector(63 downto 0);
    
    signal address_bank           : std_logic_vector(7 downto 0);
    signal address_offset         : std_logic_vector(7 downto 0);

    signal start                  : std_logic;
    signal sync_reset             : std_logic;
    signal sync_reset_resync      : std_logic;
    signal done                   : std_logic;
    signal done_latched           : std_logic;
    signal data_base_address      : std_logic_vector(31 downto 0);
    signal matrix_base_address    : std_logic_vector(31 downto 0);
    signal result_base_address    : std_logic_vector(31 downto 0);
    signal target_base_address    : std_logic_vector(31 downto 0);

    type avalon_state_type        is (E_IDLE, E_READ_TARGET_REQ, E_READ_TARGET, E_READ_DATA_REQ, E_READ_DATA, E_READ_MATRIX_REQ, E_READ_MATRIX, E_WAIT, E_WRITE);
    signal avalon_state           : avalon_state_type;
    signal avalon_word_cnt        : unsigned(7 downto 0);
    signal start_hash             : std_logic;
    signal start_hash_resync      : std_logic;
    signal result_sr              : std_logic_vector(319 downto 0);

    signal matrix_row_in          : std_logic_vector(2047 downto 0);
    signal matrix_row_in_en       : std_logic;
    signal matrix_row_req         : std_logic;
    signal matrix_row_idx         : unsigned(2 downto 0);

    signal target                 : std_logic_vector(255 downto 0);
    signal din                    : std_logic_vector(575 downto 0);
    signal golden_resync          : std_logic_vector(319 downto 0);
    signal golden_en_resync       : std_logic;

    type nonce_state_type         is (E_IDLE, E_HASH, E_DONE);
    signal nonce_state            : nonce_state_type;
    signal hash_in                : std_logic_vector(639 downto 0);
    signal hash_in_en             : std_logic;
    signal nonce                  : unsigned(63 downto 0);
    signal input_cnt              : unsigned(3 downto 0);
    signal hash_in_cnt            : unsigned(0 downto 0);
    signal golden_nonce           : std_logic_vector(63 downto 0);
    signal golden_nonce_en        : std_logic;
    signal golden_hash            : std_logic_vector(255 downto 0);
    signal nonce_mem_waddr        : unsigned(4 downto 0);
    signal nonce_mem_in           : std_logic_vector(63 downto 0);
    signal nonce_mem_in_en        : std_logic;
    signal nonce_mem_raddr        : unsigned(4 downto 0);
    signal nonce_mem_out          : std_logic_vector(63 downto 0);
    signal hash_out_en            : std_logic;
    signal hash_out               : std_logic_vector(255 downto 0);

begin

    -- hash clock and reset generation
    mmcm_clk_hash : clk_wiz_0
        port map ( 
            clk_out1 => clk_hash,
            resetn   => '1',
            locked   => pll_hash_locked,
            clk_in1  => CLK_125M);

    arst_hash_n <= pll_hash_locked;

    -- instantiate processor interface
    u_soc_wrapper : soc_wrapper
        port map (
            ARST_AVL_N(0)          => arst_avalon_n,
            CLK_AVL                => clk_avalon,
            M_AVALON_address       => m_avalon_address,
            M_AVALON_byteenable    => m_avalon_byteenable,
            M_AVALON_read          => m_avalon_read,
            M_AVALON_readdata      => m_avalon_readdata,
            M_AVALON_readdatavalid => m_avalon_readdatavalid,
            M_AVALON_waitrequest   => m_avalon_waitrequest,
            M_AVALON_write         => m_avalon_write,
            M_AVALON_writedata     => m_avalon_writedata,
            S_AVALON_address       => s_avalon_address,
            S_AVALON_burstcount    => s_avalon_burstcount,
            S_AVALON_read          => s_avalon_read,
            S_AVALON_readdata      => s_avalon_readdata,
            S_AVALON_readdatavalid => s_avalon_readdatavalid,
            S_AVALON_waitrequest   => s_avalon_waitrequest,
            S_AVALON_write         => s_avalon_write,
            S_AVALON_writedata     => s_avalon_writedata);

    -- memory interface
    process(clk_avalon, arst_avalon_n) begin
        if (arst_avalon_n = '0') then
            avalon_state        <= E_IDLE;
            s_avalon_read       <= '0';
            s_avalon_address    <= (others => '0');
            s_avalon_burstcount <= (others => '0');
            s_avalon_write      <= '0';
            target              <= (others => '0');
            din                 <= (others => '0');
            avalon_word_cnt     <= (others => '0');
            start_hash          <= '0';
            result_sr           <= (others => '0');
            done                <= '0';
        elsif rising_edge(clk_avalon) then
            start_hash <= '0';
            done       <= '0';

            case (avalon_state) is
                when E_IDLE =>
                    if (start = '1') then
                        avalon_state        <= E_READ_TARGET_REQ;
                        s_avalon_read       <= '1';
                        s_avalon_address    <= target_base_address;
                        s_avalon_burstcount <= std_logic_vector(to_unsigned(C_TARGET_WORDS, s_avalon_burstcount'length));
                        avalon_word_cnt     <= (others => '0');
                    end if;

                when E_READ_TARGET_REQ =>
                    if (s_avalon_waitrequest = '0') then
                        avalon_state  <= E_READ_TARGET;
                        s_avalon_read <= '0';
                    end if;

                when E_READ_TARGET =>
                    if (s_avalon_readdatavalid = '1') then
                        target          <= s_avalon_readdata & target(255 downto 64);
                        avalon_word_cnt <= avalon_word_cnt + 1;
                        if (avalon_word_cnt = C_TARGET_WORDS-1) then
                            avalon_state        <= E_READ_DATA_REQ;
                            s_avalon_read       <= '1';
                            s_avalon_address    <= data_base_address;
                            s_avalon_burstcount <= std_logic_vector(to_unsigned(C_DATA_WORDS, s_avalon_burstcount'length));
                            avalon_word_cnt     <= (others => '0');
                        end if;
                    end if;

                when E_READ_DATA_REQ =>
                    if (s_avalon_waitrequest = '0') then
                        avalon_state  <= E_READ_DATA;
                        s_avalon_read <= '0';
                    end if;

                when E_READ_DATA =>
                    if (s_avalon_readdatavalid = '1') then
                        din             <= s_avalon_readdata & din(575 downto 64);
                        avalon_word_cnt <= avalon_word_cnt + 1;
                        if (avalon_word_cnt = C_DATA_WORDS-1) then
                            avalon_state        <= E_READ_MATRIX_REQ;
                            s_avalon_read       <= '1';
                            s_avalon_address    <= matrix_base_address;
                            s_avalon_burstcount <= std_logic_vector(to_unsigned(C_MATRIX_WORDS, s_avalon_burstcount'length));
                            avalon_word_cnt     <= (others => '0');
                        end if;
                    end if;
                
                when E_READ_MATRIX_REQ =>
                    if (s_avalon_waitrequest = '0') then
                        avalon_state  <= E_READ_MATRIX;
                        s_avalon_read <= '0';
                    end if;

                when E_READ_MATRIX =>
                    if (s_avalon_readdatavalid = '1') then
                        avalon_word_cnt <= avalon_word_cnt + 1;
                        if (avalon_word_cnt = C_MATRIX_WORDS-1) then
                            avalon_state    <= E_WAIT;
                            start_hash      <= '1';
                            avalon_word_cnt <= (others => '0');
                        end if;
                    end if;

                when E_WAIT =>
                    if (sync_reset = '1') then
                        avalon_state <= E_IDLE;
                    elsif (golden_en_resync = '1') then
                        avalon_state        <= E_WRITE;
                        result_sr           <= golden_resync;
                        s_avalon_address    <= result_base_address;
                        s_avalon_write      <= '1';
                        s_avalon_burstcount <= std_logic_vector(to_unsigned(1, s_avalon_burstcount'length)); -- no burst writes
                    end if;

                when E_WRITE =>
                    if (s_avalon_waitrequest = '0') then
                        result_sr        <= x"0000000000000000" & result_sr(319 downto 64);
                        s_avalon_address <= std_logic_vector(unsigned(s_avalon_address) + 8);
                        avalon_word_cnt  <= avalon_word_cnt + 1;
                        if (avalon_word_cnt = C_RESULT_WORDS-1) then
                            avalon_state    <= E_IDLE;
                            avalon_word_cnt <= (others => '0');
                            s_avalon_write  <= '0';
                            done            <= '1';
                        end if;
                    end if;
                    
                when others => null;
            end case;
        end if;
    end process;

    -- assign write data
    s_avalon_writedata <= result_sr(63 downto 0);

    -- CDC start, reset, current nonce, and done signals
    start_hash_cdc : pulse_cdc
        port map (
            CLK_IN     => clk_avalon,
            ARST_IN_N  => arst_avalon_n,
            CLK_OUT    => clk_hash,
            ARST_OUT_N => arst_hash_n,
            DIN        => start_hash,
            DOUT       => start_hash_resync);

    sync_reset_cdc : pulse_cdc
        port map (
            CLK_IN     => clk_avalon,
            ARST_IN_N  => arst_avalon_n,
            CLK_OUT    => clk_hash,
            ARST_OUT_N => arst_hash_n,
            DIN        => sync_reset,
            DOUT       => sync_reset_resync);

    dout_cdc : data_cdc
        generic map (
            G_DATA_BITS => 320)
        port map (
            CLK_IN     => clk_hash,
            ARST_IN_N  => arst_hash_n,
            CLK_OUT    => clk_avalon,
            ARST_OUT_N => arst_avalon_n,
            DIN        => golden_nonce & golden_hash,
            DIN_EN     => golden_nonce_en,
            DOUT       => golden_resync,
            DOUT_EN    => golden_en_resync);

    -- target and din should be stable when used on clk_hash so don't need to CDC them
    -- nonce should be stable when used on clk_avalon so don't need to CDC it

    -- local matrix memory
    matrix_mem_1 : blk_mem_gen_1
       port map ( 
           clka   => clk_avalon,
           ena    => '1',
           wea(0) => s_avalon_readdatavalid,
           addra  => std_logic_vector(avalon_word_cnt),
           dina   => s_avalon_readdata,
           clkb   => clk_hash,
           enb    => '1',
           addrb  => std_logic_vector(matrix_row_idx),
           doutb  => matrix_row_in);

   process(clk_hash, arst_hash_n) begin
       if (arst_hash_n = '0') then
           matrix_row_in_en <= '0';
       elsif rising_edge(clk_hash) then
           matrix_row_in_en <= matrix_row_req;
       end if;
   end process;

    -- register interface
    m_avalon_waitrequest <= '0'; -- always ready
  
    -- decode register address
    address_bank   <= m_avalon_address(15 downto 8);
    address_offset <= m_avalon_address(7 downto 0);

    process(clk_avalon, arst_avalon_n) begin
        if (arst_avalon_n = '0') then
            m_avalon_readdata      <= (others => '0');
            m_avalon_readdatavalid <= '0';
            start                  <= '0';
            sync_reset             <= '0';
            done_latched           <= '0';
            data_base_address      <= (others => '0');
            matrix_base_address    <= (others => '0');
            result_base_address    <= (others => '0');
            target_base_address    <= (others => '0');
        elsif rising_edge(clk_avalon) then
            m_avalon_readdata      <= (others => '0');
            m_avalon_readdatavalid <= '0';
            start                  <= '0';
            sync_reset             <= '0';

            if (done = '1') then
                done_latched <= '1';
            end if;

            -- read
            if (m_avalon_read = '1') then
                m_avalon_readdatavalid <= '1';
                if (to_integer(unsigned(address_bank)) = 0) then
                    case to_integer(unsigned(address_offset)) is
                        when 0 =>
                            m_avalon_readdata <= C_VERSION;
                        when 2 =>
                            m_avalon_readdata <= (0 => done_latched, others => '0');
                            if (done_latched = '1') then
                                done_latched <= '0'; -- clear on read if done
                            end if;
                        when 3 =>
                            m_avalon_readdata <= target_base_address;
                        when 4 =>
                            m_avalon_readdata <= data_base_address;
                        when 5 =>
                            m_avalon_readdata <= matrix_base_address;
                        when 6 =>
                            m_avalon_readdata <= result_base_address;
                        when 7 =>
                            m_avalon_readdata <= std_logic_vector(nonce(31 downto 0));
                        when 8 =>
                            m_avalon_readdata <= std_logic_vector(nonce(63 downto 32));
                        when others =>
                            null;
                    end case;
                end if;
            -- write
            elsif (m_avalon_write = '1') then
                if (to_integer(unsigned(address_bank)) = 0) then
                    case to_integer(unsigned(address_offset)) is 
                        when 1 =>
                            start               <= m_avalon_writedata(0);
                            sync_reset          <= m_avalon_writedata(1);
                        when 3 =>
                            target_base_address <= m_avalon_writedata;
                        when 4 =>
                            data_base_address   <= m_avalon_writedata;
                        when 5 =>
                            matrix_base_address <= m_avalon_writedata;
                        when 6 =>
                            result_base_address <= m_avalon_writedata;
                        when others =>
                            null;
                    end case;
                end if;
            end if;
        end if;
    end process;

    -- nonce control
    process(clk_hash, arst_hash_n) begin
        if (arst_hash_n = '0') then
            nonce_state     <= E_IDLE;
            nonce           <= (others => '0');
            hash_in         <= (others => '0');
            hash_in_en      <= '0';
            input_cnt       <= (others => '0');
            hash_in_cnt     <= (others => '0');
            golden_nonce    <= (others => '0');
            golden_nonce_en <= '0';
            golden_hash     <= (others => '0');
            nonce_mem_raddr <= (others => '0');
            nonce_mem_waddr <= (others => '0');
            nonce_mem_in    <= (others => '0');
            nonce_mem_in_en <= '0';
        elsif rising_edge(clk_hash) then
            hash_in_en      <= '0';
            golden_nonce_en <= '0';
            nonce_mem_in_en <= '0';

            if (nonce_mem_in_en = '1') then
                nonce_mem_waddr <= nonce_mem_waddr + 1;
            end if;
            
            case (nonce_state) is
                when E_IDLE =>
                    if (start_hash_resync = '1') then
                        input_cnt       <= to_unsigned(C_INPUT_CYCLES, input_cnt'length);
                        hash_in_cnt     <= (others => '0');
                        nonce           <= (others => '0');
                        nonce_mem_raddr <= (others => '0');
                        nonce_mem_waddr <= (others => '0');
                        nonce_state     <= E_HASH;
                    end if;
                
                when E_HASH =>
                    if (sync_reset_resync = '1') then
                        nonce_state <= E_IDLE;
                    elsif (hash_out_en = '1') then
                        if (unsigned(hash_out) < unsigned(target)) then
                            nonce_state <= E_DONE;
                            golden_hash <= hash_out;
                        else
                            nonce_mem_raddr <= nonce_mem_raddr + 1;
                            input_cnt       <= input_cnt + 1;
                        end if;
                    elsif (input_cnt = C_INPUT_CYCLES) then
                        hash_in_cnt     <= hash_in_cnt + 1;
                        hash_in         <= std_logic_vector(nonce) & din;
                        hash_in_en      <= '1';
                        nonce           <= nonce + 1;
                        nonce_mem_in_en <= '1';
                        nonce_mem_in    <= std_logic_vector(nonce);
                        if (hash_in_cnt = 1) then
                            input_cnt <= (others => '0');
                        end if;
                    else
                        input_cnt <= input_cnt + 1;
                    end if;
                
                when E_DONE =>
                    golden_nonce    <= nonce_mem_out;
                    golden_nonce_en <= '1';
                    nonce_state     <= E_IDLE;

                when others =>
                    null;
            end case;
        end if;
    end process;

    -- nonce memory to keep track of which nonce produced golden hash
    u_nonce_mem : nonce_mem
        port map (
            clka   => clk_hash,
            ena    => '1',
            wea(0) => nonce_mem_in_en,
            addra  => std_logic_vector(nonce_mem_waddr),
            dina   => nonce_mem_in,
            clkb   => clk_hash,
            enb    => '1',
            addrb  => std_logic_vector(nonce_mem_raddr),
            doutb  => nonce_mem_out);

    -- instantiate heavy hash core
    u_heavy_hash : heavy_hash
        port map (
            CLK              => clk_hash,
            ARST_N           => arst_hash_n,
            DIN_EN           => hash_in_en,
            DIN              => hash_in,
            MATRIX_ROW_IN    => matrix_row_in,
            MATRIX_ROW_IN_EN => matrix_row_in_en,
            MATRIX_ROW_REQ   => matrix_row_req,
            MATRIX_ROW_IDX   => matrix_row_idx,
            DOUT             => hash_out,
            DOUT_EN          => hash_out_en);

end rtl;
