----------------------------------------------------------------------------------
-- Richie Harris
-- rkharris12@gmail.com
-- 5/6/2022
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use STD.ENV.STOP;


entity tb_heavy_hash is
    
end tb_heavy_hash;

architecture sim of tb_heavy_hash is

    type slv_array_type is array (natural range <>) of std_logic_vector;

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

    constant C_CLK_PERIOD   : time := 10 ns; -- 100 MHz

    -- test input
    --header_hash = b"\x02\x12\x34\x90\x48\x23\x11\x87\x46\x38\x13\x46\x28\x43\x79\x12\x22\x33\x02\x09\x43\x52\x44\x66\x52\x31\x77\x62\x29\x02\x88\x41"
    --timestamp = 100
    --target = int("07ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff", 16)
    --matrix = generate_matrix(header_hash)

    constant C_MATRIX_MEM   : slv_array_type(0 to 7)(2047 downto 0) :=
                             (x"5c25de4c17ca0f2ddb2cf9e482a3bd13c37f00c892fac484beb4b2293812209c2e7e24319dc78ae7958a08936ed6beb4fda93831ebdcabb5b1527a66e72ad4bd974756b917446ccc8af1c1c585f4e20393a26e9bec52ff3aa5398dce51422969b0fff77af72108cbd5b6956a1db1887b00482229c3b268ba5e7cb400a27ff261b325446cbc02f3343f998bd8379fe215af32bb39f7fda2d9d20e041299ad684328d13a08dbe4dbd1039b41f298c18877fa246cb74a8a38881ccb99ecea0118f685b045696b5d3f33ed7f83a19dc5c5e184adffc06f44fd80c770435b890e755141f3b25518fc6377d1fc0a87317c7d1038ce9a69857b1c8c400a78ea3a985e94",
                              x"a294bbe522607a599af7cfd2a23c4eb9fc8262fbce494af59c73acef2020a5475c5445bfb6d988df3e0eef234a25ac7510601bc40b330aef5fb7fc9b6685b7a44641513d7afdac5faadf466a300ee9f11e43db3db971696b8e3c19a2aa230348979ef1213627110a978e753ed4312e9cfc51151d5d2ca4d0194c1954642103e192ed07afe176720f15164e890c9d086b57c238d916110abf07a77cf388c045c032eb089d23de572c68cf16a30b5a53ff1a5d8ed9e7720cd25a2fb6ba6bd1f9aa883c54a57238b7d3f0970ed61330701e0209a2b539540a3f4b1815be9473a3de549a9f2c4b157f4b8c7e14520d02166a78c0866cf2f86fb3674e4113f55c2c07",
                              x"844ee534b54cc468db07b0f9f97d0bc9d9847b524fe6d0d15a16a0211abcdba8dfb5fd5dfb056113b774433c48fe47efd186afe5064f9df5e2fbd82e2bb85ceecfe1a4576f25521ce46d7681a9ae9fe8f86d0d1c0e965ee1b89feb23fc7d891f84d8479352b402b60195b21733495e0478d434df18251b87d49385667aa06e6aced524483d1b93845ce9c91ed7093d63a98ef7e8b2b01dbe7087de274c1b58d3cf8131a37cdc861e9a8fdb389251693da90305e253d6fbf67073e4a18b8ea92f9aa4f8accd3b35b43cdc0a1c09aae2b4f7532fc72bdd5f908ae1e7ebd6ba239bdee8b9c6a4eb519ce4118c131b018773adf190e0362be029376bb0ba9b8a69ce",
                              x"4fec34425fa7d4222535489fe1d7bd56374bb1eeeb4402691bbcc0e5dccac4bbc0b4041df14d6daba60d8f6afbf475f58aacd5fbfb9350cee9578d764d182f412c0efcf5fcc117be2797aa66790344b3aaf33b61b87509542489f62247fee0a645616eb22579ab56e39ef555b303c923a3fdd6f7d8f4cf952f88bcdd5eaabe7aed1fbddf239a00df36fb6d3ef26e93223ba11017fe37da654b2fa6413c009b9cd1455aa732ff11f89ed05d592d664cd0e2b23a2b9a9c899e748436b486238aab94c2ff246b25effc5d44bbabef49a3175426dc1c2c2ac346ab3a0e6111f35414f318f4b361934dbeec2984a017d70e08bdfa1b87b60dddc20f241b8e20b26ad9",
                              x"3d4199c466a89878e42dc10be711c8f640dbd75e90bd65b204ce731a64b65ef28494f0aec25dcf940b5eb337b30bcc1dae70e645add531accf5527924bb9a6e58bde527a980847a73096a4e2c45cf277ff2353ce167dc2f0ac88bc745a9b7da2897ce69d46a48891433746749c5b532137dedccbc80e5c7baa9b3a6f5c851c56be82660569c0523ab48bd01c135bc6ac68de2e02959a0eb3e3758ccc8197e6252ae5c368cff839a73f323639474612880db661529e5606b8bba37d123cc1e078fad2daad9391e6da56936128ca0f782cca958e339cf6d766518b828325da00e5d5d08ea966cefaaab083d77d0c999dfed4a59a01b2614299d9fb95bbfcca8de7",
                              x"3de1b6b8ad0a75a632f21ae5984ddaf983eb5d39bea67c501693e0b75ef20068ad1295019d3a4ca058de82f3ad8d375c3ec1aec9108c6712140cb42590dff6a72cc9012be6a20a043e196d9436c96aeab7a0400dae1917e80c141122457a2e8559572474a37a41a924c8edae6fb29a1ce15d4a1390481aa8a4a2de87c54f1d631e93224c0d560f1cfcababcbf8a8aeb2a1a9e6eb4b76355762eadccdc318e050f395c2cd67e0ccebcb0fbc4ff9fbfa06aeb69dfab2d740066a66776ef5085eb97aad616d80749d4edd72e02c04ce9df080df8b0a3b2d793f153da41f758a364bbee142298e24bf42344deda269c717021bfc2dd93fe8d8831959ad9a18ae7bf4",
                              x"16e04daeab180af48286e1f06ceee00fc156ef587120ddbfef657134e66d2f78db0be8ffa6a0fc232f704eab83881e774164f29dadcbf12edc37aa3f0f1e04a0792e55b18506ea6d36d8082c2809699a7721870b9c24ad13ab46e912f9ccc3c93efc40bfa8c7bb842556f9c0d54ffc84a8cdd0ef93f63ca808dc5f0676acb46b92abb73a9a80fcf03fbae6184dbd1feffce39267a896b1ba7d71e8eeae954f6c46f5f383b45f378a8c8e6cd2ef16da77cda55c96aee0adb5014f2b4aa3a5bb35d2101e2de52131c6f79892554ebcd19a1248ead39a4fb0860d5659c33d5c56537ab7daa26137c9eadc949c95e978fccf7e9fa4ead062126b21c4b186564fb243",
                              x"42841e8e74b06f773871ea53332b99fceb4b495f1baadc431c4d1e9ca9f690dd06bec292a5bd9302578a320c6de8f7081c7188851835d61c450cab37fd3ec55f87fef924f3d418bd00300022833fc9afed1e75c1c9fec0cb157cea6fa8a4e43baaaabc85afc989201e9e14f1020b47d5dc5de214ab8f25bffcd2a59ee8f4a49a0cc86ec6ef9567d6027e1ecb456d7783d37c155625ef5464c778c452e776f551d8997353b8fd5b1cbbbcf4b34ee5627263aa8d2d9eee339b933f6d6b24c37bd95398deea8317cca3925725ca5c5fb959ee085feafebe9a78c216e0afadcf6b350c0216be0d82fa1baccaaf214520d318fb5c15bbcaa127d853493fabb40d3506");

    constant C_DIN          : std_logic_vector(575 downto 0) := x"000000000000000000000000000000000000000000000000000000000000000000000000000000644188022962773152664452430902332212794328461338468711234890341202";
    constant C_TARGET       : unsigned(255 downto 0) := x"07ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff";
    constant C_GOLDEN_NONCE : integer := 94;
    constant C_NONCE_START  : integer := C_GOLDEN_NONCE - 10; -- excercise code a little

    signal clk              : std_logic := '1';
    signal arst_n           : std_logic := '0';

    type state_type         is (E_IDLE, E_HASH, E_DONE);
    signal state            : state_type;

    signal start            : std_logic;
    signal hash_in          : std_logic_vector(639 downto 0);
    signal hash_in_en       : std_logic;
    signal nonce            : unsigned(63 downto 0);
    signal input_cnt        : unsigned(3 downto 0);
    signal hash_in_cnt      : unsigned(0 downto 0);
    signal matrix_row_in    : std_logic_vector(2047 downto 0);
    signal matrix_row_in_en : std_logic;
    signal matrix_row_req   : std_logic;
    signal matrix_row_idx   : unsigned(2 downto 0);
    signal hash_out         : std_logic_vector(255 downto 0);
    signal hash_out_en      : std_logic;

    signal golden_nonce     : std_logic_vector(63 downto 0);
    signal golden_nonce_en  : std_logic;
    signal golden_hash      : std_logic_vector(255 downto 0);
    signal nonce_mem        : slv_array_type(31 downto 0)(63 downto 0);
    signal nonce_mem_waddr  : unsigned(4 downto 0);
    signal nonce_mem_in     : std_logic_vector(63 downto 0);
    signal nonce_mem_in_en  : std_logic;
    signal nonce_mem_raddr  : unsigned(4 downto 0);
    signal nonce_mem_out    : std_logic_vector(63 downto 0);

begin

    -- clk and arst_n
    clk    <= not clk after C_CLK_PERIOD/2;
    arst_n <= '1' after 10*C_CLK_PERIOD;

    -- send input data
    process begin
        start <= '0';

        wait for 20*C_CLK_PERIOD;

        start <= '1';

        wait for C_CLK_PERIOD;

        start <= '0';

        wait until (golden_nonce_en = '1');
        wait until (golden_nonce_en = '0');
        report "golden nonce: " & integer'image(to_integer(unsigned(golden_nonce)));
        report "golden hash:  0x" & to_hstring(golden_hash);
        stop;
    end process;

    -- nonce control
    process(clk, arst_n) begin
        if (arst_n = '0') then
            state           <= E_IDLE;
            nonce           <= to_unsigned(C_NONCE_START, nonce'length);
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
        elsif rising_edge(clk) then
            hash_in_en      <= '0';
            golden_nonce_en <= '0';
            nonce_mem_in_en <= '0';

            if (nonce_mem_in_en = '1') then
                nonce_mem_waddr <= nonce_mem_waddr + 1;
            end if;
            
            case (state) is
                when E_IDLE =>
                    if (start = '1') then
                        input_cnt       <= to_unsigned(14, input_cnt'length);
                        hash_in_cnt     <= (others => '0');
                        nonce           <= to_unsigned(C_NONCE_START, nonce'length);
                        nonce_mem_raddr <= (others => '0');
                        nonce_mem_waddr <= (others => '0');
                        state           <= E_HASH;
                    end if;
                
                when E_HASH =>
                    if (hash_out_en = '1') then
                        if (unsigned(hash_out) < C_TARGET) then
                            state       <= E_DONE;
                            nonce       <= (others => '0');
                            golden_hash <= hash_out;
                        else
                            nonce_mem_raddr <= nonce_mem_raddr + 1;
                            input_cnt       <= input_cnt + 1;
                        end if;
                    elsif (input_cnt = 14) then
                        hash_in_cnt     <= hash_in_cnt + 1;
                        hash_in         <= std_logic_vector(nonce) & C_DIN;
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
                    state           <= E_IDLE;

                when others =>
                    null;
            end case;
        end if;
    end process;

    -- nonce memory
    process(clk, arst_n) begin
        if (arst_n = '0') then
            nonce_mem     <= (others => (others => '0'));
            nonce_mem_out <= (others => '0');
        elsif rising_edge(clk) then
            if (nonce_mem_in_en = '1') then
                nonce_mem(to_integer(nonce_mem_waddr)) <= std_logic_vector(nonce_mem_in);
            end if;
            nonce_mem_out <= nonce_mem(to_integer(nonce_mem_raddr));
        end if;
    end process;

    -- matrix memory
    process(clk, arst_n) begin
        if (arst_n = '0') then
            matrix_row_in    <= (others => '0');
            matrix_row_in_en <= '0';
        elsif rising_edge(clk) then
            matrix_row_in_en <= '0';

            if (matrix_row_req = '1') then
                matrix_row_in_en <= '1';
                matrix_row_in    <= C_MATRIX_MEM(to_integer(matrix_row_idx));
            end if;
        end if;
    end process;

    -- instantiate hasher
    uut : heavy_hash
        port map (
            CLK              => clk,
            ARST_N           => arst_n,
            DIN_EN           => hash_in_en,
            DIN              => hash_in,
            MATRIX_ROW_IN    => matrix_row_in,
            MATRIX_ROW_IN_EN => matrix_row_in_en,
            MATRIX_ROW_REQ   => matrix_row_req,
            MATRIX_ROW_IDX   => matrix_row_idx,
            DOUT             => hash_out,
            DOUT_EN          => hash_out_en);

end sim;
