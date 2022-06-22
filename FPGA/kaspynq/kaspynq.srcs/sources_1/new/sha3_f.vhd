----------------------------------------------------------------------------------
-- Richie Harris
-- rkharris12@gmail.com
-- 5/6/2022
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;


entity sha3_f is
    port (
        CLK          : in  std_logic;
        ARST_N       : in  std_logic;
        ROUND_CNT    : in  unsigned(4 downto 0);
        STATE_IN     : in  std_logic_vector(1599 downto 0);
        STATE_IN_EN  : in  std_logic;
        STATE_OUT    : out std_logic_vector(1599 downto 0);
        STATE_OUT_EN : out std_logic
    );
end sha3_f;

architecture rtl of sha3_f is

    type slv_array_type is array (natural range <>) of std_logic_vector;
    type integer_array_type is array (natural range <>) of integer;

    function pack_state(
        state_unpacked : std_logic_vector(1599 downto 0))
        return slv_array_type is
        variable temp : slv_array_type(24 downto 0)(63 downto 0);
    begin
        for word in 0 to 24 loop
            temp(word) := state_unpacked(64*(word+1)-1 downto 64*word);
        end loop;
        return temp;
    end pack_state;

    function unpack_state(
        state_packed : slv_array_type(24 downto 0)(63 downto 0))
        return std_logic_vector is
        variable temp : std_logic_vector(1599 downto 0);
    begin
        for word in 0 to 24 loop
            temp(64*(word+1)-1 downto 64*word) := state_packed(word);
        end loop;
        return temp;
    end unpack_state;

    constant C_RHO_ROT_AMT : integer_array_type(0 to 23) := (1, 3, 6, 10, 15, 21, 28, 36, 45, 55, 2, 14, 27, 41, 56, 8, 25, 43, 62, 18, 39, 61, 20, 44);
    constant C_PI_IDX      : integer_array_type(0 to 23) := (10, 7, 11, 17, 18, 3, 5, 16, 8, 21, 24, 4, 15, 23, 19, 13, 12, 2, 20, 14, 22, 9, 6, 1);
    constant C_IOTA_RND    : slv_array_type(0 to 23) := (x"0000000000000001", x"0000000000008082", x"800000000000808a", x"8000000080008000",
                                                           x"000000000000808b", x"0000000080000001", x"8000000080008081", x"8000000000008009",
                                                           x"000000000000008a", x"0000000000000088", x"0000000080008009", x"000000008000000a",
                                                           x"000000008000808b", x"800000000000008b", x"8000000000008089", x"8000000000008003",
                                                           x"8000000000008002", x"8000000000000080", x"000000000000800a", x"800000008000000a",
                                                           x"8000000080008081", x"8000000000008080", x"0000000080000001", x"8000000080008008");

    signal theta_out      : slv_array_type(24 downto 0)(63 downto 0);
    signal state_out_i    : slv_array_type(24 downto 0)(63 downto 0);

    signal state_in_en_d1 : std_logic;

begin

    -- pipelined, latency is 2 cycles
    process(CLK, ARST_N)
        variable state_in_packed : slv_array_type(24 downto 0)(63 downto 0);
        variable t0              : slv_array_type(4 downto 0)(63 downto 0);
        variable t1              : slv_array_type(4 downto 0)(63 downto 0);
        variable rho_pi_out      : slv_array_type(24 downto 0)(63 downto 0);
    begin
        if (ARST_N = '0') then
            theta_out      <= (others => (others => '0'));
            state_out_i    <= (others => (others => '0'));
            state_in_en_d1 <= '0';
            STATE_OUT_EN   <= '0';
        elsif rising_edge(CLK) then
            state_in_en_d1 <= STATE_IN_EN;
            
            -- theta on cycle 1 -------------------------------------------------------------------------------------------------------------------------------
            state_in_packed := pack_state(STATE_IN);
            
            for i in 0 to 4 loop
                t0(i) := state_in_packed(i) xor state_in_packed(5+i) xor state_in_packed(10+i) xor state_in_packed(15+i) xor state_in_packed(20+i); -- C
            end loop;

            t1(0) := t0(4) xor (t0(1)(62 downto 0) & t0(1)(63)); -- D
            t1(1) := t0(0) xor (t0(2)(62 downto 0) & t0(2)(63));
            t1(2) := t0(1) xor (t0(3)(62 downto 0) & t0(3)(63));
            t1(3) := t0(2) xor (t0(4)(62 downto 0) & t0(4)(63));
            t1(4) := t0(3) xor (t0(0)(62 downto 0) & t0(0)(63));

            for i in 0 to 4 loop -- XOR loop
                theta_out(i)    <= t1(i) xor state_in_packed(i);
                theta_out(i+5)  <= t1(i) xor state_in_packed(i+5);
                theta_out(i+10) <= t1(i) xor state_in_packed(i+10);
                theta_out(i+15) <= t1(i) xor state_in_packed(i+15);
                theta_out(i+20) <= t1(i) xor state_in_packed(i+20);
            end loop;

            -- rho pi chi iota on cycle 2 ---------------------------------------------------------------------------------------------------------------------
            rho_pi_out(C_PI_IDX(0)) := theta_out(1)(64-C_RHO_ROT_AMT(0)-1 downto 0) & theta_out(1)(63 downto 64-C_RHO_ROT_AMT(0));
            for i in 1 to 23 loop
                rho_pi_out(C_PI_IDX(i)) := theta_out(C_PI_IDX(i-1))(64-C_RHO_ROT_AMT(i)-1 downto 0) & theta_out(C_PI_IDX(i-1))(63 downto 64-C_RHO_ROT_AMT(i));
            end loop;
            rho_pi_out(0) := theta_out(0);

            state_out_i(0) <= rho_pi_out(0) xor ((not rho_pi_out(1)) and rho_pi_out(2)) xor C_IOTA_RND(to_integer(ROUND_CNT));
            state_out_i(1) <= rho_pi_out(1) xor ((not rho_pi_out(2)) and rho_pi_out(3));
            state_out_i(2) <= rho_pi_out(2) xor ((not rho_pi_out(3)) and rho_pi_out(4));
            state_out_i(3) <= rho_pi_out(3) xor ((not rho_pi_out(4)) and rho_pi_out(0));
            state_out_i(4) <= rho_pi_out(4) xor ((not rho_pi_out(0)) and rho_pi_out(1));

            state_out_i(5) <= rho_pi_out(5) xor ((not rho_pi_out(6)) and rho_pi_out(7));
            state_out_i(6) <= rho_pi_out(6) xor ((not rho_pi_out(7)) and rho_pi_out(8));
            state_out_i(7) <= rho_pi_out(7) xor ((not rho_pi_out(8)) and rho_pi_out(9));
            state_out_i(8) <= rho_pi_out(8) xor ((not rho_pi_out(9)) and rho_pi_out(5));
            state_out_i(9) <= rho_pi_out(9) xor ((not rho_pi_out(5)) and rho_pi_out(6));

            state_out_i(10) <= rho_pi_out(10) xor ((not rho_pi_out(11)) and rho_pi_out(12));
            state_out_i(11) <= rho_pi_out(11) xor ((not rho_pi_out(12)) and rho_pi_out(13));
            state_out_i(12) <= rho_pi_out(12) xor ((not rho_pi_out(13)) and rho_pi_out(14));
            state_out_i(13) <= rho_pi_out(13) xor ((not rho_pi_out(14)) and rho_pi_out(10));
            state_out_i(14) <= rho_pi_out(14) xor ((not rho_pi_out(10)) and rho_pi_out(11));

            state_out_i(15) <= rho_pi_out(15) xor ((not rho_pi_out(16)) and rho_pi_out(17));
            state_out_i(16) <= rho_pi_out(16) xor ((not rho_pi_out(17)) and rho_pi_out(18));
            state_out_i(17) <= rho_pi_out(17) xor ((not rho_pi_out(18)) and rho_pi_out(19));
            state_out_i(18) <= rho_pi_out(18) xor ((not rho_pi_out(19)) and rho_pi_out(15));
            state_out_i(19) <= rho_pi_out(19) xor ((not rho_pi_out(15)) and rho_pi_out(16));

            state_out_i(20) <= rho_pi_out(20) xor ((not rho_pi_out(21)) and rho_pi_out(22));
            state_out_i(21) <= rho_pi_out(21) xor ((not rho_pi_out(22)) and rho_pi_out(23));
            state_out_i(22) <= rho_pi_out(22) xor ((not rho_pi_out(23)) and rho_pi_out(24));
            state_out_i(23) <= rho_pi_out(23) xor ((not rho_pi_out(24)) and rho_pi_out(20));
            state_out_i(24) <= rho_pi_out(24) xor ((not rho_pi_out(20)) and rho_pi_out(21));

            STATE_OUT_EN    <= state_in_en_d1;
        end if;
    end process;

    STATE_OUT <= unpack_state(state_out_i);

end rtl;
