----------------------------------------------------------------------------------
-- Richie Harris
-- rkharris12@gmail.com
-- 5/6/2022
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity heavy_hash is
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
end heavy_hash;

architecture rtl of heavy_hash is

    type slv_array_type is array (natural range <>) of std_logic_vector;
    type unsigned_array_type is array (natural range <>) of unsigned;

    function unpack_add_result(
        add_result : unsigned_array_type(7 downto 0)(13 downto 0))
        return std_logic_vector is
        variable temp : std_logic_vector(31 downto 0);
    begin
        for row in 0 to 7 loop
            temp(4*(row+1)-1 downto 4*row) := std_logic_vector(add_result(row)(13 downto 10));
        end loop;
        return temp;
    end unpack_add_result;

    component sha3 is
        generic (
            G_NUM_PARALLEL_F : integer;
            G_INIT_STATE     : std_logic_vector(1599 downto 0);
            G_NUM_INPUT_BITS : integer
        );
        port (
            CLK     : in  std_logic;
            ARST_N  : in  std_logic;
            DIN     : in  std_logic_vector(G_NUM_INPUT_BITS-1 downto 0);
            DIN_EN  : in  std_logic;
            DOUT    : out std_logic_vector(255 downto 0);
            DOUT_EN : out std_logic
        );
    end component;

    constant C_NUM_PARALLEL_SHA  : integer := 3; -- only tested with 3. If you use another value, other changes are required
    
    constant C_SHA3_1_INIT_STATE : std_logic_vector(1599 downto 0) := x"02b97c786f8243835d1129cf82afa5bcb1fcce9ce78b527248b09427a8742edb89ca4e849bcecf4ad102574105095f8dba1de5e4451668e4c1a2021d563bb1428f06dd1c7a2f851a3485549064a36a46b21a601f85b4b223e6c85d8f82e9da89ec70f1a425b1371544e367875b2991520f96070540f14a0e2e651c3c43285ff0f8ebf13388663140776bf60c789bc29c183a981ead415b104aef61d629dce2467b2fafca875e2d651ba5a4a3f59869a01e5f2e720efb44d229bf8855b7027e3c113cff0da1f6d83d";
    constant C_SHA3_1_INPUT_BITS : integer := 640;
    
    constant C_SHA3_2_INIT_STATE : std_logic_vector(1599 downto 0) := x"1619327d10b9da35549ae0312f9fc61592bb399db5290c0a47c39f675112c22ec776c5048481b957b992f2d37b34ca58ea8fdb80bac46d397e8f1db17765cc0787e961b036bc9416774c86835434f2b04ef74b3a99cdb0442ec65bd3562493e46c6b7d01a769cc3dd31f4cc354c18c3ff431c05dd0a9a226a0bcaa9f792a3d0c8039f9a60dcf6a485e219040250fc462c100ff2a938935ba72c7d82e14f34069e720e0df44eecede11a75f4c800564987a14ff4816c7f8ee79629b0e2f9f42163ad74c52b2248509";
    constant C_SHA3_2_INPUT_BITS : integer := 256;

    signal sha3_1_out            : std_logic_vector(255 downto 0);
    signal sha3_1_out_en         : std_logic;

    signal sha3_1_out_sr         : slv_array_type(3 downto 0)(255 downto 0);
    signal mult1_result          : unsigned_array_type(511 downto 0)(7 downto 0);
    signal add1_l1_result        : unsigned_array_type(255 downto 0)(8 downto 0);
    signal add1_l2_result        : unsigned_array_type(127 downto 0)(9 downto 0);
    signal add1_l3_result        : unsigned_array_type(63 downto 0)(10 downto 0);
    signal add1_l4_result        : unsigned_array_type(31 downto 0)(11 downto 0);
    signal add1_l5_result        : unsigned_array_type(15 downto 0)(12 downto 0);
    signal mm1_result            : std_logic_vector(255 downto 0);
    signal mult2_result          : unsigned_array_type(511 downto 0)(7 downto 0);
    signal add2_l1_result        : unsigned_array_type(255 downto 0)(8 downto 0);
    signal add2_l2_result        : unsigned_array_type(127 downto 0)(9 downto 0);
    signal add2_l3_result        : unsigned_array_type(63 downto 0)(10 downto 0);
    signal add2_l4_result        : unsigned_array_type(31 downto 0)(11 downto 0);
    signal add2_l5_result        : unsigned_array_type(15 downto 0)(12 downto 0);
    signal mm2_result            : std_logic_vector(255 downto 0);
    signal mm_result_en          : std_logic;
    signal mm_result_en_d1       : std_logic;
    signal mult_result_en_sr     : std_logic_vector(5 downto 0);
    signal row_cnt               : unsigned(2 downto 0);

    signal precompute_result     : std_logic_vector(255 downto 0);
    signal precompute_result_en  : std_logic;

begin

    -- first sha3 hash
    u_sha3_1 : sha3
        generic map (
            G_NUM_PARALLEL_F => C_NUM_PARALLEL_SHA,
            G_INIT_STATE     => C_SHA3_1_INIT_STATE,
            G_NUM_INPUT_BITS => C_SHA3_1_INPUT_BITS)
        port map (
            CLK     => CLK,
            ARST_N  => ARST_N,
            DIN     => DIN,
            DIN_EN  => DIN_EN,
            DOUT    => sha3_1_out,
            DOUT_EN => sha3_1_out_en);

    -- matrix multiplication
    process(CLK, ARST_N)
        variable mult1_result_temp1  : unsigned(7 downto 0);
        variable mult1_result_temp2  : unsigned(7 downto 0);
        variable add1_l1_result_temp : unsigned(8 downto 0);
        variable add1_l2_result_temp : unsigned(9 downto 0);
        variable add1_l3_result_temp : unsigned(10 downto 0);
        variable add1_l4_result_temp : unsigned(11 downto 0);
        variable add1_l5_result_temp : unsigned(12 downto 0);
        variable add1_l6_result_temp : unsigned_array_type(7 downto 0)(13 downto 0);
        variable mult2_result_temp1  : unsigned(7 downto 0);
        variable mult2_result_temp2  : unsigned(7 downto 0);
        variable add2_l1_result_temp : unsigned(8 downto 0);
        variable add2_l2_result_temp : unsigned(9 downto 0);
        variable add2_l3_result_temp : unsigned(10 downto 0);
        variable add2_l4_result_temp : unsigned(11 downto 0);
        variable add2_l5_result_temp : unsigned(12 downto 0);
        variable add2_l6_result_temp : unsigned_array_type(7 downto 0)(13 downto 0);
    begin
        if (ARST_N = '0') then
            sha3_1_out_sr     <= (others => (others => '0'));
            mult1_result      <= (others => (others => '0'));
            mult2_result      <= (others => (others => '0'));
            MATRIX_ROW_REQ    <= '0';
            MATRIX_ROW_IDX    <= (others => '0');
            add1_l1_result    <= (others => (others => '0'));
            add1_l2_result    <= (others => (others => '0'));
            add1_l3_result    <= (others => (others => '0'));
            add1_l4_result    <= (others => (others => '0'));
            add1_l5_result    <= (others => (others => '0'));
            mm1_result        <= (others => '0');
            add2_l1_result    <= (others => (others => '0'));
            add2_l2_result    <= (others => (others => '0'));
            add2_l3_result    <= (others => (others => '0'));
            add2_l4_result    <= (others => (others => '0'));
            add2_l5_result    <= (others => (others => '0'));
            mm2_result        <= (others => '0');
            mm_result_en      <= '0';
            mm_result_en_d1   <= '0';
            mult_result_en_sr <= (others => '0');
            row_cnt           <= (others => '0');
        elsif rising_edge(CLK) then
            mult_result_en_sr <= MATRIX_ROW_IN_EN & mult_result_en_sr(mult_result_en_sr'length-1 downto 1);
            mm_result_en      <= '0';
            mm_result_en_d1   <= mm_result_en;

            -- shift in the two results
            if (sha3_1_out_en = '1') then
                sha3_1_out_sr <= sha3_1_out & sha3_1_out_sr(sha3_1_out_sr'high downto 1);
            end if;
            
            -- request 8 matrix rows
            if (sha3_1_out_en = '1') then
                MATRIX_ROW_REQ <= '1';
            elsif (MATRIX_ROW_IN_EN = '1') and (MATRIX_ROW_IDX = 7) then
                MATRIX_ROW_REQ <= '0';
            end if;

            if (MATRIX_ROW_REQ = '1') then
                MATRIX_ROW_IDX <= MATRIX_ROW_IDX + 1; -- rollover
            end if;

            -- do 8 rows at a time
            -- parallel multiply, tricky because the upper 4 bits of each byte of sha3_1_out are first
            for j in 0 to 7 loop
                for i in 0 to 31 loop
                    mult1_result_temp1 := unsigned(MATRIX_ROW_IN(8*(i+1)-5+256*j downto 8*i+256*j)) * unsigned(sha3_1_out_sr(2)(8*(i+1)-1 downto 8*i+4));
                    mult1_result_temp2 := unsigned(MATRIX_ROW_IN(8*(i+1)-1+256*j downto 8*i+4+256*j)) * unsigned(sha3_1_out_sr(2)(8*(i+1)-5 downto 8*i));
                    mult1_result(2*i+64*j)   <= mult1_result_temp1;
                    mult1_result(2*i+1+64*j) <= mult1_result_temp2;
                end loop;
            end loop;

            for j in 0 to 7 loop
                for i in 0 to 31 loop
                    mult2_result_temp1 := unsigned(MATRIX_ROW_IN(8*(i+1)-5+256*j downto 8*i+256*j)) * unsigned(sha3_1_out_sr(3)(8*(i+1)-1 downto 8*i+4));
                    mult2_result_temp2 := unsigned(MATRIX_ROW_IN(8*(i+1)-1+256*j downto 8*i+4+256*j)) * unsigned(sha3_1_out_sr(3)(8*(i+1)-5 downto 8*i));
                    mult2_result(2*i+64*j)   <= mult2_result_temp1;
                    mult2_result(2*i+1+64*j) <= mult2_result_temp2;
                end loop;
            end loop;

            -- adder tree
            for i in 0 to 255 loop
                add1_l1_result_temp := resize(mult1_result(2*i), 9) + resize(mult1_result(2*i+1), 9);
                add1_l1_result(i)   <= add1_l1_result_temp;
            end loop;
            for i in 0 to 127 loop
                add1_l2_result_temp := resize(add1_l1_result(2*i), 10) + resize(add1_l1_result(2*i+1), 10);
                add1_l2_result(i)   <= add1_l2_result_temp;
            end loop;
            for i in 0 to 63 loop
                add1_l3_result_temp := resize(add1_l2_result(2*i), 11) + resize(add1_l2_result(2*i+1), 11);
                add1_l3_result(i)   <= add1_l3_result_temp;
            end loop;
            for i in 0 to 31 loop
                add1_l4_result_temp := resize(add1_l3_result(2*i), 12) + resize(add1_l3_result(2*i+1), 12);
                add1_l4_result(i)   <= add1_l4_result_temp;
            end loop;
            for i in 0 to 15 loop
                add1_l5_result_temp := resize(add1_l4_result(2*i), 13) + resize(add1_l4_result(2*i+1), 13);
                add1_l5_result(i)   <= add1_l5_result_temp;
            end loop;

            for i in 0 to 255 loop
                add2_l1_result_temp := resize(mult2_result(2*i), 9) + resize(mult2_result(2*i+1), 9);
                add2_l1_result(i)   <= add2_l1_result_temp;
            end loop;
            for i in 0 to 127 loop
                add2_l2_result_temp := resize(add2_l1_result(2*i), 10) + resize(add2_l1_result(2*i+1), 10);
                add2_l2_result(i)   <= add2_l2_result_temp;
            end loop;
            for i in 0 to 63 loop
                add2_l3_result_temp := resize(add2_l2_result(2*i), 11) + resize(add2_l2_result(2*i+1), 11);
                add2_l3_result(i)   <= add2_l3_result_temp;
            end loop;
            for i in 0 to 31 loop
                add2_l4_result_temp := resize(add2_l3_result(2*i), 12) + resize(add2_l3_result(2*i+1), 12);
                add2_l4_result(i)   <= add2_l4_result_temp;
            end loop;
            for i in 0 to 15 loop
                add2_l5_result_temp := resize(add2_l4_result(2*i), 13) + resize(add2_l4_result(2*i+1), 13);
                add2_l5_result(i)   <= add2_l5_result_temp;
            end loop;

            -- shift in result of row multiply
            if (mult_result_en_sr(0) = '1') then
                for i in 0 to 7 loop
                    add1_l6_result_temp(i) := resize(add1_l5_result(2*i), 14) + resize(add1_l5_result(2*i+1), 14);
                end loop;
                mm1_result <= unpack_add_result(add1_l6_result_temp) & mm1_result(255 downto 32);
                for i in 0 to 7 loop
                    add2_l6_result_temp(i) := resize(add2_l5_result(2*i), 14) + resize(add2_l5_result(2*i+1), 14);
                end loop;
                mm2_result <= unpack_add_result(add2_l6_result_temp) & mm2_result(255 downto 32);
                row_cnt    <= row_cnt + 1; -- rollover
                if (row_cnt = 7) then
                    mm_result_en <= '1';
                end if;
            end if;
        end if;
    end process;

    -- xor precompute
    process(CLK, ARST_N)
        variable precompute_result_temp1 : std_logic_vector(3 downto 0);
        variable precompute_result_temp2 : std_logic_vector(3 downto 0);
    begin
        if (ARST_N = '0') then
            precompute_result    <= (others => '0');
            precompute_result_en <= '0';
        elsif rising_edge(CLK) then
            precompute_result_en <= '0';

            if (mm_result_en = '1') then
                precompute_result_en <= '1';
                -- again, tricky because the upper 4 bits of each byte of sha3_1_out are first
                for i in 0 to 31 loop
                    precompute_result_temp1                   := mm1_result(8*(i+1)-5 downto 8*i) xor sha3_1_out_sr(2)(8*(i+1)-1 downto 8*i+4);
                    precompute_result_temp2                   := mm1_result(8*(i+1)-1 downto 8*i+4) xor sha3_1_out_sr(2)(8*(i+1)-5 downto 8*i);
                    precompute_result(8*(i+1)-1 downto 8*i+4) <= precompute_result_temp1; -- upper 4 bits first
                    precompute_result(8*(i+1)-5 downto 8*i)   <= precompute_result_temp2;
                end loop;
            elsif (mm_result_en_d1 = '1') then
                precompute_result_en <= '1';
                -- again, tricky because the upper 4 bits of each byte of sha3_1_out are first
                for i in 0 to 31 loop
                    precompute_result_temp1                   := mm2_result(8*(i+1)-5 downto 8*i) xor sha3_1_out_sr(2)(8*(i+1)-1 downto 8*i+4);
                    precompute_result_temp2                   := mm2_result(8*(i+1)-1 downto 8*i+4) xor sha3_1_out_sr(2)(8*(i+1)-5 downto 8*i);
                    precompute_result(8*(i+1)-1 downto 8*i+4) <= precompute_result_temp1; -- upper 4 bits first
                    precompute_result(8*(i+1)-5 downto 8*i)   <= precompute_result_temp2;
                end loop;
            end if;
        end if;
    end process;

    -- second sha3 hash
    u_sha3_2 : sha3
        generic map (
            G_NUM_PARALLEL_F => C_NUM_PARALLEL_SHA,
            G_INIT_STATE     => C_SHA3_2_INIT_STATE,
            G_NUM_INPUT_BITS => C_SHA3_2_INPUT_BITS)
        port map (
            CLK     => CLK,
            ARST_N  => ARST_N,
            DIN     => precompute_result,
            DIN_EN  => precompute_result_en,
            DOUT    => DOUT,
            DOUT_EN => DOUT_EN);

end rtl;
