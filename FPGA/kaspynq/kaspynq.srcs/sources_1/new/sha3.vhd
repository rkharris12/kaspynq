----------------------------------------------------------------------------------
-- Richie Harris
-- rkharris12@gmail.com
-- 5/6/2022
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;


entity sha3 is
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
end sha3;

architecture rtl of sha3 is

    type slv_array_type is array (natural range <>) of std_logic_vector;
    type unsigned_array_type is array (natural range <>) of unsigned;

    component sha3_f is
        port (
            CLK          : in  std_logic;
            ARST_N       : in  std_logic;
            ROUND_CNT    : in  unsigned(4 downto 0);
            STATE_IN     : in  std_logic_vector(1599 downto 0);
            STATE_IN_EN  : in  std_logic;
            STATE_OUT    : out std_logic_vector(1599 downto 0);
            STATE_OUT_EN : out std_logic
        );
    end component;

    constant C_NUM_F_ROUNDS   : integer := 24;
    constant C_ROUNDS_PER_F   : integer := 24 / G_NUM_PARALLEL_F;
    constant C_SHA3_F_LATENCY : integer := 2;

    constant C_DELIMITER      : std_logic_vector(7 downto 0) := x"04";
    constant C_SUFFIX         : std_logic_vector(7 downto 0) := x"80";

    type state_type is (E_IDLE, E_STARTUP, E_HASH);
    signal state              : state_type;

    signal f_cnt              : unsigned(0 downto 0);
    signal valid_output       : std_logic;
    signal round_cnt_arr      : unsigned_array_type(G_NUM_PARALLEL_F-1 downto 0)(4 downto 0);
    signal feedback           : std_logic;

    signal state_in_arr       : slv_array_type(G_NUM_PARALLEL_F-1 downto 0)(1599 downto 0);
    signal state_in_en_slv    : std_logic_vector(G_NUM_PARALLEL_F-1 downto 0);
    signal state_out_arr      : slv_array_type(G_NUM_PARALLEL_F-1 downto 0)(1599 downto 0);
    signal state_out_en_slv   : std_logic_vector(G_NUM_PARALLEL_F-1 downto 0);

begin

    -- main FSM
    process(CLK, ARST_N) begin
        if (ARST_N = '0') then
            state         <= E_IDLE;
            f_cnt         <= (others => '0');
            valid_output  <= '0';
            round_cnt_arr <= (others => (others => '0'));
        elsif rising_edge(CLK) then
            case (state) is
                when E_IDLE =>
                    valid_output <= '0';
                    if (DIN_EN = '1') then
                        state         <= E_STARTUP;
                        f_cnt         <= (others => '0');
                        round_cnt_arr <= (others => (others => '0'));
                    end if;

                when E_STARTUP =>
                    state <= E_HASH;
                    f_cnt <= f_cnt + 1;

                when E_HASH =>
                    f_cnt <= f_cnt + 1;
                    if (f_cnt = C_SHA3_F_LATENCY-1) then
                        for i in 0 to G_NUM_PARALLEL_F-1 loop
                            round_cnt_arr(i) <= round_cnt_arr(i) + 1;
                        end loop;
                        if (round_cnt_arr(0) = C_ROUNDS_PER_F-1) then
                            round_cnt_arr(0) <= (others => '0');
                            if (G_NUM_PARALLEL_F > 1) then
                                for i in 1 to G_NUM_PARALLEL_F-1 loop
                                    round_cnt_arr(i) <= round_cnt_arr(i-1) + 1;
                                end loop;
                            end if;
                        end if;
                    end if;
                    if ((round_cnt_arr(G_NUM_PARALLEL_F-1) = C_NUM_F_ROUNDS-1) and (f_cnt = C_SHA3_F_LATENCY-1) and (DIN_EN = '0')) then
                        state <= E_IDLE;
                    end if;
                    if ((round_cnt_arr(G_NUM_PARALLEL_F-1) = C_NUM_F_ROUNDS-1) and (f_cnt = 0)) then
                        valid_output <= '1';
                    end if;

                when others => null;
            end case;
        end if;
    end process;

    feedback <= '0' when ((DIN_EN = '1') or ((state = E_HASH) and (((round_cnt_arr(0) = C_ROUNDS_PER_F-1) and (f_cnt = C_SHA3_F_LATENCY-1)) or
                                            (((round_cnt_arr(0) = 0) and (f_cnt = 0)))))) else '1';

    -- choose to feed in or feed back state and enables
    process(all) begin
        if (feedback = '1') then
            state_in_en_slv <= state_out_en_slv;
            for i in 0 to G_NUM_PARALLEL_F-1 loop
                state_in_arr(i) <= state_out_arr(i);
            end loop;
        else
            state_in_en_slv(0) <= DIN_EN;
            if (G_NUM_PARALLEL_F > 1) then
                state_in_en_slv(G_NUM_PARALLEL_F-1 downto 1) <= state_out_en_slv(G_NUM_PARALLEL_F-2 downto 0);
            end if;
            state_in_arr(0)(G_NUM_INPUT_BITS-1 downto 0)                <= G_INIT_STATE(G_NUM_INPUT_BITS-1 downto 0) xor DIN;
            state_in_arr(0)(G_NUM_INPUT_BITS+7 downto G_NUM_INPUT_BITS) <= G_INIT_STATE(G_NUM_INPUT_BITS+7 downto G_NUM_INPUT_BITS) xor C_DELIMITER;
            state_in_arr(0)(1079 downto G_NUM_INPUT_BITS+8)             <= G_INIT_STATE(1079 downto G_NUM_INPUT_BITS+8);
            state_in_arr(0)(1087 downto 1080)                           <= G_INIT_STATE(1087 downto 1080) xor C_SUFFIX;
            state_in_arr(0)(1599 downto 1088)                           <= G_INIT_STATE(1599 downto 1088);
            if (G_NUM_PARALLEL_F > 1) then
                for i in 1 to G_NUM_PARALLEL_F-1 loop
                    state_in_arr(i) <= state_out_arr(i-1);
                end loop;
            end if;
        end if;
    end process;

    -- instantiate the number of parallel f functions we want
    GEN_F_FUNCTIONS : for i in 0 to G_NUM_PARALLEL_F-1 generate
        sha3_f_x : sha3_f
            port map (
                CLK          => CLK,
                ARST_N       => ARST_N,
                ROUND_CNT    => round_cnt_arr(i),
                STATE_IN     => state_in_arr(i),
                STATE_IN_EN  => state_in_en_slv(i),
                STATE_OUT    => state_out_arr(i),
                STATE_OUT_EN => state_out_en_slv(i));
    end generate;

    DOUT    <= state_out_arr(G_NUM_PARALLEL_F-1)(255 downto 0);
    DOUT_EN <= state_out_en_slv(G_NUM_PARALLEL_F-1) and valid_output and (not feedback);

end rtl;
